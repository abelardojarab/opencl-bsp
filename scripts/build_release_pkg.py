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


# build_release_pkg.py
# description:
#    this script builds an opencl release package
# usage:
#    python build_release_pkg.py -h


import argparse
import datetime
import glob
import os
import shutil
import subprocess
import tarfile

from setup_bsp import delete_and_mkdir, copy_glob, run_cmd
import setup_bsp

SCRIPT_PATH = os.path.dirname(os.path.abspath(__file__))
PROJECT_PATH = os.path.dirname(os.path.abspath(SCRIPT_PATH))
DEFAULT_BSP = setup_bsp.DEFAULT_BSP
DEFAULT_BSP_DIR = setup_bsp.DEFAULT_BSP_DIR
DEFAULT_PLATFORM = setup_bsp.DEFAULT_PLATFORM

DEFAULT_BSP_DIR_NAME = 'opencl_bsp'

# use a stable OPAE release
OPAE_GIT_BRANCH = 'dcp_1_0_beta_rc1'


def setup_sw_packages(opae_branch=None, sim_mode=None):
    cmd = ""
    if(opae_branch):
        cmd += "OPAE_GIT_BRANCH=%s " % opae_branch
    if(sim_mode is not None):
        if(sim_mode):
            cmd += "OPENCL_ASE_SIM=1 "
        else:
            cmd += "OPENCL_ASE_SIM=0 "
    cmd += "%s/setup_packages.sh" % SCRIPT_PATH
    exitcode = subprocess.call(cmd, shell=True)
    if(exitcode != 0):
        print "ERROR: package setup failed."
        exit(1)


def find_all_files_with_text(src, search):
    result = []
    for filename in glob.glob(src):
        if os.path.isdir(filename):
            dir_path = os.path.join(filename, '*')
            result.extend(find_all_files_with_text(dir_path, search))
            # '.' files(hidden files) are not included in '*'
            dir_path = os.path.join(filename, '.*')
            result.extend(find_all_files_with_text(dir_path, search))
        else:
            with open(filename) as f:
                for line in f:
                    if(search in line):
                        result.append(filename)
                        break
    return result


# get bsp list by using search path and optionally only including certain ones
def get_filtered_bsp_list(bsp_search_dirs, include_bsp):
    bsp_info_map = setup_bsp.get_bsp_info_map(bsp_search_dirs)
    if(include_bsp):
        filter_bsp_list = {}
        for i in bsp_info_map.keys():
            if(i in include_bsp):
                filter_bsp_list[i] = bsp_info_map[i]
        bsp_info_map = filter_bsp_list
    return bsp_info_map


# setup rename bsp map and validate it
def create_rename_bsp_map(bsp_info_map, rename_bsp_arg):
    rename_bsp_map = {}
    rename_bsp_map_reverse = {}
    for i in rename_bsp_arg:
        tmp = i.split(":")
        if(len(tmp) != 2):
            print "Error: rename_bsp argument is invalid: '%s'" % i
            exit(1)
        src, dst = tmp
        if src in rename_bsp_map:
            print "Error: rename_bsp argument already used: '%s'" % i
            exit(1)
        if dst in rename_bsp_map_reverse:
            print "Error: rename_bsp argument already used: '%s'" % i
            exit(1)
        if(src not in bsp_info_map):
            print "Error: rename_bsp argument not in bsp list: '%s'" % i
            exit(1)
        if(dst in bsp_info_map):
            print "Error: rename_bsp argument already in bsp list: '%s'" % i
            exit(1)

        rename_bsp_map[src] = dst
        rename_bsp_map_reverse[dst] = src
    return rename_bsp_map


# setup bsp dir
def setup_bsp_release_dir(release_build_dir, bsp_dir_name):
    release_bsp_dir = os.path.join(release_build_dir, bsp_dir_name)
    delete_and_mkdir(release_bsp_dir)

    copy_glob(os.path.join(PROJECT_PATH, 'board_env.xml'), release_bsp_dir)
    # leave readme.txt out of package for now.  Maybe add it in the future?
    # copy_glob(os.path.join(PROJECT_PATH, 'readme.txt'), release_bsp_dir)
    copy_glob(os.path.join(PROJECT_PATH, 'linux64'), release_bsp_dir)
    delete_and_mkdir(get_bsp_hw_dir(release_bsp_dir))

    return release_bsp_dir


# get path to hardware directory in bsp directory
def get_bsp_hw_dir(release_bsp_dir):
    return os.path.join(release_bsp_dir, 'hardware')


# set default BSP in board_env.xml file
def set_default_bsp(default_bsp_arg, rename_bsp_map, release_bsp_dir):
    default_bsp_to_set = default_bsp_arg
    if(default_bsp_arg in rename_bsp_map.keys()):
        default_bsp_to_set = rename_bsp_map[default_bsp_arg]
    if(DEFAULT_BSP != default_bsp_to_set):
        board_env_path = os.path.join(release_bsp_dir, 'board_env.xml')
        setup_bsp.replace_lines_in_file(board_env_path,
                                        DEFAULT_BSP, default_bsp_to_set)


# copy and setup bsp hw directories and handle renaming if needed
def copy_and_setup_bsp_hw_dirs(release_bsp_dir, bsp_info_map, rename_bsp_map):
    for i in bsp_info_map.keys():
        copy_glob(bsp_info_map[i]['dir'], get_bsp_hw_dir(release_bsp_dir))
        bsp_dir = os.path.join(get_bsp_hw_dir(release_bsp_dir),
                               bsp_info_map[i]['name'])
        setup_bsp.rm_glob(os.path.join(bsp_dir, '*.sh'))
        copy_glob(os.path.join(bsp_info_map[i]['dir'], 'run.sh'), bsp_dir)
        if(i in rename_bsp_map.keys()):
            old_name = i
            new_name = rename_bsp_map[i]
            renamed_bsp_dir = os.path.join(get_bsp_hw_dir(release_bsp_dir),
                                           new_name)
            shutil.move(bsp_dir, renamed_bsp_dir)
            setup_bsp.replace_lines_in_file(os.path.join(renamed_bsp_dir,
                                                         'board_spec.xml'),
                                            old_name, new_name)
            setup_bsp.replace_lines_in_file(os.path.join(renamed_bsp_dir,
                                                         'build',
                                                         'opencl_afu.json'),
                                            old_name, new_name)
            s = find_all_files_with_text(os.path.join(renamed_bsp_dir, "*"),
                                         old_name)
            if(s):
                print("ERROR: bsp rename failed for files: %s\n" % s)
                exit(1)


# main work function for setting up bsp
def build_release_pkg(platform, bsp_search_dirs, include_bsp, rename_bsp_arg,
                      default_bsp_arg=DEFAULT_BSP,
                      bsp_dir_name=DEFAULT_BSP_DIR_NAME,
                      verbose=False, debug=False, overlay=None):
    setup_sw_packages(opae_branch=OPAE_GIT_BRANCH, sim_mode=False)

    bsp_info_map = get_filtered_bsp_list(bsp_search_dirs, include_bsp)
    if(debug):
        print "bsp_info_map: ", bsp_info_map

    rename_bsp_map = create_rename_bsp_map(bsp_info_map, rename_bsp_arg)

    print "Building Release package for BSPs: %s" % include_bsp

    # clean up existing build setup new release build directory
    release_build_dir = os.path.join(PROJECT_PATH, 'release_build')
    delete_and_mkdir(release_build_dir)
    release_bsp_dir = setup_bsp_release_dir(release_build_dir, bsp_dir_name)

    set_default_bsp(default_bsp_arg, rename_bsp_map, release_bsp_dir)

    copy_and_setup_bsp_hw_dirs(release_bsp_dir, bsp_info_map, rename_bsp_map)

    setup_bsp.setup_bsp(platform=platform,
                        bsp_search_dirs=[get_bsp_hw_dir(release_bsp_dir)],
                        sim_mode=False, verbose=verbose, debug=debug,
                        overlay=overlay)

    create_log_file(release_build_dir)

    release_tar_path = create_tar_package(bsp_dir_name,
                                          release_build_dir,
                                          release_bsp_dir)

    run_basic_sanity_test(release_build_dir, release_tar_path, bsp_dir_name)


# tar up release package
def create_tar_package(bsp_dir_name, release_build_dir, release_bsp_dir):
    top_git_commit = run_cmd(cmd='git rev-parse --short HEAD',
                             path=PROJECT_PATH)
    now = datetime.datetime.now()
    release_tar_filename = "%s_%s_%s.tar.gz" % (bsp_dir_name, top_git_commit,
                                                now.strftime("%m%d%y_%H%M%S"))

    release_tar_path = os.path.join(release_build_dir, release_tar_filename)
    setup_bsp.rm_glob(release_tar_path)
    with tarfile.open(release_tar_path, "w:gz") as tar:
        tar.add(release_bsp_dir, bsp_dir_name)

    return release_tar_path


# create log for release
def create_log_file(release_build_dir):
    repo_version_file = os.path.join(release_build_dir, 'repo_version.txt')
    with open(repo_version_file, 'w') as f:
        f.write("repo information\n")
        f.write("git repository path: %s\n" % PROJECT_PATH)
        f.write("last commit log:\n")
        log_info = run_cmd(cmd="git log -n 1", path=PROJECT_PATH)
        f.write(log_info)
        f.write("\n")


# basic sanity checks/testings
def run_basic_sanity_test(release_build_dir, release_tar_path, bsp_dir_name):
    package_test_path = os.path.join(release_build_dir, 'test_pkg')
    delete_and_mkdir(package_test_path)
    with tarfile.open(release_tar_path) as tar:
        tar.extractall(package_test_path)

    bsp_test_path = os.path.join(package_test_path, bsp_dir_name)
    run_bsp_cmd(bsp_test_path, 'aocl board-xml-test')
    run_bsp_cmd(bsp_test_path, 'aoc --list-boards')


# run bsp command by setting environment variable to bsp path before cmd
def run_bsp_cmd(bsp_dir, cmd):
    bsp_cmd = "AOCL_BOARD_PACKAGE_ROOT=%s " % bsp_dir
    exitcode = subprocess.call(bsp_cmd + cmd, shell=True)
    if(exitcode != 0):
        print "ERROR: '%s' failed." % cmd
        exit(1)


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
    parser.add_argument('--bsp-search-dirs', '-b', nargs='*',
                        required=False,
                        default=[DEFAULT_BSP_DIR],
                        help='set bsp search directories')
    parser.add_argument('--include-bsp', '-i', nargs='*',
                        required=False,
                        default=[DEFAULT_BSP],
                        help='list of bsps to include in package')
    parser.add_argument('--default-bsp', required=False,
                        default=DEFAULT_BSP,
                        help='set default bsp for package')
    parser.add_argument('--bsp-dir-name', '-n', required=False,
                        default=DEFAULT_BSP_DIR_NAME,
                        help='set bsp dir name and package name')
    parser.add_argument('--rename-bsp', '-r', nargs='*',
                        required=False,
                        default=[],
                        help='list of bsp to rename, '
                        'example old_name:new_name')
    parser.add_argument('--overlay', '-o', required=False,
                        default=None, help='include bsp overlay modification')

    args = parser.parse_args()

    if(args.debug):
        print "ARGS: ", args

    build_release_pkg(platform=args.platform,
                      bsp_search_dirs=args.bsp_search_dirs,
                      include_bsp=args.include_bsp,
                      default_bsp_arg=args.default_bsp,
                      bsp_dir_name=args.bsp_dir_name,
                      rename_bsp_arg=args.rename_bsp,
                      verbose=args.verbose, debug=args.debug,
                      overlay=args.overlay)


if __name__ == '__main__':
    main()
