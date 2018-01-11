--------------------------------------------------------------------------------
-- Synthesizer : ISE 14.6
-- Platform    : Linux Ubuntu 10.04
-- Targets     : Synthese
--------------------------------------------------------------------------------
-- This work is held in copyright as an unpublished work by HEPHY (Institute
-- of High Energy Physics) All rights reserved.  This work may not be used
-- except by authorized licensees of HEPHY. This work is the
-- confidential information of HEPHY.
--------------------------------------------------------------------------------
-- $HeadURL: svn://heros.hephy.at/GlobalTriggerUpgrade/firmware/finor_amc502/trunk/src/mp7_payload/firmware/hdl/ipbus_decode_mp7_payload.vhd $
-- $Date: 2015-07-08 11:44:28 +0200 (Wed, 08 Jul 2015) $
-- $Author: bergauer $
-- $Revision: 4084 $
--------------------------------------------------------------------------------

--
-- Address decode logic for ipbus fabric.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.math_pkg.all;

package ipbus_decode_mp7_payload is

    -- Number of slaves defined in the address table.
    constant N_SLAVES: positive := 7;

    -- Define selection vector format.
    constant IPBUS_SEL_WIDTH: positive := log2c(N_SLAVES);

    subtype ipbus_sel_t is std_logic_vector(IPBUS_SEL_WIDTH - 1 downto 0);
    function ipbus_sel_mp7_payload(addr : in std_logic_vector(31 downto 0)) return ipbus_sel_t;

    -- Item's unique identification index, used in slave implementation.
    constant N_SLV_MINFO: integer := 0;
    constant N_SLV_TCM: integer := 1;
    constant N_SLV_PULSE_REGS: integer := 2;
    constant N_SLV_RATE_CNT_FINOR: integer := 3;
    constant N_SLV_RATE_CNT_LOC_FINOR: integer := 4;
    constant N_SLV_RATE_CNT_LOC_VETO: integer := 5;
    constant N_SLV_SPYMEM: integer := 6;

    -- Item's address width in bits, used in slave implementation.
    constant N_SLV_MINFO_SIZE: integer := 5;
    constant N_SLV_SPYMEM_SIZE: integer := 12;

end ipbus_decode_mp7_payload;

package body ipbus_decode_mp7_payload is

    function ipbus_sel_mp7_payload(addr : in std_logic_vector(31 downto 0)) return ipbus_sel_t is
        variable sel: ipbus_sel_t;
    begin
        if    std_match(addr, "100000000000000000000000000-----") then sel := ipbus_sel_t(to_unsigned(N_SLV_MINFO, IPBUS_SEL_WIDTH));       -- 0x80000000
        elsif std_match(addr, "100000000000000000000000100-----") then sel := ipbus_sel_t(to_unsigned(N_SLV_TCM, IPBUS_SEL_WIDTH));         -- 0x80000080
        elsif std_match(addr, "10000000000000000000000010100000") then sel := ipbus_sel_t(to_unsigned(N_SLV_PULSE_REGS, IPBUS_SEL_WIDTH));  -- 0x800000A0
        elsif std_match(addr, "1000000000000000000000001011000-") then sel := ipbus_sel_t(to_unsigned(N_SLV_RATE_CNT_FINOR, IPBUS_SEL_WIDTH));     -- 0x800000B0
        elsif std_match(addr, "1000000000000000000000001100----") then sel := ipbus_sel_t(to_unsigned(N_SLV_RATE_CNT_LOC_FINOR, IPBUS_SEL_WIDTH)); -- 0x800000C0
        elsif std_match(addr, "1000000000000000000000001101----") then sel := ipbus_sel_t(to_unsigned(N_SLV_RATE_CNT_LOC_VETO, IPBUS_SEL_WIDTH));  -- 0x800000D0
        elsif std_match(addr, "10000001000000000000------------") then sel := ipbus_sel_t(to_unsigned(N_SLV_SPYMEM, IPBUS_SEL_WIDTH));      -- 0x81000000 .. 0x81000FFF
        else
            sel := ipbus_sel_t(to_unsigned(N_SLAVES, IPBUS_SEL_WIDTH));
        end if;
        return sel;
    end function ipbus_sel_mp7_payload;

end ipbus_decode_mp7_payload;


