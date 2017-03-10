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

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <unistd.h>
// ACL specific includes
#include "CL/opencl.h"
//#include "ACLHostUtils.h"
#include "AOCLUtils/aocl_utils.h"
using namespace aocl_utils;
static const size_t V = 16;
static size_t vectorSize = 1024*1024*4*16;

static const char *kernel_name =  "memcopy";

float bw;

// ACL runtime configuration
static cl_platform_id platform;
static cl_device_id device;
static cl_context context;
static cl_command_queue queue;
static cl_kernel kernel;
static cl_kernel kernel_read;
static cl_kernel kernel_write;

static cl_program program;
static cl_int status;


// input and output vectors
static unsigned *hdatain, *hdataout;

static void initializeVector(unsigned* vector, int size) {
  for (int i = 0; i < size; ++i) {
    vector[i] = 0x32103210;
  }
}
static void initializeVector_seq(unsigned* vector, int size) {
  for (int i = 0; i < size; ++i) {
    vector[i] = i;
  }
}

static void dump_error(const char *str, cl_int status) {
  printf("%s\n", str);
  printf("Error code: %d\n", status);
}

// free the resources allocated during initialization
static void freeResources() {

  if(kernel) 
    clReleaseKernel(kernel);  
  if(kernel_read) 
    clReleaseKernel(kernel_read);  
  if(kernel_write) 
    clReleaseKernel(kernel_write);      
  if(program) 
    clReleaseProgram(program);
  if(queue) 
    clReleaseCommandQueue(queue);
  if(hdatain) 
   clSVMFreeIntelFPGA(context,hdatain);
  if(hdataout) 
   clSVMFreeIntelFPGA(context,hdataout);     
  if(context) 
    clReleaseContext(context);

}






void cleanup() {

}
int main(int argc, char *argv[]) {
  cl_uint num_platforms;
  cl_uint num_devices;
  int lines = vectorSize/V;
  if ( argc >= 2 ) /* argc should be  >2 for correct execution */
  {
      vectorSize = atoi(argv[1])*V;
      lines = atoi(argv[1]);
  }    
    
  if(lines == 0 || lines > 8000000) {
    printf("Invalid Number of cachelines.\n");
    return 1;
  }

  // get the platform ID
  status = clGetPlatformIDs(1, &platform, &num_platforms);
  if(status != CL_SUCCESS) {
    dump_error("Failed clGetPlatformIDs.", status);
    freeResources();
    return 1;
  }
  if(num_platforms != 1) {
    printf("Found %d platforms!\n", num_platforms);
    freeResources();
    return 1;
  }

  // get the device ID
  status = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, 1, &device, &num_devices);
  if(status != CL_SUCCESS) {
    dump_error("Failed clGetDeviceIDs.", status);
    freeResources();
    return 1;
  }
  if(num_devices != 1) {
    printf("Found %d devices!\n", num_devices);
    freeResources();
    return 1;
  }

  // create a context
  context = clCreateContext(0, 1, &device, NULL, NULL, &status);
  if(status != CL_SUCCESS) {
    dump_error("Failed clCreateContext.", status);
    freeResources();
    return 1;
  }
    
  printf("Creating host buffers.\n");
  unsigned int buf_size =  vectorSize <= 0 ? 64 : vectorSize*4;
 
  // allocate and initialize the input vectors
  hdatain = (unsigned int*)clSVMAllocIntelFPGA(context, 0, buf_size, 1024); 
  hdataout = (unsigned int*)clSVMAllocIntelFPGA(context, 0, buf_size, 1024);
  if(!hdatain || !hdataout) {
    dump_error("Failed to allocate buffers.", status);
    freeResources();
    return 1;	
  
  }
  initializeVector_seq(hdatain, vectorSize);
  initializeVector(hdataout, vectorSize);
  // create a command queue
  queue = clCreateCommandQueue(context, device, CL_QUEUE_PROFILING_ENABLE, &status);
  if(status != CL_SUCCESS) {
    dump_error("Failed clCreateCommandQueue.", status);
    freeResources();
    return 1;
  }
  
  // create the program

  cl_int kernel_status;
  
 
  size_t binsize = 0;
  unsigned char * binary_file = loadBinaryFile("bin/mem_bandwidth.aocx", &binsize);
  
  if(!binary_file) {
    dump_error("Failed loadBinaryFile.", status);
    freeResources();
    return 1;
  }
  program = clCreateProgramWithBinary(context, 1, &device, &binsize, (const unsigned char**)&binary_file, &kernel_status, &status);
  if(status != CL_SUCCESS) {
    dump_error("Failed clCreateProgramWithBinary.", status);
    freeResources();
    return 1;
  }
  delete [] binary_file;
  // build the program
  status = clBuildProgram(program, 0, NULL, "", NULL, NULL);
  if(status != CL_SUCCESS) {
    dump_error("Failed clBuildProgram.", status);
    freeResources();
    return 1;
  }
  initializeVector_seq(hdatain, vectorSize);
  initializeVector(hdataout, vectorSize);
  int failures = 0;
  int successes = 0;
  printf("Creating memcopy kernel\n");
  {
    // create the kernel
    kernel = clCreateKernel(program, "memcopy", &status);
    
    if(status != CL_SUCCESS) {
      dump_error("Failed clCreateKernel.", status);
      freeResources();
      return 1;
    }

    // set the arguments
    status = clSetKernelArgSVMPointerIntelFPGA(kernel, 0, (void*)hdatain);
    if(status != CL_SUCCESS) {
      dump_error("Failed set arg 0.", status);
      return 1;
    }
    status = clSetKernelArgSVMPointerIntelFPGA(kernel, 1, (void*)hdataout);
    if(status != CL_SUCCESS) {
      dump_error("Failed Set arg 1.", status);
      freeResources();
      return 1;
    }

    cl_int arg_3 = lines;
    status = clSetKernelArg(kernel, 2, sizeof(cl_int), &(arg_3));
    if(status != CL_SUCCESS) {
      dump_error("Failed Set arg 2.", status);
      freeResources();
      return 1;
    }

    printf("Launching the kernel...\n");

    status = clEnqueueSVMMap(queue, CL_TRUE, CL_MAP_READ | CL_MAP_WRITE, 
       (void *)hdatain,buf_size, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMMap", status);
      freeResources();
      return 1;
    }
    status = clEnqueueSVMMap(queue, CL_TRUE,  CL_MAP_READ | CL_MAP_WRITE, 
       (void *)hdataout, buf_size, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMMap", status);
      freeResources();
      return 1;
    }	
	
	
	
    const double start_time = getCurrentTimestamp();
    status = clEnqueueTask(queue, kernel, 0, NULL, NULL);
    if (status != CL_SUCCESS) {
      dump_error("Failed to launch kernel.", status);
      freeResources();
      return 1;
    }
	
    status = clEnqueueSVMUnmap(queue, (void *)hdatain, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMUnmap", status);
      freeResources();
      return 1;
    }
    status = clEnqueueSVMUnmap(queue, (void *)hdataout, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMUnmap", status);
      freeResources();
      return 1;
    }	
	
	
	
    clFinish(queue);
    const double end_time = getCurrentTimestamp();

    // Wall-clock time taken.
    float time = (end_time - start_time);

    bw = vectorSize / (time * 1000000.0f) * sizeof(unsigned int) * 2;
    printf("Processed %d unsigned ints in %.4f us\n", vectorSize, time*1000000.0f);
    printf("Read/Write Bandwidth = %.0f MB/s\n", bw);
    printf("Kernel execution is complete.\n");

    // Verify the output
    for(size_t i = 0; i < vectorSize; i++) {
      if(hdatain[i] != hdataout[i]) {
        if (failures < 1024) printf("Verification_failure %d: %d != %d, diff %d, line %d\n",i, hdatain[i], hdataout[i], hdatain[i]-hdataout[i],i*4/128);
        failures++;
      }else{
        successes++;
      }
    }   
  }
  printf("Creating memcopy kernel\n");
  {
    // create the kernel
    kernel = clCreateKernel(program, "memcopy", &status);
    
    if(status != CL_SUCCESS) {
      dump_error("Failed clCreateKernel.", status);
      freeResources();
      return 1;
    }

    // set the arguments
    status = clSetKernelArgSVMPointerIntelFPGA(kernel, 0, (void*)hdatain);
    if(status != CL_SUCCESS) {
      dump_error("Failed set arg 0.", status);
      return 1;
    }
    status = clSetKernelArgSVMPointerIntelFPGA(kernel, 1, (void*)hdataout);
    if(status != CL_SUCCESS) {
      dump_error("Failed Set arg 1.", status);
      freeResources();
      return 1;
    }

    cl_int arg_3 = lines;
    status = clSetKernelArg(kernel, 2, sizeof(cl_int), &(arg_3));
    if(status != CL_SUCCESS) {
      dump_error("Failed Set arg 2.", status);
      freeResources();
      return 1;
    }

    printf("Launching the kernel...\n");
    status = clEnqueueSVMMap(queue, CL_TRUE, CL_MAP_READ | CL_MAP_WRITE, 
       (void *)hdatain,buf_size, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMMap", status);
      freeResources();
      return 1;
    }
    status = clEnqueueSVMMap(queue, CL_TRUE,  CL_MAP_READ | CL_MAP_WRITE, 
       (void *)hdataout, buf_size, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMMap", status);
      freeResources();
      return 1;
    }	
	

    
    const double start_time = getCurrentTimestamp();
    status = clEnqueueTask(queue, kernel, 0, NULL, NULL);
    if (status != CL_SUCCESS) {
      dump_error("Failed to launch kernel.", status);
      freeResources();
      return 1;
    }
	
		
	status = clEnqueueSVMUnmap(queue, (void *)hdatain, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMUnmap", status);
      freeResources();
      return 1;
    }
    status = clEnqueueSVMUnmap(queue, (void *)hdataout, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMUnmap", status);
      freeResources();
      return 1;
    }	
	
	
    clFinish(queue);
    const double end_time = getCurrentTimestamp();

    // Wall-clock time taken.
    float time = (end_time - start_time);

    bw = vectorSize / (time * 1000000.0f) * sizeof(unsigned int) * 2;
    printf("Processed %d unsigned ints in %.4f us\n", vectorSize, time*1000000.0f);
    printf("Read/Write Bandwidth = %.0f MB/s\n", bw);
    printf("Kernel execution is complete.\n");

    // Verify the output
    for(size_t i = 0; i < vectorSize; i++) {
      if(hdatain[i] != hdataout[i]) {
        if (failures < 1024) printf("Verification_failure %d: %d != %d, diff %d, line %d\n",i, hdatain[i], hdataout[i], hdatain[i]-hdataout[i],i*4/128);
        failures++;
      }else{
        successes++;
      }
    }   
  }

  printf("Creating memread kernel\n");
  {
    kernel_read = clCreateKernel(program, "memread", &status);
    if(status != CL_SUCCESS) {
      dump_error("Failed clCreateKernel.", status);
      freeResources();
      return 1;
    }

    // set the arguments
    status = clSetKernelArgSVMPointerIntelFPGA(kernel_read, 0, (void*)hdatain);
    if(status != CL_SUCCESS) {
      dump_error("Failed set arg 0.", status);
      return 1;
    }
    status = clSetKernelArgSVMPointerIntelFPGA(kernel_read, 1, (void*)hdataout);
    if(status != CL_SUCCESS) {
      dump_error("Failed Set arg 1.", status);
      freeResources();
      return 1;
    }

    cl_int arg_3 = lines;
    status = clSetKernelArg(kernel_read, 2, sizeof(cl_int), &(arg_3));
    if(status != CL_SUCCESS) {
      dump_error("Failed Set arg 2.", status);
      freeResources();
      return 1;
    }
    printf("Launching the kernel...\n");
    status = clEnqueueSVMMap(queue, CL_TRUE, CL_MAP_READ | CL_MAP_WRITE, 
       (void *)hdatain,buf_size, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMMap", status);
      freeResources();
      return 1;
    }
    status = clEnqueueSVMMap(queue, CL_TRUE,  CL_MAP_READ | CL_MAP_WRITE, 
       (void *)hdataout, buf_size, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMMap", status);
      freeResources();
      return 1;
    }	
	
    // launch kernel
    const double start_time = getCurrentTimestamp();
    status = clEnqueueTask(queue, kernel_read, 0, NULL, NULL);
    if (status != CL_SUCCESS) {
      dump_error("Failed to launch kernel.", status);
      freeResources();
      return 1;
    }
	

	status = clEnqueueSVMUnmap(queue, (void *)hdatain, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMUnmap", status);
      freeResources();
      return 1;
    }
    status = clEnqueueSVMUnmap(queue, (void *)hdataout, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMUnmap", status);
      freeResources();
      return 1;
    }	
	
	

	
    clFinish(queue);
    const double end_time = getCurrentTimestamp();

    // Wall-clock time taken.
    float time = (end_time - start_time);

    bw = vectorSize  / (time * 1000000.0f) * sizeof(unsigned int);
    printf("Processed %d unsigned ints in %.4f us\n", vectorSize, time*1000000.0f);
    printf("Read Bandwidth = %.0f MB/s\n", bw);
    printf("Kernel execution is complete.\n");
  
  }

  printf("Creating memwrite kernel\n");
  {
    kernel_write = clCreateKernel(program, "memwrite", &status);
  
    if(status != CL_SUCCESS) {
      dump_error("Failed clCreateKernel.", status);
      freeResources();
      return 1;
    }

    // set the arguments
    status = clSetKernelArgSVMPointerIntelFPGA(kernel_write, 0, (void*)hdatain);
    if(status != CL_SUCCESS) {
      dump_error("Failed set arg 0.", status);
      return 1;
    }
    status = clSetKernelArgSVMPointerIntelFPGA(kernel_write, 1, (void*)hdataout);
    if(status != CL_SUCCESS) {
      dump_error("Failed Set arg 1.", status);
      freeResources();
      return 1;
    }

    cl_int arg_3 = lines;
    status = clSetKernelArg(kernel_write, 2, sizeof(cl_int), &(arg_3));
    if(status != CL_SUCCESS) {
      dump_error("Failed Set arg 2.", status);
      freeResources();
      return 1;
    }
    status = clEnqueueSVMMap(queue, CL_TRUE, CL_MAP_READ | CL_MAP_WRITE, 
       (void *)hdatain,buf_size, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMMap", status);
      freeResources();
      return 1;
    }
    status = clEnqueueSVMMap(queue, CL_TRUE,  CL_MAP_READ | CL_MAP_WRITE, 
       (void *)hdataout, buf_size, 0, NULL, NULL); 
    if(status != CL_SUCCESS) {
      dump_error("Failed clEnqueueSVMMap", status);
      freeResources();
      return 1;
    }	
	
	
	
	printf("Launching the kernel...\n");
    
    const double start_time = getCurrentTimestamp();
    status = clEnqueueTask(queue, kernel_write, 0, NULL, NULL);
    if (status != CL_SUCCESS) {
      dump_error("Failed to launch kernel.", status);
      freeResources();
      return 1;
    }
    clFinish(queue);
    const double end_time = getCurrentTimestamp();

    // Wall-clock time taken.
    float time = (end_time - start_time);

    bw = vectorSize  / (time * 1000000.0f) * sizeof(unsigned int);
    printf("Processed %d unsigned ints in %.4f us\n", vectorSize, time*1000000.0f);
    printf("Write Bandwidth = %.0f MB/s\n", bw);
    printf("Kernel execution is complete.\n");

  }
  
  if(failures == 0) {
    printf("Verification finished.\n");
  } else {
    printf("FAILURES %d - successes - %d\n", failures, successes);
  }
  
  freeResources();

  return 0;
}



