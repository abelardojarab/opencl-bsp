# ***************************************************************************
# Copyright (c) 2013-2017, Intel Corporation All Rights Reserved.
# The source code contained or described herein and all  documents related to
# the  source  code  ("Material")  are  owned by  Intel  Corporation  or  its
# suppliers  or  licensors.    Title  to  the  Material  remains  with  Intel
# Corporation or  its suppliers  and licensors.  The Material  contains trade
# secrets and  proprietary  and  confidential  information  of  Intel or  its
# suppliers and licensors.  The Material is protected  by worldwide copyright
# and trade secret laws and treaty provisions. No part of the Material may be
# copied,    reproduced,    modified,    published,     uploaded,     posted,
# transmitted,  distributed,  or  disclosed  in any way without Intel's prior
# express written permission.
# ***************************************************************************

set p4_revision(main) [regsub -nocase -- {\$revision:\s*(\S+)\s*\$} {$Revision: #2 $} {\1}]


#    Arria 10 Partial Reconfiguration Flow Script
#
#    This template, once configured for your design, can be used to invoke the
#    partial reconfiguration flow for an Arria 10 design. To use this template
#    customize the settings in the "define_pr_project" procedure to specify the 
#    revision names for each PR implementation along with the blocks they implement.
#    Alternatively, a setup script can be used to define the PR project using
#    the -setup_script option.
#
#    Blocks are the names of partitions that are created using the PARTITION
#    assignment in the QSF file.
#
#    You can tun this script using qpro_sh -t a10_partial_reconfig.tcl
#
#    You can run this script in 1 of 5 modes:
#       1) Compile all implementations and the base revision.
#          This is the default mode, or can be explicitly set using the -all
#          argument.
#       2) Compile a specific implementation identified by its implementation 
#          revision name. A specific implementation can be identified using the 
#          -impl $name argument. The $name argument passed to -impl 
#          matches the implementation revision name used when defining 
#          the configuration with the define_pr_revision procedure.
#       3) Compile all implementations but do not compile the base revision.
#          This is enabled using the -all_impl argument.
#       4) Compile only the base revision and do not compile any of the PR
#          implementation revisions. This is enabled using the -base argument.
#       5) Check the configuration of the script and then exit.
#          This is enabled using the -check argument.
#
#   An additional option of -setup_script can be used to specify the
#   configuration as opposed to running the define_pr_project proc. Note that
#   the script should still call the define_project, define_base_revision, and
#   define_pr_revision procedures


###############################################################################
# CONFIGURE YOUR COMPILATION HERE:
###############################################################################
proc define_pr_project {} {

	# Define the name of the project. This corresponds to the name of the QPF
	# file. Note that all revisions must be present in the QPF file.
	define_project dcp
	
	# Define the base revision name. This revision represents the static
	# region of the design
	define_base_revision dcp
	
	# Define each of the partial reconfiguration implementation revisions by
	# providing the PR implementation revision name, and then the list of each
	# synthesis revision name and block name. This provides the mapping from the
	# synthesis revision for use in implementing the block for the given
	# implementation compilation. For designs with multiple PR regions, you must 
	# provide multiple synthesis revisions and block names. The block name is
	# the name assigned to the partition using the PARTITION assignment in the
	# QSF file.
	#
	# The define_pr_revision accepts a single -impl_rev_name argument
	# which defines the implementation revision name, then accepts multiple
	# -impl_block arguments which supplies a 2 element list of block name
	# and synthesis revision name for the block. During the compilation, the
	# PR implementation revision imports all necessary synthesis revisions
	# to implement the blocks required.
	#
	# The example defines a PR implementation revision named top_v2 where the
	# block named auto_partition is to be implemented using the synthesized
	# snapshot from the synth_auto_pr_v2 revision, and the time_partition
	# is to be implemented using the synthesized snapshot from the
	# synth_time_pr_v2 revision. To compile only the first implementation in this 
    # example you can run this script using command:
    # qpro_sh -t a10_partial_reconfig.tcl -impl top_v2 

#	define_pr_revision -impl_rev_name top_v3 \
#		-impl_block [list auto_partition synth_auto_pr_v3] \
#		-impl_block [list time_partition synth_time_pr_v3]
}


###############################################################################
# IMPLEMENTATION DETAILS
###############################################################################
global PROJECT_NAME
global BASE_REVISION_NAME
global SYNTHESIS_REVISIONS
global IMPL_REV_BLOCK_IMPORT_MAP
global BASE_REVISION_BLOCK_NAMES
global BASE_REVISION_OUTPUT_DIR
global options


proc define_project {project_name} {
	global PROJECT_NAME
	if {[string compare $PROJECT_NAME ""] != 0}  {
		post_message -type error "The project name has already been defined. Please ensure define_project is only called once"
		qexit -error
	}
	
	set PROJECT_NAME $project_name
}

proc define_base_revision {rev_name} {
	global BASE_REVISION_NAME
	if {[string compare $BASE_REVISION_NAME ""] != 0}  {
		post_message -type error "The base revision name has already been defined. Please ensure define_base_revision is only called once"
		qexit -error
	}
	
	set BASE_REVISION_NAME $rev_name
}

proc define_pr_revision {args} {
	global SYNTHESIS_REVISIONS
	global IMPL_REV_BLOCK_IMPORT_MAP

	set impl_rev_name ""
	
	if {[expr {[llength $args] % 2}] != 0} {
		post_message -type error "The arguments passed to define_pr_revision are invalid: $args"
		qexit -error
	}
	# Check legality and get rev name
	for {set i 0} {$i < [llength $args]} {incr i 2} {
		set arg_name [lindex $args $i]
		set arg_val [lindex $args $i+1]

		if {$arg_name == "-impl_rev_name"} {
			if {$impl_rev_name != ""} {
				post_message -type error "The argument impl_rev_name was passed multiple times to define_pr_revision. It can only be passed once."
				qexit -error
			}
			set impl_rev_name $arg_val
		} elseif {$arg_name == "-impl_block"} {
		} else {
			post_message -type error "The argument $arg_name passed to define_pr_revision is not a recognized argument"
			qexit -error
		}
	}
	if {$impl_rev_name == ""} {
		post_message -type error "The required argument impl_rev_name was not supplied to define_pr_revision."
		qexit -error
	}
	
	
	# Process blocks	
	for {set i 0} {$i < [llength $args]} {incr i 2} {
		set arg_name [lindex $args $i]
		set arg_val [lindex $args $i+1]

		if {$arg_name == "-impl_block"} {
			if {[llength $arg_val] != 2} {
				post_message -type error "The value $arg_val for argument impl_block argument is illegal."
				qexit -error
			}
			set block_name [lindex $arg_val 0]
			set synth_name [lindex $arg_val 1]
			
			if {[info exists IMPL_REV_BLOCK_IMPORT_MAP]} {
				if {[dict exists $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name]} {
					if {[dict exists [dict get $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name] $block_name]} {
						post_message -type error "The block name $block_name was defined multiple times in the same implementation revision $impl_rev_name"
						qexit -error
					}
				}
			}

			dict set IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name $block_name $synth_name
			set SYNTHESIS_REVISIONS($synth_name) 1
		}
	}
	
	post_message -type info "Defined [dict size [dict get $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name]] block(s) for revision $impl_rev_name"
	if {[dict size [dict get $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name]] == 0} {
		post_message -type error "The required argument impl_block was not supplied to define_pr_revision."
		qexit -error
	}
}

proc print_pr_project_info {} {
	global PROJECT_NAME
	global BASE_REVISION_NAME
	global SYNTHESIS_REVISIONS
	global IMPL_REV_BLOCK_IMPORT_MAP
	global BASE_REVISION_BLOCK_NAMES

	puts "Arria 10 Partial Reconfiguation Flow"
	puts "-------------------------------------------------------------------------------"
	puts "   Project name       : $PROJECT_NAME"
	puts "   Base revision name : $BASE_REVISION_NAME"
	puts "   Block names : $BASE_REVISION_BLOCK_NAMES"
	dict for {impl_rev_name block_map} $IMPL_REV_BLOCK_IMPORT_MAP {
		puts "   Implementation Revision : $impl_rev_name"
		set blocks_for_impl [list]
		dict for {block_name synth_rev} $block_map {
			puts "      Block Name : $block_name (synth rev $synth_rev)"
			lappend blocks_for_impl $block_name
			
			if {[lsearch -exact $BASE_REVISION_BLOCK_NAMES $block_name] == -1} {
				post_message -type error "Block name $block_name does not exist in the base revision $BASE_REVISION_NAME"
				post_message -type error "Existing block names are: $BASE_REVISION_BLOCK_NAMES"
				qexit -error
			}
		}
		
		# Make sure all base blocks are defined
		foreach base_block $BASE_REVISION_BLOCK_NAMES {
			if {[lsearch -exact $blocks_for_impl $base_block] == -1} {
				post_message -type error "Required block name $base_block does not exist in the PR implementation revision $impl_rev_name"
				post_message -type error "Required block names are: $BASE_REVISION_BLOCK_NAMES"
				qexit -error
			}
		}
	}
	

}

proc initialize {} {
	global PROJECT_NAME
	global BASE_REVISION_NAME
	global SYNTHESIS_REVISIONS
	global IMPL_REV_BLOCK_IMPORT_MAP
	global BASE_REVISION_OUTPUT_DIR
	global BASE_REVISION_BLOCK_NAMES
	

	if {[project_exists $PROJECT_NAME] == 0} {
		post_message -type error "No project named $PROJECT_NAME exists in [pwd]"
		qexit -type error
	}
	
	# Open the base revision to check assignments
	if { [catch {project_open $PROJECT_NAME -rev $BASE_REVISION_NAME} msg] } {
		puts $msg
		post_message -type error "Could not open project $PROJECT_NAME and revision $BASE_REVISION_NAME. Please check the revision exists on disk and exists in the project QPF."
		qexit -error
	}

	# Default to the current directory
	set BASE_REVISION_OUTPUT_DIR [pwd]

	# Get the project_output_dir assignment from the base revision
	foreach_in_collection asgn [get_all_global_assignments -name PROJECT_OUTPUT_DIRECTORY] {
		## Each element in the collection has the following
		## format: { {} {<Assignment name>} {<Assignment value>} {<Entity name>} {<Tag data>} }                                                                     
		set name   [lindex $asgn 1]                                                 
		set value  [lindex $asgn 2]                                                 
		set entity [lindex $asgn 3]                                                 
		set tag    [lindex $asgn 4]   	
		
		set BASE_REVISION_OUTPUT_DIR $value
	}	

	# Get all the PR partition assignments from the base revision
	set pr_partition_targets [list]
	foreach_in_collection asgn [get_all_instance_assignments -name PARTIAL_RECONFIGURATION_PARTITION ] {
		## Each element in the collection has the following
		## format: { {} {<Source>} {<Destination>} {<Assignment name>} {<Assignment value>} {<Entity name>} {<Tag data>} }                                          
		set from   [lindex $asgn 1]                                                 
		set to     [lindex $asgn 2]                                                 
		set name   [lindex $asgn 3]                                                 
		set value  [lindex $asgn 4]                                                 
		set entity [lindex $asgn 5]                                                 
		set tag    [lindex $asgn 6]                                                 
	
		
		if {($to != "root_partition") && ([string compare -nocase "on" $value] == 0)} {
			lappend pr_partition_targets $to
		}
	}	

	# Get all the partition assignments from the base revision
	set BASE_REVISION_BLOCK_NAMES [list]
	foreach_in_collection asgn [get_all_instance_assignments -name PARTITION] {
		## Each element in the collection has the following
		## format: { {} {<Source>} {<Destination>} {<Assignment name>} {<Assignment value>} {<Entity name>} {<Tag data>} }                                          
		set from   [lindex $asgn 1]                                                 
		set to     [lindex $asgn 2]                                                 
		set name   [lindex $asgn 3]                                                 
		set value  [lindex $asgn 4]                                                 
		set entity [lindex $asgn 5]                                                 
		set tag    [lindex $asgn 6]                                                 
	
		
		# Filter out root_partition partitions, and partitions that are not
		# PR partitions
		if {$value != "root_partition"} {
			if {[lsearch -exact $pr_partition_targets $to] != -1} {
				lappend BASE_REVISION_BLOCK_NAMES $value
			}
		}
	}	

	# Close the base revision
	project_close

	
	# Check all synthesis revisions
	foreach rev [array names SYNTHESIS_REVISIONS] {
		# Make sure the revision can be opened
		if { [catch {project_open $PROJECT_NAME -rev $rev} msg] } {
			puts $msg
			post_message -type error "Could not open revision $rev. Please check the revision exists on disk and exists in the project QPF."
			qexit -error
		}
		project_close
	}
	
	# Check all implementation revisions
	foreach rev [dict keys $IMPL_REV_BLOCK_IMPORT_MAP] {
		# Open the revision to check for assignments
		if { [catch {project_open $PROJECT_NAME -rev $rev} msg] } {
			puts $msg
			post_message -type error "Could not open revision $rev. Please check the revision exists on disk and exists in the project QPF."
			qexit -error
		}
		
		
		# Get the project_output_dir assignment from the revision
		set rev_output_dir [pwd]
		foreach_in_collection asgn [get_all_global_assignments -name PROJECT_OUTPUT_DIRECTORY] {
			## Each element in the collection has the following
			## format: { {} {<Assignment name>} {<Assignment value>} {<Entity name>} {<Tag data>} }                                                                     
			set name   [lindex $asgn 1]                                                 
			set value  [lindex $asgn 2]                                                 
			set entity [lindex $asgn 3]                                                 
			set tag    [lindex $asgn 4]   	
			
			set rev_output_dir $value
		}
		if {$rev_output_dir != $BASE_REVISION_OUTPUT_DIR} {
			post_message -type error "Output directory for revision $rev does not match output directory for base revision $BASE_REVISION_NAME. All output directories must be the same."
			qexit -error
		}
		
		
		project_close
		
	}

}

proc synthesize_persona_impl {synth_rev} {
	global PROJECT_NAME
	global BASE_REVISION_NAME

	# Open the project 
	project_open $PROJECT_NAME -rev $synth_rev

	post_message -type info "   Synthesizing $synth_rev"
	execute_module -tool ipg -args "--generate_project_qsys_files -c $synth_rev"
	execute_module -tool syn -args "-c $synth_rev"
	
	# Export the synthesis for use in the impl compile
	design::export_block root_partition -snapshot synthesized -file "$synth_rev.qdb"

	project_close
}

proc compile_pr_revision_impl {impl_rev} {
	global PROJECT_NAME
	global BASE_REVISION_NAME
	global IMPL_REV_BLOCK_IMPORT_MAP
	global BASE_REVISION_BLOCK_NAMES
	global BASE_REVISION_OUTPUT_DIR

	# Open the project 
	project_open $PROJECT_NAME -rev $impl_rev

	# Import the root partition
	design::import_block root_partition -file "$BASE_REVISION_NAME.qdb"

	
	# Import each block required
	dict for {block_name synth_rev} [dict get $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev] {
		design::import_block $block_name -file "$synth_rev.qdb"
	}
	
	post_message -type info "Compiling PR implementation $impl_rev"
	execute_module -tool fit -args "-c $impl_rev"
	execute_module -tool asm -args "-c $impl_rev"
	execute_module -tool sta -args "-c $impl_rev"
	
	# Create all bitstreams
	foreach block_name $BASE_REVISION_BLOCK_NAMES {
		post_message -type info "   Converting bitstream for $block_name"
		execute_module -tool cpf -args "-p ${BASE_REVISION_OUTPUT_DIR}/${impl_rev}.${block_name}.msf ${BASE_REVISION_OUTPUT_DIR}/${impl_rev}.sof ${BASE_REVISION_OUTPUT_DIR}/${impl_rev}.${block_name}.pmsf"
		execute_module -tool cpf -args "-c ${BASE_REVISION_OUTPUT_DIR}/${impl_rev}.${block_name}.pmsf ${BASE_REVISION_OUTPUT_DIR}/${impl_rev}.${block_name}.rbf"
	}
	
	project_close
}

proc compile_base_revision {} {
	global PROJECT_NAME
	global BASE_REVISION_NAME
	global BASE_REVISION_BLOCK_NAMES
	global BASE_REVISION_OUTPUT_DIR

	project_open $PROJECT_NAME -rev $BASE_REVISION_NAME
	
	# Compile the base revision
	post_message -type info "Compiling base revision $BASE_REVISION_NAME from project $PROJECT_NAME"
	execute_module -tool ipg -args "--generate_project_qsys_files -c $BASE_REVISION_NAME"
	execute_module -tool syn -args "-c $BASE_REVISION_NAME"
	execute_module -tool fit -args "-c $BASE_REVISION_NAME"
	execute_module -tool asm -args "-c $BASE_REVISION_NAME"
	execute_module -tool sta -args "-c $BASE_REVISION_NAME"
	
	# export the root partition
	design::export_block "root_partition" -snapshot final -file "$BASE_REVISION_NAME.qdb" -exclude_pr_subblocks

	# Create all bitstreams
	foreach block_name $BASE_REVISION_BLOCK_NAMES {
		post_message -type info "   Converting bitstream for $block_name"
		execute_module -tool cpf -args "-p ${BASE_REVISION_OUTPUT_DIR}/${BASE_REVISION_NAME}.${block_name}.msf ${BASE_REVISION_OUTPUT_DIR}/${BASE_REVISION_NAME}.sof ${BASE_REVISION_OUTPUT_DIR}/${BASE_REVISION_NAME}.${block_name}.pmsf"
		execute_module -tool cpf -args "-c ${BASE_REVISION_OUTPUT_DIR}/${BASE_REVISION_NAME}.${block_name}.pmsf ${BASE_REVISION_OUTPUT_DIR}/${BASE_REVISION_NAME}.${block_name}.rbf"
	}

	project_close
}


proc compile_all_pr_revisions {} {
	global SYNTHESIS_REVISIONS
	global IMPL_REV_BLOCK_IMPORT_MAP

	# Synthesize each revision
	foreach synth_rev [array names SYNTHESIS_REVISIONS] {
		synthesize_persona_impl $synth_rev
	}
	
	# Implement each PR revision
	foreach impl_rev [dict keys $IMPL_REV_BLOCK_IMPORT_MAP] {
		compile_pr_revision_impl $impl_rev
	}
}

proc compile_all_revisions {} {
	# Compile the base revision
	compile_base_revision
	
	# compile all PR implementations
	compile_all_pr_revisions
}

proc compile_pr_revision {requested_impl_name} {
	global PROJECT_NAME
	global BASE_REVISION_NAME
	global IMPL_REV_BLOCK_IMPORT_MAP

	# Find the desired PR implementation and then compile it
	dict for {impl_rev_name block_map} $IMPL_REV_BLOCK_IMPORT_MAP {
		
		if {[string compare $requested_impl_name $impl_rev_name] == 0} {
			# Normalize the list of synth revisions
			array set synth_rev_names [list]
			dict for {block_name synth_rev} $block_map {
				set synth_rev_names($synth_rev) 1
			}

			# Synthesize each revision required
			foreach synth_rev [array names synth_rev_names] {
				synthesize_persona_impl $synth_rev
			}
			
			# Compile the desired revision
			compile_pr_revision_impl $impl_rev_name
		
			return 1
		}
	}
	
	post_message -type error "Could not find an implementation revision named $requested_impl_name"
	qexit -error
}

proc cleanup {} {
	global PROJECT_NAME
	global BASE_REVISION_NAME
	global SYNTHESIS_REVISIONS
	global BASE_REVISION_OUTPUT_DIR

	
	# Open project 
	project_open $PROJECT_NAME -rev $BASE_REVISION_NAME

	post_message -type info "Cleaning up project"
	
	# Clean up the project across all revisions. This also
	# closes the project. Catch any errors from this command to handle
	# old revisions
	catch {project_clean} msg
	puts $msg

	# Cleanup things not done by project_clean
	file delete -force qdb
	if {${BASE_REVISION_OUTPUT_DIR} != [pwd]} {
		file delete -force ${BASE_REVISION_OUTPUT_DIR}
	}
	file delete -force "${BASE_REVISION_NAME}.qdb"
	foreach synth_rev [array names SYNTHESIS_REVISIONS] {
		file delete -force "${synth_rev}.qdb"
	}
	
}

###############################################################################
# MAINLINE
###############################################################################
set available_options {
	{ check "Check the script configuration then exit" }
	{ all "Compile all revisions" }
	{ base "Compile base revision" }
	{ all_impl "Compile all PR implementation revisions" }
	{ impl.arg "\#_ignore_\#" "Compile a specifically named implementation identified by the implementation revision name" }
	{ setup_script.arg "\#_ignore_\#" "Specify a script to use as opposed to running the define_pr_project in the script" }
}

# Load required packages
load_package flow
load_package design
package require cmdline

# Initialize
set PROJECT_NAME ""
set BASE_REVISION_NAME ""


# Print some useful infomation
post_message -type info "[file tail [info script]] version: $::p4_revision(main)"

# Check arguments
# Need to define argv for the cmdline package to work
set argv0 "quartus_sh -t [info script]"
set usage "\[<options>\]"

set argument_list $quartus(args)
msg_vdebug "CMD_ARGS = $argument_list"

# Use cmdline package to parse options
if [catch {array set options [cmdline::getoptions argument_list $::available_options]} result] {
	if {[llength $argument_list] > 0 } {
		# This is not a simple -? or -help but an actual error condition
		post_message -type error "Illegal Options $argument_list"
		post_message -type error  [::cmdline::usage $::available_options $usage]
		qexit -error
	} else {
		post_message -type info  "Usage:"
		post_message -type info  [::cmdline::usage $::available_options $usage]
		qexit -success
	}
}

# Define the PR project
if {$options(setup_script) != "#_ignore_#"} {
	source $options(setup_script)
} else {
	define_pr_project
}

# Perform initial checks and initialize
initialize

# Print the info on the project. This also checks the project
print_pr_project_info

# Perform the required flow
if {$options(check)} {
	# Do nothing

	post_message -type info "Successfully completed flow script check"
} elseif {$options(impl) != "#_ignore_#"} {
	# Compile a single revision
	compile_pr_revision $options(impl)

	post_message -type info "Successfully completed A10 PR compile"
} elseif {$options(base)} {
	cleanup

	# Compile a single revision
	compile_base_revision
	post_message -type info "Successfully completed base revision"
} elseif {$options(all_impl)} {
	# Compile all PR implementation revisions. In this case do not cleanup
	
	compile_all_pr_revisions
	post_message -type info "Successfully completed A10 PR compile"
} else {
	# Do a full compile
	cleanup

	compile_all_revisions
	post_message -type info "Successfully completed A10 PR compile"
}
