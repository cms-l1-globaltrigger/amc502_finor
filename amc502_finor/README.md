### Build amc502_finor firmware with IPBB ###

* This is a draft description with branches of MP7 and ugt repos.
* A fork of [MP7](https://gitlab.cern.ch/hbergaue/mp7) firmware is available with following branches:
  - branch "mp7fw_v2_4_1_amc502_finor" created from tag mp7fw_v2_4_1.
  - branch "mp7fw_v2_4_3_amc502_finor" created from tag mp7fw_v2_4_3.
* These branches contain modified MP7 files for amc502_finor (files are taken from directory "replacement_files"):
  - boards/mp7/base_fw/mp7_690es/firmware/cfg/mp7_690es.dep
  - boards/mp7/base_fw/mp7_690es/firmware/cfg/mp7_690es.tcl
  - components/mp7_readout/firmware/cfg/mp7_readout.dep
  - boards/mp7/base_fw/common/firmware/cfg/constraints_r1.dep
  - components/ipbus_eth/firmware/cfg/k7_420.dep
  - boards/mp7/base_fw/mp7_690es/firmware/hdl/mp7_690es.vhd
  - boards/mp7/base_fw/mp7_690es/firmware/hdl/mp7_brd_decl.vhd
  - components/mp7_infra/firmware/hdl/mp7_infra.vhd
  - components/mp7_links/firmware/hdl/protocol/ext_align_gth_32b_10g_spartan.vhd
  - boards/mp7/base_fw/common/firmware/ucf/area_constraints.tcl
  - boards/mp7/base_fw/common/firmware/ucf/clock_constraints.tcl
  - boards/mp7/base_fw/common/firmware/ucf/mp7_mgt.tcl
  - boards/mp7/base_fw/common/firmware/ucf/pins.tcl
  - components/ipbus_eth/firmware/ngc/gig_eth_pcs_pma_v11_4.ngc
  - components/ipbus_eth/firmware/cgn/gtwizard_v2_3_gbe.xco
  - components/ipbus_eth/firmware/hdl/eth_7s_1000basex_gtx.vhd
  - components/ipbus_eth/firmware/gen_hdl/gig_eth_pcs_pma_v11_4/gig_eth_pcs_pma_v11_4_reset_sync.vhd
  - components/ipbus_eth/firmware/gen_hdl/gig_eth_pcs_pma_v11_4/gig_eth_pcs_pma_v11_4_sync_block.vhd
  - components/ipbus_eth/firmware/gen_hdl/gig_eth_pcs_pma_v11_4/gig_eth_pcs_pma_v11_4_block.vhd
  - components/mp7_ttc/firmware/hdl/ttc_clocks.vhd
  - components/mp7_links/firmware/cfg/gth_10g.dep

* One of these branches is used for build (see below).

* The ugt repo is a fork of [svn2git ugt](https://gitlab.cern.ch/cms-cactus/svn2git/firmware/ugt) repo.

### Setup ###

    # Run kerberos for outside of CERN network
    kinit username@CERN.CH

    # Download and install ipbb
    curl -L https://github.com/ipbus/ipbb/archive/v0.2.8.tar.gz | tar xvz
    source ipbb-0.2.8/env.sh

    # Create a local working area
    ipbb init <build_name>
    cd <build_name>
    ipbb add git https://github.com/ipbus/ipbus-firmware.git -b master
    ipbb add git https://:@gitlab.cern.ch:8443/hbergaue/mp7.git -b mp7fw_v2_4_1_amc502_finor
    ipbb add git https://:@gitlab.cern.ch:8443/hbergaue/ugt.git -b master

    # Patch file top_decl.vhd and copy to ../src/ugt/amc502_finor/firmware/hdl

    # Source Vivado
    
    # Create project 
    ipbb proj create vivado amc502_finor_<build_version> mp7:../ugt/amc502_finor
    cd proj/amc502_finor_<build_version>
    ipbb vivado project

    # Run implementation, synthesis
    ipbb vivado synth
    ipbb vivado impl
    
    # Generate a bitfile
    ipbb vivado package
    deactivate

