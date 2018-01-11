# Timing constraints for MP7

# TTC clock (40MHz) - external
create_clock -period 24 -name clk_40_ext [get_ports clk40_in_p]

# Ethernet RefClk (125MHz) - external
create_clock -period 8 -name eth_refclk [get_ports eth_clkp]

# Clock rate setting for refclks (kind of arbitrary, 125MHz here) - external
create_clock -name configurable_refclks -period 7.900 [get_ports {refclkn[*]}]

# Clock from Ethernet Transceiver (derived from Ethernet RefClk)
# create_clock -period 16 -name eth_transceiver [get_pins infra/eth/phy/transceiver_inst/gtwizard_inst/gtwizard_v2_3_gbe_i/gt0_gtwizard_v2_3_gbe_i/gtxe2_i/TXOUTCLK]

# The decoupled_clk is driven from a flip-flop to circumvent Xilinx rules for the ethernet sys clk.
create_clock -period 16 -name decoupled_clk [get_pins infra/eth/decoupled_clk_src_reg/Q]

# Fake 40MHz clock for tests without external clock source
create_generated_clock -name clk_40_pseudo -source [get_pins infra/clocks/mmcm/CLKIN1] [get_pins infra/clocks/mmcm/CLKOUT2]

##############################################################################
# Datapath clks
##############################################################################

# Xilinx prefers 1 clk definition per clock, but you end up with a stupid
# number of clk definitions. For refclks easier to place all clocks into
# single definition.  Unfortunately it is currenntly limited to 64 clks.
# Hence split problem up into many more clk definitions.

set mgt_type "gth_3g gth_10g gth_10g_std_lat"
set mgt_clkdir "rx tx"
set mgt_chans "0 1 2 3"

foreach k $mgt_type {
	foreach j $mgt_clkdir {
		foreach i $mgt_chans {
			if {$j == "rx"} {
				set mgt_clkpin "RXOUTCLK"
			}
			if {$j == "tx"} {
				set mgt_clkpin "TXOUTCLK"
			}
			if {$k == "gth_3g"} {
				set mgt_clks [get_pins "datapath/rgen[*].region/mgt_gen_gth_3g.quad/*/*/*/gt$i*/gthe2_i/$mgt_clkpin"]
                set mgt_clk_period 6.6
			}
			if {$k == "gth_10g"} {
                set mgt_clks [get_pins "datapath/rgen[*].region/mgt_gen_gth_10g.quad/*/*/*/gt$i*/gthe2_i/$mgt_clkpin"]
                set mgt_clk_period 4
            }
			if {$k == "gth_10g_std_lat"} {
				set mgt_clks [get_pins "datapath/rgen[*].region/mgt_gen_gth_10g.quad/*/*/*/g_gt_instances\[$i\]*/gtxe2_i/$mgt_clkpin"]
				set mgt_clk_period 4
			}
            if {[llength $mgt_clks] != 0} {
                if {[info exists clkname]} { unset clkname }
                append clkname "" $k _ $j $i _clk
                create_clock -period $mgt_clk_period -name "$clkname" "$mgt_clks"
                set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks $clkname]
            }
        }
	}
}

# Clock relationship

set_clock_groups -asynch -group [get_clocks -include_generated_clocks eth_refclk]
#set_clock_groups -asynch -group [get_clocks -include_generated_clocks eth_transceiver]
set_clock_groups -asynch -group [get_clocks -include_generated_clocks clk_40_ext]
set_clock_groups -asynch -group [get_clocks -include_generated_clocks clk_40_pseudo]
set_clock_groups -asynch -group [get_clocks -filter {NAME =~ readout/amc13/*/TXOUTCLK}]

# Special path constraints

#set_false_path -through [get_nets {*refclk_mon[*]} -hierarchical]

#  Search design for false path endpoints
set_false_path -to [get_cells -hier -filter {MP7_FALSE_PATH_DEST_CELL == TRUE}]

# Tx path for MGTs

for {set i 0} {$i < 2} {incr i} {
	for {set j 0} {$j < 4} {incr j} {
		set tx_ff_out [get_pins -quiet "datapath/rgen[$i].region/*/tx_gen[$j].tx_clk_bridge/buf*_reg[*]/C"]
		set tx_ff_in [get_pins -quiet "datapath/rgen[$i].region/*/tx_gen[$j].tx_clk_bridge/data_out_reg[*]/D"]
		if {[llength $tx_ff_out] != 0} {
			set_max_delay -from $tx_ff_out -to $tx_ff_in -datapath_only 4.0
			set_min_delay -to $tx_ff_in 0.2
		}
	}
}
