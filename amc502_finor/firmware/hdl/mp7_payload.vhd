
-- HB 2016-09-28: 0x1010 => based on v100F, but no testpoints. IOB register for finor_in and veto_in, IOB output register for finor_2_tcds (see ../ucf/mp7_null_algo.tcl).
--                          Inserted "dont_touch" attribute for finor_total_2_out and used neg. edge of clks_aux_0 for output register to get the same conditions for TCDS as with 0x100C.
--                          Removed unused inputs clks_aux_1 and rst_aux_1.
-- HB 2016-09-28: 0xB013 => TESTVERSION - based on vB012, but used neg. edge of clks_aux_0 for output register (in vB011 outputs to TCDS to early ~3 ns).
-- HB 2016-09-28: 0xB012 => TESTVERSION - based on vB011, but no testpoints. IOB register for finor_in and veto_in, IOB output register for finor_2_tcds (see ../ucf/mp7_null_algo.tcl).
--                          Inserted "dont_touch" attribute for finor_total_2_out.
-- HB 2016-09-27: 0xB011 => TESTVERSION - based on v100F, but changed to unclocked testpoints, output to TCDS is clocked before testpoints mux.
-- HB 2016-09-26: 0x100F => based on v100E, but used pos. edge of clks_aux(0) for input FFs and internals, used neg. edge of clks_aux(1) for output FFs. New ports clks_aux_0 and clks_aux_1 used.
-- JW 2016-09-22: 0x100E => based on v100C, but shifted the phase of the payload_clk(0) by 45deg (3,125 ns) to be in phase with the MP7 payload clk.
-- JW 2016-09-22: 0x100C => based on v100A, but fixed the finor signal issue by moving the mask_inputs logic block.
-- HB 2016-09-02: 0x100A => based on v1009, but changed logic for enabling inputs, default => inputs disabled, writing 1 to register enables input.
-- HB 2016-09-01: 0x1009 => based on v1008, but implemented register for disabling inputs (finors and vetos).
-- JW 2016-08-29: 0x1008 => based on v1007, but extended ip addresses for P5 testcrate.
-- HB 2016-08-18: 0x1007 => same payload logic as v1006, but used mp7 fw v2_2_0. Regeneration of some IPs in Vivado GUI was neccessary!!!
--                          Used clks_aux(0) for clk_payload in mp7_690es.vhd, not sure whether this is ok !!!
-- HB 2016-06-28: 0x1006 => based on v1005, but used new tcm.vhd, update algo_rate_counter.vhd and implemented selection for signals on LEMO outputs (for tests).
-- HB 2016-06-23: 0x1005 => based on v1004, but used LUM_SEG_PERIOD_MSK_RESET as fix value for lumi section length in tcm.vhd.
-- HB 2016-06-22: 0x1004 => updated for OC0 in tcm. Used module module_info_status_regs(0) for version number.
--                          Inserted spytrigger and delay (1 bx) for finor/veto_in_s_2_spy, to occur in same memory-addresss as finor_2_tcds_2_spy.
-- HB 2016-04-27: updated for synchronized BGos and new tcm

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

use work.ipbus.all;
use work.ipbus_reg_types.all;
use work.mp7_data_types.all;
-- use work.lhc_data_pkg.all;
use work.top_decl.all;
use work.mp7_brd_decl.all;
use work.mp7_ttc_decl.all;
use work.user_package.all;
use work.ipbus_decode_mp7_payload.all;
use work.gt_mp7_core_pkg.all;

entity mp7_payload is
	generic(
		NR_FINORS_VETOS: positive := 6;
		FINOR_RATE_COUNTER_WIDTH: positive := 32
	);
	port(
		clk: in std_logic; -- ipbus signals
		rst: in std_logic;
		ipb_in: in ipb_wbus;
		ipb_out: out ipb_rbus;
		clks_aux_0: in std_logic;-- 40MHz LHC clk with 45 degree phase shift for inputs
		rst_aux_0: in std_logic;--reset 40MHz
		clk_p: in std_logic; -- data clock
        	rst_loc: in std_logic_vector(N_REGION - 1 downto 0);
        	clken_loc: in std_logic_vector(N_REGION - 1 downto 0);
		ctrs: in ttc_stuff_array;
		bc0: out std_logic;
		user_sw: in  std_logic_vector(6 downto 0); -- sw1 on amc502
		finor_in: in  std_logic_vector(5 downto 0); -- inputs from FINOR-FMC
		veto_in: in  std_logic_vector(5 downto 0); -- inputs from FINOR-FMC
		finor_2_tcds: out  std_logic_vector(3 downto 0); -- outputs to FINOR-FMC
        	board_mac_o: out std_logic_vector(47 downto 0); -- sets the mac address in infra
        	board_ip_o: out std_logic_vector(31 downto 0); -- sets the ip address in infra
		d: in ldata(4 * N_REGION - 1 downto 0); -- data in
		q: out ldata(4 * N_REGION - 1 downto 0) -- data out
	);

end mp7_payload;

architecture rtl of mp7_payload is

-- HB 2015-06-29: CLK_EDGE_4_INPUTS depends on the output clock of fdl_module.vhd of gt_mp7 and the latency caused by FW and HW traces of gt_mp7, LEMO cable, HW and FW traces of finor_amc502.
    constant CLK_EDGE_4_INPUTS : std_logic := '1'; -- rising edge
    constant CLK_EDGE_4_OUTPUTS : std_logic := not CLK_EDGE_4_INPUTS; -- falling edge

    constant MEM_FINOR_INDEX_BEG : integer := 0; -- from 0 to 5 (6 and 7 - free)
    constant MEM_VETO_INDEX_BEG : integer := 8; -- from 8 to 13 (14 and 15 - free)
    constant MEM_FINOR_2_TCDS_INDEX : integer := 16;

    signal ipb_to_slaves: ipb_wbus_array(N_SLAVES-1 downto 0);
    signal ipb_from_slaves: ipb_rbus_array(N_SLAVES-1 downto 0);
    signal pulse   :  std_logic_vector(31 downto 0) := X"00000000";

    signal rst_inputs: std_logic; -- lhc clk reset
    signal cntr_rst : std_logic; -- TCM counter reset

    signal simmem_o: std_logic_vector(63 downto 0); -- simmem to logic

    signal board_mac  :  std_logic_vector(47 downto 0) := X"1EED19271A16";
    signal board_ip   :  std_logic_vector(31 downto 0) := X"C0A801DE";
    signal board_id   :  std_logic_vector(3 downto 0); -- slot number
    signal loc_id     :  std_logic_vector(2 downto 0); -- crate location

    signal module_info_status_regs  : ipb_reg_v(15 downto 0) := (others => (others => '0'));
-- HB 2016-09-01: only module_info_control_regs 0, 1, 14 and 15 used !!! "luminosity_seg_period_msk" is a constant value in tcm.vhd.
--                module_info_control_regs(0)(31 downto 0) ==> selection of finor_2_tcds (LEMO outputs)
--                module_info_control_regs(1)(5 downto 0)  ==> disable finor and veto inputs 5..0
--                module_info_control_regs(14) ==> used for spytrigger
--                module_info_control_regs(15) ==> used for spytrigger

--     signal module_info_control_regs : ipb_reg_v(15 downto 0) := (4 => X"00040000", others => (others => '0')); -- init value for "luminosity_seg_period_msk"
    signal module_info_control_regs : ipb_reg_v(15 downto 0) := (others => (others => '0'));
    signal tcm_status_regs          : ipb_reg_v(15 downto 0) := (others => (others => '0'));
    signal tcm_control_regs         : ipb_reg_v(15 downto 0) := (others => (others => '0'));
    signal rate_cnt_finor_reg       : ipb_reg_v(0 downto 0) := (others => (others => '0'));
    signal read_rate_cnt_loc_finor  : ipb_reg_v(NR_FINORS_VETOS-1 downto 0) := (others => (others => '0'));
    signal read_rate_cnt_loc_veto   : ipb_reg_v(NR_FINORS_VETOS-1 downto 0) := (others => (others => '0'));

    signal bc_res                           : std_logic;
    signal bcres_d_int                           : std_logic;
    signal oc0_sync_bc0_int                           : std_logic;
    signal oc0_d_int                           : std_logic;
    signal bc_cnt                           : std_logic_vector (15 DOWNTO 0); --! Bunch crossing counter (16 bits)
    signal bx_length                        : std_logic_vector (15 DOWNTO 0); --! Length between two orbit signals
    signal bx_nr                            : bx_nr_t;
    signal orbit_nr                         : orbit_nr_t;
    signal luminosity_seg_nr                : luminosity_seg_nr_t;

    signal sres_finor_rate_counter: std_logic := '0';
    signal begin_lumi_section: std_logic;
    signal finor_in_s: std_logic_vector(NR_FINORS_VETOS-1 downto 0);
    signal veto_in_s: std_logic_vector(NR_FINORS_VETOS-1 downto 0);
    signal finor_in_s_2_spy: std_logic_vector(NR_FINORS_VETOS-1 downto 0);
    signal veto_in_s_2_spy: std_logic_vector(NR_FINORS_VETOS-1 downto 0);
    signal finor_in_enabled: std_logic_vector(NR_FINORS_VETOS-1 downto 0);
    signal veto_in_enabled: std_logic_vector(NR_FINORS_VETOS-1 downto 0);

    signal spy_mem_input: std_logic_vector(31 downto 0);
    signal finor_all: std_logic;
    signal veto_all: std_logic;
    signal finor_total_int: std_logic;
    signal finor_total_2_out: std_logic_vector(3 downto 0);
    signal finor_2_tcds_2_spy: std_logic;

    signal spytrig_i: sw_reg_spytrigger_in_t;
    signal spytrig_o: sw_reg_spytrigger_out_t;
    signal spytrigger: std_logic;

-- HB 2016-09-28: "... DONT_TOUCH is forward annotated to place and route to prevent logic optimization." (UG901/pg.33)
--                Used to implement output registers for finor_2_tcds in IOB.
    attribute dont_touch : string;
    attribute dont_touch of finor_total_2_out : signal is "true";

begin

    bc0 <= '0'; -- output

    rst_inputs <= rst_aux_0 or pulse(0);
	cntr_rst <= pulse(5); -- counter reset pulse

    fabric_i: entity work.ipbus_fabric_sel
        generic map(
            NSLV => N_SLAVES,
            SEL_WIDTH => IPBUS_SEL_WIDTH)
        port map(
          ipb_in => ipb_in,
          ipb_out => ipb_out,
          sel => ipbus_sel_mp7_payload(ipb_in.ipb_addr),
          ipb_to_slaves => ipb_to_slaves,
          ipb_from_slaves => ipb_from_slaves
        );

    bgo_sync_i: entity work.bgo_sync
        port map(
            clk_payload => clks_aux_0,
            rst_payload => rst_inputs,
            ttc_in      => ctrs(0).ttc_cmd,
            bc0_out     => bc_res,
            ec0_out     => open,
            ec0_sync_bc0_out     => open,
            oc0_out     => open,
            oc0_sync_bc0_out     => oc0_sync_bc0_int,
            resync_out  => open,
            resync_sync_bc0_out     => open,
            start_out  => open,
            start_sync_bc0_out  => open
        );

-- HB 2016-06-16: no dm in this version
    bcres_d_int <= bc_res;
    oc0_d_int <= oc0_sync_bc0_int;

    tcm_i: entity work.tcm
        port map(
            lhc_clk            =>  clks_aux_0,
            lhc_rst            =>  rst_inputs,
            cntr_rst           =>  cntr_rst,
            ec0                =>  '0',
            oc0                =>  oc0_d_int,
            start              =>  '0',
            l1a_sync           =>  '0',
            bcres_d            =>  bcres_d_int,
            bcres_d_FDL        =>  '0',
            sw_reg_in          =>  tcm_control_regs,
            sw_reg_out         =>  tcm_status_regs,
            bx_nr              =>  bx_nr,
            bx_nr_d_fdl        =>  open,
            event_nr           =>  open,
            trigger_nr         =>  open,
            orbit_nr           =>  orbit_nr,
            luminosity_seg_nr  =>  open,
            start_lumisection  =>  begin_lumi_section
        );

    user_i: entity work.user_switch
        port map(
	    user_in => user_sw,
	    id_out => board_id,
	    loc_out => loc_id,
	    mac_out => board_mac,
	    ip_out => board_ip
        );

    module_info_status_regs(0) <= ALGO_REV;
    module_info_status_regs(1) <= X"0000000" & board_id;
    module_info_status_regs(2) <= X"0000000" & '0' & loc_id;
    module_info_status_regs(3) <= board_mac(31 downto 0);
    module_info_status_regs(4) <= X"0000" & board_mac(47 downto 32);
    module_info_status_regs(5) <= board_ip;
    module_info_status_regs(6) <= BUILDSYS_BUILD_TIME;
    module_info_status_regs(7) <= TOP_USERNAME(31 downto 0);
    module_info_status_regs(8) <= TOP_USERNAME(63 downto 32);
    module_info_status_regs(9) <= TOP_USERNAME(95 downto 64);
    module_info_status_regs(10) <= TOP_USERNAME(127 downto 96);
    module_info_status_regs(11) <= TOP_USERNAME(159 downto 128);
    module_info_status_regs(12) <= TOP_USERNAME(191 downto 160);
    module_info_status_regs(13) <= TOP_USERNAME(223 downto 192);
    module_info_status_regs(14) <= TOP_USERNAME(255 downto 224);
    module_info_status_regs(15) <= spytrig_o.trig_spy12_ready & spytrig_o.trig_spy12_error & spytrig_o.trig_spy12_busy & '0' & X"0000000";

    --===========================================--
    module_info_i: entity work.ipbus_ctrlreg_v
    --===========================================--
        generic map(
            N_CTRL => 16,
            N_STAT => 16
        )
        port map(
            clk              => clk,
            reset            => rst,
            ipbus_in         => ipb_to_slaves(N_SLV_MINFO),
            ipbus_out        => ipb_from_slaves(N_SLV_MINFO),
            d                => module_info_status_regs,
            q                => module_info_control_regs,
            stb              => open
        );
    --===========================================--

    --===========================================--
    tcm_regs_i: entity work.ipbus_ctrlreg_v
    --===========================================--
        generic map(
            N_CTRL => 16,
            N_STAT => 16
        )
        port map(
            clk              => clk,
            reset            => rst,
            ipbus_in         => ipb_to_slaves(N_SLV_TCM),
            ipbus_out        => ipb_from_slaves(N_SLV_TCM),
            d                => tcm_status_regs,
            q                => tcm_control_regs,
            stb              => open
        );
    --===========================================--

    --===========================================--
    pulse_regs_inst: entity work.ipb_pulse_regs
    --===========================================--
        port map(  -- IPBus slave which translates a pulse in the ipb clk domain in to the lhc clk domain
            ipb_clk             => clk,
            ipb_reset           => rst,
            ipb_mosi_i          => ipb_to_slaves(N_SLV_PULSE_REGS),
            ipb_miso_o          => ipb_from_slaves(N_SLV_PULSE_REGS),
            lhc_clk             => clks_aux_0,
            pulse_o             => pulse
        );
    --===========================================--

    --===========================================--
    read_rate_cnt_finor_i: entity work.ipbus_ctrlreg_v
    --===========================================--
        generic map(
            N_CTRL => 1,
            N_STAT => 1
        )
        port map(
            clk              => clk,
            reset            => rst,
            ipbus_in         => ipb_to_slaves(N_SLV_RATE_CNT_FINOR),
            ipbus_out        => ipb_from_slaves(N_SLV_RATE_CNT_FINOR),
            d                => rate_cnt_finor_reg,
            q                => open,
            stb              => open
        );
    --===========================================--

    --===========================================--
    read_rate_cnt_loc_finor_i: entity work.ipbus_ctrlreg_v
    --===========================================--
	generic map(
	    N_CTRL => NR_FINORS_VETOS,
	    N_STAT => NR_FINORS_VETOS
	)
	port map(
	    clk              => clk,
	    reset            => rst,
	    ipbus_in         => ipb_to_slaves(N_SLV_RATE_CNT_LOC_FINOR),
	    ipbus_out        => ipb_from_slaves(N_SLV_RATE_CNT_LOC_FINOR),
	    d                => read_rate_cnt_loc_finor,
	    q                => open,
	    stb              => open
	);
    --===========================================--

    --===========================================--
    read_rate_cnt_loc_veto_i: entity work.ipbus_ctrlreg_v
    --===========================================--
	generic map(
	    N_CTRL => NR_FINORS_VETOS,
	    N_STAT => NR_FINORS_VETOS
	)
	port map(
	    clk              => clk,
	    reset            => rst,
	    ipbus_in         => ipb_to_slaves(N_SLV_RATE_CNT_LOC_VETO),
	    ipbus_out        => ipb_from_slaves(N_SLV_RATE_CNT_LOC_VETO),
	    d                => read_rate_cnt_loc_veto,
	    q                => open,
	    stb              => open
	);
    --===========================================--

-- sync finor_in and veto_in with lhc clk (pull-ups on finor_in and veto_in, because of inverted signal from HFMC-FINOR)
    sync_finor_veto: process(clks_aux_0, rst_inputs, finor_in, veto_in)
    begin
        if (rst_inputs = '1') then
            finor_in_s <= (others => '0');
            veto_in_s <= (others => '0');
        elsif(clks_aux_0'event and clks_aux_0 = CLK_EDGE_4_INPUTS) then
            finor_in_s <= not finor_in; -- finor_in is an inverted signal from HFMC-FINOR !!!
            veto_in_s <= not veto_in; -- veto_in is an inverted signal from HFMC-FINOR !!!
            finor_in_s_2_spy <= finor_in_s; -- finor_in_s to spy-mem for occurring in same bx as finor_2_tcds_2_spy
            veto_in_s_2_spy <= veto_in_s; -- veto_in_s to spy-mem for occurring in same bx as finor_2_tcds_2_spy
            finor_2_tcds_2_spy <= finor_total_int; -- finor_2_tcds synchronized for spy-mem
        end if;
    end process;

    enable_input_signals_p: process(module_info_control_regs, finor_in_s)
    begin
	for i in 0 to NR_FINORS_VETOS-1 loop
            finor_in_enabled(i) <= finor_in_s(i) and module_info_control_regs(1)(i);
            veto_in_enabled(i) <= veto_in_s(i) and module_info_control_regs(1)(i);
        end loop;
    end process;

-- HB 2018-03-19: changed "spytrig_i.orbit_nr" assignment, because of error Vivado 2017.4 (but not with 2017.1) => 

--     spytrig_i.orbit_nr                <= X"0000" & module_info_control_regs(14)(15 downto 0) & module_info_control_regs(13);
    spytrig_i.orbit_nr                <= module_info_control_regs(14)(15 downto 0) & module_info_control_regs(13);
    spytrig_i.spy12_once_event        <= pulse(2);
    spytrig_i.spy12_next_event        <= pulse(3);
    spytrig_i.clear_spy12_ready_event <= module_info_control_regs(15)(3);
    spytrig_i.clear_spy12_error_event <= module_info_control_regs(15)(5);

    spytrig: entity work.spytrig
    port map(
        lhc_clk  => clks_aux_0,
        lhc_rst  => rst_inputs,
        orbit_nr => orbit_nr,
        bx_nr    => bx_nr,
        sw_reg_i => spytrig_i,
        sw_reg_o => spytrig_o,
        spy1_o   => spytrigger,
        spy2_o   => open,
        spy3_o   => open,
        spy3_ack_i => '0',
        simmem_in_use_i => '0'
    );

-- spy memory data: bit 16 = finor_2_tcds_2_spy, bit 15..8 = veto_in_s_2_spy and bit 7..0 = finor_in_s_2_spy. Max. number of NR_FINORS_VETOS = 8 (only 6 are in the HW currently) !!!
    spy_mem_input_l: for i in 0 to NR_FINORS_VETOS-1 generate
	spy_mem_input(i+MEM_FINOR_INDEX_BEG) <= finor_in_s_2_spy(i);
	spy_mem_input(i+MEM_VETO_INDEX_BEG) <= veto_in_s_2_spy(i);
    end generate spy_mem_input_l;

    spy_mem_input(MEM_FINOR_2_TCDS_INDEX) <= finor_2_tcds_2_spy;

    spy_mem_i: entity work.ipb_dpmem_4096_32
        port map(
            ipbus_clk => clk,
            reset     => rst,
            ipbus_in  => ipb_to_slaves(N_SLV_SPYMEM),
            ipbus_out => ipb_from_slaves(N_SLV_SPYMEM),
            wea       => '0',
            ------------------
            clk_b     => clks_aux_0,
            enb       => '1',
            web       => spytrigger,
	    addrb     => bx_nr,
            dinb      => spy_mem_input,
            doutb     => open
        );

-- FINOR
    finor_p: process(finor_in_enabled)
       variable or_finor_var : std_logic := '0';
    begin
        or_finor_var := '0';
        for i in 0 to NR_FINORS_VETOS-1 loop
            or_finor_var := or_finor_var or finor_in_enabled(i);
        end loop;
        finor_all <= or_finor_var;
    end process finor_p;

-- VETO
    veto_p: process(veto_in_enabled)
       variable or_veto_var : std_logic := '0';
    begin
        or_veto_var := '0';
        for i in 0 to NR_FINORS_VETOS-1 loop
            or_veto_var := or_veto_var or veto_in_enabled(i);
        end loop;
        veto_all <= or_veto_var;
    end process veto_p;

    finor_total_int <= finor_all and not veto_all;

-- HB 2016-09-28: finor_total_2_out needed for IOB FF for finor_2_tcds
    finor_total_2_out_p: process(finor_all, veto_all)
    begin
	for i in 0 to 3 loop
	    finor_total_2_out(i) <= finor_all and not veto_all;
	end loop;
    end process;

-- HB 2016-09-28: output to TCDS is clocked (no testpoints mux used)
-- HB 2016-09-28: used neg. edge of clks_aux(0) for output register (in vB011 outputs to TCDS to early ~3 ns)
    finor_2_tcds_ff_p: process(clks_aux_0, rst_inputs, finor_total_2_out)
    begin
        if (rst_inputs = '1') then
            finor_2_tcds <= (others => '0');
       elsif(clks_aux_0'event and clks_aux_0 = CLK_EDGE_4_OUTPUTS) then
	    for i in 0 to 3 loop
		finor_2_tcds(i) <= finor_total_2_out(i);
	    end loop;
	end if;
    end process;

-- Rate counter finor register
-- HB 2016-02-11: requested for monitoring (in legacy system part of TCS).
    rate_cnt_finor_i: entity work.algo_rate_counter
	generic map(
	    COUNTER_WIDTH => FINOR_RATE_COUNTER_WIDTH
	)
	port map(
            sys_clk => clk,
            lhc_clk => clks_aux_0,
            sres_counter => sres_finor_rate_counter,
            store_cnt_value => begin_lumi_section,
            algo_i => finor_total_int,
            counter_o => rate_cnt_finor_reg(0)(FINOR_RATE_COUNTER_WIDTH-1 downto 0)
	);

    rate_cnt_loc_finor_l: for i in 0 to (NR_FINORS_VETOS-1) generate
        rate_cnt_loc_finor_i: entity work.algo_rate_counter
        generic map(
            COUNTER_WIDTH => FINOR_RATE_COUNTER_WIDTH
        )
        port map(
            sys_clk => clk,
            lhc_clk => clks_aux_0,
            sres_counter => sres_finor_rate_counter,
            store_cnt_value => begin_lumi_section,
            algo_i => finor_in_enabled(i),
            counter_o => read_rate_cnt_loc_finor(i)(FINOR_RATE_COUNTER_WIDTH-1 downto 0)
        );
    end generate rate_cnt_loc_finor_l;

    rate_cnt_loc_veto_l: for i in  0 to (NR_FINORS_VETOS-1) generate
        rate_cnt_loc_veto_i: entity work.algo_rate_counter
        generic map(
            COUNTER_WIDTH => FINOR_RATE_COUNTER_WIDTH
        )
        port map(
            sys_clk => clk,
            lhc_clk => clks_aux_0,
            sres_counter => sres_finor_rate_counter,
            store_cnt_value => begin_lumi_section,
            algo_i => veto_in_enabled(i),
            counter_o => read_rate_cnt_loc_veto(i)(FINOR_RATE_COUNTER_WIDTH-1 downto 0)
        );
    end generate rate_cnt_loc_veto_l;

    board_mac_o <= board_mac;
    board_ip_o <= board_ip;

end rtl;

