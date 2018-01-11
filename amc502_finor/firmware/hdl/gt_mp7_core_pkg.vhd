-- HB 2017-10-18: reduced for use in amc502 fw

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use IEEE.numeric_std.all;

use work.mp7_data_types.all;
use work.math_pkg.all;
-- use work.lhc_data_pkg.all;
-- use work.gt_top_pkg.all;
use work.top_decl.all;


package gt_mp7_core_pkg is

type ipb_regs_array is array (natural range <>) of std_logic_vector(31 downto 0);

constant BUNCHES_PER_ORBIT : natural range 3564 to 3564 := 3564;

-- HB 2014-07-08: ipbus_rst is high active, RST_ACT changed to '1' (for lhc_rst [in gt_mp7_core_pkg.vhd]) to get proper reset-conditions,
--                because in delay_line_sl.vhd and delay_line_slv.vhd both resets are used !!!
-- constant RST_ACT : std_logic := '0';
constant RST_ACT : std_logic := '1';

type vec32_array is array (NATURAL RANGE <>) of std_logic_vector(31 downto 0);
type vec16_array is array (NATURAL RANGE <>) of std_logic_vector(15 downto 0);
type vec8_array is array (NATURAL RANGE <>) of std_logic_vector(7 downto 0);

--------------------------------------------------------------------------------
-- TCM
--------------------------------------------------------------------------------
constant BGOS_WIDTH                   : integer := 4;
constant BX_NR_WIDTH                  : integer := log2c(BUNCHES_PER_ORBIT);
constant ORBIT_NR_WIDTH               : integer := 48;
--BR Aug. 29 2013
--1. change the width in tcm.xml
--2. change package
--3. trunk/make distribute-xml
--4. script/autogenRb/autogenRb.py
--5. change xml/rop_frame_format.xml
--6. script/rop_frame_generator/make frame
--7 script/rop_frame_generator/make distribute-frame

constant LUM_SEG_NR_WIDTH             : integer := 32;
constant EVENT_NR_WIDTH               : integer := 32;
constant EVENT_TYPE_WIDTH             : integer := 4;
constant LUM_SEG_PERIOD_WIDTH         : integer := 32;
constant LUM_SEG_PERIOD_MSK_WIDTH     : integer := 32;
constant TRIGGER_NR_WIDTH             : natural := 48;

subtype bgos_t                      is std_logic_vector(BGOS_WIDTH-1 downto 0);
subtype bx_nr_t                     is std_logic_vector(BX_NR_WIDTH-1 downto 0);
subtype orbit_nr_t                  is std_logic_vector(ORBIT_NR_WIDTH-1 downto 0);
subtype luminosity_seg_nr_t         is std_logic_vector(LUM_SEG_NR_WIDTH-1 downto 0);
subtype event_nr_t                  is std_logic_vector(EVENT_NR_WIDTH-1 downto 0);
subtype event_type_t                is std_logic_vector(EVENT_TYPE_WIDTH-1 downto 0);
subtype luminosity_seg_period_t     is std_logic_vector(LUM_SEG_PERIOD_WIDTH-1 downto 0);
subtype luminosity_seg_period_msk_t is std_logic_vector(LUM_SEG_PERIOD_MSK_WIDTH-1 downto 0);
subtype trigger_nr_t                is std_logic_vector(TRIGGER_NR_WIDTH-1 downto 0);

constant BC_TOP                       : integer := BUNCHES_PER_ORBIT-1;
constant LUM_SEG_PERIOD_MSK_RESET     : luminosity_seg_period_msk_t := X"00040000";

-- BGos commands
constant BGOS_NOP                       : bgos_t := "0000";
constant BGOS_RESYNC                    : bgos_t := "0101";
constant BGOS_ORBIT_COUNTER_RESET       : bgos_t := "1000";
constant BGOS_START_RUN                 : bgos_t := "1001";
constant BGOS_EVENT_COUNTER_RESET       : bgos_t := "0111";

--------------------------------------------------------------------------------
-- ADDRESS DECODER
--------------------------------------------------------------------------------
constant SYNC_STAGES : natural := 3;
constant ERROR_ADDRESS : std_logic_vector(31 downto 0) := X"0000EADD";

--------------------------------------------------------------------------------

	function to_obrit_nr(i : integer) return orbit_nr_t;
	function to_bx_nr(i : integer) return bx_nr_t;

end package;

package body gt_mp7_core_pkg is

	function to_obrit_nr(i : integer) return orbit_nr_t is
		variable ret_value : orbit_nr_t := (others=>'0');
	begin
		ret_value := std_logic_vector(to_unsigned(i, ret_value'length));
		return ret_value;
	end function;


	function to_bx_nr(i : integer) return bx_nr_t is
		variable ret_value : bx_nr_t := (others=>'0');
	begin
		assert(i < BUNCHES_PER_ORBIT) report "Unable to convert integer to bx_nr_t: value too large" severity error;
		ret_value := std_logic_vector(to_unsigned(i, ret_value'length));
		return ret_value;
	end function;


end;



