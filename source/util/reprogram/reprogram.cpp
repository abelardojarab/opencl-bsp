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


#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "aocl_mmd.h"
#include "ccip_mmd.h"

/* given filename, load its content into memory.
 * Returns file size in file_size_out ptr and ptr to buffer (allocated
 * with malloc() by this function that contains the content of the file.*/
unsigned char *acl_loadFileIntoMemory (const char *in_file, size_t *file_size_out) {

  FILE *f = NULL;
  unsigned char *buf;
  size_t file_size;
  
  // When reading as binary file, no new-line translation is done.
  f = fopen (in_file, "rb");
  if (f == NULL) {
    fprintf (stderr, "Couldn't open file %s for reading\n", in_file);
    return NULL;
  }
  
  // get file size
  fseek (f, 0, SEEK_END);
  file_size = (size_t)ftell (f);
  rewind (f);
  
  // slurp the whole file into allocated buf
  buf = (unsigned char*) malloc (sizeof(char) * file_size);
  *file_size_out = fread (buf, sizeof(char), file_size, f);
  fclose (f);
  
  if (*file_size_out != file_size) {
    fprintf (stderr, "Error reading %s. Read only %lu out of %lu bytes\n", 
                     in_file, *file_size_out, file_size);
    return NULL;
  }
  return buf;
}


int main(int argc, char ** argv){

   char *device_name = NULL;
   char *aocx_filename_from_cmd = NULL;
  
   unsigned char *aocx_file = NULL;
   size_t aocx_filesize;

   if ( argc != 4 ) {
      printf("Error: Invalid number of arguments.\n");
      return 1;
   }

   // The 'aocl' command passes the device_name in argv[1] and the aocx filename in argv[3]. 
   // It also passed the fpga_bin filename in argv[2] which is not used by DCP
   device_name = argv[1];
   aocx_filename_from_cmd = argv[3];  
  
   aocx_file = acl_loadFileIntoMemory(aocx_filename_from_cmd,&aocx_filesize); 
   if (aocx_file == NULL) 
   {
     printf("Error: Failed to find aocx\n");
     exit(-1);
   }

   int res = ccip_mmd_device_reprogram(device_name, aocx_file, aocx_filesize);
   if ( res > 0 ) {
      printf("Program succeed. \n");
      return 0;
   } else {
      printf("Error programming device\n");
      return 1;
   }
}
