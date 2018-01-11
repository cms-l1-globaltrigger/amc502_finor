-- top_decl
--
-- Defines constants for the whole device
--
-- Dave Newbold, June 2014

library IEEE;
use IEEE.STD_LOGIC_1164.all;

use work.mp7_top_decl.all;

package top_decl is

        constant ALGO_REV: std_logic_vector(31 downto 0) := {{IPBUS_BUILD_VERSION}};
        constant BUILDSYS_BUILD_TIME: std_logic_vector(31 downto 0) := {{IPBUS_TIMESTAMP}};
        constant TOP_USERNAME : std_logic_vector(32*8-1 downto 0)  := {{IPBUS_USERNAME}};
        constant BUILDSYS_BLAME_HASH: std_logic_vector(31 downto 0) := TOP_USERNAME(31 downto 0);
	
	constant LHC_BUNCH_COUNT: integer := 3564;
	constant LB_ADDR_WIDTH: integer := 10;
	constant DR_ADDR_WIDTH: integer := 9;
	constant RO_CHUNKS: integer := 32;
	constant CLOCK_RATIO: integer := 6;
	constant CLOCK_AUX_RATIO: clock_ratio_array_t := (1, 1, 1);
	constant PAYLOAD_LATENCY: integer := 2;
	constant DAQ_N_BANKS: integer := 4; -- Number of readout banks
	constant DAQ_TRIGGER_MODES: integer := 2; -- Number of trigger modes for readout
	constant DAQ_N_CAP_CTRLS: integer := 4; -- Number of capture controls per trigger mode
	constant ZS_ENABLED: boolean := FALSE;

  -- Alternative refclk (4th entry in table) is 
  -- not used in R1 card, but is used in XE.
  -- 3rd column is therefore just duplicated.
  
	constant REGION_CONF: region_conf_array_t := (
		(gtx_10g_std_lat, u_crc32, buf, demux, buf, u_crc32, gtx_10g_std_lat, 0, 0), -- 0 / 112
		(gtx_10g_std_lat, u_crc32, buf, demux, buf, u_crc32, gtx_10g_std_lat, 0, 0)  -- 1 / 111
	);

end top_decl;
