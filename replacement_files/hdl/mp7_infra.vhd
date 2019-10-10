-- mp7_infra
--
-- All board-specific stuff goes here. Wrapper for ethernet, ipbus, MMC link
-- and various clock control interfaces
--
-- All clocks are derived from 125MHz xtal clock for backplane ethernet serdes
--
-- Dave Newbold, June 2013

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.ipbus.all;
use work.ipbus_trans_decl.all;
use work.ipbus_decode_mp7_infra.all;

entity mp7_infra is
	generic(
		-- the following two generics are now obsolete and have no
		-- effect anymore. MAC and IP address are taken from IPbus
		-- configuration space, which is controlled by the MMC. I leave
		-- the generics in for now to make it easier to revert to hard-
		-- coded MAC/IP address for debugging. In order to do this, set
		-- MAC_CFG and IP_CFG in ipbus_ctrl (see below) to EXTERNAL.  
		MAC_ADDR: std_logic_vector(47 downto 0) := X"080030f3038f"; --X"000000000000";
		IP_ADDR: std_logic_vector(31 downto 0) := X"c0A80161" -- fixed: 192.168.1.97 --X"00000000"
	);
	port(
		gt_clkp, gt_clkn: in std_logic; -- ethernet serdes signals
		gt_txp, gt_txn: out std_logic;
		gt_rxp, gt_rxn: in std_logic;
		leds: out std_logic_vector(11 downto 0); -- status LEDs
		clk_ipb: out std_logic; -- ipbus clock (nominally ~30MHz) & reset
		rst_ipb: out std_logic;
		clk40ish: out std_logic; -- "pseudo 40MHz" clock for running without TTC
		clk_fr: out std_logic; -- 125MHz free-running clock & reset (for reset state machines)
		rst_fr: out std_logic;
		refclk_out: out std_logic;
		nuke: in std_logic; -- The signal of doom
		soft_rst: in std_logic; -- The signal of lesser doom
		oc_flag: in std_logic;
		ec_flag: in std_logic;
		mac_addr_u: in std_logic_vector(47 downto 0);
		ip_addr_u: in std_logic_vector(31 downto 0);
		ipb_in_ctrl: in ipb_rbus; -- ipbus signals to top-level slaves
		ipb_out_ctrl: out ipb_wbus;
		ipb_in_ttc: in ipb_rbus;
		ipb_out_ttc: out ipb_wbus;
		ipb_in_datapath: in ipb_rbus;
		ipb_out_datapath: out ipb_wbus;
		ipb_in_readout: in ipb_rbus;
		ipb_out_readout: out ipb_wbus;
		ipb_in_payload: in ipb_rbus;
		ipb_out_payload: out ipb_wbus
	);

end mp7_infra;

architecture rtl of mp7_infra is

	signal clk125_fr, clk125, clk200, ipb_clk, clk_locked, locked, eth_locked: std_logic;
	signal rsti_125, rsti_ipb, rsti_eth, rsti_ipb_ctrl, onehz, rsti_fr: std_logic;
	signal mac_tx_data, mac_rx_data: std_logic_vector(7 downto 0);
	signal mac_tx_valid, mac_tx_last, mac_tx_error, mac_tx_ready, mac_rx_valid, mac_rx_last, mac_rx_error: std_logic;
	signal pkt, pkt_oob: std_logic;
	signal ipb_out_m: ipb_wbus;
	signal ipb_in_m: ipb_rbus;
	signal oob_in: ipbus_trans_in;
	signal oob_out: ipbus_trans_out;
	signal uc_wdata, test_wdata, uc_rdata, test_rdata, mmc_wdata, mmc_rdata: std_logic_vector(15 downto 0);
	signal uc_we, test_we, uc_re, test_re, mmc_we, mmc_re: std_logic;
	signal uc_req, test_req, uc_bdone, test_bdone, mmc_req, mmc_done: std_logic;
	signal ipbw: ipb_wbus_array(N_SLAVES - 1 downto 0);
	signal ipbr: ipb_rbus_array(N_SLAVES - 1 downto 0);
	signal led_q: std_logic_vector(3 downto 0);
	
	attribute KEEP: string;	
	attribute KEEP of clk125_fr: signal is "TRUE";	

begin

-- DCM clock generation for ipbus, ethernet, POR

	clocks: entity work.clocks_7s_serdes
		port map(
			clki_fr => clk125_fr,
			clki_125 => clk125,
			clko_ipb => ipb_clk,
			clko_p40 => clk40ish,
			clko_200 => clk200,
			eth_locked => eth_locked,
			locked => clk_locked,
			nuke => nuke,
			soft_rst => soft_rst,
			rsto_125 => rsti_125,
			rsto_ipb => rsti_ipb,
			rsto_eth => rsti_eth,
			rsto_ipb_ctrl => rsti_ipb_ctrl,
			rsto_fr => rsti_fr,
			onehz => onehz
		);
		
	locked <= clk_locked and eth_locked;
	
-- The Most Important Part: flashing lights
-- Arranged as LED_B B,G,R; LED_D (top) B,G,R; LED_A (bot) B, G, R; LED_C B,G,R 
-- LED D: TTS status; LED C: orb / evt ctr monitor; LED B: pkt monitor; LED A: clock monitor
	
	stretch: entity work.led_stretcher
		generic map(
			WIDTH => 4
		)
		port map(
			clk => clk125,
			d(0) => pkt,
			d(1) => pkt_oob,
			d(2) => oc_flag,
			d(3) => ec_flag,
			q => led_q
		);

	leds <= '1' & not led_q(1) & not led_q(0) & "111" & '1' & not (locked and onehz) & locked & '1' & not led_q(3) & not led_q(2);
	
-- Clocks for rest of logic

	clk_ipb <= ipb_clk;
	rst_ipb <= rsti_ipb;
	clk_fr <= clk125_fr;
	rst_fr <= rsti_fr;

-- Ethernet MAC core and PHY interface
	
	eth: entity work.eth_7s_1000basex
		port map(
			gt_clkp => gt_clkp,
			gt_clkn => gt_clkn,
			gt_txp => gt_txp,
			gt_txn => gt_txn,
			gt_rxp => gt_rxp,
			gt_rxn => gt_rxn,
			clk125_out => clk125,
			clk125_fr => clk125_fr,
			refclk_out => refclk_out,
			rsti => rsti_eth,
			locked => eth_locked,
			tx_data => mac_tx_data,
			tx_valid => mac_tx_valid,
			tx_last => mac_tx_last,
			tx_error => mac_tx_error,
			tx_ready => mac_tx_ready,
			rx_data => mac_rx_data,
			rx_valid => mac_rx_valid,
			rx_last => mac_rx_last,
			rx_error => mac_rx_error
		);
	
-- ipbus control logic

	ipbus: entity work.ipbus_ctrl
		generic map(
			MAC_CFG => EXTERNAL, --INTERNAL,
			IP_CFG => EXTERNAL, --INTERNAL,
			N_OOB => 1
		)
		port map(
			mac_clk => clk125,
			rst_macclk => rsti_125,
			ipb_clk => ipb_clk,
			rst_ipb => rsti_ipb_ctrl,
			mac_rx_data => mac_rx_data,
			mac_rx_valid => mac_rx_valid,
			mac_rx_last => mac_rx_last,
			mac_rx_error => mac_rx_error,
			mac_tx_data => mac_tx_data,
			mac_tx_valid => mac_tx_valid,
			mac_tx_last => mac_tx_last,
			mac_tx_error => mac_tx_error,
			mac_tx_ready => mac_tx_ready,
			ipb_out => ipb_out_m,
			ipb_in => ipb_in_m,
			mac_addr => mac_addr_u,
			ip_addr => ip_addr_u,
			pkt => pkt,
			pkt_oob => pkt_oob,
			oob_in(0) => oob_in,
			oob_out(0) => oob_out
		);


-- ipbus address decode
		
	fabric: entity work.ipbus_fabric_sel
    generic map(
    	NSLV => N_SLAVES,
    	SEL_WIDTH => IPBUS_SEL_WIDTH)
    port map(
      ipb_in => ipb_out_m,
      ipb_out => ipb_in_m,
      sel => ipbus_sel_mp7_infra(ipb_out_m.ipb_addr),
      ipb_to_slaves => ipbw,
      ipb_from_slaves => ipbr
    );

	ipb_out_ctrl <= ipbw(N_SLV_CTRL);
	ipbr(N_SLV_CTRL) <= ipb_in_ctrl;
	ipb_out_ttc <= ipbw(N_SLV_TTC);
	ipbr(N_SLV_TTC) <= ipb_in_ttc;
	ipb_out_datapath <= ipbw(N_SLV_DATAPATH);
	ipbr(N_SLV_DATAPATH) <= ipb_in_datapath;
	ipb_out_readout <= ipbw(N_SLV_READOUT);
	ipbr(N_SLV_READOUT) <= ipb_in_readout;
	ipb_out_payload <= ipbw(N_SLV_PAYLOAD);
	ipbr(N_SLV_PAYLOAD) <= ipb_in_payload;

end rtl;
