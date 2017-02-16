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

define_project dcp

define_base_revision dcp

define_pr_revision -impl_rev_name afu_fit -impl_block [list green_region afu_synth]
