


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

use work.package_links.all;
use work.package_types.all;
use work.package_utilities.all;

use work.mp7_top_decl.all;

entity ext_align_gth_32b_10g_spartan is
generic
(
  SIM_GTRESET_SPEEDUP: string := "TRUE";  -- Simulation setting for GT secureip model
  SIMULATION: integer := 0;               -- Set to 1 for simulation
  LOCAL_LHC_BUNCH_COUNT: integer;         -- Number of bx per orbit
  KIND: integer;
  QUAD_ID: integer
  );
port
(
  -- TTC based clock
  ttc_clk_in : in std_logic;
  ttc_rst_in : in std_logic;
  -- Common signals
  refclk_in : in std_logic;  -- 125mhz via dedicated distribution network
  drpclk_in : in std_logic;  -- 50mhz
  sysclk_in : in std_logic;  -- 100mhz
  -- Common dynamic reconfiguration port
  common_drp_address_in : in  std_logic_vector(7 downto 0);
  common_drp_data_in : in  std_logic_vector(15 downto 0);
  common_drp_data_out : out std_logic_vector(15 downto 0);
  common_drp_enable_in : in  std_logic;
  common_drp_ready_out : out std_logic;
  common_drp_write_in : in  std_logic;
  -- High Speed Serdes
  rxn_in : in std_logic_vector(3 downto 0);
  rxp_in : in std_logic_vector(3 downto 0);
  txn_out : out std_logic_vector(3 downto 0);
  txp_out : out std_logic_vector(3 downto 0);
  -- Channel dynamic reconfiguration port
  chan_drp_address_in  : in type_drp_addr_array(3 downto 0);
  chan_drp_data_in : in type_drp_data_array(3 downto 0);
  chan_drp_data_out : out type_drp_data_array(3 downto 0);
  chan_drp_enable_in : in std_logic_vector(3 downto 0);
  chan_drp_ready_out : out std_logic_vector(3 downto 0);
  chan_drp_write_in  : in std_logic_vector(3 downto 0);
  -- Parallel interface data
  txdata_in : in type_32b_data_array(3 downto 0);
  txdatavalid_in : in std_logic_vector(3 downto 0);
  rxdata_out : out type_32b_data_array(3 downto 0);
  rxdatavalid_out : out std_logic_vector(3 downto 0);
  -- External Rx buffer control
  buf_master_in: in  std_logic_vector(3 downto 0);
  buf_rst_in: in  std_logic_vector(3 downto 0);
  buf_ptr_inc_in: in  std_logic_vector(3 downto 0);
  buf_ptr_dec_in: in  std_logic_vector(3 downto 0);
  -- Synchronisation signals
  align_marker_out : out std_logic_vector(3 downto 0);
  -- Channel Registers
  chan_ro_regs_out : out type_chan_ro_reg_array(3 downto 0);
  chan_rw_regs_in : in type_chan_rw_reg_array(3 downto 0);
  -- Common Registers
  common_ro_regs_out : out type_common_ro_reg;
  common_rw_regs_in : in type_common_rw_reg;
  qplllock: out std_logic;
  -- Monitoring clocks
  txclk_mon: out std_logic;
  rxclk_mon: out std_logic_vector(3 downto 0)
  );
end ext_align_gth_32b_10g_spartan;



architecture behave of ext_align_gth_32b_10g_spartan is

  constant BYTE_WIDTH: natural := 4;
  constant DATA_WIDTH: natural := 8*BYTE_WIDTH;


  -- When crossing clock domains we wish for the data and datavalid signals
  -- to jump at the same time.  Hence merge data nad datavalid into a single 
  -- word called "info" when jumping across the domains.
  type info is array (natural range <>) of std_logic_vector(DATA_WIDTH downto 0);
  signal txinfo_at_ttc_clk: info(3 downto 0);
  signal txinfo_at_link_clk: info(3 downto 0);
  
  -- Data path operating @ link speed - 250MHz (K codes not yet inserted)
  signal txcomma_at_link_clk: std_logic_vector(3 downto 0);
  signal txdata_at_link_clk: type_32b_data_array(3 downto 0);
  signal txpad_at_link_clk : std_logic_vector(3 downto 0);

  -- Clocks driving MGT fabric interface
  signal txusrclk, rxusrclk : std_logic_vector(3 downto 0);
  signal txusrrst, rxusrrst : std_logic_vector(3 downto 0);
 
  -- Final data for transmission 
  signal txdata, rxdata : type_32b_data_array(3 downto 0);
  signal txcharisk, rxcharisk : type_32b_charisk_array(3 downto 0);
  
  signal loopback : type_loopback_array(3 downto 0);
  signal txpolarity, rxpolarity : std_logic_vector(3 downto 0);

  signal rxchariscomma : type_32b_chariscomma_array(3 downto 0);
  signal rxpcommaalignen : std_logic_vector(3 downto 0) := "1111";
  signal rxmcommaalignen : std_logic_vector(3 downto 0) := "1111";
  signal rxbyteisaligned : std_logic_vector(3 downto 0);
  
  signal rxdata_int :  type_32b_data_array(3 downto 0);
  signal rxdatavalid_int :  std_logic_vector(3 downto 0);

  signal rxcdrlock :  std_logic_vector(3 downto 0);
  signal txoutclk : std_logic_vector(3 downto 0);
  signal txdatavalid, rxdatavalid :  std_logic_vector(3 downto 0);
  signal rx_comma_det : std_logic_vector(3 downto 0);  

  signal tx_fsm_reset, rx_fsm_reset, tx_fsm_reset_done, rx_fsm_reset_done: std_logic_vector(3 downto 0);
  signal orbit_tag_enable, align_disable, buf_inc, buf_dec: std_logic_vector(3 downto 0);

  signal rx_crc_checked_cnt, rx_crc_error_cnt: type_vector_of_stdlogicvec_x8(3 downto 0);
  signal reset_crc_counters: std_logic_vector(3 downto 0);
  signal rx_trailer, tx_trailer : type_vector_of_stdlogicvec_x32(3 downto 0);
  
  signal data_start                   : std_logic_vector(3 downto 0);
  
  signal divclk, divclkout: std_logic_vector(4 downto 0);
  signal soft_reset, soft_reset_sysclk, qplllock_i : std_logic;

  component gth_quad_wrapper_8b10bx32b is
  generic
  (
    -- Simulation attributes
    SIMULATION                      : integer := 0;           -- Set to 1 for simulation
    SIM_GTRESET_SPEEDUP             : string := "FALSE";     -- Set to "true" to speed up sim reset
    -- Configuration
    STABLE_CLOCK_PERIOD             : integer := 32;          -- Period of the stable clock driving this state-machine, unit is [ns] 
    LINE_RATE                       : real := 10.0;        -- gb/s
    REFERENCE_CLOCK_RATE            : real := 125.0;         -- mhz
    PRBS_MODE                       : string := "SET THIS TO SOMETHING SENSIBLE";
    -- Placement information
    X_LOC                           : integer := 0;
    Y_LOC                           : integer := 0
  );
  port
  (
    -- Common signals
    soft_reset_in                      : in   std_logic;
    refclk_in                          : in   std_logic;
    drpclk_in                          : in   std_logic;
    sysclk_in                          : in   std_logic;
    qplllock_out                       : out   std_logic;

    -- Common dynamic reconfiguration port
    common_drp_address_in    : in  std_logic_vector(7 downto 0);
    common_drp_data_in      : in  std_logic_vector(15 downto 0);
    common_drp_data_out     : out std_logic_vector(15 downto 0);
    common_drp_enable_in     : in  std_logic;
    common_drp_ready_out    : out std_logic;
    common_drp_write_in      : in  std_logic;

    -- Channel signals
    rxusrclk_out                       : out  std_logic_vector(3 downto 0);
    txusrclk_out                       : out  std_logic_vector(3 downto 0);
    rxusrrst_out                       : out  std_logic_vector(3 downto 0);
    txusrrst_out                       : out  std_logic_vector(3 downto 0);

    -- Serdes links
    rxn_in                             : in   std_logic_vector(3 downto 0);
    rxp_in                             : in   std_logic_vector(3 downto 0);
    txn_out                            : out  std_logic_vector(3 downto 0);
    txp_out                            : out  std_logic_vector(3 downto 0);

    -- Channel dynamic reconfiguration ports
    chan_drp_address_in    : in type_drp_addr_array(3 downto 0);
    chan_drp_data_in      : in type_drp_data_array(3 downto 0);
    chan_drp_data_out      : out type_drp_data_array(3 downto 0);
    chan_drp_enable_in    : in std_logic_vector(3 downto 0);
    chan_drp_ready_out    : out std_logic_vector(3 downto 0);
    chan_drp_write_in      : in std_logic_vector(3 downto 0);

    -- State machines that control MGT Tx / Rx initialisation
    tx_fsm_reset_in                    : in   std_logic_vector(3 downto 0);
    rx_fsm_reset_in                    : in   std_logic_vector(3 downto 0);
    tx_fsm_reset_done_out              : out   std_logic_vector(3 downto 0);
    rx_fsm_reset_done_out              : out   std_logic_vector(3 downto 0);

    -- Misc
    loopback_in                        : in type_loopback_array(3 downto 0);

    -- Tx signals
    txoutclk_out                       : out  std_logic_vector(3 downto 0);
    txpolarity_in                      : in  std_logic_vector(3 downto 0);
    txdata_in                          : in type_32b_data_array(3 downto 0);
    txcharisk_in                       : in type_32b_charisk_array(3 downto 0);

    -- Rx signals 
    rx_comma_det_out                   : out   std_logic_vector(3 downto 0);
    rxpolarity_in                      : in  std_logic_vector(3 downto 0);
    rxcdrlock_out                      : out  std_logic_vector(3 downto 0);
    rxdata_out                         : out type_32b_data_array(3 downto 0);
    rxcharisk_out                      : out type_32b_charisk_array(3 downto 0);
    rxchariscomma_out                  : out type_32b_chariscomma_array(3 downto 0);
    rxbyteisaligned_out                : out std_logic_vector(3 downto 0);
    rxpcommaalignen_in                : in std_logic_vector(3 downto 0);
    rxmcommaalignen_in                : in std_logic_vector(3 downto 0)
  );
  end component;

  component gtx_quad_wrapper_8b10bx32b is
  generic
  (
    -- Simulation attributes
    SIMULATION                      : integer := 0;           -- Set to 1 for simulation
    SIM_GTRESET_SPEEDUP             : string := "FALSE";     -- Set to "true" to speed up sim reset
    -- Configuration
    STABLE_CLOCK_PERIOD             : integer := 32;          -- Period of the stable clock driving this state-machine, unit is [ns] 
    LINE_RATE                       : real := 10.0;        -- gb/s
    REFERENCE_CLOCK_RATE            : real := 125.0;         -- mhz
    PRBS_MODE                       : string := "SET THIS TO SOMETHING SENSIBLE";
    -- Placement information
    X_LOC                           : integer := 0;
    Y_LOC                           : integer := 0
  );
  port
  (
    -- Common signals
    soft_reset_in                      : in   std_logic;
    refclk_in                          : in   std_logic;
    drpclk_in                          : in   std_logic;
    sysclk_in                          : in   std_logic;
    qplllock_out                       : out   std_logic;

--     -- Common dynamic reconfiguration port
--     common_drp_address_in    : in  std_logic_vector(7 downto 0);
--     common_drp_data_in      : in  std_logic_vector(15 downto 0);
--     common_drp_data_out     : out std_logic_vector(15 downto 0);
--     common_drp_enable_in     : in  std_logic;
--     common_drp_ready_out    : out std_logic;
--     common_drp_write_in      : in  std_logic;

    -- Channel signals
    rxusrclk_out                       : out  std_logic_vector(3 downto 0);
    txusrclk_out                       : out  std_logic_vector(3 downto 0);
    rxusrrst_out                       : out  std_logic_vector(3 downto 0);
    txusrrst_out                       : out  std_logic_vector(3 downto 0);

    -- Serdes links
    rxn_in                             : in   std_logic_vector(3 downto 0);
    rxp_in                             : in   std_logic_vector(3 downto 0);
    txn_out                            : out  std_logic_vector(3 downto 0);
    txp_out                            : out  std_logic_vector(3 downto 0);

--     -- Channel dynamic reconfiguration ports
--     chan_drp_address_in    : in type_drp_addr_array(3 downto 0);
--     chan_drp_data_in      : in type_drp_data_array(3 downto 0);
--     chan_drp_data_out      : out type_drp_data_array(3 downto 0);
--     chan_drp_enable_in    : in std_logic_vector(3 downto 0);
--     chan_drp_ready_out    : out std_logic_vector(3 downto 0);
--     chan_drp_write_in      : in std_logic_vector(3 downto 0);

    -- State machines that control MGT Tx / Rx initialisation
    tx_fsm_reset_in                    : in   std_logic_vector(3 downto 0);
    rx_fsm_reset_in                    : in   std_logic_vector(3 downto 0);
    tx_fsm_reset_done_out              : out   std_logic_vector(3 downto 0);
    rx_fsm_reset_done_out              : out   std_logic_vector(3 downto 0);

    -- Misc
    loopback_in                        : in type_loopback_array(3 downto 0);

    -- Tx signals
    txoutclk_out                       : out  std_logic_vector(3 downto 0);
    txpolarity_in                      : in  std_logic_vector(3 downto 0);
    txdata_in                          : in type_32b_data_array(3 downto 0);
    txcharisk_in                       : in type_32b_charisk_array(3 downto 0);

    -- Rx signals 
    rx_comma_det_out                   : out   std_logic_vector(3 downto 0);
    rxpolarity_in                      : in  std_logic_vector(3 downto 0);
    rxcdrlock_out                      : out  std_logic_vector(3 downto 0);
    rxdata_out                         : out type_32b_data_array(3 downto 0);
    rxcharisk_out                      : out type_32b_charisk_array(3 downto 0);
    rxchariscomma_out                  : out type_32b_chariscomma_array(3 downto 0);
    rxbyteisaligned_out                : out std_logic_vector(3 downto 0);
    rxpcommaalignen_in                : in std_logic_vector(3 downto 0);
    rxmcommaalignen_in                : in std_logic_vector(3 downto 0)
  );
  end component;
  
begin                       

  divclk <= txusrclk(0) & rxusrclk;
  
  div_ref: entity work.freq_ctr_div
    generic map(
      N_CLK => 5
    )
    port map(
      clk => divclk,
      clkdiv => divclkout
    );
    
  txclk_mon <= divclkout(4);
  rxclk_mon <= divclkout(3 downto 0);
    
  -- Loop over all channels
  tx_gen: for i in 0 to 3 generate 
        
  ---------------------------------------------------------------------------
  -- Tx Stage (1): Add CRC 
  ---------------------------------------------------------------------------
  -- Add CRC, then merge data & datavalid signal into single word ready for 
  -- clk jump (i.e. we want the data and the datavalid to jump at the same 
  -- time).
  
  tx_trailer(i) <= x"0000" & std_logic_vector(to_unsigned(QUAD_ID, 8)) & std_logic_vector(to_unsigned(i, 8));

  -- Takes external generated in TTC clock domain
  tx_crc_insert: links_crc_tx
  generic map (
    --CRC_METHOD => "ULTIMATE_CRC",
    CRC_METHOD => "OUTPUT_LOGIC",
    POLYNOMIAL => "00000100110000010001110110110111",
    INIT_VALUE => "11111111111111111111111111111111",
    DATA_WIDTH => DATA_WIDTH,
    SYNC_RESET => 1)   
    port map(
      reset => ttc_rst_in,
      clk => ttc_clk_in,
      clken_in => '1',
      data_in => txdata_in(i)(DATA_WIDTH-1 downto 0), 
      data_valid_in => txdatavalid_in(i),
      trailer_in => tx_trailer(i)(DATA_WIDTH-1 downto 0),
      data_out => txinfo_at_ttc_clk(i)(DATA_WIDTH-1 downto 0),
      data_valid_out => txinfo_at_ttc_clk(i)(DATA_WIDTH));
    
    ---------------------------------------------------------------------------
    -- Tx Stage (2): Bridge data from 240MHz domain to 250MHz link clock
    ---------------------------------------------------------------------------
    -- There was originally another method of jumping from 240MHz to 250MHz.
    -- It was called cdc_txdata.  It may be worth looking at if te method 
    -- below fails.
    
    tx_clk_bridge: cdc_txdata_circular_buf
    --tx_clk_bridge: cdc_txdata_fifo
    generic map(
      data_length       => DATA_WIDTH+1)
    port map( 
      upstream_clk      =>     ttc_clk_in,
      upstream_rst      =>     ttc_rst_in,
      upstream_en       =>     '1',
      downstream_clk    =>     txusrclk(i),
      downstream_rst    =>     txusrrst(i),
      data_in           =>     txinfo_at_ttc_clk(i),
      data_out          =>     txinfo_at_link_clk(i),
      pad_out           =>     txpad_at_link_clk(i));
     
  ---------------------------------------------------------------------------
  -- Tx Stage (3): Insert K codes
  ---------------------------------------------------------------------------

   txcomma_at_link_clk(i) <= not txinfo_at_link_clk(i)(DATA_WIDTH);
   txdata_at_link_clk(i) <= txinfo_at_link_clk(i)(DATA_WIDTH-1 downto 0);

   tx_kcode_insert: kcode_insert_commas_and_pad
   generic map(
    BYTE_WIDTH => BYTE_WIDTH)
   port map(
      data_in           => txdata_at_link_clk(i),
      comma_in          => txcomma_at_link_clk(i),
      pad_in            => txpad_at_link_clk(i),
      data_out          => txdata(i),
      charisk_out       => txcharisk(i));   
      
   txdatavalid(i) <=  not txcharisk(i)(0);
    
  end generate tx_gen;

  ---------------------------------------------------------------------------
  -- GTX
  ---------------------------------------------------------------------------

  -- The "virtex7_quad_wrapper" contains:
  -- 1) rxusrclk & txusrclk distribution.
  -- 2) gtx initilisation
  -- 3) gtx x 4
  -- 4) quad clocking

  -- Make sure soft reset is in stable clock domain
  sync_pulse_inst: async_pulse_sync
    port map(
        async_pulse_in => soft_reset,
        sync_clk_in => sysclk_in,
        sync_pulse_out => soft_reset_sysclk,
        sync_pulse_sgl_clk_out => open);

  
  ---------------------------------------------------------------------------
  -- Selecting std v low latency 10g architectures.
  ---------------------------------------------------------------------------

  -- If VHDL configuration specifications could be selected on a generic 
  -- or constant it would make them super useful (i.e. bind different 
  -- architectures to the same entity).  As it is they are useless....
  
  -- I come back to this every ~6months.  The only option is to build 
  -- configuration files in python/tcl or have lots of have lots of generate 
  -- statement in your code with multiple "port maps"

  -- If you search the web there are many others out there with the same 
  -- idea and even the standards committee are pondering it with the phrase

  -- "After having waxed eloquently (and over long) in a manner reminiscent 
  -- of Il Duce's six hour 1933 radio broadcast on the relative merits of 
  -- staples and paper clips[10]. I'd point out that..."

  -- http://www.eda.org/twiki/bin/view.cgi/P1076/ConditionalCompilation



  ---------------------------------------------------------------------------
  -- Instantiate 10G low latency latency tranceiver. 
  ---------------------------------------------------------------------------

  gth_lowlat: if KIND = mgt_kind_t'pos(gth_10g) generate

    quad_wrapper_inst: entity work.gth_quad_wrapper_8b10bx32b_xi_10g
    generic map(
      -- Simulation attributes  
      SIMULATION => SIMULATION,
      SIM_GTRESET_SPEEDUP => SIM_GTRESET_SPEEDUP,
      -- Configuration
      STABLE_CLOCK_PERIOD => 32,  -- Period of the stable clock driving this state-machine, unit is [ns] 
      LINE_RATE => 10.0,  -- Gb/s
      PLL => "QPLL",
      REFERENCE_CLOCK_RATE => 250.0,   -- Mhz
      PRBS_MODE => "PRBS-7",
      -- Placement information
      X_LOC => 0,
      Y_LOC => 0)
    port map
    ( 
      -- Common signals
      soft_reset_in => soft_reset_sysclk,       -- Clock domain = STABLE_CLOCK
      refclk_in => refclk_in,
      drpclk_in => drpclk_in,
      sysclk_in => sysclk_in,
      qplllock_out => qplllock_i,
  
      -- Common dynamic reconfiguration port
      common_drp_address_in => common_drp_address_in,
      common_drp_data_in => common_drp_data_in,
      common_drp_data_out => common_drp_data_out,
      common_drp_enable_in => common_drp_enable_in, 
      common_drp_ready_out => common_drp_ready_out,
      common_drp_write_in => common_drp_write_in,
  
      -- Fabric interface clocks
      rxusrclk_out => rxusrclk,
      txusrclk_out => txusrclk,
      rxusrrst_out => rxusrrst,
      txusrrst_out => txusrrst,
  
      -- Serdes links
      rxn_in => rxn_in,
      rxp_in => rxp_in,
      txn_out => txn_out,
      txp_out => txp_out,
  
      -- Channel dynamic reconfiguration ports
      chan_drp_address_in => chan_drp_address_in,
      chan_drp_data_in => chan_drp_data_in,
      chan_drp_data_out => chan_drp_data_out,
      chan_drp_enable_in => chan_drp_enable_in,
      chan_drp_ready_out => chan_drp_ready_out,
      chan_drp_write_in => chan_drp_write_in,
  
      -- State machines that control MGT Tx / Rx initialisation
      tx_fsm_reset_in => tx_fsm_reset, 
      rx_fsm_reset_in => rx_fsm_reset,
      tx_fsm_reset_done_out => tx_fsm_reset_done,
      rx_fsm_reset_done_out => rx_fsm_reset_done,
  
      -- Misc
      loopback_in => loopback,
      prbs_enable_in => "0000",
  
      -- Tx signals
      txoutclk_out => txoutclk,
      txpolarity_in => txpolarity,
      txdata_in => txdata,
      txcharisk_in => txcharisk,
  
      -- Rx signals
      rx_comma_det_out => rx_comma_det,
      rxpolarity_in => rxpolarity,
      rxcdrlock_out => rxcdrlock,
      rxdata_out => rxdata,
      rxcharisk_out => rxcharisk,
      rxchariscomma_out => rxchariscomma,
      rxbyteisaligned_out => rxbyteisaligned,
      rxpcommaalignen_in => rxpcommaalignen,      -- Clock domain = RXUSRCLK2
      rxmcommaalignen_in => rxmcommaalignen);     -- Clock domain = RXUSRCLK2

  end generate gth_lowlat;
  
  
  ---------------------------------------------------------------------------
  -- Instantiate 10G standard latency tranceiver. 
  ---------------------------------------------------------------------------
  
  gth_stdlat: if KIND = mgt_kind_t'pos(gth_10g_std_lat) generate

    quad_wrapper_inst: gth_quad_wrapper_8b10bx32b 
    generic map(
      -- Simulation attributes  
      SIMULATION => SIMULATION,
      SIM_GTRESET_SPEEDUP => SIM_GTRESET_SPEEDUP,
      -- Configuration
      STABLE_CLOCK_PERIOD => 32,  -- Period of the stable clock driving this state-machine, unit is [ns] 
      LINE_RATE => 10.0,  -- Gb/s
      REFERENCE_CLOCK_RATE => 250.0,   -- Mhz
      PRBS_MODE => "PRBS-7",
      -- Placement information
      X_LOC => 0,
      Y_LOC => 0)
    port map
    ( 
      -- Common signals
      soft_reset_in => soft_reset_sysclk,       -- Clock domain = STABLE_CLOCK
      refclk_in => refclk_in,
      drpclk_in => drpclk_in,
      sysclk_in => sysclk_in,
      qplllock_out => qplllock_i,
  
      -- Common dynamic reconfiguration port
      common_drp_address_in => common_drp_address_in,
      common_drp_data_in => common_drp_data_in,
      common_drp_data_out => common_drp_data_out,
      common_drp_enable_in => common_drp_enable_in, 
      common_drp_ready_out => common_drp_ready_out,
      common_drp_write_in => common_drp_write_in,
  
      -- Fabric interface clocks
      rxusrclk_out => rxusrclk,
      txusrclk_out => txusrclk,
      rxusrrst_out => rxusrrst,
      txusrrst_out => txusrrst,
  
      -- Serdes links
      rxn_in => rxn_in,
      rxp_in => rxp_in,
      txn_out => txn_out,
      txp_out => txp_out,
  
      -- Channel dynamic reconfiguration ports
      chan_drp_address_in => chan_drp_address_in,
      chan_drp_data_in => chan_drp_data_in,
      chan_drp_data_out => chan_drp_data_out,
      chan_drp_enable_in => chan_drp_enable_in,
      chan_drp_ready_out => chan_drp_ready_out,
      chan_drp_write_in => chan_drp_write_in,
  
      -- State machines that control MGT Tx / Rx initialisation
      tx_fsm_reset_in => tx_fsm_reset, 
      rx_fsm_reset_in => rx_fsm_reset,
      tx_fsm_reset_done_out => tx_fsm_reset_done,
      rx_fsm_reset_done_out => rx_fsm_reset_done,
  
      -- Misc
      loopback_in => loopback,
  
      -- Tx signals
      txoutclk_out => txoutclk,
      txpolarity_in => txpolarity,
      txdata_in => txdata,
      txcharisk_in => txcharisk,
  
      -- Rx signals
      rx_comma_det_out => rx_comma_det,
      rxpolarity_in => rxpolarity,
      rxcdrlock_out => rxcdrlock,
      rxdata_out => rxdata,
      rxcharisk_out => rxcharisk,
      rxchariscomma_out => rxchariscomma,
      rxbyteisaligned_out => rxbyteisaligned,
      rxpcommaalignen_in => rxpcommaalignen,      -- Clock domain = RXUSRCLK2
      rxmcommaalignen_in => rxmcommaalignen);     -- Clock domain = RXUSRCLK2

  end generate gth_stdlat;


  gtx_stdlat: if KIND = mgt_kind_t'pos(gtx_10g_std_lat) generate

    quad_wrapper_inst: gtx_quad_wrapper_8b10bx32b 
    generic map(
      -- Simulation attributes  
      SIMULATION => SIMULATION,
      SIM_GTRESET_SPEEDUP => SIM_GTRESET_SPEEDUP,
      -- Configuration
      STABLE_CLOCK_PERIOD => 32,  -- Period of the stable clock driving this state-machine, unit is [ns] 
      LINE_RATE => 10.0,  -- Gb/s
      REFERENCE_CLOCK_RATE => 250.0,   -- Mhz
      PRBS_MODE => "PRBS-7",
      -- Placement information
      X_LOC => 0,
      Y_LOC => 0)
    port map
    ( 
      -- Common signals
      soft_reset_in => soft_reset_sysclk,       -- Clock domain = STABLE_CLOCK
      refclk_in => refclk_in,
      drpclk_in => drpclk_in,
      sysclk_in => sysclk_in,
      qplllock_out => qplllock_i,
  
--       -- Common dynamic reconfiguration port
--       common_drp_address_in => common_drp_address_in,
--       common_drp_data_in => common_drp_data_in,
--       common_drp_data_out => common_drp_data_out,
--       common_drp_enable_in => common_drp_enable_in, 
--       common_drp_ready_out => common_drp_ready_out,
--       common_drp_write_in => common_drp_write_in,
  
      -- Fabric interface clocks
      rxusrclk_out => rxusrclk,
      txusrclk_out => txusrclk,
      rxusrrst_out => rxusrrst,
      txusrrst_out => txusrrst,
  
      -- Serdes links
      rxn_in => rxn_in,
      rxp_in => rxp_in,
      txn_out => txn_out,
      txp_out => txp_out,
  
--       -- Channel dynamic reconfiguration ports
--       chan_drp_address_in => chan_drp_address_in,
--       chan_drp_data_in => chan_drp_data_in,
--       chan_drp_data_out => chan_drp_data_out,
--       chan_drp_enable_in => chan_drp_enable_in,
--       chan_drp_ready_out => chan_drp_ready_out,
--       chan_drp_write_in => chan_drp_write_in,
  
      -- State machines that control MGT Tx / Rx initialisation
      tx_fsm_reset_in => tx_fsm_reset, 
      rx_fsm_reset_in => rx_fsm_reset,
      tx_fsm_reset_done_out => tx_fsm_reset_done,
      rx_fsm_reset_done_out => rx_fsm_reset_done,
  
      -- Misc
      loopback_in => loopback,
  
      -- Tx signals
      txoutclk_out => txoutclk,
      txpolarity_in => txpolarity,
      txdata_in => txdata,
      txcharisk_in => txcharisk,
  
      -- Rx signals
      rx_comma_det_out => rx_comma_det,
      rxpolarity_in => rxpolarity,
      rxcdrlock_out => rxcdrlock,
      rxdata_out => rxdata,
      rxcharisk_out => rxcharisk,
      rxchariscomma_out => rxchariscomma,
      rxbyteisaligned_out => rxbyteisaligned,
      rxpcommaalignen_in => rxpcommaalignen,      -- Clock domain = RXUSRCLK2
      rxmcommaalignen_in => rxmcommaalignen);     -- Clock domain = RXUSRCLK2

  end generate gtx_stdlat;



  -- Loop over all channels
  rx_gen: for i in 0 to 3 generate 
  
  -----------------------------------------------------------------------------
  ---- Rx Stage (1): CDC
  -----------------------------------------------------------------------------

  buf_inc(i) <= buf_ptr_inc_in(i) and not align_disable(i);
  buf_dec(i) <= buf_ptr_dec_in(i) and not align_disable(i);
  
  rxdata_simple_cdc_buf_inst: rxdata_simple_cdc_buf
    generic map(
      SIMULATION => SIMULATION,
      BYTE_WIDTH => BYTE_WIDTH
    )
    port map(
      -- All the following in link clk domain
      link_rst_in => rxusrrst(i),
      link_clk_in => rxusrclk(i),
      rxdata_in => rxdata(i),
      rxcharisk_in => rxcharisk(i),
      rx_comma_det_in => rx_comma_det(i),
      -- All in sys clk domain
      rx_fsm_reset_done_in => rx_fsm_reset_done(i),
      -- Want to keep it all in the local clk domain
      local_rst_in => ttc_rst_in,
      local_clk_in => ttc_clk_in,
      local_clken_in => '1',
      buf_master_in => buf_master_in(i),
      buf_rst_in => buf_rst_in(i),
      buf_ptr_inc_in => buf_inc(i),
      buf_ptr_dec_in => buf_dec(i),
      rxdata_out => rxdata_int(i),
      rxdatavalid_out => rxdatavalid_int(i)
    );
    
  ---------------------------------------------------------------------------
  -- Rx Stage (2): CRC
  ---------------------------------------------------------------------------

  rx_crc: links_crc_rx
  generic map (
    --CRC_METHOD => "ULTIMATE_CRC",
    CRC_METHOD => "OUTPUT_LOGIC",
    POLYNOMIAL => "00000100110000010001110110110111",
    INIT_VALUE => "11111111111111111111111111111111",
    DATA_WIDTH => DATA_WIDTH,
    SYNC_RESET => 1)   
     port map (
        reset                 => ttc_rst_in, 
        clk                   => ttc_clk_in,
        clken_in              => '1',
        data_in               => rxdata_int(i),
        data_valid_in         => rxdatavalid_int(i),
        data_out              => rxdata_out(i)(DATA_WIDTH-1 downto 0),
        data_valid_out        => rxdatavalid_out(i),
        data_start_out        => data_start(i),
        reset_counters_in     => reset_crc_counters(i),
        crc_checked_cnt_out   => rx_crc_checked_cnt(i),
        crc_error_cnt_out     => rx_crc_error_cnt(i),
        trailer_out           => rx_trailer(i)(DATA_WIDTH-1 downto 0),
        status_out            => open);    

--  pad_ext_interface: if DATA_WIDTH /= 32 generate
--    rxdata_out(i)(31 downto DATA_WIDTH) <= (others => '0');
--    rx_trailer(i)(31 downto DATA_WIDTH) <= (others => '0');    
--  end generate;

		-- Alignment marker must ocvcur at fixed frequency for alignment mechanism.  
		-- Simplest is one per orbit.  Not time critical.  Large fan in later so register.
--		align_marker_proc: process(ttc_clk_in) 
--		begin
--			if rising_edge(ttc_clk_in) then
				align_marker_out(i) <= (data_start(i) and (rxdata_int(i)(12) or (not orbit_tag_enable(i)))) or align_disable(i);
--			end if;
--		end process;
    
  end generate rx_gen;

  -----------------------------------------------------------------------------
  ---- CHANNEL Register Access:
  -----------------------------------------------------------------------------

  -- Loop over all channels
  reg_gen: for i in 0 to 3 generate 
  
   ----------------------------------------------------------------------------- 
   -- ReadOnly Regs. All TTC domain
   -----------------------------------------------------------------------------
   
   chan_ro_regs_out(i)(0) <= rx_trailer(i);
   chan_ro_regs_out(i)(1) <= txusrrst(i) & 
                             rxusrrst(i) &
                             tx_fsm_reset_done(i) & 
                             rx_fsm_reset_done(i) &
                             rxcdrlock(i) & 
                             '0' & -- CPLL lock unused
                             "00" & 
                             x"00" & rx_crc_error_cnt(i) & rx_crc_checked_cnt(i);
      
   -----------------------------------------------------------------------------
   -- ReadWrite Regs. All TTC domain except for polarity & loopback regs: 
   -----------------------------------------------------------------------------
   
   -- loopback is async input
   loopback(i) <= chan_rw_regs_in(i)(0)(2 downto 0);
   -- crc reset is in TTC domain
   reset_crc_counters(i) <= chan_rw_regs_in(i)(0)(3);
   -- txpolarity is in the txusrclk2 domain
   txpolarity(i) <= chan_rw_regs_in(i)(0)(4) when rising_edge(txusrclk(i));
   -- rxpolarity is in the rxusrclk2 domain
   rxpolarity(i) <= chan_rw_regs_in(i)(0)(5) when rising_edge(rxusrclk(i));
   -- JJ's code handles clock domain crossing
   -- JJ's code also seprates out QPLL, which has a FSM that will automatically try to lock
   tx_fsm_reset(i) <= chan_rw_regs_in(i)(0)(6);
   rx_fsm_reset(i) <= chan_rw_regs_in(i)(0)(7);
   orbit_tag_enable(i)  <= chan_rw_regs_in(i)(0)(8);
   align_disable(i) <= chan_rw_regs_in(i)(0)(9);

  end generate;


  -----------------------------------------------------------------------------
  ---- COMMON Register Access:
  -----------------------------------------------------------------------------
  
  -- COMMON: ReadOnly Regs.
  -- WARNING: Clock domain may not be observed
  common_ro_regs_out(0)(0) <= qplllock_i;
  common_ro_regs_out(0)(4 downto 1) <= std_logic_vector(to_unsigned(KIND,4));
  common_ro_regs_out(0)(31 downto 5) <= (others => '0');

  -- COMMON: ReadWrite Regs.
  -- WARNING: Clock domain may not be observed
  soft_reset <= common_rw_regs_in(0)(0);
  
  qplllock <= qplllock_i;
  
---------------------------------------------------------------------------
-- Useful information
---------------------------------------------------------------------------

   -- Loopback mode (loopback)
   -- 000: Normal operation
   -- 001: Near-End PCS Loopback
   -- 010: Near-End PMA Loopback
   -- 011: Reserved
   -- 100: Far-End PMA Loopback
   -- 101: Reserved
   -- 110: Far-End PCS Loopback(1)
   -- 111: Reserved

   -- Magnitude of differential swing (txdiffctrl)
   -- 000: 1100
   -- 001: 1050
   -- 010: 1000
   -- 011: 900
   -- 100: 800
   -- 101: 600
   -- 110: 400
   -- 111: 0

   -- Magnitude of pre-emphasis (txpreemphasis)
   -- TxPreEmphasis (%) TX_DIFF_BOOST = FALSE(Default), TRUE
   -- 000: 2 3
   -- 001: 2 3
   -- 010: 2.5 4
   -- 011: 4.5 10.5
   -- 100: 9.5 18.5
   -- 101: 16 28
   -- 110: 23 39
   -- 111: 31 52
     
end behave;
