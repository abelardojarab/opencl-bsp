// Copyright (C) 2013-2015 Altera Corporation, San Jose, California, USA. All rights reserved.
// Permission is hereby granted, free of charge, to any person obtaining a copy of this
// software and associated documentation files (the "Software"), to deal in the Software
// without restriction, including without limitation the rights to use, copy, modify, merge,
// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to
// whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or
// substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//
// This agreement shall be governed in all respects by the laws of the State of California and
// by the laws of the United States of America.

///////////////////////////////////////////////////////////////////////////////////
// This host program runs a "hello world" kernel. This kernel prints out a
// message for if the work-item index matches a kernel argument.
//
// Most of this host program code is the basic elements of a OpenCL host
// program, handling the initialization and cleanup of OpenCL objects. The
// host program also makes queries through the OpenCL API to get various
// properties of the device.
///////////////////////////////////////////////////////////////////////////////////

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <cstring>
#include "CL/opencl.h"
#include "AOCLUtils/aocl_utils.h"

using namespace aocl_utils;

#define STRING_BUFFER_LEN 1024

//max device buffer size; not necessarily the transfer size; use the master-loop increment to increase the size.
#define DEVICE_BUFFER_SIZE (1024*1024*16)
#define MIN_DEVICE_BUFFER_SIZE 512

// Runtime constants
// Used to define the work set over which this kernel will execute.
static const size_t work_group_size = 8;  // 8 threads in the demo workgroup
// Defines kernel argument value, which is the workitem ID that will
// execute a printf call
static const int thread_id_to_output = 2;

// OpenCL runtime configuration
static cl_platform_id platform = NULL;
static cl_device_id device = NULL;
static cl_context context = NULL;
static cl_command_queue queue = NULL;
static cl_kernel kernel = NULL;
static cl_program program = NULL;
static cl_mem device_a_buf = NULL;
static cl_mem device_b_buf = NULL;
static int mem_buf_test_size = 1024*1024*16;//start at xM instead of DEVICE_BUFFER_SIZE;
static int buffer_window_size = mem_buf_test_size;
static int starting_buffer_offset = 0;
static bool do_buffer_windowing = false;

//these defaults are used for in-hardware testing; ASE sims pass in new 
//  values to overwrite the defaults for shorter and smaller tests.
static int max_tst_cnt = 100;
static int do_test_1 = 1;//data is all 0x0's
static int do_test_2 = 1;//data is incrementing pattern
static int do_test_3 = 1;//accesses are small and random

static int do_wr_buf = 1;
static int do_cp_buf = 1;
static int do_rd_buf = 1;
static int compare_memory = do_rd_buf;

static int do_small_reads = 0;
static int rdsz = 1024;

static int rd_tst_cnt = 5;

static bool DBG_MSGS_MMD_COPY_TEST = false;
static const int DBG_MSG_FREQ = 50;
static bool DBG_MSG_EN_TEST_2 = false;

static int max_err_print = 50;
static bool display_matching_data = false;
static bool display_every_test_iteration = false;

//this defines the number of times to execute the 3-test sequence with new buffer sizes
static int num_master_loop_reps = 100;
static int buf_size_incr_each_master_loop = 0;//1024*1024*1;

// Function prototypes
bool init();
void cleanup();
static void check_mmd_copy(int mloop);

// Entry point.
int main(int argc, char **argv) {
  cl_int status;

  fprintf(stderr, "mmd_copy host|main: argc is %d.\n",argc);
  for(int i=1;i<argc;i++) {
          fprintf(stderr, "mmd_copy|main: argv[%d] is %s\n",i,argv[i]);
  }
  
  if(argc == 2) {
        mem_buf_test_size       = atoi(argv[1]);
  } else if (argc == 13) {
        mem_buf_test_size       = atoi(argv[1] );
        max_tst_cnt             = atoi(argv[2] );
        do_test_1               = atoi(argv[3] );
        do_test_2               = atoi(argv[4] );
        do_test_3               = atoi(argv[5] );
        do_wr_buf               = atoi(argv[6] );
        do_cp_buf               = atoi(argv[7] );
        do_rd_buf               = atoi(argv[8] );
        compare_memory          = atoi(argv[9] );
        do_small_reads          = atoi(argv[10]);
        rdsz                    = atoi(argv[11]);
        rd_tst_cnt              = atoi(argv[12]);
  }
  fprintf(stderr, "mmd_copy host|main: mem_buf_test_size     is %d.\n",mem_buf_test_size);
  fprintf(stderr, "mmd_copy host|main: max_tst_cnt           is %d.\n",max_tst_cnt          );
  fprintf(stderr, "mmd_copy host|main: do_test_1             is %d.\n",do_test_1            );
  fprintf(stderr, "mmd_copy host|main: do_test_2             is %d.\n",do_test_2            );
  fprintf(stderr, "mmd_copy host|main: do_test_3             is %d.\n",do_test_3            );
  fprintf(stderr, "mmd_copy host|main: do_wr_buf             is %d.\n",do_wr_buf            );
  fprintf(stderr, "mmd_copy host|main: do_cp_buf             is %d.\n",do_cp_buf            );
  fprintf(stderr, "mmd_copy host|main: do_rd_buf             is %d.\n",do_rd_buf            );
  fprintf(stderr, "mmd_copy host|main: compare_memory        is %d.\n",compare_memory       );
  fprintf(stderr, "mmd_copy host|main: do_small_reads        is %d.\n",do_small_reads       );
  fprintf(stderr, "mmd_copy host|main: rdsz                  is %d.\n",rdsz                 );
  fprintf(stderr, "mmd_copy host|main: rd_tst_cnt            is %d.\n",rd_tst_cnt           );
  fprintf(stderr, "mmd_copy host|main: max_err_print         is %d.\n",max_err_print        );
  
  
  assert(mem_buf_test_size <= DEVICE_BUFFER_SIZE);
  assert(mem_buf_test_size >= (MIN_DEVICE_BUFFER_SIZE*2));
  
  if(!init()) {
      return -1;
  }
  if (DBG_MSGS_MMD_COPY_TEST) fprintf(stderr, "mmd_copy host|main: after init function call\n");
  
  // Set the kernel argument (argument 0)
  status = clSetKernelArg(kernel, 0, sizeof(cl_int), (void*)&thread_id_to_output);
  checkError(status, "Failed to set kernel arg 0");
  
  fprintf(stderr, "\nKernel initialization is complete.\n");
  fprintf(stderr, "Launching the kernel...\n\n");
  
  // Configure work set over which the kernel will execute
  size_t wgSize[3] = {work_group_size, 1, 1};
  size_t gSize[3] = {work_group_size, 1, 1};
  
  // Launch the kernel
  status = clEnqueueNDRangeKernel(queue, kernel, 1, NULL, gSize, wgSize, 0, NULL, NULL);
  checkError(status, "Failed to launch kernel");
  
  // Wait for command queue to complete pending events
  status = clFinish(queue);
  checkError(status, "Failed to finish");
  
  fprintf(stderr, "\nKernel execution is complete. Now execute the check_mmd_copy test.\n");
  
  //master loop of 3-test function
  for (int i=1; i<=num_master_loop_reps;i++){
    fprintf(stderr, "mmd_copy main: Start master-loop %d of %d. buf-size for this test is %d.\n",i,num_master_loop_reps,mem_buf_test_size);
    check_mmd_copy(i);
    fprintf(stderr, "mmd_copy main: End master-loop %d of %d. mem_buf_test_size for this test was %d.\n\n",i,num_master_loop_reps,mem_buf_test_size);
    mem_buf_test_size += buf_size_incr_each_master_loop;
  } //num_master_loop_reps
  
  // Free the resources allocated
  cleanup();

  return 0;
}

static void check_mmd_copy(int mloop) {
  cl_int status;

  char *test_buffer;
  test_buffer = (char *)malloc(DEVICE_BUFFER_SIZE);
  assert(test_buffer);

  char *verify_buffer;
  verify_buffer = (char *)malloc(DEVICE_BUFFER_SIZE);
  assert(verify_buffer);
  
  ///////////////////////////////////////////////////
  //test 1
  //zero out buffer and test
  {
        if (do_test_1==1) {
            fprintf(stderr,"Starting test 1, master-loop %d...\n",mloop);
            memset(test_buffer, 0, DEVICE_BUFFER_SIZE);
            for (int tst_cnt=1;tst_cnt<=max_tst_cnt;tst_cnt++){
                int tst_err=0;
                if (tst_cnt%DBG_MSG_FREQ==0 || tst_cnt==1 || tst_cnt==max_tst_cnt || display_every_test_iteration) {
                    fprintf(stderr, "mmd_copy_test test 1: zero out buffer and test. Starting %d of %d, master-loop %d\n",tst_cnt,max_tst_cnt,mloop);
                }
                status = clEnqueueWriteBuffer(queue, device_a_buf, CL_TRUE,
                        0, mem_buf_test_size, test_buffer, 0, NULL, NULL);
                checkError(status, "Failed to transfer buffer A");
                
                if (DBG_MSGS_MMD_COPY_TEST)  fprintf(stderr, "mmd_copy_test|check_mmd_copy: test 1, master-loop %d: after clEnqueueWriteBuffer.\n",mloop);
                status = clEnqueueCopyBuffer(queue, device_a_buf, device_b_buf,
                        0, 0, mem_buf_test_size, 0, NULL, NULL);
                checkError(status, "Failed to transfer from buffer A to B");
                
                // Read buffer B to verify
                if (DBG_MSGS_MMD_COPY_TEST)  fprintf(stderr, "mmd_copy_test|check_mmd_copy: test 1,master-loop %d: after clEnqueueCopyBuffer.\n",mloop);
                status = clEnqueueReadBuffer(queue, device_b_buf, CL_TRUE,
                        0, mem_buf_test_size, verify_buffer, 0, NULL, NULL);
                checkError(status, "Failed to transfer buffer B");
                if (DBG_MSGS_MMD_COPY_TEST)  fprintf(stderr, "mmd_copy_test|check_mmd_copy: test 1,master-loop %d: after clEnqueueReadBuffer.\n",mloop);
                
                // Wait for command queue to complete pending events
                status = clFinish(queue);
                checkError(status, "Failed to finish");
                
                if(memcmp(test_buffer, verify_buffer, mem_buf_test_size) != 0)
                {
                    fprintf(stderr, "ERROR: buffer check failed! Checking each byte...\n");
                    for (int j=0; j<mem_buf_test_size; j++) {
                        if (test_buffer[j] != verify_buffer[j]){
                            tst_err++;
                            if (tst_err < max_err_print) {
                                fprintf(stderr, "mmd_copy test 1: byte %d verif error #%d test_buffer(wr)[j] %d verify_buffer(rd)[j] %d\n",j,tst_err,test_buffer[j],verify_buffer[j]);
                                //don't print forever - find a pattern with the first bunch of errors
                            } else if (tst_err == max_err_print) {
                                fprintf(stderr, "mmd_copy test 1: too many errors in this test - not checking anymore but still counting.\n");
                            }
                        }
                    }
                    fprintf(stderr, "mmd_copy test 1 loop %d, master-loop %d: total data mismatches: %d. Quitting.",tst_cnt,mloop,tst_err);
                    exit(1);
                }
                if (tst_cnt%DBG_MSG_FREQ==0 || tst_cnt==1 || tst_cnt==max_tst_cnt || display_every_test_iteration) {
                    if (tst_err==0) {
                        fprintf(stderr, "mmd_copy_test test 1: PASS. %d of %d, master-loop %d\n",tst_cnt,max_tst_cnt,mloop);
                    } else {
                        fprintf(stderr, "mmd_copy_test test 1: FAIL. Loop %d of %d, master-loop %d had %d errors.\n",tst_cnt,max_tst_cnt,mloop,tst_err);
                    }
                }
            }
        } else {
            fprintf(stderr, "\nSkipping test 1\n");
        }
  }
  
  ///////////////////////////////////////////////////
  //test 2
  //test sequential pattern
  {
        if (do_test_2==1) {
            fprintf(stderr,"Starting test 2, master-loop %d...\n",mloop);
            int buffer_offset = starting_buffer_offset;
            for (int tst_cnt=1;tst_cnt<=max_tst_cnt;tst_cnt++){
                int tst_err=0;
                if (tst_cnt%DBG_MSG_FREQ==0 || tst_cnt==1 || tst_cnt==max_tst_cnt || DBG_MSG_EN_TEST_2) {
                    fprintf(stderr, "mmd_copy_test test 2: test sequential pattern. Starting %d of %d,master-loop %d\n",tst_cnt,max_tst_cnt,mloop);
                }
                for(int i = 0; i < mem_buf_test_size; i++) {
                    test_buffer[i] = i+tst_cnt;
                }
                if ( (do_wr_buf==1) || ( tst_cnt==1 && (do_cp_buf==1 || do_rd_buf==1)  ) ) {
                    if (DBG_MSGS_MMD_COPY_TEST || DBG_MSG_EN_TEST_2)  fprintf(stderr, "mmd_copy_test|check_mmd_copy: test 2: doing clEnqueueWriteBuffer %d.\n",tst_cnt);
                    status = clEnqueueWriteBuffer(queue, device_a_buf, CL_TRUE,
                            buffer_offset, mem_buf_test_size, test_buffer, 0, NULL, NULL);
                    checkError(status, "Failed to transfer buffer A");
                    if (DBG_MSGS_MMD_COPY_TEST || DBG_MSG_EN_TEST_2)  fprintf(stderr, "mmd_copy_test|check_mmd_copy: test 2: after clEnqueueWriteBuffer %d.\n",tst_cnt);
                }
                
                if (do_cp_buf==1) {
                    if (DBG_MSGS_MMD_COPY_TEST || DBG_MSG_EN_TEST_2)  fprintf(stderr, "mmd_copy_test|check_mmd_copy: test 2: doing clEnqueueCopyBuffer %d.\n",tst_cnt);
                    status = clEnqueueCopyBuffer(queue, device_a_buf, device_b_buf,
                            buffer_offset, buffer_offset, mem_buf_test_size, 0, NULL, NULL);
                    checkError(status, "Failed to transfer from buffer A to B");
                    if (DBG_MSGS_MMD_COPY_TEST || DBG_MSG_EN_TEST_2)  fprintf(stderr, "mmd_copy_test|check_mmd_copy: test 2: after clEnqueueCopyBuffer %d.\n",tst_cnt);
                }
                
                // Read buffer B to verify
                if (do_rd_buf==1 || (tst_cnt >= (max_tst_cnt-rd_tst_cnt) ) ) {
                    if (DBG_MSGS_MMD_COPY_TEST || DBG_MSG_EN_TEST_2)  fprintf(stderr, "mmd_copy_test|check_mmd_copy: test 2: doing clEnqueueReadBuffer %d.\n",tst_cnt);
                    if (do_small_reads) {
                        //if we don't copy from a_buf into b_buf, read back from a_buf; else read from b_buf.
                        //int numrds_reqd = mem_buf_test_size/rdsz;
                        for (int offset=0, cnt=0;offset<mem_buf_test_size;offset+=rdsz,cnt++) {
                            if (DBG_MSGS_MMD_COPY_TEST)  fprintf(stderr, "mmd_copy_test|check_mmd_copy: test 2. cnt %d offset %d. rdsz %d.\n", cnt, offset, rdsz);
                            if (do_cp_buf==0) {
                                status = clEnqueueReadBuffer(queue, device_a_buf, CL_TRUE,
                                        (buffer_offset+offset), rdsz, (verify_buffer+offset), 0, NULL, NULL);
                            } else {
                                status = clEnqueueReadBuffer(queue, device_b_buf, CL_TRUE,
                                        (buffer_offset+offset), rdsz, (verify_buffer+offset), 0, NULL, NULL);
                            }
                            checkError(status, "Failed to transfer buffer B");
                            if (DBG_MSGS_MMD_COPY_TEST)  fprintf(stderr, "mmd_copy_test|check_mmd_copy: test 2. after small read %d to offset %d\n",cnt, offset);
                        }
                        if (DBG_MSGS_MMD_COPY_TEST)  fprintf(stderr, "mmd_copy_test|check_mmd_copy: test 2: after clEnqueueReadBuffer %d.\n",tst_cnt);
                    } else {
                        if (do_cp_buf==0) {
                            status = clEnqueueReadBuffer(queue, device_a_buf, CL_TRUE,
                                    buffer_offset, mem_buf_test_size, verify_buffer, 0, NULL, NULL);
                        } else {
                            status = clEnqueueReadBuffer(queue, device_b_buf, CL_TRUE,
                                    buffer_offset, mem_buf_test_size, verify_buffer, 0, NULL, NULL);
                        }
                        checkError(status, "Failed to transfer buffer B");
                        if (DBG_MSGS_MMD_COPY_TEST || DBG_MSG_EN_TEST_2)  fprintf(stderr, "mmd_copy_test|check_mmd_copy: test 2: after clEnqueueReadBuffer %d.\n",tst_cnt);
                    }
                }
                
                // Wait for command queue to complete pending events
                status = clFinish(queue);
                checkError(status, "Failed to finish");
                
                if ( (compare_memory==1) || (tst_cnt >= (max_tst_cnt-rd_tst_cnt) ) ) {
                    if (DBG_MSGS_MMD_COPY_TEST || DBG_MSG_EN_TEST_2)  fprintf(stderr, "mmd_copy_test|check_mmd_copy: test 2: doing memory-compare %d.\n",tst_cnt);
                    if(memcmp(test_buffer, verify_buffer, mem_buf_test_size) != 0)
                    {
                        fprintf(stderr, "ERROR: buffer check failed! Checking each byte...\n");
                        for (int j=0; j<mem_buf_test_size; j++) {
                            if (test_buffer[j] != verify_buffer[j]){
                                tst_err++;
                                if (tst_err < max_err_print) {
                                    fprintf(stderr, "mmd_copy test 2: loop %d: byte %d verif error # %d test_buffer(wr)[j] %d verify_buffer(rd)[j] %d.\n",tst_cnt,j,tst_err,test_buffer[j],verify_buffer[j]);
                                } else if (tst_err == max_err_print) {
                                    //don't print forever - find a pattern with the first bunch of errors
                                    fprintf(stderr, "mmd_copy test 2: too many errors in this test - not checking anymore, but still counting.\n");
                                }
                            } else if (display_matching_data) {
                                fprintf(stderr, "mmd_copy test 2: loop %d: byte %d verif match test_buffer(wr)[j] %d verify_buffer(rd)[j] %d.\n",tst_cnt,j,test_buffer[j],verify_buffer[j]);
                            }
                        }
                        fprintf(stderr, "mmd_copy test 2 loop %d: total data mismatches: %d. Quitting.",tst_cnt,tst_err);
                        exit(1);
                    }
                    if (tst_cnt%DBG_MSG_FREQ==0 || tst_cnt==1 || tst_cnt==max_tst_cnt || DBG_MSG_EN_TEST_2) {
                        if (tst_err==0) {
                            fprintf(stderr, "mmd_copy_test test 2: PASS. %d of %d, master-loop %d\n",tst_cnt,max_tst_cnt,mloop);
                        } else {
                            fprintf(stderr, "mmd_copy_test test 2: FAIL. Loop %d of %d had %d errors.\n",tst_cnt,max_tst_cnt,tst_err);
                        }
                    }
                }
                if (do_buffer_windowing) buffer_offset+=buffer_window_size;
            }
        } else {
            fprintf(stderr, "\nSkipping test 2\n");
        }
  }

  ///////////////////////////////////////////////////
  //test 3
  //test random copies
  {
        if (do_test_3==1) {
            fprintf(stderr,"Starting test 3, master-loop %d...\n",mloop);
            int tst_err=0;
            fprintf(stderr, "mmd_copy_test test 3: test random copies. Starting...master-loop %d\n",mloop);
            
            int num_transfers = mem_buf_test_size/MIN_DEVICE_BUFFER_SIZE;
            memcpy(verify_buffer, test_buffer, mem_buf_test_size);
            for(int i = 0; i < num_transfers; i++) {
                size_t src_offset = rand() % (mem_buf_test_size - MIN_DEVICE_BUFFER_SIZE - 1);
                size_t dst_offset = rand() % (mem_buf_test_size - MIN_DEVICE_BUFFER_SIZE - 1);
                size_t size = (rand() % MIN_DEVICE_BUFFER_SIZE) + 1;
                
                //if (DBG_MSGS_MMD_COPY_TEST)  fprintf(stderr,"test 3 about to call clEnqCopyBuffer. num-transfers is %d, i is %d\n",num_transfers,i);
                status = clEnqueueCopyBuffer(queue, device_a_buf, device_b_buf,
                    src_offset, dst_offset, size, 0, NULL, NULL);
                memcpy(test_buffer+dst_offset, verify_buffer+src_offset, size);
                checkError(status, "Failed to transfer from buffer A to B");
            }
            
            // Read buffer B to verify
            if (DBG_MSGS_MMD_COPY_TEST)  fprintf(stderr,"test 3 about to call clEnqReadBuffer\n");
            status = clEnqueueReadBuffer(queue, device_b_buf, CL_TRUE,
                    0, mem_buf_test_size, verify_buffer, 0, NULL, NULL);
            checkError(status, "Failed to transfer buffer B");
            
            // Wait for command queue to complete pending events
            status = clFinish(queue);
            checkError(status, "Failed to finish");
            
            if(memcmp(test_buffer, verify_buffer, mem_buf_test_size) != 0)
            {
                fprintf(stderr, "ERROR: buffer check failed! Checking each byte...\n");
                for (int j=0; j<mem_buf_test_size; j++) {
                    if (test_buffer[j] != verify_buffer[j]){
                        tst_err++;
                        if (tst_err < max_err_print) {
                            fprintf(stderr, "mmd_copy test 3: byte %d verif error # %d test_buffer(wr)[j] %d verify_buffer(rd)[j] %d.\n",j,tst_err,test_buffer[j],verify_buffer[j]);
                        } else if (tst_err == max_err_print) {
                            //don't print forever - find a pattern with the first bunch of errors
                            fprintf(stderr, "mmd_copy test 3: too many errors in this test - not checking anymore.\n");
                        }
                    } else if (display_matching_data) {
                        fprintf(stderr, "mmd_copy test 3: byte %d verif match test_buffer(wr)[j] %d verify_buffer(rd)[j] %d.\n",j,test_buffer[j],verify_buffer[j]);
                    }
                }
                fprintf(stderr, "mmd_copy test 3: total data mismatches: %d. Quitting.",tst_err);
                exit(1);
            }
            if (tst_err==0) {
                fprintf(stderr, "mmd_copy_test test 3: PASS., master-loop %d\n",mloop);
            } else {
                fprintf(stderr, "mmd_copy_test test 3, master-loop %d: FAIL. %d errors.\n",mloop,tst_err);
            }
        } else {
            fprintf(stderr, "\nSkipping test 3\n");
        }
  }

  ///////////////////////////////////////////////////
  //cleanup

  //free test buffer
  if(test_buffer)
	 free(test_buffer);

  if(verify_buffer)
	 free(verify_buffer);

  fprintf(stderr, "aocl_mmd_copy test master-loop %d complete.\n",mloop);
}

/////// HELPER FUNCTIONS ///////

bool init() {
  cl_int status;
    
  if (DBG_MSGS_MMD_COPY_TEST)  fprintf(stderr, "mmd_copy host|init: starting init function.\n");
  
  if(!setCwdToExeDir()) {
    return false;
  }
  if (DBG_MSGS_MMD_COPY_TEST)  fprintf(stderr, "mmd_copy host|init: after setCwdToExeDir, before findPlatform\n");

  // Get the OpenCL platform.
  platform = findPlatform("fpga");
  if (DBG_MSGS_MMD_COPY_TEST)  fprintf(stderr, "mmd_copy host|init: found platform fpga\n");
  if(platform == NULL) {
    if (DBG_MSGS_MMD_COPY_TEST)  fprintf(stderr, "ERROR: Unable to find Altera OpenCL platform.\n");
    return false;
  }

  // User-visible output - Platform information
  {
    char char_buffer[STRING_BUFFER_LEN];
    fprintf(stderr, "Querying platform for info:\n");
    fprintf(stderr, "==========================\n");
    clGetPlatformInfo(platform, CL_PLATFORM_NAME, STRING_BUFFER_LEN, char_buffer, NULL);
    fprintf(stderr, "%-40s = %s\n", "CL_PLATFORM_NAME", char_buffer);
    clGetPlatformInfo(platform, CL_PLATFORM_VENDOR, STRING_BUFFER_LEN, char_buffer, NULL);
    fprintf(stderr, "%-40s = %s\n", "CL_PLATFORM_VENDOR ", char_buffer);
    clGetPlatformInfo(platform, CL_PLATFORM_VERSION, STRING_BUFFER_LEN, char_buffer, NULL);
    fprintf(stderr, "%-40s = %s\n\n", "CL_PLATFORM_VERSION ", char_buffer);
  }

  // Query the available OpenCL devices.
  scoped_array<cl_device_id> devices;
  cl_uint num_devices;

  devices.reset(getDevices(platform, CL_DEVICE_TYPE_ALL, &num_devices));

  // We'll just use the first device.
  device = devices[0];

  // Create the context.
  context = clCreateContext(NULL, 1, &device, &oclContextCallback, NULL, &status);
  checkError(status, "Failed to create context");

  // Create the command queue.
  queue = clCreateCommandQueue(context, device, CL_QUEUE_PROFILING_ENABLE, &status);
  checkError(status, "Failed to create command queue");

  // Create the program.
  std::string binary_file = getBoardBinaryFile("hello_world", device);
  fprintf(stderr, "Using AOCX: %s\n", binary_file.c_str());
  program = createProgramFromBinary(context, binary_file.c_str(), &device, 1);

  // Build the program that was just created.
  status = clBuildProgram(program, 0, NULL, "", NULL, NULL);
  checkError(status, "Failed to build program");

  // Create the kernel - name passed in here must match kernel name in the
  // original CL file, that was compiled into an AOCX file using the AOC tool
  const char *kernel_name = "hello_world";  // Kernel name, as defined in the CL file
  kernel = clCreateKernel(program, kernel_name, &status);
  checkError(status, "Failed to create kernel");

  // device memory buffers.
  device_a_buf = clCreateBuffer(context, CL_MEM_READ_WRITE,
        DEVICE_BUFFER_SIZE, NULL, &status);
  checkError(status, "Failed to create buffer A");

  device_b_buf = clCreateBuffer(context, CL_MEM_READ_WRITE,
      DEVICE_BUFFER_SIZE, NULL, &status);
  checkError(status, "Failed to create buffer B");

  return true;
}

// Free the resources allocated during initialization
void cleanup() {
  if(device_a_buf) {
    clReleaseMemObject(device_a_buf);
  }
  if(device_b_buf) {
    clReleaseMemObject(device_b_buf);
  }

  if(kernel) {
    clReleaseKernel(kernel);
  }
  if(program) {
    clReleaseProgram(program);
  }
  if(queue) {
    clReleaseCommandQueue(queue);
  }
  if(context) {
    clReleaseContext(context);
  }
}

