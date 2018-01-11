-- Top-level design for AMC502 base firmware
--
-- Dave Newbold, July 2012
-- Nikitas Loukas, March 2016

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use work.ipbus.all;
use work.ipbus_trans_decl.all;
use work.mp7_data_types.all;
use work.mp7_readout_decl.all;
use work.mp7_ttc_decl.all;
use work.mp7_brd_decl.all;

entity top is
    port(
	eth_clkp, eth_clkn: in std_logic;
        eth_txp, eth_txn: out std_logic;
        eth_rxp, eth_rxn: in std_logic;
        -- LEDs out --------------------------------
        leds_gpoi: out std_logic_vector(3 downto 0);
        -- 40MHz clk --------------
        clk40_in_p: in std_logic;
        clk40_in_n: in std_logic;
        -- AMC13 TTC input --------
        ttc_in_p: in std_logic;
        ttc_in_n: in std_logic;
        -- user sw input ---------------------------
        user:    in std_logic_vector(6 downto 0); -- 7 User DIP switches
        --fmc1_la17_p, fmc1_la13_n, fmc1_la10_p, fmc1_la06_n, fmc1_la15_p, fmc1_la11_n, fmc1_la08_p, fmc1_la04_n : out std_logic; -- quad_0
        --fmc1_la33_p, fmc1_la29_n, fmc1_la26_p, fmc1_la22_n, fmc1_la31_p, fmc1_la27_n, fmc1_la24_p, fmc1_la20_n : out std_logic; -- quad_1
--      fmc0_la17_p, fmc0_la13_n, fmc0_la10_p, fmc0_la06_n, fmc0_la15_p, fmc0_la11_n, fmc0_la08_p, fmc0_la04_n : out std_logic; -- quad_2
--      fmc0_la33_p, fmc0_la29_n, fmc0_la26_p, fmc0_la22_n, fmc0_la31_p, fmc0_la27_n, fmc0_la24_p, fmc0_la20_n : out std_logic; -- quad_3
        -- FMC0 LA
        FMC0_LA00_CC_P      : in std_logic;
        FMC0_LA01_CC_P      : in std_logic;
        FMC0_LA02_P         : in std_logic;
        FMC0_LA03_P         : in std_logic;
        FMC0_LA04_P         : in std_logic;
        FMC0_LA05_P         : in std_logic;
        FMC0_LA06_P         : out std_logic;
        FMC0_LA07_P         : out std_logic;
        -- FMC1 LA
        FMC1_LA00_CC_P      : in std_logic;
        FMC1_LA01_CC_P      : in std_logic;
        FMC1_LA02_P         : in std_logic;
        FMC1_LA03_P         : in std_logic;
        FMC1_LA04_P         : in std_logic;
        FMC1_LA05_P         : in std_logic;
        FMC1_LA06_P         : out std_logic;
        FMC1_LA07_P         : out std_logic;

        -- refclk ------------------------------------------
        refclkp: in std_logic_vector(N_REFCLK - 1 downto 0);
        refclkn: in std_logic_vector(N_REFCLK - 1 downto 0)
    );

end top;

architecture rtl of top is
	
	signal clk_ipb, rst_ipb, clk40ish, clk40, rst40, eth_refclk: std_logic;
	signal clk40_rst, clk40_sel, clk40_lock, clk40_stop, nuke, soft_rst: std_logic;
	signal clk_p, rst_p: std_logic;
	signal clks_aux, rsts_aux: std_logic_vector(2 downto 0);
	
	signal ipb_in_ctrl, ipb_in_ttc, ipb_in_datapath, ipb_in_readout, ipb_in_payload, ipb_in_formatter: ipb_wbus;
	signal ipb_out_ctrl, ipb_out_ttc, ipb_out_datapath, ipb_out_readout, ipb_out_payload, ipb_out_formatter: ipb_rbus;
	
	signal payload_d, payload_q: ldata(N_REGION * 4	- 1 downto 0);
	signal qsel: std_logic_vector(7 downto 0);
	signal board_id: std_logic_vector(31 downto 0);
	signal ttc_l1a, ttc_l1a_dist, dist_lock, oc_flag, ec_flag, payload_bc0, ttc_l1a_throttle, ttc_l1a_flag: std_logic;
	signal ttc_cmd, ttc_cmd_dist: ttc_cmd_t;
	signal bunch_ctr: bctr_t;
	signal evt_ctr, orb_ctr: eoctr_t;
	signal tmt_sync: tmt_sync_t;
	
	signal clkmon: std_logic_vector(2 downto 0);
	
	signal cap_bus: daq_cap_bus;
	signal daq_bus_top, daq_bus_bot: daq_bus;
	signal ctrs: ttc_stuff_array(N_REGION - 1 downto 0);
	signal rst_loc, clken_loc: std_logic_vector(N_REGION - 1 downto 0);

	signal leds: std_logic_vector(11 downto 0);
	
	    -- user signals
	signal board_mac  :  std_logic_vector(47 downto 0) := X"1EED19271A12";
	signal board_ip   :  std_logic_vector(31 downto 0) := X"C0A801D3";

	signal finor_in: std_logic_vector(5 downto 0);
	signal veto_in: std_logic_vector(5 downto 0);
	signal finor_2_tcds: std_logic_vector(3 downto 0);

begin

----sfps-enable-----------------------
-- 	fmc1_la17_p<='0'; fmc1_la13_n<='0'; fmc1_la10_p<='0'; fmc1_la06_n<='0'; fmc1_la15_p<='0'; fmc1_la11_n<='0'; fmc1_la08_p<='0'; fmc1_la04_n<='0'; --0
-- 	fmc1_la33_p<='0'; fmc1_la29_n<='0'; fmc1_la26_p<='0'; fmc1_la22_n<='0'; fmc1_la31_p<='0'; fmc1_la27_n<='0'; fmc1_la24_p<='0'; fmc1_la20_n<='0'; --1
--	fmc0_la17_p<='0'; fmc0_la13_n<='0'; fmc0_la10_p<='0'; fmc0_la06_n<='0'; fmc0_la15_p<='0'; fmc0_la11_n<='0'; fmc0_la08_p<='0'; fmc0_la04_n<='0'; --2
--	fmc0_la33_p<='0'; fmc0_la29_n<='0'; fmc0_la26_p<='0'; fmc0_la22_n<='0'; fmc0_la31_p<='0'; fmc0_la27_n<='0'; fmc0_la24_p<='0'; fmc0_la20_n<='0'; --3

-- comments --
--	leds <= '1' & not led_q(1) & not led_q(0) & "111" & '1' & not (locked and onehz) & locked & '1' & not led_q(3) & not led_q(2);
	leds_gpoi <= leds(4) & leds(3) & not leds(1) & not leds(0);
--	             onehz     locked        led_q(3)      led_q(2)
--------------

-- Clocks and control IO

	infra: entity work.mp7_infra
		port map(
			gt_clkp => eth_clkp,
			gt_clkn => eth_clkn,
			gt_txp => eth_txp,
			gt_txn => eth_txn,
			gt_rxp => eth_rxp,
			gt_rxn => eth_rxn,
			leds => leds,
			clk_ipb => clk_ipb,
			rst_ipb => rst_ipb,
			clk40ish => clk40ish,
			refclk_out => eth_refclk,
			nuke => nuke,
			soft_rst => soft_rst,
			oc_flag => oc_flag,
			ec_flag => ec_flag,
			mac_addr_u => board_mac,
			ip_addr_u => board_ip,
			ipb_in_ctrl => ipb_out_ctrl,
			ipb_out_ctrl => ipb_in_ctrl,
			ipb_in_ttc => ipb_out_ttc,
			ipb_out_ttc => ipb_in_ttc,
			ipb_in_datapath => ipb_out_datapath,
			ipb_out_datapath => ipb_in_datapath,
			ipb_in_readout => ipb_out_readout,
			ipb_out_readout => ipb_in_readout,
			ipb_in_payload => ipb_out_payload,
			ipb_out_payload => ipb_in_payload
		);

-- Control registers and board IO
		
	ctrl: entity work.mp7_ctrl
		port map(
			clk => clk_ipb,
			rst => rst_ipb,
			ipb_in => ipb_in_ctrl,
			ipb_out => ipb_out_ctrl,
			nuke => nuke,
			soft_rst => soft_rst,
			board_id => board_id,
			clk40_rst => clk40_rst,
			clk40_sel => clk40_sel,
			clk40_lock => clk40_lock,
			clk40_stop => clk40_stop
		);

-- TTC signal handling
	
	ttc: entity work.mp7_ttc
		port map(
			clk => clk_ipb,
			rst => rst_ipb,
			mmcm_rst => clk40_rst,
			sel => clk40_sel,
			lock => clk40_lock,
			stop => clk40_stop,
			ipb_in => ipb_in_ttc,
			ipb_out => ipb_out_ttc,
			clk40_in_p => clk40_in_p,
			clk40_in_n => clk40_in_n,
			clk40ish_in => clk40ish,
			clk40 => clk40,
			rst40 => rst40,
			clk_p => clk_p,
			rst_p => rst_p,
			clks_aux => clks_aux,
			rsts_aux => rsts_aux,
			ttc_in_p => ttc_in_p,
			ttc_in_n => ttc_in_n,
			ttc_cmd => ttc_cmd,
			ttc_cmd_dist => ttc_cmd_dist,
			ttc_l1a => ttc_l1a,
			ttc_l1a_flag => ttc_l1a_flag,
			ttc_l1a_dist => ttc_l1a_dist,
			l1a_throttle => ttc_l1a_throttle,
			dist_lock => dist_lock,
			bunch_ctr => bunch_ctr,
			evt_ctr => evt_ctr,
			orb_ctr => orb_ctr,
			oc_flag => oc_flag,
			ec_flag => ec_flag,
			tmt_sync => tmt_sync,
			monclk => clkmon
		);

-- MGTs, buffers and TTC fanout
		
	datapath: entity work.mp7_datapath
		port map(
			clk => clk_ipb,
			rst => rst_ipb,
			ipb_in => ipb_in_datapath,
			ipb_out => ipb_out_datapath,
			board_id => board_id,
			clk40 => clk40,
			clk_p => clk_p,
			rst_p => rst_p,
			ttc_cmd => ttc_cmd_dist,
			ttc_l1a => ttc_l1a_dist,
			lock => dist_lock,
			ctrs_out => ctrs,
			rst_out => rst_loc,
			clken_out => clken_loc,
			tmt_sync => tmt_sync,
			cap_bus => cap_bus,
			daq_bus_in => daq_bus_top,
			daq_bus_out => daq_bus_bot,
			payload_bc0 => payload_bc0,
			refclkp => refclkp,
			refclkn => refclkn,
			clkmon => clkmon,
			q => payload_d,
			d => payload_q
		);

-- Readout
		
	readout: entity work.mp7_readout
		port map(
			clk => clk_ipb,
			rst => rst_ipb,
			ipb_in => ipb_in_readout,
			ipb_out => ipb_out_readout,
			board_id => board_id,
			ttc_clk => clk40,
			ttc_rst => rst40,
			ttc_cmd => ttc_cmd,
			l1a => ttc_l1a,
			l1a_flag => ttc_l1a_flag,
			l1a_throttle => ttc_l1a_throttle,
			bunch_ctr => bunch_ctr,
			evt_ctr => evt_ctr,
			orb_ctr => orb_ctr,			
			clk_p => clk_p,
			rst_p => rst_p,
			cap_bus => cap_bus,
			daq_bus_out => daq_bus_top,
			daq_bus_in => daq_bus_bot,
			amc13_refclk => eth_refclk
		);

-- Payload
		
	payload: entity work.mp7_payload
		port map(
			clk => clk_ipb,
			rst => rst_ipb,
			ipb_in => ipb_in_payload,
			ipb_out => ipb_out_payload,
-- HB 2016-09-28: used clks_aux(0) for input FFs, internals and output FFs (clks_aux(0) with 45 degree phase shift to clk40_in, see ttc_clocks.vhd)
			clks_aux_0 => clks_aux(0),
			rst_aux_0 => rsts_aux(0),
			clk_p => clk_p,
			rst_loc => rst_loc,
			clken_loc => clken_loc,
			board_mac_o => board_mac,
			board_ip_o => board_ip,
			ctrs => ctrs,
			bc0 => payload_bc0,
			user_sw => user,
                        finor_in => finor_in,
                        veto_in => veto_in,
                        finor_2_tcds => finor_2_tcds,
			d => payload_d,
			q => payload_q
		);
		
-----------------------------------------------------------------------
-- HB 2016-02-11: see HFMC-FINOR (HW).

    finor_in(0)     <=    FMC0_LA00_CC_P;
    finor_in(1)     <=    FMC0_LA01_CC_P;
    finor_in(2)     <=    FMC0_LA02_P;

    veto_in(0)     <=    FMC0_LA03_P;
    veto_in(1)     <=    FMC0_LA04_P;
    veto_in(2)     <=    FMC0_LA05_P;

    FMC0_LA06_P    <=    finor_2_tcds(0); -- output to TCDS
    FMC0_LA07_P    <=    finor_2_tcds(1); -- optional output to TCDS (could be used for test outputs, too)

    finor_in(3)     <=    FMC1_LA00_CC_P;
    finor_in(4)     <=    FMC1_LA01_CC_P;
    finor_in(5)     <=    FMC1_LA02_P;

    veto_in(3)     <=    FMC1_LA03_P;
    veto_in(4)     <=    FMC1_LA04_P;
    veto_in(5)     <=    FMC1_LA05_P;

    FMC1_LA06_P    <=    finor_2_tcds(2); -- optional output to TCDS (could be used for test outputs, too)
    FMC1_LA07_P    <=    finor_2_tcds(3); -- optional output to TCDS (could be used for test outputs, too)

-----------------------------------------------------------------------

end rtl;
