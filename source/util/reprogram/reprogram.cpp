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
// ACL specific includes
#include "board.h"

//HACK: needed for reprogram to know if opencl image is loaded
//opencl runtime gets confused if there is no opencl image loaded
bool ccip_mmd_is_fpga_configured_with_opencl();

// ACL runtime configuration
static cl_platform_id platform;
static cl_device_id device;
static cl_context context;
static cl_program program;
static cl_int status;

/* return 1 if given filename has given extension */
int filename_has_ext (const char *filename, const char *ext)
{
   size_t ext_len = strlen (ext);  
   return (strcmp (filename + strlen(filename) - ext_len, ext) == 0);
}

int is_fpga_bin( const char* filename)
{
  if (filename_has_ext (filename, ".bin") || 
      filename_has_ext (filename, ".BIN") ) {
    return 1;
  }
  return 0;
}

int is_aocx( const char* filename)
{
  if (filename_has_ext (filename, ".aocx") || 
      filename_has_ext (filename, ".AOCX") ) {
    return 1;
  }
  return 0;
}

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

static void dump_error(const char *str, cl_int status) {
  printf("%s\n", str);
  printf("Error code: %d\n", status);
}

// Set to false to temporarily disable printing of error notification callbacks
bool g_enable_notifications = true;
void ocl_notify(
    const char *errinfo, 
    const void *private_info, 
    size_t cb, 
    void *user_data) {
  if(g_enable_notifications) {
    printf("  OpenCL Notification Callback:");
    printf(" %s\n", errinfo);
  }
}



int main(int argc, char ** argv){

   char *device_name = NULL;
   char *fpga_bin_filename_from_cmd = NULL;
   char *aocx_filename_from_cmd = NULL;

   unsigned char *fpga_bin_file = NULL;
   size_t fpga_bin_filesize;
  
   unsigned char *aocx_file = NULL;
   size_t aocx_filesize;

   cl_uint num_platforms;
   cl_uint num_devices;

   if ( argc != 4 ) {
      printf("Error: Invalid number of arguments.\n");
      return 1;
   }

   device_name = argv[1];
   fpga_bin_filename_from_cmd = argv[2];
   aocx_filename_from_cmd = argv[3];  
 
   if ( !is_fpga_bin(fpga_bin_filename_from_cmd) ) {
      printf("Error: Not passing in an BIN file.\n");
      return 1;
   }

   fpga_bin_file = acl_loadFileIntoMemory(fpga_bin_filename_from_cmd, &fpga_bin_filesize);   
   if ( fpga_bin_file == NULL ) {
      printf("Error: Unable to load BIN file into memory.\n");
      return 1;
   }

   aocx_file = acl_loadFileIntoMemory(aocx_filename_from_cmd,&aocx_filesize); 
   if (aocx_file == NULL) 
   {
     printf("Error: Failed to find aocx\n");
     exit(-1);
   }
   
   if(!ccip_mmd_is_fpga_configured_with_opencl())
   {
   	   int result = aocl_mmd_reprogram(1, aocx_file, aocx_filesize);
   	   if(result < 1)
   	   {
			dump_error("Failed aocl_mmd_reprogram.", result);
			return 1;
   	   }
   	   
       printf("Program succeed. \n");
   	   return 0;
   }

   // get the platform ID
   status = clGetPlatformIDs(1, &platform, &num_platforms);
   if(status != CL_SUCCESS) {
     dump_error("Failed clGetPlatformIDs.", status);
   }

   // get the number of devices
   status = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, 0, NULL, &num_devices);
   if(status != CL_SUCCESS) {
     dump_error("Failed clGetDeviceIDs.", status);
   }

   cl_device_id * devices = (cl_device_id*) malloc(num_devices*sizeof(cl_device_id));

   // get the device IDs
   status = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, num_devices, devices, NULL);
   if(status != CL_SUCCESS) {
     dump_error("Failed clGetDeviceIDs.", status);
   }

   bool found = false;

   // Look through all the devices for the one that ends with
   // "(device_name)" since we know that the MMD as implemented in
   // acl_pcie.cpp tacks this on to the ACL_BOARD_NAME in hw_pcie_constants.h
   for ( unsigned d = 0; d < num_devices; d++ ) {

     char dev_name_string[1024];
     status = clGetDeviceInfo(devices[d], CL_DEVICE_NAME, sizeof(dev_name_string), (void*)&dev_name_string[0], NULL);

     char phys_dev_substring[256];
     strcpy(phys_dev_substring,"(");
     strcat(phys_dev_substring,device_name);
     strcat(phys_dev_substring,")");

     char * found_substr = NULL;
     if ( (found_substr = strstr(dev_name_string, phys_dev_substring)) != NULL  &&
          *(found_substr + strlen(phys_dev_substring)) == '\0' ) {
       device = devices[d];
       found = true;

       printf("Programming device: %s\n",dev_name_string);

       break;
     }

   }

   // Error out if none found
   if( ! found ) {
     printf("Failed to find requested device %s from %d devices\n", device_name, num_devices);
     return 1;
   }

   // create a context
   context = clCreateContext(0, 1, &device, &ocl_notify, NULL, &status);
   if(status != CL_SUCCESS) {
     dump_error("Failed clCreateContext.", status);
     return 1;
   }

   // create the program
   // 
   // This is a special function that works the same as clCreateProgramWithBinary,
   // but always forces a device program operation at the end and returns whether
   // the device program operation was successful.
   // 
   cl_int kernel_status;
   program = clCreateProgramWithBinaryAndProgramDeviceIntelFPGA(context, 1, &device,
     &aocx_filesize, (const unsigned char**) &aocx_file, &kernel_status, &status);
   if(status != CL_SUCCESS) {
     dump_error("Failed clCreateProgramWithBinary.", status);
     return 1;
   }

   printf("Program succeed. \n");
   return 0;
}
