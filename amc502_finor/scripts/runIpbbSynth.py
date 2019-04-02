#!/usr/bin/env python2
# -*- coding: utf-8 -*-

import toolbox as tb

import argparse
import datetime
import urllib
import logging
import shutil
from distutils.dir_util import copy_tree
import subprocess
import glob
import ConfigParser
import sys, os, re
import stat
import pwd
import socket
from os.path import expanduser

HB_PC = 'powerslave'
"""if HB_PC => Bergauer PC 'powerslave' Xilinx Vivado installation location = '/opt/Xilinx/Vivado."""
"""else => Default Xilinx Vivado installation location = '/opt/xilinx/Vivado'."""
if socket.gethostname() == HB_PC:
    VIVADO_BASE_DIR = '/opt/Xilinx/Vivado'
else:
    VIVADO_BASE_DIR = '/opt/xilinx/Vivado'

EXIT_SUCCESS = 0
EXIT_FAILURE = 1

# Set correct FW_TYPE and BOARD_TYPE for each project!
FW_TYPE = 'finor'
BOARD_TYPE = 'amc502'

BoardAliases = {
    'mp7_690es': 'r1',
    #'mp7xe_690': 'xe',
}

DefaultBoardType = 'mp7_690es'
"""Default board type to be used."""

DefaultFirmwareDir = os.path.expanduser("~/work_ipbb")
"""Default output directory for firmware builds."""

DefaultGitlabUrlIPB = 'https://github.com/ipbus/ipbus-firmware.git'
"""Default URL of gitlab IPB repo."""

DefaultGitlabUrlMP7 = 'https://:@gitlab.cern.ch:8443/hbergaue/mp7.git'
"""Default URL of gitlab MP7 repo."""

DefaultGitlabUrlUgt = 'https://:@gitlab.cern.ch:8443/hbergaue/ugt.git'
"""Default URL of gitlab ugt repo."""

def run_command(*args):
    command = ' '.join(args)
    logging.info(">$ %s", command)
    os.system(command)

def vivado_t(version):
    """Validates Xilinx Vivado version number."""
    if not re.match(r'^\d{4}\.\d+$', version):
        raise ValueError("not a xilinx vivado version: '{version}'".format(**locals()))
    return version

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument('vivado', type=vivado_t, help="xilinx vivado version to run, eg. '2018.2'")
    parser.add_argument('--ipburl', metavar='<path>', default=DefaultGitlabUrlIPB, help="URL of IPB firmware repo")
    parser.add_argument('-i', '--ipb', metavar='<tag>', default='master', help='IPBus firmware repo: tag or branch name (default is "master")')
    parser.add_argument('--mp7url', metavar='<path>', default=DefaultGitlabUrlMP7, help="URL of MP7 firmware repo")
    parser.add_argument('-t', '--tag', metavar='<tag>', required=True, help="MP7 firmware repo: tag name [is required]")
    parser.add_argument('--ugturl', metavar='<path>', default=DefaultGitlabUrlUgt, help="URL of ugt firmware repo")
    parser.add_argument('-u', '--ugt', metavar='<tag>', required=True, help='ugt firmware repo: tag or branch name [is required]')
    parser.add_argument('--board', metavar='<type>', default=DefaultBoardType, choices=BoardAliases.keys(), help="set board type (default is {})".format(DefaultBoardType))
    parser.add_argument('-p', '--path', metavar='<path>', default=DefaultFirmwareDir, type=os.path.abspath, help="fw build path (default is {})".format(DefaultFirmwareDir))
    parser.add_argument('-b', '--build', metavar='<version>', required=True, type=tb.build_t, help='menu build version (eg. 0x1001) [is required]')
    return parser.parse_args()

def main():
    """Main routine."""

    # Parse command line arguments.
    args = parse_args()

    # Setup console logging
    logging.basicConfig(format='%(levelname)s: %(message)s', level=logging.DEBUG)

    # Compile build root directory
    project_type = "{}_{}".format(BOARD_TYPE, FW_TYPE)
    build_name = "0x{}".format(args.build)
    ipbb_dir = os.path.join(args.path, project_type, args.tag, build_name)

    if os.path.isdir(ipbb_dir):
        raise RuntimeError("build area alredy exists: {}".format(ipbb_dir))

    ipbb_src_fw_dir = os.path.abspath(os.path.join(ipbb_dir, 'src', 'ugt', project_type, 'firmware'))

    # IPBB commands: creating IPBB area
    cmd_source_ipbb = "source ipbb-0.2.8/env.sh"
    cmd_ipbb_init = "ipbb init {ipbb_dir}".format(**locals())
    cmd_ipbb_add_ipb = "ipbb add git {args.ipburl} -b {args.ipb}".format(**locals())
    cmd_ipbb_add_mp7 = "ipbb add git {args.mp7url} -b {args.tag}_amc502_finor".format(**locals())
    cmd_ipbb_add_ugt = "ipbb add git {args.ugturl} -b {args.ugt}".format(**locals())

    logging.info("===========================================================================")
    logging.info("creating IPBB area ...")
    command = 'bash -c "cd; {cmd_source_ipbb}; {cmd_ipbb_init}; cd {ipbb_dir}; {cmd_ipbb_add_ipb} && {cmd_ipbb_add_mp7} && {cmd_ipbb_add_ugt}"'.format(**locals())
    run_command(command)

    # Removing unused mp7_ugt, mp7_tdf and AMC502 firmware directories
    logging.info("removing src directories of unused firmware ...")
    command = 'bash -c "cd; cd {ipbb_dir}/src/ugt; rm -rf mp7_ugt && rm -rf amc502_extcond && rm -rf amc502_finor_pre && rm -rf mp7_tdf"'.format(**locals())
    run_command(command)

    logging.info("patch the target package with current UNIX timestamp/username/hostname ...")
    top_pkg_tpl = os.path.join(ipbb_src_fw_dir, 'hdl', 'top_decl_tpl.vhd')
    top_pkg = os.path.join(ipbb_src_fw_dir, 'hdl', 'top_decl.vhd')
    subprocess.check_call(['python', os.path.join(ipbb_src_fw_dir, '..', 'scripts', 'pkgpatch.py'), '--build', args.build, top_pkg_tpl, top_pkg])

    # Vivado settings
    settings64 = os.path.join(VIVADO_BASE_DIR, args.vivado, 'settings64.sh')
    if not os.path.isfile(settings64):
        raise RuntimeError(
            "no such Xilinx Vivado settings file '{settings64}'\n" \
            "  check if Xilinx Vivado {args.vivado} is installed on this machine.".format(**locals())
        )

    logging.info("creating IPBB project ...")
    cmd_ipbb_proj_create = "ipbb proj create vivado {project_type}_{build_name} mp7:../ugt/{project_type}".format(**locals())

    command = 'bash -c "cd; {cmd_source_ipbb}; cd {ipbb_dir}; {cmd_ipbb_proj_create}"'.format(**locals())
    run_command(command)

    logging.info("running IPBB project, synthesis and implementation, creating bitfile ...")

    # IPBB commands: running IPBB project, synthesis and implementation, creating bitfile
    cmd_ipbb_project = "ipbb vivado project"
    cmd_ipbb_synth = "ipbb vivado synth"
    cmd_ipbb_impl = "ipbb vivado impl"
    cmd_ipbb_bitfile = "ipbb vivado package"

    command = 'bash -c "cd; {cmd_source_ipbb}; source {settings64}; cd {ipbb_dir}/proj/{project_type}_{build_name}; {cmd_ipbb_project} && {cmd_ipbb_synth} && {cmd_ipbb_impl} && {cmd_ipbb_bitfile}"'.format(**locals())

    session = "build_{project_type}_{build_name}".format(**locals())
    logging.info("starting screen session '%s' ...", session)
    run_command('screen', '-dmS', session, command)

    # list running screen sessions
    run_command('screen', '-ls')

    os.chdir(ipbb_dir)

    # Creating configuration file.
    config = ConfigParser.RawConfigParser()
    config.add_section('environment')
    config.set('environment', 'timestamp', tb.timestamp())
    config.set('environment', 'hostname', tb.hostname())
    config.set('environment', 'username', tb.username())

    config.add_section('firmware')
    config.set('firmware', 'ipb URL', args.ipburl)
    config.set('firmware', 'ipb branch', args.ipb)
    config.set('firmware', 'mp7 URL', args.mp7url)
    config.set('firmware', 'mp7 tag', args.tag)
    config.set('firmware', 'ugt URL', args.ugturl)
    config.set('firmware', 'ugt branch', args.ugt)
    config.set('firmware', 'type', FW_TYPE)
    config.set('firmware', 'buildarea', ipbb_dir)

    config.add_section('device')
    config.set('device', 'type', args.board)
    config.set('device', 'name', BOARD_TYPE)
    config.set('device', 'alias', BoardAliases[args.board])

    # Writing configuration file
    with open('build_0x{}.cfg'.format(args.build), 'wb') as fp:
        config.write(fp)

    logging.info("created configuration file: %s/build_0x%s.cfg.", ipbb_dir, args.build)
    logging.info("done.")

if __name__ == '__main__':
    try:
        main()
    except RuntimeError, message:
        logging.error(message)
        sys.exit(EXIT_FAILURE)
    sys.exit(EXIT_SUCCESS)
