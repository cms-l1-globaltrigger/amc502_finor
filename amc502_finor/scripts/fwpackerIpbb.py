#!/usr/bin/env python2
# -*- coding: utf-8 -*-

from makeProject import (
    BoardAliases,
    get_timestamp,
)

import tarfile
import datetime
import argparse
import logging
import shutil
import glob
import tempfile
import ConfigParser
import sys, stat, os

EXIT_SUCCESS = 0
EXIT_FAILURE = 1

def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument('config', help="build configuration file to read")
    parser.add_argument('--outdir', metavar="<path>", type=os.path.abspath, help="set location to write tarball")
    return parser.parse_args()

def main():
    """Main routine."""

    # Parse command line arguments.
    args = parse_args()

    # Setup console logging
    logging.basicConfig(format = '%(levelname)s: %(message)s', level = logging.DEBUG)

    # with tarfile

    config = ConfigParser.RawConfigParser()
    config.read(args.config)

    for section in config.sections():
        print section
        for option in config.options(section):
            print " ", option, "=", config.get(section, option)

    board = config.get('device', 'name')
    build = config.get('firmware', 'build')
    fw_type = config.get('firmware', 'type')
    buildarea = config.get('firmware', 'buildarea')
    timestamp = get_timestamp()

    basename = "{board}_{fw_type}_v{build}".format(**locals())
    basepath = os.path.dirname(args.config)
    # Custom output directory?
    if args.outdir:
        basepath = args.outdir
    filename = os.path.join(basepath, "{basename}-{timestamp}.tar.gz".format(**locals()))

    tmpdir = tempfile.mkdtemp()
    logging.info("Created temporary dircetory %s", tmpdir)

    logging.info("collecting data from AMC502 %s", fw_type)
    build_dir = os.path.join(tmpdir, 'build')
    log_dir = os.path.join(tmpdir, 'log')
    proj_dir = 'proj/{}_{}_0x{}'.format(board, fw_type, build)
    os.makedirs(build_dir)
    os.makedirs(log_dir)
    shutil.copy(os.path.join(buildarea, proj_dir, 'top', 'top.runs', 'impl_1', 'top.bit'),
        os.path.join(build_dir, '{board}_{fw_type}_v{build}.bit'.format(**locals())))
    shutil.copy(os.path.join(buildarea, proj_dir, 'top', 'top.runs', 'synth_1', 'runme.log'),
        os.path.join(log_dir, 'runme_synth_1.log'))
    shutil.copy(os.path.join(buildarea, proj_dir, 'top', 'top.runs', 'impl_1', 'runme.log'),
        os.path.join(log_dir, 'runme_impl_1.log'))

    logging.info("adding build configuration: %s", args.config)
    shutil.copy(args.config, tmpdir)


    logging.info("creating tarball: %s", filename)
    tar = tarfile.open(filename, "w:gz")
    logging.info("adding to tarball: %s", tmpdir)
    tar.add(tmpdir, arcname = basename, recursive = True)
    logging.info("closing tarball: %s", filename)
    tar.close()

    logging.info("removing temporary directory %s.", tmpdir)
    shutil.rmtree(tmpdir)

    logging.info("done.")

if __name__ == '__main__':
    try:
        main()
    except RuntimeError, message:
        logging.error(message)
        sys.exit(EXIT_FAILURE)
    sys.exit(EXIT_SUCCESS)
