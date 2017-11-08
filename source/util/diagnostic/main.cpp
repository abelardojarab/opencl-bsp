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


/********
 * The diagnostic program go through a few steps to test if the board is 
 * working properly
 *
 * 1. Driver Installation Check
 *
 * 2. Board Installation Check
 *
 * 3. Basic Functionality Check
 *
 * 4. Large Size DMA transmission between host and the device
 *
 * 5. Measure PCIe bandwidth:
 *
 * Fastest: Max speed of any one Enqueue call
 * Slowest: Min speed of any one Enqueue call
 * Average: Sum of transfer times from Queued-End of each request divided
 * by total bytes
 * Total: Queue time of first Enqueue call to End time of last Enqueue call
 * divided by total bytes
 *
 * Final "Throughput" value is average of max read and max write speeds.
 ********/

#define _GNU_SOURCE 1
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <malloc.h>
#include <time.h>

#include <limits>
#include <sstream>   // std::ostringstream
#include <iomanip>   // std::setw

#include "ocl.h"
#include "acl_aligned.h"
#undef _GNU_SOURCE 

#include "aocl_mmd.h"


#define ACL_BOARD_PKG_NAME                          "a10_dcp"
#define ACL_VENDOR_NAME                             "Intel(R) Corporation"
#define ACL_BOARD_NAME                              "Arria 10 DCP Platform"


// WARNING: host runs out of events if MAXNUMBYTES is much greater than
// MINNUMBYTES!!!
#define INT_KB (1024)
#define INT_MB (1024 * 1024)
#define INT_GB (1024 * 1024 * 1024)
#define DEFAULT_MAXNUMBYTES (256ULL * INT_MB)
#define DEFAULT_MINNUMBYTES (512ULL * INT_KB)

bool ccip_mmd_dma_setup_check();
bool ccip_mmd_check_fme_driver_for_pr();
bool ccip_mmd_bsp_loaded(const char *name);

bool check_results(unsigned int * buf, unsigned int * output, unsigned n)
{
  bool result=true;
  int prints=0;
  for (unsigned j=0; j<n; j++)
    if (buf[j]!=output[j])
    {
      if (prints++ < 512)
        printf("Error! Mismatch at element %d: %8x != %8x, xor = %08x\n",
          j,buf[j],output[j], buf[j]^output[j]);
      result=false;
    }
  return result;
}

#define MMD_STRING_RETURN_SIZE 1024

int scan_devices ( const char * device_name )
{
   static char vendor_name[MMD_STRING_RETURN_SIZE];
   aocl_mmd_get_offline_info(AOCL_MMD_VENDOR_NAME, sizeof(vendor_name), vendor_name, NULL);
   printf("Vendor: %s\n", vendor_name);

   // create a output string stream for information of the list of devices
   // this information will be output to stdout at the end to form a nice looking list
   std::ostringstream o_list_stream;

   // get all supported board names from MMD
   static char boards_name[MMD_STRING_RETURN_SIZE];
   aocl_mmd_get_offline_info(AOCL_MMD_BOARD_NAMES, sizeof(boards_name), boards_name, NULL);

   // query through all possible device name
   static char board_name[MMD_STRING_RETURN_SIZE];
   static char pcie_info[MMD_STRING_RETURN_SIZE];
   char       *dev_name;
   int         handle;
   int         first_row_printed = 0;
   int         num_active_boards = 0;
   float       temperature;
   for(dev_name = strtok(boards_name, ";"); dev_name != NULL; dev_name = strtok(NULL, ";")) {
      if ( device_name != NULL && strcmp(dev_name,device_name) != 0 ) continue;

      handle = aocl_mmd_open(dev_name);

      // print out the first row of the table when needed
      if( handle != -1 && !first_row_printed) {
         o_list_stream << "\nPhys Dev Name  Status   Information\n";
         first_row_printed = 1;
      }

      // when handle < -1, a supported device exists, but it failed the initial tests. 
      if( handle < -1 ) {
         o_list_stream << std::left << std::setw(14) << dev_name << "Uninitialized   Not configured with OpenCL BSP.\n";
         o_list_stream << "\n";
      }

      // skip to next dev_name
      if( handle < 0 ){   continue;   }

      // found a working supported device
      num_active_boards++;
      o_list_stream << "\n";
      aocl_mmd_get_info(handle,AOCL_MMD_BOARD_NAME, sizeof(board_name), board_name, NULL);
      o_list_stream << std::left << std::setw(14) << dev_name << "Passed   " << board_name << "\n";

      aocl_mmd_get_info(handle, AOCL_MMD_PCIE_INFO, sizeof(pcie_info), pcie_info, NULL);
      o_list_stream << "                       PCIe " << pcie_info << "\n";

      aocl_mmd_get_info(handle, AOCL_MMD_TEMPERATURE, sizeof(float), &temperature,NULL);
      o_list_stream << "                       FPGA temperature = " << temperature << " degrees C.\n";
   }

   if(num_active_boards > 0) {
      if ( device_name == NULL)
      {
         o_list_stream << "\nFound " << num_active_boards 
            << " active device(s) installed on the host machine. To perform a full diagnostic on a specific device, please run\n";
         o_list_stream << "      aocl diagnose <device_name>\n";
      }
   } else {
      o_list_stream << "\nFound no active device installed on the host machine.\n";
      o_list_stream << "\nPlease make sure to: \n";
      o_list_stream << "      1. Set the environment variable AOCL_BOARD_PACKAGE_ROOT to the correct board package.\n";
      o_list_stream << "      2. Install the driver from the selected board package.\n";
      o_list_stream << "      3. Properly install the device in the host machine.\n";
      o_list_stream << "      4. Configure the device with a supported OpenCL design.\n";
      o_list_stream << "      5. Reboot the machine if the PCI Express link failed.\n";
   }

   // output all characters in ostringstream
   std::string s = o_list_stream.str();
   printf("%s", s.c_str());

   return num_active_boards > 0 ? 0 : 1;
}

int main (int argc, char *argv[])
{
   char * device_name = NULL;
   bool probe = false;
   
   bool use_polling = true;
   
   for ( int i = 1 ; i < argc; i ++ ) {
     if (strcmp(argv[i],"-probe") == 0) 
       probe = true;
     else 
       device_name=argv[i];
   }

   if(!ccip_mmd_dma_setup_check())
   {
       printf("\nBASIC DCP DRIVER CHECK FAILED\n");
       printf("\nDIAGNOSTIC_FAILED\n");
       return -1;
   }

   if(!ccip_mmd_check_fme_driver_for_pr())
   {
       printf("\nWARNING: DCP PR device files are not available.\n");
       printf("\nWARNING: 'aocl program' is not available.\n");
   }

   // we scan all the device installed on the host machine and print
   // preliminary information about all or just the one specified
   if ( (!probe && device_name == NULL) || (probe && device_name != NULL) ) {
       if( scan_devices(device_name) == 0 ){
           printf("\nDIAGNOSTIC_PASSED\n");
       } else {
           printf("\nDIAGNOSTIC_FAILED\n");
           return -1;
       }
       return 0;
   }


   // get all supported board names from MMD
   //   if probing all device just print them and exit
   //   if diagnosing a particular device, check if it exists
   char boards_name[MMD_STRING_RETURN_SIZE];
   aocl_mmd_get_offline_info(AOCL_MMD_BOARD_NAMES, sizeof(boards_name), boards_name, NULL);
   char *dev_name;
   bool device_exists = false;
   bool bsp_loaded = false;
   for(dev_name = strtok(boards_name, ";"); dev_name != NULL; dev_name = strtok(NULL, ";")) {
      if ( probe )
         printf("%s\n",dev_name);
      else
         device_exists |= ( strcmp(dev_name,argv[1]) == 0 );
   }

   // If probing all devices we're done here
   if ( probe )
      return 0;

   // Full diagnosis of a particular device begins here

   // get device number provided in the argument
   if ( !device_exists ) {
      printf("Unable to open the device %s.\n", argv[1]);
      printf("Please make sure you have provided a proper <device_name>.\n");
      printf("  Expected device names = %s\n", boards_name);
      return -1;
   }

   bsp_loaded = ccip_mmd_bsp_loaded(argv[1]);
   if ( !bsp_loaded ) {
      printf("\nBSP not loaded for Programmable Accelerator Card %s\n",argv[1]);
      printf("Use 'aocl program <device_name> <aocx_file>' to initialize BSP\n\n");
      return -1;
   }


   srand ( unsigned(time(NULL)) );

   int maxbytes = DEFAULT_MAXNUMBYTES;
   if(argc >= 3) {
       maxbytes = atoi(argv[2]);
       if(maxbytes < 0 || maxbytes > std::numeric_limits<int>::max())
          maxbytes = DEFAULT_MAXNUMBYTES;
   }

   unsigned maxints = unsigned(maxbytes/sizeof(int));

   unsigned iterations=1;
   for (unsigned i=maxbytes/DEFAULT_MINNUMBYTES; i>>1 ; i=i>>1)
     iterations++;

   struct speed *readspeed = new struct speed[iterations];
   struct speed *writespeed = new struct speed[iterations];

   bool result=true;

   unsigned int *buf = (unsigned int*) acl_util_aligned_malloc (maxints * sizeof(unsigned int));
   unsigned int *output = (unsigned int*) acl_util_aligned_malloc (maxints * sizeof(unsigned int));
  
   // Create sequence: 0 rand1 ~2 rand2 4 ...
   for (unsigned j=0; j<maxints; j++)
     if (j%2==0)
       buf[j]=(j&2) ? ~j : j;
     else
       buf[j]=unsigned(rand()*rand());

   //FIXME: should not assume one CL device
   unsigned dev_num = 0;  // Assume only one CL device

   ocl_device_init(dev_num,maxbytes);

   int block_bytes=DEFAULT_MINNUMBYTES;

   // Warm up
   ocl_writespeed((char*)buf,block_bytes,maxbytes);
   ocl_readspeed((char*)output,block_bytes,maxbytes);

   for (unsigned i=0; i<iterations; i++, block_bytes*=2)
   {
     printf("Transferring %d KBs in %d %d KB blocks ...",maxbytes/1024,maxbytes/block_bytes,block_bytes/1024);
     writespeed[i] = ocl_writespeed((char*)buf,block_bytes,maxbytes);
     readspeed[i] = ocl_readspeed((char*)output,block_bytes,maxbytes);
     result &= check_results(buf,output,maxints);
     printf(" %.2f MB/s\n",(writespeed[i].fastest > readspeed[i].fastest) ? writespeed[i].fastest : readspeed[i].fastest);
   }
   
   printf("\nAs a reference:\n");
   printf("PCIe Gen1 peak speed: 250MB/s/lane\n");
   printf("PCIe Gen2 peak speed: 500MB/s/lane\n");
   printf("PCIe Gen3 peak speed: 985MB/s/lane\n");

   printf("\n");
   printf("Writing %d KBs with block size (in bytes) below:\n",maxbytes/1024);

   printf("\nBlock_Size Avg    Max    Min    End-End (MB/s)\n");

   float write_topspeed = 0;
   block_bytes=DEFAULT_MINNUMBYTES;
   for (unsigned i=0; i<iterations; i++, block_bytes*=2)
   {
     printf("%8d %.2f %.2f %.2f %.2f\n", block_bytes, 
         writespeed[i].average,
         writespeed[i].fastest,
         writespeed[i].slowest,
         writespeed[i].total);

     if (writespeed[i].fastest > write_topspeed)
       write_topspeed = writespeed[i].fastest;
     if (writespeed[i].total > write_topspeed)
       write_topspeed = writespeed[i].total;
   }

   float read_topspeed = 0;
   block_bytes=DEFAULT_MINNUMBYTES;

   printf("\n");

   printf("Reading %d KBs with block size (in bytes) below:\n",maxbytes/1024);
   printf("\nBlock_Size Avg    Max    Min    End-End (MB/s)\n");
   for (unsigned i=0; i<iterations; i++, block_bytes*=2)
   {
     printf("%8d %.2f %.2f %.2f %.2f\n", block_bytes, 
         readspeed[i].average,
         readspeed[i].fastest,
         readspeed[i].slowest,
         readspeed[i].total);

     if (readspeed[i].fastest > read_topspeed)
       read_topspeed = readspeed[i].fastest;
     if (readspeed[i].total > read_topspeed)
       read_topspeed = readspeed[i].total;
   }

   printf("\nWrite top speed = %.2f MB/s\n",write_topspeed);
   printf("Read top speed = %.2f MB/s\n",read_topspeed);
   printf("Throughput = %.2f MB/s\n",(read_topspeed+write_topspeed)/2);
   
   if (use_polling ) {
      printf("\nUsing polling for DMA transfers.\n");
      printf("Bandwidth is higher at the cost of CPU utilization\n");
      printf("When using interrupts for DMA, bandwidth is limited by the maximum number of interrupts per second that the driver can process.\n");
      printf("To use interrupts for DMA Set environment variable 'ACL_PCIE_DMA_USE_MSI'.\n");
   } 
   if (result)
     printf("\nDIAGNOSTIC_PASSED\n");
   else
     printf("\nDIAGNOSTIC_FAILED\n");

   acl_util_aligned_free (buf);
   acl_util_aligned_free (output);

   delete[] readspeed;
   delete[] writespeed;

   return (result) ? 0 : -1;
}
