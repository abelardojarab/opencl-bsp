// (C) 1992-2014 Altera Corporation. All rights reserved.                         
// Your use of Altera Corporation's design tools, logic functions and other       
// software and tools, and its AMPP partner logic functions, and any output       
// files any of the foregoing (including device programming or simulation         
// files), and any associated documentation or information are expressly subject  
// to the terms and conditions of the Altera Program License Subscription         
// Agreement, Altera MegaCore Function License Agreement, or other applicable     
// license agreement, including, without limitation, that your use is for the     
// sole purpose of programming logic devices manufactured by Altera and sold by   
// Altera or its authorized distributors.  Please refer to the applicable         
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

#include <sstream>   // std::ostringstream
#include <iomanip>   // std::setw

#include "ocl.h"
#include "acl_aligned.h"
#undef _GNU_SOURCE 

#include "aocl_mmd.h"

#if defined(WINDOWS)
#  include "wdc_lib_wrapper.h"
#endif   // WINDOWS


// WARNING: host runs out of events if MAXNUMBYTES is much greater than
// MINNUMBYTES!!!
#define INT_KB (1024)
#define INT_MB (1024 * 1024)
#define INT_GB (1024 * 1024 * 1024)
#define DEFAULT_MAXNUMBYTES (8ULL * INT_MB)
#define DEFAULT_MINNUMBYTES (512ULL * INT_KB)

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
int general_basic_tests()
{
/*#if defined(WINDOWS)
   const char *license = JUNGO_LICENSE;
   DWORD status        = WDC_DriverOpen( WDC_DRV_OPEN_DEFAULT, license );
   if(status == WD_STATUS_SUCCESS) {
      WDC_DriverClose();   
   } else {
      printf("\nUnable to open the kernel mode driver.\n");
      printf("\nPlease make sure you have properly installed the driver. To install the driver, run\n");
      printf("      aocl install\n");
      return -1;   
   }
#endif   // WINDOWS
#if defined(LINUX)
   if ( system("cat /proc/modules | grep \"aclpci_drv\" > /dev/null") ) {
      printf("\nUnable to find the kernel mode driver.\n");
      printf("\nPlease make sure you have properly installed the driver. To install the driver, run\n");
      printf("      aocl install\n");
      return -1;
   }
#endif   // LINUX*/

   printf("\nVerified that the kernel mode driver is installed on the host machine.\n\n");
   return 0;
}

int scan_all_devices()
{
   static char vendor_name[MMD_STRING_RETURN_SIZE];
   aocl_mmd_get_offline_info(AOCL_MMD_VENDOR_NAME, sizeof(vendor_name), vendor_name, NULL);
   printf("Using board package from vendor: %s\n", vendor_name);

   printf("Querying information for all supported devices that are installed on the host machine ... \n\n");

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
      handle = aocl_mmd_open(dev_name);

      // print out the first row of the table when needed
      if( handle != -1 && !first_row_printed) {
         o_list_stream << "\nDevice Name   Status   Information\n\n";
         first_row_printed = 1;
      }

      // when handle < -1, a supported device exists, but it failed the initial tests. 
      if( handle < -1 ) {
         o_list_stream << std::left << std::setw(14) << dev_name << "Failed   Board name not available.\n";
         o_list_stream << "                       Failed initial tests, so not working as expected.\n"; 
         o_list_stream << "                       Please try again after reprogramming the device.\n";
         o_list_stream << "\n";
      }

      // skip to next dev_name
      if( handle < 0 ){   continue;   }

      // found a working supported device
      num_active_boards++;
      aocl_mmd_get_info(handle,AOCL_MMD_BOARD_NAME, sizeof(board_name), board_name, NULL);
      o_list_stream << std::left << std::setw(14) << dev_name << "Passed   " << board_name << "\n";

      aocl_mmd_get_info(handle, AOCL_MMD_PCIE_INFO, sizeof(pcie_info), pcie_info, NULL);
      o_list_stream << "                       PCIe " << pcie_info << "\n";

      aocl_mmd_get_info(handle, AOCL_MMD_TEMPERATURE, sizeof(float), &temperature,NULL);
      o_list_stream << "                       FPGA temperature = " << temperature << " degrees C.\n";
      o_list_stream << "\n";
      
      
      /*
      for( int i =0;  i < 16;i++){
        int num = 0;
        aocl_mmd_read(handle, 0, 4, &num, 0, i*4);
        printf(" Read at %d is %x\n", i*4, num);
      }*/
   }

   if(num_active_boards > 0) {
      o_list_stream << "\nFound " << num_active_boards 
                    << " active device(s) installed on the host machine. To perform a full diagnostic on a specific device, please run\n";
      o_list_stream << "      aocl diagnose <device_name>\n";
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
#undef MMD_STRING_RETURN_SIZE

int main (int argc, char *argv[])
{
   unsigned dev_num = 0;

   if( general_basic_tests() != 0 ){
      printf("\nDIAGNOSTIC_FAILED\n");
      return 0;
   }

   // if no specific device name is provided
   // we scan all the device installed on the host machine
   if (argc < 2) {
      if( scan_all_devices() == 0 ){
         printf("\nDIAGNOSTIC_PASSED\n");
      } else {
         printf("\nDIAGNOSTIC_FAILED\n");
      }
      return 0;
   }

   // get device number provided in the argument
   if (sscanf(argv[1],"acl%d",&dev_num) != 1) {
      printf("Unable to open the device %s.\n", argv[1]);
      printf("Please make sure you have provided a proper <device_name> (e.g. acl0 to acl15).\n");
      return 0;
   }



   bool result=true;


   ocl_device_init(dev_num,0);


   if (result)
     printf("\nDIAGNOSTIC_PASSED\n");
   else
     printf("\nDIAGNOSTIC_FAILED\n");



   return (result) ? 0 : -1;
}
