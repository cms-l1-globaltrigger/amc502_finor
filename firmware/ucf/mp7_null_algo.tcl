# Area constraints for MP7 null algo

## HB 2018-01-12: this constraint was moved to area_constraints.tcl (by JW). See directory "replacement_files".
#add_cells_to_pblock [get_pblock payload] payload

# HB 2016-09-28: set input and output FFs for finor_in, veto_in and finor_2_tcds
# Input ports finor
set_property IOB TRUE [get_ports FMC0_LA00_CC_P]
set_property IOB TRUE [get_ports FMC0_LA01_CC_P]
set_property IOB TRUE [get_ports FMC0_LA02_P]
set_property IOB TRUE [get_ports FMC1_LA00_CC_P]
set_property IOB TRUE [get_ports FMC1_LA01_CC_P]
set_property IOB TRUE [get_ports FMC1_LA02_P]
# Input ports veto
set_property IOB TRUE [get_ports FMC0_LA03_P]
set_property IOB TRUE [get_ports FMC0_LA04_P]
set_property IOB TRUE [get_ports FMC0_LA05_P]
set_property IOB TRUE [get_ports FMC1_LA03_P]
set_property IOB TRUE [get_ports FMC1_LA04_P]
set_property IOB TRUE [get_ports FMC1_LA05_P]
# Output ports
set_property IOB TRUE [get_ports FMC0_LA06_P]
set_property IOB TRUE [get_ports FMC0_LA07_P]
set_property IOB TRUE [get_ports FMC1_LA06_P]
set_property IOB TRUE [get_ports FMC1_LA07_P]
