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


#ifdef __cplusplus
extern "C" {
#endif

// Min good alignment for DMA
#define ACL_ALIGNMENT 64

#ifdef LINUX
#include <stdlib.h>
#include <stdio.h>
void* acl_util_aligned_malloc (size_t size) {
  void *result = NULL;
  int res = posix_memalign (&result, ACL_ALIGNMENT, size);
  if(res) {
     fprintf(stderr,"Error: memory allocation failed: %d\n", res);
  }
  return result;
}
void acl_util_aligned_free (void *ptr) {
  free (ptr);
}

#else // WINDOWS

#include <malloc.h>

void* acl_util_aligned_malloc (size_t size) {
  return _aligned_malloc (size, ACL_ALIGNMENT);
}
void acl_util_aligned_free (void *ptr) {
  _aligned_free (ptr);
}

#endif // LINUX

#ifdef __cplusplus
}
#endif



