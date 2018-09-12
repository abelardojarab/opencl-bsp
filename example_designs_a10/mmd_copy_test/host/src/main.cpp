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
static int max_mem_buf_test_size = DEVICE_BUFFER_SIZE;

// Function prototypes
bool init();
void cleanup();
static void check_mmd_copy();

// Entry point.
int main(int argc, char **argv) {
  cl_int status;

  if(argc == 2) {
  	  max_mem_buf_test_size = atoi(argv[1]);
  }

  assert(max_mem_buf_test_size <= DEVICE_BUFFER_SIZE);
  assert(max_mem_buf_test_size >= (MIN_DEVICE_BUFFER_SIZE*2));

  if(!init()) {
    return -1;
  }

  // Set the kernel argument (argument 0)
  status = clSetKernelArg(kernel, 0, sizeof(cl_int), (void*)&thread_id_to_output);
  checkError(status, "Failed to set kernel arg 0");

  printf("\nKernel initialization is complete.\n");
  printf("Launching the kernel...\n\n");

  // Configure work set over which the kernel will execute
  size_t wgSize[3] = {work_group_size, 1, 1};
  size_t gSize[3] = {work_group_size, 1, 1};

  // Launch the kernel
  status = clEnqueueNDRangeKernel(queue, kernel, 1, NULL, gSize, wgSize, 0, NULL, NULL);
  checkError(status, "Failed to launch kernel");

  // Wait for command queue to complete pending events
  status = clFinish(queue);
  checkError(status, "Failed to finish");

  printf("\nKernel execution is complete.\n");

  check_mmd_copy();

  // Free the resources allocated
  cleanup();

  return 0;
}

static void check_mmd_copy() {
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
  memset(test_buffer, 0, DEVICE_BUFFER_SIZE);
  status = clEnqueueWriteBuffer(queue, device_a_buf, CL_TRUE,
        0, max_mem_buf_test_size, test_buffer, 0, NULL, NULL);
  checkError(status, "Failed to transfer buffer A");

  status = clEnqueueCopyBuffer(queue, device_a_buf, device_b_buf,
        0, 0, max_mem_buf_test_size, 0, NULL, NULL);
  checkError(status, "Failed to transfer from buffer A to B");

  // Read buffer B to verify
  status = clEnqueueReadBuffer(queue, device_b_buf, CL_TRUE,
        0, max_mem_buf_test_size, verify_buffer, 0, NULL, NULL);
  checkError(status, "Failed to transfer buffer B");

  // Wait for command queue to complete pending events
  status = clFinish(queue);
  checkError(status, "Failed to finish");

  if(memcmp(test_buffer, verify_buffer, max_mem_buf_test_size) != 0)
  {
  	  printf("ERROR: buffer check failed!\n");
  	  exit(1);
  }

  ///////////////////////////////////////////////////
  //test 2
  //test sequential pattern
  for(int i = 0; i < max_mem_buf_test_size; i++) {
  	  test_buffer[i] = i;
  }
  status = clEnqueueWriteBuffer(queue, device_a_buf, CL_TRUE,
        0, max_mem_buf_test_size, test_buffer, 0, NULL, NULL);
  checkError(status, "Failed to transfer buffer A");

  status = clEnqueueCopyBuffer(queue, device_a_buf, device_b_buf,
        0, 0, max_mem_buf_test_size, 0, NULL, NULL);
  checkError(status, "Failed to transfer from buffer A to B");

  // Read buffer B to verify
  status = clEnqueueReadBuffer(queue, device_b_buf, CL_TRUE,
        0, max_mem_buf_test_size, verify_buffer, 0, NULL, NULL);
  checkError(status, "Failed to transfer buffer B");

  // Wait for command queue to complete pending events
  status = clFinish(queue);
  checkError(status, "Failed to finish");

  if(memcmp(test_buffer, verify_buffer, max_mem_buf_test_size) != 0)
  {
  	  printf("ERROR: buffer check failed!\n");
  	  exit(1);
  }

  ///////////////////////////////////////////////////
  //test 3
  //test random copies
  int num_transfers = max_mem_buf_test_size/MIN_DEVICE_BUFFER_SIZE;
  memcpy(verify_buffer, test_buffer, max_mem_buf_test_size);
  for(int i = 0; i < num_transfers; i++) {
  	  size_t src_offset = rand() % (max_mem_buf_test_size - MIN_DEVICE_BUFFER_SIZE - 1);
  	  size_t dst_offset = rand() % (max_mem_buf_test_size - MIN_DEVICE_BUFFER_SIZE - 1);
  	  size_t size = (rand() % MIN_DEVICE_BUFFER_SIZE) + 1;

  	  status = clEnqueueCopyBuffer(queue, device_a_buf, device_b_buf,
          src_offset, dst_offset, size, 0, NULL, NULL);
      memcpy(test_buffer+dst_offset, verify_buffer+src_offset, size);
      checkError(status, "Failed to transfer from buffer A to B");
  }

  // Read buffer B to verify
  status = clEnqueueReadBuffer(queue, device_b_buf, CL_TRUE,
        0, max_mem_buf_test_size, verify_buffer, 0, NULL, NULL);
  checkError(status, "Failed to transfer buffer B");

  // Wait for command queue to complete pending events
  status = clFinish(queue);
  checkError(status, "Failed to finish");

  if(memcmp(test_buffer, verify_buffer, max_mem_buf_test_size) != 0)
  {
  	  printf("ERROR: buffer check failed!\n");
  	  exit(1);
  }

  ///////////////////////////////////////////////////
  //cleanup

  //free test buffer
  if(test_buffer)
	 free(test_buffer);

  if(verify_buffer)
	 free(verify_buffer);

  printf("aocl_mmd_copy test complete.\n");
}

/////// HELPER FUNCTIONS ///////

bool init() {
  cl_int status;

  if(!setCwdToExeDir()) {
    return false;
  }

  // Get the OpenCL platform.
  platform = findPlatform("fpga");
  if(platform == NULL) {
    printf("ERROR: Unable to find Altera OpenCL platform.\n");
    return false;
  }

  // User-visible output - Platform information
  {
    char char_buffer[STRING_BUFFER_LEN];
    printf("Querying platform for info:\n");
    printf("==========================\n");
    clGetPlatformInfo(platform, CL_PLATFORM_NAME, STRING_BUFFER_LEN, char_buffer, NULL);
    printf("%-40s = %s\n", "CL_PLATFORM_NAME", char_buffer);
    clGetPlatformInfo(platform, CL_PLATFORM_VENDOR, STRING_BUFFER_LEN, char_buffer, NULL);
    printf("%-40s = %s\n", "CL_PLATFORM_VENDOR ", char_buffer);
    clGetPlatformInfo(platform, CL_PLATFORM_VERSION, STRING_BUFFER_LEN, char_buffer, NULL);
    printf("%-40s = %s\n\n", "CL_PLATFORM_VERSION ", char_buffer);
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
  printf("Using AOCX: %s\n", binary_file.c_str());
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

