library ieee;
use ieee.std_logic_1164.all;

use work.gt_mp7_core_pkg.all;

package user_package is
-- type definition for unconstraint range of IPbus register blocks
--     type ipb_regs_array is array (natural range <>) of std_logic_vector(31 downto 0);

    type sw_reg_spytrigger_in_t is record
        orbit_nr                      : orbit_nr_t;
        spy12_once_event              : std_logic;
        spy12_next_event              : std_logic;
        spy3_event                    : std_logic;
        clear_spy12_ready_event       : std_logic;
        clear_spy3_ready_event        : std_logic;
        clear_spy12_error_event       : std_logic;
    end record;
    constant SW_REG_SPYTRIGGER_IN_RESET : sw_reg_spytrigger_in_t :=
    (
        orbit_nr                      => (others=>('0')),
        spy12_once_event              => '0',
        spy12_next_event              => '0',
        spy3_event                    => '0',
        clear_spy12_ready_event       => '0',
        clear_spy3_ready_event        => '0',
        clear_spy12_error_event       => '0'
    );
    type sw_reg_spytrigger_out_t is record
        trig_spy12_error              : std_logic;
        trig_spy3_ready               : std_logic;
        trig_spy12_ready              : std_logic;
        trig_spy3_busy                : std_logic;
        trig_spy12_busy               : std_logic;
    end record;
    constant SW_REG_SPYTRIGGER_OUT_RESET : sw_reg_spytrigger_out_t :=
    (
        trig_spy12_error              => '0',
        trig_spy3_ready               => '0',
        trig_spy12_ready              => '0',
        trig_spy3_busy                => '0',
        trig_spy12_busy               => '0'
    );

end user_package;
