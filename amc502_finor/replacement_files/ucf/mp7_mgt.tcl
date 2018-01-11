# Constraints specific to '420 AMC502

set_property LOC GTXE2_CHANNEL_X0Y20 [get_cells -hier -filter {name=~infra/eth/*/gtxe2_i}]
set_property LOC GTXE2_CHANNEL_X0Y21 [get_cells -hier -filter {name=~readout/amc13/*/gtxe2_i}]

##quad0 - mgtts112
#set_property LOC GTXE2_COMMON_X0Y1 [get_cells -hier -filter {name=~datapath/rgen[0].region/mgt_gen_gth_10g.quad/quad/stdlat.quad_wrapper_inst/gtx_quad_i/gtxe2_common_i}]
#set_property LOC GTXE2_CHANNEL_X0Y4  [get_cells -hier -filter {name=~datapath/rgen[0].region/mgt_gen_gth_10g.quad/quad/stdlat.quad_wrapper_inst/gtx_quad_i/g_gt_instances[0].gtx_transceiver_i/gtxe2_i}]
#set_property LOC GTXE2_CHANNEL_X0Y5  [get_cells -hier -filter {name=~datapath/rgen[0].region/mgt_gen_gth_10g.quad/quad/stdlat.quad_wrapper_inst/gtx_quad_i/g_gt_instances[1].gtx_transceiver_i/gtxe2_i}]
#set_property LOC GTXE2_CHANNEL_X0Y6  [get_cells -hier -filter {name=~datapath/rgen[0].region/mgt_gen_gth_10g.quad/quad/stdlat.quad_wrapper_inst/gtx_quad_i/g_gt_instances[2].gtx_transceiver_i/gtxe2_i}]
#set_property LOC GTXE2_CHANNEL_X0Y7  [get_cells -hier -filter {name=~datapath/rgen[0].region/mgt_gen_gth_10g.quad/quad/stdlat.quad_wrapper_inst/gtx_quad_i/g_gt_instances[3].gtx_transceiver_i/gtxe2_i}]
##quad1 - mgtts111
#set_property LOC GTXE2_COMMON_X0Y0 [get_cells -hier -filter {name=~datapath/rgen[1].region/mgt_gen_gth_10g.quad/quad/stdlat.quad_wrapper_inst/gtx_quad_i/gtxe2_common_i}]
#set_property LOC GTXE2_CHANNEL_X0Y0  [get_cells -hier -filter {name=~datapath/rgen[1].region/mgt_gen_gth_10g.quad/quad/stdlat.quad_wrapper_inst/gtx_quad_i/g_gt_instances[0].gtx_transceiver_i/gtxe2_i}]
#set_property LOC GTXE2_CHANNEL_X0Y1  [get_cells -hier -filter {name=~datapath/rgen[1].region/mgt_gen_gth_10g.quad/quad/stdlat.quad_wrapper_inst/gtx_quad_i/g_gt_instances[1].gtx_transceiver_i/gtxe2_i}]
#set_property LOC GTXE2_CHANNEL_X0Y2  [get_cells -hier -filter {name=~datapath/rgen[1].region/mgt_gen_gth_10g.quad/quad/stdlat.quad_wrapper_inst/gtx_quad_i/g_gt_instances[2].gtx_transceiver_i/gtxe2_i}]
#set_property LOC GTXE2_CHANNEL_X0Y3  [get_cells -hier -filter {name=~datapath/rgen[1].region/mgt_gen_gth_10g.quad/quad/stdlat.quad_wrapper_inst/gtx_quad_i/g_gt_instances[3].gtx_transceiver_i/gtxe2_i}]

# Format is x_loc y_channel_loc y_common_loc

set m_loc {
	{0 4 1}
	{0 0 0}
}

# Loop over regions
for {set i 0} {$i < 2} {incr i} {
	set d [lindex $m_loc $i]
	set l [get_cells "datapath/rgen\[$i\].region/*/*/*/*/gtxe2_common_*"]
	if {[llength $l] == 1} {
		set_property LOC GTXE2_COMMON_X[lindex $d 0]Y[lindex $d 2] $l
	}
	# Loop over channels
	for {set j 0} {$j < 4} {incr j} {
    # 10g link
    set m [get_cells "datapath/rgen\[$i\].region/*/*/*/*/g_gt_instances\[$j\]*/gtxe2_i"]
        if {[llength $m] != 1} {
      # 3g link
      set m [get_cells "datapath/rgen\[$i\].region/*/*/*/*/gt$j*/gtxe2_i"]
    }
        if {[llength $m] != 1} {
      # 4g8 calo link
      set m [get_cells "datapath/rgen\[$i\].region/mgt_gen_gth_calo.quad/*/*/gt_4g8\[$j\]*/*/*/*/gtxe2_i"]
    }
		if {[llength $m] != 1} {
      # 6g4 calo link
      set m [get_cells "datapath/rgen\[$i\].region/mgt_gen_gth_calo.quad/*/*/gt_6g4\[$j\]*/*/*/*/gtxe2_i"]
    }
		if {[llength $m] != 1} {
      # 4g8 calo link tester
      set m [get_cells "datapath/rgen\[$i\].region/mgt_gen_gth_calotest.quad/*/*/gt_4g8\[$j\]*/*/*/*/gtxe2_i"]
    }
		if {[llength $m] != 1} {
      # 6g4 calo link tester
      set m [get_cells "datapath/rgen\[$i\].region/mgt_gen_gth_calotest.quad/*/*/gt_6g4\[$j\]*/*/*/*/gtxe2_i"]
    }
		if {[llength $m] == 1} {
			#if {$i < 3} {
			#	set c [expr {[lindex $d 1] + 3 - $j}]
			#} else {
            set c [expr {[lindex $d 1] + $j}]
			#}
			set_property LOC GTXE2_CHANNEL_X[lindex $d 0]Y$c $m
		}
	}
}
