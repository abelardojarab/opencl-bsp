# !/usr/bin/env python

# (C) 2017 Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions and other
# software and tools, and its AMPP partner logic functions, and any output
# files any of the foregoing (including device programming or simulation
# files), and any associated documentation or information are expressly subject
# to the terms and conditions of the Intel Program License Subscription
# Agreement, Intel MegaCore Function License Agreement, or other applicable
# license agreement, including, without limitation, that your use is for the
# sole purpose of programming logic devices manufactured by Intel and sold by
# Intel or its authorized distributors.  Please refer to the applicable
# agreement for further details.


# setup_bsp.py
# description:
#    this script imports pr project files from a DCP bbs build
# usage:
#    python setup_bsp.py -h


import argparse
import glob
import os
import shutil
import stat
import sys
import tarfile

SCRIPT_PATH = os.path.dirname(os.path.abspath(__file__))
PROJECT_PATH = os.path.dirname(os.path.abspath(SCRIPT_PATH))
DEFAULT_BSP_DIR = os.path.join(PROJECT_PATH, 'hardware', 'dcp_a10')
DEFAULT_PLATFORM = "dcp_1.0-rc"


# get bsp list by searching a list of directories.
# BSPs are identified as diretories with board_spec.xml
# searches these paths:
#    [bsp_search_dir, bsp_search_dir/*, bsp_search_dir/hardware/*]
# builds map with name, xml path, absolute dir path
def get_bsp_list(bsp):
    bsp_list = []
    # bsp can be string or list but we want to convert it to list
    if(isinstance(bsp, (str, unicode))):
        dir_list = [bsp]
    else:
        dir_list = bsp

    xml_list = []
    for i in dir_list:
        glob_str = '%s/*' % i
        xml_list += glob.glob(os.path.join(i, 'board_spec.xml'))
        xml_list += glob.glob(os.path.join(i, '*', 'board_spec.xml'))
        xml_list += glob.glob(os.path.join(i, 'hardware', '*',
                                           'board_spec.xml'))

    bsp_map = {}
    for i in xml_list:
        bsp_item = {}
        bsp_item['xml'] = os.path.abspath(i)
        bsp_item['dir'] = os.path.abspath(os.path.dirname(i))
        bsp_name = os.path.basename(bsp_item['dir'])
        bsp_item['name'] = bsp_name
        if bsp_name in bsp_map:
            print "ERROR: BSP '%s' is defined multiple times" % bsp_name
            sys.exit(1)
        bsp_map[bsp_name] = bsp_item

    return bsp_map


# get platform dir from ADAPT_DEST_ROOT
def get_platform_dir(platform_name):
    if "ADAPT_DEST_ROOT" not in os.environ:
        print "ERROR: ADAPT_DEST_ROOT environment variable is not set!\n"
        sys.exit(1)

    platform_path = os.path.join(os.environ["ADAPT_DEST_ROOT"], 'platform',
                                 platform_name)
    if not os.path.exists(platform_path):
        print "ERROR: %s path not found" % platform_path
        sys.exit(1)

    return platform_path


# get packager bin file from ADAPT_DEST_ROOT
def get_packager_bin():
    if "ADAPT_DEST_ROOT" not in os.environ:
        print "ERROR: ADAPT_DEST_ROOT environment variable is not set!\n"
        sys.exit(1)

    packager_bin = os.path.join(os.environ["ADAPT_DEST_ROOT"], 'tools',
                                'packager', 'packager.pyz')

    if(not os.path.exists(packager_bin)):
        print "ERROR: %s path not found" % packager_bin
        sys.exit(1)

    return packager_bin


# delete directory and create empty directory in its place
def delete_and_mkdir(dir_path):
    shutil.rmtree(dir_path, ignore_errors=True)
    os.mkdir(dir_path)


# copy function that accepts globs and can overlay existing directories
def copy_glob(src, dst):
    for i in glob.glob(src):
        if os.path.isdir(i):
            dst_dir_path = os.path.join(dst, os.path.basename(i))
            if(not os.path.exists(dst_dir_path)):
                os.mkdir(dst_dir_path)
            copy_glob(os.path.join(i, '*'), dst_dir_path)
            # '.' files(hidden files) are not included in '*'
            copy_glob(os.path.join(i, '.*'), dst_dir_path)
        else:
            shutil.copy2(i, dst)


# take a glob path and remove the files
def rm_glob(src, verbose=False):
    for i in glob.glob(src):
        os.remove(i)
        if(verbose):
            print "Removed: %s" % i


# main work function for setting up bsp
def setup_bsp(platform, bsp_search_dirs, verbose=False, debug=False):
    packager_bin = get_packager_bin()
    platform_dir = get_platform_dir(platform)

    bsp_list = get_bsp_list(bsp_search_dirs)

    if(verbose):
        print "bsp_search_dirs: %s" % bsp_search_dirs
        print "platform: %s" % platform
        print "packager_bin: %s" % packager_bin
        print "platform_dir: %s" % platform_dir
        print "bsp_list: %s" % bsp_list.keys()

    if(debug):
        print "bsp_list %s\n" % bsp_list

    for bsp in bsp_list.keys():
        bsp_dir = bsp_list[bsp]['dir']

        # create empty directories inside bsp_dir
        output_files_dir = os.path.join(bsp_dir, 'output_files')
        delete_and_mkdir(output_files_dir)

        bsp_afu_dir = os.path.join(bsp_dir, 'afu')
        delete_and_mkdir(bsp_afu_dir)

        afu_interfaces_dir = os.path.join(bsp_afu_dir, 'interfaces')
        delete_and_mkdir(afu_interfaces_dir)

        # copy empty afu template files to bsp_dir
        copy_glob(os.path.join(platform_dir, 'lib', '*'), bsp_dir)
        copy_glob(os.path.join(platform_dir, 'empty_afu', 'afu', '*'),
                  bsp_afu_dir)
        copy_glob(os.path.join(platform_dir, 'empty_afu', 'build', '*'),
                  bsp_dir)

        # clean up unneeded files
        rm_glob(os.path.join(bsp_dir, '*.stp'), verbose=verbose)
        rm_glob(os.path.join(bsp_dir, 'a10_partial_reconfig',
                             'import_bbs_sdc.tcl'), verbose=verbose)

        # add packager to opencl bsp to make bsp easier to use
        bsp_tools_dir = os.path.join(bsp_dir, 'tools')
        delete_and_mkdir(bsp_tools_dir)
        shutil.copy2(packager_bin, bsp_tools_dir)

        shutil.rmtree(os.path.join(bsp_dir, 'design'), ignore_errors=True)
        pr_design_artifacts_path = os.path.join(bsp_dir,
                                                'pr_design_artifacts.tar.gz')

        # unzip pr artifacts
        tar = tarfile.open(pr_design_artifacts_path)
        tar.extractall(bsp_dir)
        tar.close()
        os.remove(pr_design_artifacts_path)

        # setup sim stuff if needed
        if("OPENCL_ASE_SIM" in os.environ):
            if(os.environ["OPENCL_ASE_SIM"] == "1"):
                copy_glob(os.path.join(PROJECT_PATH, 'ase', 'bsp', '*'),
                          bsp_dir)

        # update quartus project files for opencl
        update_qsf_settings_for_opencl_afu(os.path.join(bsp_dir,
                                                        'afu_synth.qsf'))
        update_qsf_settings_for_opencl_afu(os.path.join(bsp_dir,
                                                        'afu_fit.qsf'))
        update_qpf_project_for_opencl_afu(os.path.join(bsp_dir, 'dcp.qpf'))


def remove_lines_in_file(file_name, search_text):
    lines = []
    with open(file_name) as f:
        for line in f:
            if search_text in line:
                continue
            lines += [line]

    with open(file_name, 'w') as f:
        for line in lines:
            f.write(line)


def replace_lines_in_file(file_name, search_text, replace_text):
    lines = []
    with open(file_name) as f:
        for line in f:
            if search_text in line:
                lines += [line.replace(search_text, replace_text)]
            else:
                lines += [line]

    with open(file_name, 'w') as f:
        for line in lines:
            f.write(line)


# python equivalent of "chmod +w"
def chmod_plus_w(file_path):
    file_stats = os.stat(file_path)
    os.chmod(file_path, file_stats.st_mode | (stat.S_IWRITE))


# update quartus project for opencl flow
def update_qpf_project_for_opencl_afu(qpf_path):
    chmod_plus_w(qpf_path)

    # need to rewrite these lines so that opencl AOC qsys flow modifies the
    # correct project
    remove_lines_in_file(qpf_path, 'PROJECT_REVISION')

    with open(qpf_path, 'a') as f:
        f.write('\n')
        f.write('\n')
        f.write('#YOU MUST PUT SYNTH REVISION FIRST SO THAT '
                'AOC WILL DEFAULT TO THAT WITH qsys-script!\n')
        f.write('PROJECT_REVISION = "afu_synth"\n')
        f.write('PROJECT_REVISION = "afu_fit"\n')
        f.write('PROJECT_REVISION = "dcp"\n')


def update_qsf_settings_for_opencl_afu(qsf_path):
    chmod_plus_w(qsf_path)

    with open(qsf_path, 'a') as f:
        f.write('\n')
        f.write('\n')
        f.write("# AFU  section - User AFU RTL goes here\n")
        f.write("# =============================================\n")
        f.write("#\n")
        f.write("# AFU + MPF IPs\n")
        f.write("source afu_ip.qsf\n")

    replace_lines_in_file(qsf_path, '../afu/', './afu/')


# process command line and setup bsp flow
def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--verbose', '-v', required=False, default=False,
                        action='store_true',
                        help='print more verbose output')
    parser.add_argument('--debug', '-d', required=False, default=False,
                        action='store_true',
                        help='print more output for debugging')
    parser.add_argument('--platform', '-p', required=False,
                        default=DEFAULT_PLATFORM, help='set platform')
    parser.add_argument('--bsp_search_dirs', '-b', nargs='*',
                        required=False,
                        default=[DEFAULT_BSP_DIR],
                        help='set bsp search directories')

    args = parser.parse_args()

    if(args.debug):
        print "ARGS: ", args

    setup_bsp(platform=args.platform, bsp_search_dirs=args.bsp_search_dirs,
              verbose=args.verbose, debug=args.debug)


if __name__ == '__main__':
    main()
