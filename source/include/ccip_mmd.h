// (C) 1992-2017 Intel Corporation.                            
// Intel, the Intel logo, Intel, MegaCore, NIOS II, Quartus and TalkBack words    
// and logos are trademarks of Intel Corporation or its subsidiaries in the U.S.  
// and/or other countries. Other marks and brands may be claimed as the property  
// of others. See Trademarks on intel.com for full list of Intel trademarks or    
// the Trademarks & Brands Names Database (if Intel) or See www.Intel.com/legal (if Altera) 
// Your use of Intel Corporation's design tools, logic functions and other        
// software and tools, and its AMPP partner logic functions, and any output       
// files any of the foregoing (including device programming or simulation         
// files), and any associated documentation or information are expressly subject  
// to the terms and conditions of the Altera Program License Subscription         
// Agreement, Intel MegaCore Function License Agreement, or other applicable      
// license agreement, including, without limitation, that your use is for the     
// sole purpose of programming logic devices manufactured by Intel and sold by    
// Intel or its authorized distributors.  Please refer to the applicable          
// agreement for further details.                                                 

#ifndef CCIP_MMD_H
#define CCIP_MMD_H

// Directly programs aocx file data to a device bypassing the typical
// OpenCL function calls.  Used because the aoc runtime needs
// to interface with the BSP, that is not possible if the BSP is
// not loaded yet.  This function bypasses the aoc runtime and directly
// loads the aocx using OPAE.  Note that the function is not thread-safe
// and will not have aoc locking.  It should *not* be used in conjunction
// with OpenCL API calls.
int ccip_mmd_device_reprogram(const char *device_name, void *data, size_t data_size);

#endif //CCIP_MMD_H
