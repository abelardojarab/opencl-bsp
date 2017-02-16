// ***************************************************************************
// Copyright (c) 2013-2017, Intel Corporation All Rights Reserved.
// The source code contained or described herein and all  documents related to
// the  source  code  ("Material")  are  owned by  Intel  Corporation  or  its
// suppliers  or  licensors.    Title  to  the  Material  remains  with  Intel
// Corporation or  its suppliers  and licensors.  The Material  contains trade
// secrets and  proprietary  and  confidential  information  of  Intel or  its
// suppliers and licensors.  The Material is protected  by worldwide copyright
// and trade secret laws and treaty provisions. No part of the Material may be
// copied,    reproduced,    modified,    published,     uploaded,     posted,
// transmitted,  distributed,  or  disclosed  in any way without Intel's prior
// express written permission.
// ***************************************************************************
//-------------------------------------------------------------------------
//  TOOL and VENDOR Specific configurations
// ------------------------------------------------------------------------
// The TOOL and VENDOR definition necessary to correctly configure PAR project
// package currently supports
// Vendors : Intel
// Tools   : Quartus II
`include "sys_cfg_pkg.svh"
`ifndef VENDOR_DEFINES_VH
`define VENDOR_DEFINES_VH

   
    `ifdef VENDOR_ALTERA
        `define GRAM_AUTO "no_rw_check"                         // defaults to auto
        `define GRAM_BLCK "no_rw_check, M20K"
        `define GRAM_DIST "no_rw_check, MLAB"
    `endif
    
    //-------------------------------------------
    // Generate error if TOOL not defined
    `ifdef TOOL_QUARTUS
        `define GRAM_STYLE ramstyle
        `define NO_RETIMING  dont_retime
        `define NO_MERGE dont_merge
        `define KEEP_WIRE syn_keep = 1
    `endif
    
`endif
