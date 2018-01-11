# Area constraints for AMC502 #

# Control region (X1Y0)

create_pblock ctrl
resize_pblock [get_pblocks ctrl] -add {CLOCKREGION_X0Y5:CLOCKREGION_X1Y5}
add_cells_to_pblock [get_pblocks ctrl] [get_cells -quiet [list infra ttc ctrl readout]]

# There area  few exceptions to the area constraints above due to resource availability
# In the past overwrote main constraint with "LOC" constraint in ISE.  Does not work
# in Vivado.  Use another pblock instead.

create_pblock mmcm_ttc
add_cells_to_pblock [get_pblocks mmcm_ttc] [get_cells ttc/clocks/mmcm]
resize_pblock [get_pblocks mmcm_ttc] -add {CLOCKREGION_X0Y4}

create_pblock mmcm_infra_clocks
add_cells_to_pblock [get_pblocks mmcm_infra_clocks] [get_cells infra/clocks/mmcm]
resize_pblock [get_pblocks mmcm_infra_clocks] -add {CLOCKREGION_X0Y5:CLOCKREGION_X1Y5}

create_pblock mmcm_infra_eth
add_cells_to_pblock [get_pblocks mmcm_infra_eth] [get_cells infra/eth/mmcm]
resize_pblock [get_pblocks mmcm_infra_eth] -add {CLOCKREGION_X0Y6}

# Basic payload area

create_pblock payload
resize_pblock [get_pblocks payload] -add {SLICE_X0Y0:SLICE_X88Y199}
resize_pblock [get_pblocks payload] -add {RAMB18_X0Y0:RAMB18_X5Y79}
resize_pblock [get_pblocks payload] -add {RAMB36_X0Y0:RAMB36_X5Y39}
add_cells_to_pblock [get_pblocks payload] payload

# Quad and per-region area constraints

set q_coords {
	{SLICE_X89Y50:SLICE_X189Y99 RAMB18_X6Y20:RAMB18_X11Y39}
	{SLICE_X89Y0:SLICE_X189Y49 RAMB18_X6Y0:RAMB18_X11Y19}
}

set p_coords {
	SLICE_X0Y50:SLICE_X88Y99
	SLICE_X0Y0:SLICE_X88Y49
}

for {set i 0} {$i < 2} {incr i} {
	set bq [create_pblock quad_$i]
	resize_pblock $bq -add [lindex $q_coords $i]
	add_cells_to_pblock $bq "datapath/rgen\[$i\].region"
	set br [create_pblock payload_$i]
	resize_pblock $br -add [lindex $p_coords $i]
}

# "Cross-device" registers for readout and TTC path

#add_cells_to_pblock [get_pblocks payload_1] [get_cells -quiet datapath/rgen[1].region/pgen.*]
