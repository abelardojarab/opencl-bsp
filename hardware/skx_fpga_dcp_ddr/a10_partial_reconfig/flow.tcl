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

set p4_revision(main) [regsub -nocase -- {\$revision:\s*(\S+)\s*\$} {$Revision: #2 $} {\1}]


#    Arria 10 Partial Reconfiguration Flow Script
#
#    This template, once configured for your design, can be used to invoke the
#    partial reconfiguration flow for an Arria 10 design. To use this template
#    customize the settings in the setup.tcl file  to specify the 
#    revision names for each PR implementation along with the partitions they implement.
#    The partition name is the name assigned to the partition using the PARTITION
#    assignment in the Quartus Settings File (.qsf).
#
#    You can run this script using qpro_sh -t a10_partial_reconfig/flow.tcl
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

###############################################################################
# IMPLEMENTATION DETAILS
###############################################################################
global PROJECT_NAME
global BASE_REVISION_NAME
global SYNTHESIS_REVISIONS
global IMPL_REV_BLOCK_IMPORT_MAP
set IMPL_REV_BLOCK_IMPORT_MAP [dict create]
global BASE_REVISION_BLOCK_NAMES
global BASE_REVISION_OUTPUT_DIR
global FLOW_OPTIONS
set FLOW_OPTIONS [dict create]
global options

global FLOW_OPTION_ON
set FLOW_OPTION_ON "ON"
global FLOW_OPTION_OFF
set FLOW_OPTION_OFF "OFF"
global FLOW_OPTION_RUN_POW
set FLOW_OPTION_RUN_POW "ENABLE_POWER_ANALYZER"
global FLOW_OPTION_ENABLE_PR_BITSTREAM_COMPRESSION
set FLOW_OPTION_ENABLE_PR_BITSTREAM_COMPRESSION "ENABLE_PR_BITSTREAM_COMPRESSION"
global FLOW_OPTION_ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION
set FLOW_OPTION_ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION "ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION"
global FLOW_OPTION_DISABLE_RBF_GENERATION
set FLOW_OPTION_DISABLE_RBF_GENERATION "DISABLE_RBF_GENERATION"

global CURRENT_SCRIPT
set CURRENT_SCRIPT [info script]



proc define_project {project_name} {
	global PROJECT_NAME
	if {[string compare $PROJECT_NAME ""] != 0}  {
		post_message -type error "The project name has already been defined. Ensure define_project is only called once."
		qexit -error
	}
	
	set PROJECT_NAME $project_name
}

proc define_base_revision {rev_name} {
	global BASE_REVISION_NAME
	if {[string compare $BASE_REVISION_NAME ""] != 0}  {
		post_message -type error "The base revision name has already been defined. Ensure define_base_revision is only called once."
		qexit -error
	}
	
	set BASE_REVISION_NAME $rev_name
}

# Old 16.0 partition definition handeling
proc define_pr_revision {args} {
	global SYNTHESIS_REVISIONS
	global IMPL_REV_BLOCK_IMPORT_MAP

	set impl_rev_name ""
	
	if {[expr {[llength $args] % 2}] != 0} {
		post_message -type error "The arguments passed to define_pr_revision are invalid: $args."
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
			post_message -type error "The argument $arg_name passed to define_pr_revision is not a recognized argument."
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
				post_message -type error "The value $arg_val for argument impl_block is illegal."
				qexit -error
			}
			set block_name [lindex $arg_val 0]
			set synth_name [lindex $arg_val 1]
			
			if {[info exists IMPL_REV_BLOCK_IMPORT_MAP]} {
				if {[dict exists $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name]} {
					if {[dict exists [dict get $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name] $block_name]} {
						post_message -type error "The partition name $block_name was defined multiple times in the same implementation revision $impl_rev_name. It can only be passed once."
						qexit -error
					}
				}
			}

			dict set IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name $block_name $synth_name
			set SYNTHESIS_REVISIONS($synth_name) 1
		}
	}
	
	post_message -type info "Defined [dict size [dict get $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name]] block(s) for revision $impl_rev_name."
	if {[dict size [dict get $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name]] == 0} {
		post_message -type error "The required argument impl_block was not supplied to define_pr_revision."
		qexit -error
	}
}

proc define_pr_impl_partition {args} {
	global PROJECT_NAME
	global SYNTHESIS_REVISIONS
	global IMPL_REV_BLOCK_IMPORT_MAP
	global EXPORT_BLOCK_MAP

	set impl_rev_name ""
	set partition_name ""
	set source_revision ""

	#check legality and get rev name, there can be one and only one -impl_rev_name argument.
	for {set i 0} {$i < [llength $args]} {incr i 2} {
		set arg_name [lindex $args $i]
		set arg_val [lindex $args $i+1]

		if {$arg_name == "-impl_rev_name"} {
			if {$impl_rev_name != ""} {
					post_message -type error "The argument impl_rev_name was passed multiple times to define_pr_impl_partition. It can only be passed once."
					qexit -error
			}
			set impl_rev_name $arg_val
		} elseif {$arg_name == "-partition_name"} {
				# 
		} elseif {$arg_name == "-source_rev_name"} {
				#
		} else {
				post_message -type error "The argument $arg_name passed to define_pr_impl_partition is not a recognized argument."
				qexit -error
		}
	}
	if {$impl_rev_name == ""} {
			post_message -type error "The required argument impl_rev_name was not supplied to define_pr_impl_revision."
	qexit -error
	}

	# Process the import blocks and complete the import map
	# First define the partition name
	for {set i 0} {$i < [llength $args]} {incr i 2} {
		set arg_name [lindex $args $i]
		set arg_val [lindex $args $i+1]

		if {$arg_name == "-partition_name"} {
			if {$partition_name != ""} {
				post_message -type error "The argument partition_name was passed multiple times to define_pr_impl_partition. It can only be passed once."
				qexit -error
			}
			set partition_name $arg_val
		}
	}
	if {$partition_name == ""} {
			post_message -type error "The required argument partition_name was not supplied to define_pr_impl_partition."
			qexit -error
	}

	# Second, define the source to be imported to the partition
	for {set i 0} {$i < [llength $args]} {incr i 2} {
		set arg_name [lindex $args $i]
		set arg_val  [lindex $args $i+1]
		
		if {$arg_name == "-source_rev_name"} {
			if {$source_revision != ""} {
				post_message -type error "The argument -source_rev_name was passed multiple times to define_pr_impl_partition. It can only be passed once."
				qexit -error
			}
			set source_revision $arg_val
		}
	}
	if {$source_revision == ""} {
			post_message -type error "The required argument -source_rev_name was not supplied to define_pr_impl_partition."
			qexit -error
	}

	set SYNTHESIS_REVISIONS($source_revision) 1
	
	# Complete the import map
	if {[info exists IMPL_REV_BLOCK_IMPORT_MAP]} {
		if {[dict exists $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name]} {
			if {[dict exists [dict get $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name] $partition_name]} {
				post_message -type error "The same partition $partition_name in $impl_rev_name was defined multiple times. It can only be passed once."
				qexit -error
			}
		}
	}
	dict set IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name $partition_name $source_revision
	set SYNTHESIS_REVISIONS($source_revision) 1
		
	post_message -type info "Defined [dict size [dict get $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name]] partition(s) for revision $impl_rev_name."
	if {[dict size [dict get $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev_name]] == 0} {
		post_message -type error "The required argument impl_block was not supplied to define_pr_impl_partition."
		qexit -error
	}
		
}

proc check_flow_option_on_off {opt_name opt_value opt_name} {
	global FLOW_OPTION_ON
	global FLOW_OPTION_OFF

	if {[string toupper $opt_value] == $FLOW_OPTION_ON} {
		return 1
	} elseif {[string toupper $opt_value] == $FLOW_OPTION_OFF} {
	} else {
		post_message -type error "The flow value of $opt_value for $opt_name is illegal."
		post_message -type error "   Legal values are $FLOW_OPTION_ON/$FLOW_OPTION_OFF"
		qexit -error
	}
	
	return 0
}

proc check_option_on {opt_name} {
	global FLOW_OPTIONS
	global FLOW_OPTION_ON

	if {[dict exists $FLOW_OPTIONS $opt_name] && [dict get $FLOW_OPTIONS $opt_name] == $FLOW_OPTION_ON} {
		return 1
	} else {
		return 0
	}
}

proc set_flow_option {args} {
	global FLOW_OPTIONS
	global FLOW_OPTION_ON
	global FLOW_OPTION_OFF
	global FLOW_OPTION_RUN_POW
	global FLOW_OPTION_ENABLE_PR_BITSTREAM_COMPRESSION
	global FLOW_OPTION_ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION
	global FLOW_OPTION_DISABLE_RBF_GENERATION

	set opt_name ""
	set opt_value ""

	if {[llength $args] != 3} {
		post_message -type error "The arguments passed to set_flow_option are invalid: $args."
		qexit -error
	}
	# Check legality and get option_name and value
	for {set i 0} {$i < [llength $args]} {incr i} {
		set arg_name [lindex $args $i]
		set arg_val [lindex $args $i+1]

		if {$arg_name == "-name"} {
			if {$opt_name != ""} {
				post_message -type error "The argument name was passed multiple times to set_flow_option. It can only be passed once."
				qexit -error
			}
			set opt_name $arg_val
			# Increment i as we are consuming 2 args
			incr i
		} else {
			# Use arg as positional
			set opt_value $arg_name
		}
	}
	if {$opt_name == ""} {
		post_message -type error "The required argument -name was not supplied to set_flow_option."
		qexit -error
	}

	if {[string toupper $opt_name] == $FLOW_OPTION_RUN_POW} {
		if {[check_flow_option_on_off $opt_name $opt_value $FLOW_OPTION_RUN_POW]} {
			dict set FLOW_OPTIONS $FLOW_OPTION_RUN_POW $FLOW_OPTION_ON
		}

	} elseif {[string toupper $opt_name] == $FLOW_OPTION_ENABLE_PR_BITSTREAM_COMPRESSION} {
		if {[check_flow_option_on_off $opt_name $opt_value $FLOW_OPTION_ENABLE_PR_BITSTREAM_COMPRESSION]} {
			if {[check_option_on $FLOW_OPTION_ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION]} {
				post_message -type error "Both flow options $FLOW_OPTION_ENABLE_PR_BITSTREAM_COMPRESSION and $FLOW_OPTION_ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION cannot be enabled at the same time."
				qexit -error
			}
			dict set FLOW_OPTIONS $FLOW_OPTION_ENABLE_PR_BITSTREAM_COMPRESSION $FLOW_OPTION_ON
		}

	} elseif {[string toupper $opt_name] == $FLOW_OPTION_ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION} {
		if {[check_flow_option_on_off $opt_name $opt_value $FLOW_OPTION_ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION]} {
			if {[check_option_on $FLOW_OPTION_ENABLE_PR_BITSTREAM_COMPRESSION]} {
				post_message -type error "Both flow options $FLOW_OPTION_ENABLE_PR_BITSTREAM_COMPRESSION and $FLOW_OPTION_ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION cannot be enabled at the same time."
				qexit -error
			}
			dict set FLOW_OPTIONS $FLOW_OPTION_ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION $FLOW_OPTION_ON
		}
	
	} elseif {[string toupper $opt_name] == $FLOW_OPTION_DISABLE_RBF_GENERATION} {
		if {[check_flow_option_on_off $opt_name $opt_value $FLOW_OPTION_DISABLE_RBF_GENERATION]} {
			dict set FLOW_OPTIONS $FLOW_OPTION_DISABLE_RBF_GENERATION $FLOW_OPTION_ON
		}

	} else {
		post_message -type error "Flow option $opt_name is illegal."
	}
}

proc print_pr_project_info {} {
	global PROJECT_NAME
	global BASE_REVISION_NAME
	global SYNTHESIS_REVISIONS
	global IMPL_REV_BLOCK_IMPORT_MAP
	global BASE_REVISION_BLOCK_NAMES
	global FLOW_OPTIONS
	global BASE_REVISION_OUTPUT_DIR

	puts "Arria 10 Partial Reconfiguration Flow"
	puts "-------------------------------------------------------------------------------"
	puts "   Project name                   : $PROJECT_NAME"
	puts "   Output directory               : $BASE_REVISION_OUTPUT_DIR"
	puts "   Base revision name             : $BASE_REVISION_NAME"
	puts "   Reconfigurable partition names : $BASE_REVISION_BLOCK_NAMES"
	dict for {impl_rev_name block_map} $IMPL_REV_BLOCK_IMPORT_MAP {
		puts "   Implementation Revision : $impl_rev_name"
		set blocks_for_impl [list]
		dict for {block_name synth_rev} $block_map {
			puts "      Reconfigurable Partition Name : $block_name (synth rev $synth_rev)"
			lappend blocks_for_impl $block_name
			
			if {[lsearch -exact $BASE_REVISION_BLOCK_NAMES $block_name] == -1} {
				post_message -type error "Reconfigurable partition named $block_name does not exist in the base revision $BASE_REVISION_NAME."
				post_message -type error "Existing partition names are: $BASE_REVISION_BLOCK_NAMES"
				qexit -error
			}
		}
		
		# Make sure all base blocks are defined
		foreach base_block $BASE_REVISION_BLOCK_NAMES {
			if {[lsearch -exact $blocks_for_impl $base_block] == -1} {
				post_message -type error "Required partition name $base_block does not exist in the PR implementation revision $impl_rev_name."
				post_message -type error "Required partition names are: $BASE_REVISION_BLOCK_NAMES"
				qexit -error
			}
		}
	}
	
	puts "   Flow options :"
	dict for {flow_opt flow_val} $FLOW_OPTIONS {
		puts "   Flow option - $flow_opt : $flow_val"
	}
	

}

proc initialize {skip_base_check} {
	global PROJECT_NAME
	global BASE_REVISION_NAME
	global SYNTHESIS_REVISIONS
	global IMPL_REV_BLOCK_IMPORT_MAP
	global BASE_REVISION_OUTPUT_DIR
	global BASE_REVISION_BLOCK_NAMES
	
	# Check that the setup was specified
	if {$PROJECT_NAME == ""} {
		post_message -type error "No project specified in the flow setup file."
		qexit -error
	}

	if {$BASE_REVISION_NAME == ""} {
		post_message -type error "No base revision name specified in the flow setup file."
		qexit -error
	}
	
	if {[dict size $IMPL_REV_BLOCK_IMPORT_MAP] == 0} {
		post_message -type error "No implementation revision names specified in the flow setup file."
		qexit -error
	}
	
	# Check that project exists
	if {[project_exists $PROJECT_NAME] == 0} {
		post_message -type error "No project named $PROJECT_NAME exists."
		post_message -type error "   Search path: [pwd]"
		qexit -error
	}
	
	# Check all revisions exist. Do this by checking for the existence of the QSF
	if {($skip_base_check == 0) && ([file exists "${BASE_REVISION_NAME}.qsf"] == 0)} {
		post_message -type error "No revision named ${BASE_REVISION_NAME}.qsf found."
		post_message -type error "   Search path: [pwd]"
		qexit -error
	}
	foreach rev [array names SYNTHESIS_REVISIONS] {
        	if {[file exists "${rev}.qsf"] == 0} {
        		post_message -type error "No revision named ${rev}.qsf found."
				post_message -type error "   Search path: [pwd]"
        		qexit -error
        	}
	}
	foreach rev [dict keys $IMPL_REV_BLOCK_IMPORT_MAP] {
		if {[file exists "${rev}.qsf"] == 0} {
			post_message -type error "No revision named ${rev}.qsf found."
			post_message -type error "   Search path: [pwd]"
			qexit -error
		}
	}
	
	# Open the base revision to check assignments
	if {($skip_base_check == 0)} {
		if { [catch {project_open $PROJECT_NAME -rev $BASE_REVISION_NAME} msg] } {
			puts $msg
			post_message -type error "Could not open project $PROJECT_NAME and revision $BASE_REVISION_NAME. Check the revision exists and is specified in the Quartus Project File (.qpf)."
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
	
		# Check if auto-generation of PMSF in ASM is enabled
		set value [get_global_assignment -name GENERATE_PMSF_FILES]
		if {[string toupper $value] == "OFF"} {
			post_message -type error "Global assignment GENERATE_PMSF_FILES is set to OFF, which is not supported by this flow script. Set this assignment to ON in the base revision Quartus Settings File (.qsf). "
			qexit -error
		}
	
		# Check that the family is arria 10
		set value [get_global_assignment -name FAMILY]
		if {[lsearch -exact [list "ARRIA 10" "CYCLONE 10 GX"] [string toupper [get_dstr_string -family $value]]] == -1} {
			post_message -type error "The current family $value ([get_dstr_string -family $value]) is not supported by the a10_partial_reconfig flow script. This script only supports families: Arria 10."
			qexit -error
		}
	
		# Close the base revision
		project_close
	} else {
		# Set defaults
		set BASE_REVISION_OUTPUT_DIR [pwd]
		set BASE_REVISION_BLOCK_NAMES [list]
		
		# Set all blocks from IMPLs as the list of blocks
		set rev ""
		dict for {impl_rev_name block_map} $IMPL_REV_BLOCK_IMPORT_MAP {
			if {$rev == ""} {set rev $impl_rev_name}
			dict for {block_name synth_rev} $block_map {
				if {[lsearch -exact $BASE_REVISION_BLOCK_NAMES $block_name] == -1} {
					lappend BASE_REVISION_BLOCK_NAMES $block_name
				}
			}
		}
		
		# Get the output files dir for the first revision
		if { [catch {project_open $PROJECT_NAME -rev $rev} msg] } {
			puts $msg
			post_message -type error "Could not open revision $rev. Check the revision exists and is specified in the Quartus Project File (.qpf)."
			qexit -error
		}
		
		# Get the project_output_dir assignment from the revision
		set BASE_REVISION_OUTPUT_DIR [pwd]
		foreach_in_collection asgn [get_all_global_assignments -name PROJECT_OUTPUT_DIRECTORY] {
			## Each element in the collection has the following
			## format: { {} {<Assignment name>} {<Assignment value>} {<Entity name>} {<Tag data>} }                                                                     
			set name   [lindex $asgn 1]                                                 
			set value  [lindex $asgn 2]                                                 
			set entity [lindex $asgn 3]                                                 
			set tag    [lindex $asgn 4]   	
			
			set BASE_REVISION_OUTPUT_DIR $value
		}
	
		project_close
	
	}
	
	# Check all synthesis revisions
	foreach rev [array names SYNTHESIS_REVISIONS] {
		# Make sure the revision can be opened
		if { [catch {project_open $PROJECT_NAME -rev $rev} msg] } {
			puts $msg
			post_message -type error "Could not open revision $rev. Check the Quartus Settings File (.qsf) exists and is specified in the Quartus Project File (.qpf)."
			qexit -error
		}
		project_close
	}
	
	# Check all implementation revisions
	foreach rev [dict keys $IMPL_REV_BLOCK_IMPORT_MAP] {
		# Open the revision to check for assignments
		if { [catch {project_open $PROJECT_NAME -rev $rev} msg] } {
			puts $msg
			post_message -type error "Could not open revision $rev. Check the revision exists and is specified in the Quartus Project File (.qpf)."
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
		if {($skip_base_check == 0)} {
			if {$rev_output_dir != $BASE_REVISION_OUTPUT_DIR} {
				post_message -type error "Output directory for revision $rev does not match output directory for base revision $BASE_REVISION_NAME. All output directories must be the same."
				qexit -error
			}
		}

		# Check if auto-generation of PMSF in ASM is enabled
		set value [get_global_assignment -name GENERATE_PMSF_FILES]
		if {[string toupper $value] == "OFF"} {
			post_message -type error "Global assignment GENERATE_PMSF_FILES is set to OFF, which is not supported by this flow script. Set this setting to ON in the $rev revision Quartus Settings File (.qsf). "
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
	execute_module -tool ipg -args "--generate_project_qsys_files"
	if {[file exists "post_ipgenerate_persona_synth_flow.tcl"]} {
		post_message -type info "Preparing to source post_ipgenerate_persona_synth_flow.tcl."
		source "post_ipgenerate_persona_synth_flow.tcl"
	}
	execute_module -tool syn
	
	# Export the synthesis for use in the impl compile
	design::export_block root_partition -snapshot synthesized -file "$synth_rev.qdb"

	project_close
}

proc import_blocks_for_pr_revision {impl_rev} {
	global PROJECT_NAME
	global BASE_REVISION_NAME
	global IMPL_REV_BLOCK_IMPORT_MAP

	# Open the project 
	project_open $PROJECT_NAME -rev $impl_rev

	# Make sure the QDB exists
	if {[file exists "$BASE_REVISION_NAME.qdb"] == 0} {
		post_message -type error "Could not find required file $BASE_REVISION_NAME.qdb."
		post_message -type error "   Search path: [pwd]"
		qexit -error
	}
	
	# Import the root partition
	design::import_block root_partition -file "$BASE_REVISION_NAME.qdb"

	
	# Import each block required
	dict for {block_name synth_rev} [dict get $IMPL_REV_BLOCK_IMPORT_MAP $impl_rev] {
		design::import_block $block_name -file "$synth_rev.qdb"
	}
	
	project_close
	
}


proc compile_pr_revision_impl {impl_rev} {
	global PROJECT_NAME
	global BASE_REVISION_BLOCK_NAMES
	global BASE_REVISION_OUTPUT_DIR
	global FLOW_OPTION_RUN_POW
	global FLOW_OPTION_ENABLE_PR_BITSTREAM_COMPRESSION
	global FLOW_OPTION_ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION
	global FLOW_OPTION_DISABLE_RBF_GENERATION

	# Import the blocks for the revision
	import_blocks_for_pr_revision $impl_rev

	# Open the project. It is closed at the end of the import blocks command.
	project_open $PROJECT_NAME -rev $impl_rev

	post_message -type info "Compiling PR implementation $impl_rev."
	execute_module -tool fit
	execute_module -tool asm
	execute_module -tool sta
	
	if {[check_option_on $FLOW_OPTION_RUN_POW]} {
		execute_module -tool pow
	}

	# Create all bitstreams
	if {[check_option_on $FLOW_OPTION_DISABLE_RBF_GENERATION]} {
		post_message -type info "   Skipping bitstream generation."
	} else {
		foreach block_name $BASE_REVISION_BLOCK_NAMES {
			post_message -type info "   Converting bitstream for $block_name."
	
			if {[check_option_on $FLOW_OPTION_ENABLE_PR_BITSTREAM_COMPRESSION]} {
				execute_module -tool cpf -args "-c -o bitstream_compression=on ${BASE_REVISION_OUTPUT_DIR}/${impl_rev}.${block_name}.pmsf ${BASE_REVISION_OUTPUT_DIR}/${impl_rev}.${block_name}.rbf"
			} elseif {[check_option_on $FLOW_OPTION_ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION]} {
				execute_module -tool cpf -args "-c -o enhanced_bitstream_compression=on ${BASE_REVISION_OUTPUT_DIR}/${impl_rev}.${block_name}.pmsf ${BASE_REVISION_OUTPUT_DIR}/${impl_rev}.${block_name}.rbf"
			} else {
				execute_module -tool cpf -args "-c ${BASE_REVISION_OUTPUT_DIR}/${impl_rev}.${block_name}.pmsf ${BASE_REVISION_OUTPUT_DIR}/${impl_rev}.${block_name}.rbf"
			}
		}
	}
	
	project_close
}

proc compile_base_revision {} {
	global PROJECT_NAME
	global BASE_REVISION_NAME
	global BASE_REVISION_BLOCK_NAMES
	global BASE_REVISION_OUTPUT_DIR
	global FLOW_OPTION_RUN_POW
	global FLOW_OPTION_ENABLE_PR_BITSTREAM_COMPRESSION
	global FLOW_OPTION_ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION
	global FLOW_OPTION_DISABLE_RBF_GENERATION

	project_open $PROJECT_NAME -rev $BASE_REVISION_NAME
	
	# Compile the base revision
	post_message -type info "Compiling base revision $BASE_REVISION_NAME from project $PROJECT_NAME."
	execute_module -tool ipg -args "--generate_project_qsys_files"
	if {[file exists "post_ipgenerate_base_flow.tcl"]} {
		post_message -type info "Preparing to source post_ipgenerate_base_flow.tcl."
		source "post_ipgenerate_base_flow.tcl"
	}
	execute_module -tool syn
	execute_module -tool fit
	execute_module -tool asm
	execute_module -tool sta
	
	if {[check_option_on $FLOW_OPTION_RUN_POW]} {
		execute_module -tool pow
	}
	
	# export the root partition
	design::export_block "root_partition" -snapshot final -file "$BASE_REVISION_NAME.qdb" -exclude_pr_subblocks

	# Create all bitstreams
	if {[check_option_on $FLOW_OPTION_DISABLE_RBF_GENERATION]} {
		post_message -type info "   Skipping bitstream generation."
	} else {
		foreach block_name $BASE_REVISION_BLOCK_NAMES {
			post_message -type info "   Converting bitstream for $block_name."
	
			if {[check_option_on $FLOW_OPTION_ENABLE_PR_BITSTREAM_COMPRESSION]} {
				execute_module -tool cpf -args "-c -o bitstream_compression=on ${BASE_REVISION_OUTPUT_DIR}/${BASE_REVISION_NAME}.${block_name}.pmsf ${BASE_REVISION_OUTPUT_DIR}/${BASE_REVISION_NAME}.${block_name}.rbf"
			} elseif {[check_option_on $FLOW_OPTION_ENABLE_ENHANCED_PR_BITSTREAM_COMPRESSION]} {
				execute_module -tool cpf -args "-c -o enhanced_bitstream_compression=on ${BASE_REVISION_OUTPUT_DIR}/${BASE_REVISION_NAME}.${block_name}.pmsf ${BASE_REVISION_OUTPUT_DIR}/${BASE_REVISION_NAME}.${block_name}.rbf"
			} else {
				execute_module -tool cpf -args "-c ${BASE_REVISION_OUTPUT_DIR}/${BASE_REVISION_NAME}.${block_name}.pmsf ${BASE_REVISION_OUTPUT_DIR}/${BASE_REVISION_NAME}.${block_name}.rbf"
			}
	
		}
	}

	project_close
}


proc compile_all_pr_revisions {} {
	global SYNTHESIS_REVISIONS
	global BASE_REVISION_NAME
	global IMPL_REV_BLOCK_IMPORT_MAP

	# Make sure the QDB exists
	if {[file exists "$BASE_REVISION_NAME.qdb"] == 0} {
		post_message -type error "Could not find required file $BASE_REVISION_NAME.qdb."
		post_message -type error "   Search path: [pwd]"
		qexit -error
	}

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
	
	post_message -type error "Could not find an implementation revision named $requested_impl_name."
	qexit -error
}

proc prepare_pr_revision_comp {requested_impl_name} {
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
			
			# Import the blocks for the revision
			import_blocks_for_pr_revision $impl_rev_name
		
			return 1
		}
	}
	
	post_message -type error "Could not find an implementation revision named $requested_impl_name."
	qexit -error
}

proc cleanup {} {
	global PROJECT_NAME
	global BASE_REVISION_NAME
	global SYNTHESIS_REVISIONS
	global BASE_REVISION_OUTPUT_DIR

	
	# Open project using force to override old versions 
	project_open $PROJECT_NAME -rev $BASE_REVISION_NAME -force

	post_message -type info "Cleaning up project."
	
	# Clean up the project across all revisions. This also
	# closes the project. Catch any errors from this command to handle
	# old revisions
	catch {project_clean} msg
	puts $msg

	# Cleanup things not done by project_clean
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
proc main {} {
	global quartus
	global PROJECT_NAME
	global BASE_REVISION_NAME
	global options
	global CURRENT_SCRIPT

	set available_options {
		{ check "Check the script configuration then exit" }
		{ nobasecheck "Skip configuration checking (Internal Only)" }
		{ all "Compile all revisions" }
		{ base "Compile base revision" }
		{ all_impl "Compile all PR implementation revisions" }
		{ impl.arg "\#_ignore_\#" "Compile a specifically named implementation identified by the implementation revision name" }
		{ prep_impl.arg "\#_ignore_\#" "Prepare the compile for a specifically named implementation identified by the implementation revision name" }
		{ setup_script.arg "\#_ignore_\#" "Specify a script to use instead of running the define_pr_project in the script" }
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
	if [catch {array set options [cmdline::getoptions argument_list $available_options]} result] {
		if {[llength $argument_list] > 0 } {
			# This is not a simple -? or -help but an actual error condition
			post_message -type error "Illegal Options $argument_list"
			post_message -type error  [::cmdline::usage $available_options $usage]
			qexit -error
		} else {
			post_message -type info  "Usage:"
			post_message -type info  [::cmdline::usage $available_options $usage]
			qexit -success
		}
	}
	
	# Define the PR project
	set setup_script [file join [file dirname $CURRENT_SCRIPT] "setup.tcl"]
	if {$options(setup_script) != "#_ignore_#"} {
		set setup_script $options(setup_script)
	}
	
	post_message -type info "Using setup script [file normalize $setup_script]"
	if {[file exists $setup_script]} {
		source $setup_script
	} else {
		post_message -type error "Required setup script setup.tcl was not found."
		post_message -type error "   Search path: [file dirname [file normalize $CURRENT_SCRIPT]]"
		qexit -error
	}
	
	# Perform initial checks and initialize
	initialize $options(nobasecheck)
	
	# Print the info on the project. This also checks the project
	print_pr_project_info
	
	# Perform the required flow
	if {$options(check)} {
		# Do nothing
	
		post_message -type info "Successfully completed flow script check."
	} elseif {$options(base)} {
		cleanup
	
		# Compile a single revision
		compile_base_revision
		post_message -type info "Successfully completed base revision."
		
		if {$options(prep_impl) != "#_ignore_#"} {
			# Prepare to implement a specific revision
			
			prepare_pr_revision_comp $options(prep_impl)
			post_message -type info "Successfully completed A10 PR compile preparation."
		} elseif {$options(impl) != "#_ignore_#"} {
			# Compile a single revision
			compile_pr_revision $options(impl)
		
			post_message -type info "Successfully completed A10 PR compile."
		} elseif {$options(all_impl)} {
			# Compile all PR implementation revisions. In this case do not cleanup
			
			compile_all_pr_revisions
			post_message -type info "Successfully completed A10 PR compile."
		}		
	} elseif {$options(prep_impl) != "#_ignore_#"} {
		# Prepare to implement a specific revision
		
		prepare_pr_revision_comp $options(prep_impl)
		post_message -type info "Successfully completed A10 PR compile preparation."
	} elseif {$options(impl) != "#_ignore_#"} {
		# Compile a single revision
		compile_pr_revision $options(impl)
	
		post_message -type info "Successfully completed A10 PR compile."
	} elseif {$options(all_impl)} {
		# Compile all PR implementation revisions. In this case do not cleanup
		
		compile_all_pr_revisions
		post_message -type info "Successfully completed A10 PR compile."
	} else {
		# Do a full compile
		cleanup
	
		compile_all_revisions
		post_message -type info "Successfully completed A10 PR compile."
	}
}

###############################################################################
# Prevent script from running from GUI
###############################################################################

if {($::quartus(nameofexecutable) == "quartus") || ($::quartus(nameofexecutable) == "quartus_pro") || ($::quartus(nameofexecutable) == "qpro")} {
	
	# When running from the Quartus GUI execute ourselves using execute_script
	post_message -type info "Preparing to run: $CURRENT_SCRIPT."
	if [catch {execute_script $CURRENT_SCRIPT -tool sh} result] {
		puts $result
		puts "Error occurred running $CURRENT_SCRIPT."
	} else {
		puts "Script $CURRENT_SCRIPT completed successfully."
	}
} elseif {($::quartus(nameofexecutable) == "quartus_sh") || ($::quartus(nameofexecutable) == "qpro_sh")} {
	main
} else {
	post_message -type error "The Arria 10 PR compile flow script can only be run from the Quartus GUI or quartus_sh."
}
