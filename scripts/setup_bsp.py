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
import subprocess
import sys
import tarfile

SCRIPT_PATH = os.path.dirname(os.path.abspath(__file__))
PROJECT_PATH = os.path.dirname(os.path.abspath(SCRIPT_PATH))
DEFAULT_BSP = 'dcp_a10'
DEFAULT_BSP_DIR = os.path.join(PROJECT_PATH, 'hardware')
DEFAULT_PLATFORM = "dcp_1.0-rc"


# get bsp list by searching a list of directories.
# BSPs are identified as diretories with board_spec.xml
# searches these paths:
#    [bsp_search_dir, bsp_search_dir/*, bsp_search_dir/hardware/*]
# builds map with name, xml path, absolute dir path
def get_bsp_info_map(bsp):
    # bsp can be string or list but we want to convert it to list
    if(isinstance(bsp, (str, unicode))):
        dir_list = [bsp]
    else:
        dir_list = bsp

    xml_list = []
    for i in dir_list:
        xml_list.extend(glob.glob(os.path.join(i, 'board_spec.xml')))
        xml_list.extend(glob.glob(os.path.join(i, '*', 'board_spec.xml')))
        xml_list.extend(glob.glob(os.path.join(i, 'hardware', '*',
                                               'board_spec.xml')))

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


# run command
def run_cmd(cmd, path=None):
    if(path):
        old_cwd = os.getcwd()
        os.chdir(path)
    process = subprocess.Popen(cmd,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE,
                               stdin=subprocess.PIPE,
                               shell=True)
    out, _err = process.communicate()
    exitcode = process.poll()
    if(path):
        os.chdir(old_cwd)
    if exitcode == 0:
        return str(out).rstrip()
    else:
        print "ERROR: command '%s' failed" % cmd
        sys.exit(1)


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


# symlink function that accepts globs and can overlay existing directories
def symlink_glob(src, dst):
    for i in glob.glob(src):
        if os.path.isdir(i):
            dst_dir_path = os.path.join(dst, os.path.basename(i))
            if(not os.path.exists(dst_dir_path)):
                os.mkdir(dst_dir_path)
            symlink_glob(os.path.join(i, '*'), dst_dir_path)
            # '.' files(hidden files) are not included in '*'
            symlink_glob(os.path.join(i, '.*'), dst_dir_path)
        else:
            dst_link = os.path.join(dst, os.path.basename(i))
            if(os.path.exists(dst_link)):
                os.remove(dst_link)
            os.symlink(i, dst_link)


# take a glob path and remove the files
def rm_glob(src, verbose=False):
    for i in glob.glob(src):
        os.remove(i)
        if(verbose):
            print "Removed: %s" % i


# create a text file
def create_text_file(dst, lines):
    with open(dst, 'w') as f:
        for line in lines:
            f.write(line)


# main work function for setting up bsp
def setup_bsp(platform, bsp_search_dirs, sim_mode=False, verbose=False,
              debug=False, overlay=None):
    packager_bin = get_packager_bin()
    platform_dir = get_platform_dir(platform)

    bsp_info_map = get_bsp_info_map(bsp_search_dirs)

    if(verbose):
        print "bsp_search_dirs: %s" % bsp_search_dirs
        print "platform: %s" % platform
        print "packager_bin: %s" % packager_bin
        print "platform_dir: %s" % platform_dir
        print "bsp_info_map: %s" % bsp_info_map.keys()

    if(debug):
        print "bsp_info_map %s\n" % bsp_info_map

    for bsp in bsp_info_map.keys():
        bsp_dir = bsp_info_map[bsp]['dir']
        bsp_qsf_dir = os.path.join(bsp_dir, 'build')

        # handle overlay/patch to bsp hw
        if(overlay):
            overlay_file = os.path.join(PROJECT_PATH, 'overlays',
                                        "%s.patch" % overlay)
            if(not os.path.exists(overlay_file)):
                print "ERROR: overlay %s path not found" % overlay_file
                sys.exit(1)
            run_cmd("patch -f -p3 -i %s" % overlay_file, bsp_dir)

        # copy empty afu template files to bsp_dir
        copy_glob(os.path.join(platform_dir, 'lib', 'build', '*'), bsp_qsf_dir)
        copy_glob(os.path.join(platform_dir, 'lib', '*.txt'), bsp_qsf_dir)

        # clean up junk in output_files from bbs compile
        output_files_path = os.path.join(bsp_qsf_dir, 'output_files')
        rm_glob(os.path.join(output_files_path, '*.rpt'))
        rm_glob(os.path.join(output_files_path, '*.jic'))
        rm_glob(os.path.join(output_files_path, '*.rpd'))
        rm_glob(os.path.join(output_files_path, '*.summary'))
        rm_glob(os.path.join(output_files_path, '*.sld'))
        rm_glob(os.path.join(output_files_path, 'timing_report', '*'))

        # add packager to opencl bsp to make bsp easier to use
        bsp_tools_dir = os.path.join(bsp_qsf_dir, 'tools')
        delete_and_mkdir(bsp_tools_dir)
        shutil.copy2(packager_bin, bsp_tools_dir)

        # unzip pr artifacts
        shutil.rmtree(os.path.join(bsp_dir, 'design'), ignore_errors=True)
        pr_design_artifacts_path = os.path.join(platform_dir,
                                                'pr_design_artifacts.tar.gz')
        tar = tarfile.open(pr_design_artifacts_path)
        tar.extractall(bsp_dir)
        tar.close()

        # create hw directory for afu compatibility
        bsp_hw_dir = os.path.join(bsp_dir, 'hw')
        delete_and_mkdir(bsp_hw_dir)
        # we don't use afu.qsf, so just put a stub in
        create_text_file(os.path.join(bsp_hw_dir, 'afu.qsf'), ["# NOT USED\n"])

        # find OPAE install path
        opae_inst_path = os.path.join(os.environ["ADAPT_DEST_ROOT"], 'sw',
                                      'opae_sdk_x')
        if(not os.path.exists(opae_inst_path)):
            # opae install path in adapt build is process of changing
            # need to check old location as well
            opae_inst_path = os.path.join(os.environ["ADAPT_DEST_ROOT"],
                                          'opae_sdk_x')
        if(not os.path.exists(opae_inst_path)):
            print "ERROR: opae install path not found"
            exit(1)

        # setup and run afu_platform_config
        platform_lib_dir = os.path.join(platform_dir, 'lib')
        platform_db_dir = os.path.join(platform_lib_dir,
                                       'platform', 'platform_db')
        os.environ["BBS_LIB_PATH"] = platform_lib_dir
        if("OPAE_PLATFORM_DB_PATH" in os.environ):
            os.environ["OPAE_PLATFORM_DB_PATH"] += ":" + platform_db_dir
        else:
            os.environ["OPAE_PLATFORM_DB_PATH"] = platform_db_dir
        bsp_platform_if_dir = os.path.join(bsp_qsf_dir, 'platform_if')
        delete_and_mkdir(bsp_platform_if_dir)
        opae_platform_if_path = os.path.join(opae_inst_path, 'share', 'opae',
                                             'platform', 'platform_if')
        copy_glob(os.path.join(opae_platform_if_path, "*"),
                  bsp_platform_if_dir)
        afu_platform_config_bin = os.path.join(opae_inst_path, 'bin',
                                               'afu_platform_config')

        # Read the FME class name from the standard location
        plat_class_file = os.path.join(platform_lib_dir,
                                       'fme-platform-class.txt')
        with open(plat_class_file) as f:
            plat_class_name = f.read().strip()

        cfg_cmd = (afu_platform_config_bin + " "
                   "--qsf  --ifc ccip_std_afu_avalon_mm_legacy_wires "
                   "--tgt ./build/platform "
                   "--platform_if platform_if " +
                   plat_class_name)
        run_cmd(cfg_cmd, bsp_dir)

        # setup sim stuff if needed
        if(sim_mode):
            # these can be symlinked because we won't create packages with them
            # sim_mode is internal only
            symlink_glob(os.path.join(PROJECT_PATH, 'ase', 'bsp', '*'),
                         bsp_qsf_dir)

        # create quartus project revision for opencl kernel qsf
        kernel_qsf_path = os.path.join(bsp_dir, 'afu_opencl_kernel.qsf')
        shutil.copy2(os.path.join(bsp_qsf_dir, 'afu_synth.qsf'),
                     kernel_qsf_path)
        update_qsf_settings_for_opencl_kernel_qsf(kernel_qsf_path)

        shutil.copy2(os.path.join(bsp_qsf_dir, 'dcp.qpf'), bsp_dir)
        update_qpf_project_for_opencl_flow(os.path.join(bsp_dir, 'dcp.qpf'))

        # update quartus project files for opencl
        update_qpf_project_for_afu(os.path.join(bsp_qsf_dir, 'dcp.qpf'))
        update_qsf_settings_for_opencl_afu(os.path.join(bsp_qsf_dir,
                                                        'afu_synth.qsf'))
        update_qsf_settings_for_opencl_afu(os.path.join(bsp_qsf_dir,
                                                        'afu_fit.qsf'))

        # create manifest
        create_manifest(bsp_dir)


# remove lines with search_text in file
def create_manifest(dst_dir):
    files = []
    for i in glob.glob(os.path.join(dst_dir, '*')):
        filename = os.path.basename(i)
        files.append("%s\n" % filename)
    manifest_file = 'bsp_dir_filelist.txt'
    files.append("%s\n" % manifest_file)
    # add qdb so that it is not copied to build directory
    files.append('qdb\n')
    create_text_file(os.path.join(dst_dir, manifest_file), files)


# remove lines with search_text in file
def remove_lines_in_file(file_name, search_text):
    lines = []
    with open(file_name) as f:
        for line in f:
            if search_text in line:
                continue
            lines.append(line)

    with open(file_name, 'w') as f:
        for line in lines:
            f.write(line)


# replace search_text with replace_text in file
def replace_lines_in_file(file_name, search_text, replace_text):
    lines = []
    with open(file_name) as f:
        for line in f:
            if search_text in line:
                lines.append(line.replace(search_text, replace_text))
            else:
                lines.append(line)

    with open(file_name, 'w') as f:
        for line in lines:
            f.write(line)


# python equivalent of "chmod +w"
def chmod_plus_w(file_path):
    file_stats = os.stat(file_path)
    os.chmod(file_path, file_stats.st_mode | (stat.S_IWRITE))


# update quartus project for opencl flow
def update_qpf_project_for_opencl_flow(qpf_path):
    chmod_plus_w(qpf_path)

    # need to rewrite these lines so that opencl AOC qsys flow modifies the
    # correct project
    remove_lines_in_file(qpf_path, 'PROJECT_REVISION')

    with open(qpf_path, 'a') as f:
        f.write('\n')
        f.write('\n')
        f.write('#YOU MUST PUT SYNTH REVISION FIRST SO THAT '
                'AOC WILL DEFAULT TO THAT WITH qsys-script!\n')
        f.write('PROJECT_REVISION = "afu_opencl_kernel"\n')
        f.write('PROJECT_REVISION = "dcp"\n')


# update quartus project for afu compile flow
def update_qpf_project_for_afu(qpf_path):
    chmod_plus_w(qpf_path)

    # need to rewrite these lines so that opencl AOC qsys flow modifies the
    # correct project
    remove_lines_in_file(qpf_path, 'PROJECT_REVISION')

    with open(qpf_path, 'a') as f:
        f.write('\n')
        f.write('\n')
        f.write('#YOU MUST PUT SYNTH REVISION FIRST SO THAT '
                'AOC WILL DEFAULT TO THAT WITH qsys-script!\n')
        f.write('PROJECT_REVISION = "afu_fit"\n')
        f.write('PROJECT_REVISION = "afu_synth"\n')
        f.write('PROJECT_REVISION = "dcp"\n')


def update_qsf_settings_for_opencl_kernel_qsf(qsf_path):
    # create stripped down version of qsf for opencl qsys flow
    chmod_plus_w(qsf_path)

    remove_lines_in_file(qsf_path, 'dcp_user_clocks.sdc')
    remove_lines_in_file(qsf_path, 'SCJIO')

    remove_lines_in_file(qsf_path, '..')
    remove_lines_in_file(qsf_path, '.qsf')
    remove_lines_in_file(qsf_path, '.tcl')
    remove_lines_in_file(qsf_path, 'SOURCE')
    remove_lines_in_file(qsf_path, 'SEARCH_PATH')
    remove_lines_in_file(qsf_path, '_FILE ')

    with open(qsf_path, 'a') as f:
        f.write('\n')
        f.write('\n')
        f.write('##OPENCL_KERNEL_ASSIGNMENTS_START_HERE\n')
        f.write('\n')
        f.write('\n')


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

    remove_lines_in_file(qsf_path, 'dcp_user_clocks.sdc')
    remove_lines_in_file(qsf_path, 'SCJIO')


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
    parser.add_argument('--overlay', '-o', required=False,
                        default=None, help='include bsp overlay modification')
    parser.add_argument('--bsp-search-dirs', '-b', nargs='*',
                        required=False,
                        default=[DEFAULT_BSP_DIR],
                        help='set bsp search directories')

    args = parser.parse_args()

    if(args.debug):
        print "ARGS: ", args

    sim_mode = False
    if("OPENCL_ASE_SIM" in os.environ):
        if(os.environ["OPENCL_ASE_SIM"] == "1"):
            sim_mode = True

    setup_bsp(platform=args.platform, bsp_search_dirs=args.bsp_search_dirs,
              sim_mode=sim_mode,
              verbose=args.verbose, debug=args.debug, overlay=args.overlay)


if __name__ == '__main__':
    main()
