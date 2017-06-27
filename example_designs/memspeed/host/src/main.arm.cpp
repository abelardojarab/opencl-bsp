#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>

// ACL specific includes
#include "CL/opencl.h"
#include "ACLHostUtils.h"
#include "timer.h"

static const size_t V = 8;
static const size_t vectorSize = 1024 * 1024 * 4;

static const char *kernel_name[] = {"mem_stream",
                            "mem_writestream",
                            "mem_readstream_v16"
                            };

static const size_t NUM_KERNELS = sizeof(kernel_name)/sizeof(kernel_name[0]);
float bw[NUM_KERNELS];

// ACL runtime configuration
static cl_platform_id platform;
static cl_device_id device;
static cl_context context;
static cl_command_queue queue;
static cl_kernel kernel[NUM_KERNELS];
static cl_program program;
static cl_int status;

static cl_mem ddatain, ddataout;

// input and output vectors
static unsigned *hdatain, *hdataout;

static void initializeVector(unsigned* vector, int size) {
  for (int i = 0; i < size; ++i) {
    vector[i] = rand();
  }
}

static void dump_error(const char *str, cl_int status) {
  printf("%s\n", str);
  printf("Error code: %d\n", status);
}

// free the resources allocated during initialization
static void freeResources() {
  for (int k = 0; k < NUM_KERNELS; k++)
    if(kernel[k]) 
      clReleaseKernel(kernel[k]);  
  if(program) 
    clReleaseProgram(program);
  if(queue) 
    clReleaseCommandQueue(queue);
  if(context) 
    clReleaseContext(context);
  if(ddatain) 
    clReleaseMemObject(ddatain);
  if(ddataout) 
    clReleaseMemObject(ddataout);
}

int main() {
  cl_uint num_platforms;
  cl_uint num_devices;

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

  // create a command queue
  queue = clCreateCommandQueue(context, device, CL_QUEUE_PROFILING_ENABLE, &status);
  if(status != CL_SUCCESS) {
    dump_error("Failed clCreateCommandQueue.", status);
    freeResources();
    return 1;
  }

  // create the input buffer
  size_t buf_size = sizeof(unsigned) * vectorSize;
  ddatain = clCreateBuffer(context, CL_MEM_ALLOC_HOST_PTR, buf_size, NULL, &status);
  if(status != CL_SUCCESS) {
    dump_error("Failed clCreateBuffer.", status);
    freeResources();
    return 1;
  }

  // create the input buffer
  ddataout = clCreateBuffer(context, CL_MEM_ALLOC_HOST_PTR, buf_size, NULL, &status);
  if(status != CL_SUCCESS) {
    dump_error("Failed clCreateBuffer.", status);
    freeResources();
    return 1;
  }
  hdatain  = (unsigned*)clEnqueueMapBuffer (queue, ddatain, CL_TRUE, CL_MAP_READ|CL_MAP_WRITE, 0, buf_size, 0, NULL, NULL, &status);
  hdataout = (unsigned*)clEnqueueMapBuffer (queue, ddataout, CL_TRUE, CL_MAP_READ|CL_MAP_WRITE, 0, buf_size, 0, NULL, NULL, &status);

  initializeVector(hdatain, vectorSize);
  initializeVector(hdataout, vectorSize);


  // create the program
  size_t kernel_name_length = strlen(kernel_name[0]);
  cl_int kernel_status;
  program = clCreateProgramWithBinary(context, 1, &device, &kernel_name_length, (const unsigned char**)&kernel_name[0], &kernel_status, &status);
  if(status != CL_SUCCESS) {
    dump_error("Failed clCreateProgramWithBinary.", status);
    freeResources();
    return 1;
  }

  // build the program
  status = clBuildProgram(program, 0, NULL, "", NULL, NULL);
  if(status != CL_SUCCESS) {
    dump_error("Failed clBuildProgram.", status);
    freeResources();
    return 1;
  }

  for ( int k = 0; k < NUM_KERNELS; k++)
  {

    printf("Creating kernel %d (%s)\n",k,kernel_name[k]);

    // create the kernel
    kernel[k] = clCreateKernel(program, kernel_name[k], &status);
    if(status != CL_SUCCESS) {
      dump_error("Failed clCreateKernel.", status);
      freeResources();
      return 1;
    }

    // set the arguments
    status = clSetKernelArg(kernel[k], 0, sizeof(cl_mem), (void*)&ddatain);
    if(status != CL_SUCCESS) {
      dump_error("Failed set arg 0.", status);
      return 1;
    }
    status = clSetKernelArg(kernel[k], 1, sizeof(cl_mem), (void*)&ddataout);
    if(status != CL_SUCCESS) {
      dump_error("Failed Set arg 1.", status);
      freeResources();
      return 1;
    }

    if (strcmp(kernel_name[k], "mem_readstream_v16") == 0 ||
        strcmp(kernel_name[k], "mem_random") == 0 ||
        strcmp(kernel_name[k], "mem_random_read") == 0 ||
        strcmp(kernel_name[k], "mem_writeack_burstcoalesced") == 0) { // These kernels have a different interface
      status = clSetKernelArg(kernel[k], 2, sizeof(cl_mem), (void*)&ddataout);
    } else {
      unsigned int arg=1;
      status = clSetKernelArg(kernel[k], 2, sizeof(unsigned int), &arg);
      unsigned int arg2=0;
      status |= clSetKernelArg(kernel[k], 3, sizeof(unsigned int), &arg2);
    }
    if(status != CL_SUCCESS) {
      dump_error("Failed Set arg 2 and/or 3.", status);
      freeResources();
      return 1;
    }

    printf("Launching the kernel...\n");

    clFinish(queue);

    // launch kernel
    //size_t gsize = vectorSize / V;
    size_t manual_vector;
    size_t gsize;
    size_t lsize;
    if (strcmp(kernel_name[k], "mem_readstream_v16") == 0 ||
        strcmp(kernel_name[k], "mem_random") == 0 ||
        strcmp(kernel_name[k], "mem_random_read") == 0 ||
        strcmp(kernel_name[k], "mem_writeack_burstcoalesced") == 0) { // These kernels have a different interface
      manual_vector = V ;
      gsize = vectorSize / manual_vector;
      lsize = 8;
    }
    else
    {
      manual_vector = 1;
      gsize = vectorSize / manual_vector;
      lsize = gsize;
    }
    Timer t;

    t.start();
    status = clEnqueueNDRangeKernel(queue, kernel[k], 1, NULL, &gsize, &lsize, 0, NULL, NULL);
    if (status != CL_SUCCESS) {
      dump_error("Failed to launch kernel.", status);
      freeResources();
      return 1;
    }
    clFinish(queue);
    t.stop();
    float time = t.get_time_s();
    bw[k] = gsize * manual_vector  / (time * 1000000.0f) * sizeof(unsigned int) * 2;
    printf("Processed %d unsigned ints in %.4f us\n", gsize, time*1000000.0f);
    printf("Bandwidth = %.0f MB/s\n", bw[k]);

    printf("Kernel execution is complete.\n");

    // verify the output
    for(int i = 0; i < vectorSize; i++) {
      if(hdatain[i] != hdataout[i]) {
        printf("Verification_failure %d: %d != %d\n",
            i, hdatain[i], hdataout[i]);
        return 1;
      }
    }
    printf("Verification succeeded.\n");
  }
  
  printf("REG_SUCCESS\n");

  // Ignore last kernel - the kclk kernel is only there to make sure the
  // kernel even could saturate memory bandwidth

  float avg_bw=0.0;
  for ( int k = 0; k < NUM_KERNELS-1; k++)
  {
    printf("  %.0f MB/s %s\n",bw[k],kernel_name[k]);
    avg_bw += bw[k];
  }
  avg_bw /= NUM_KERNELS-1;

  printf("\nThroughput = %.0f MB/s\n",avg_bw);

  // free the resources allocated
  freeResources();

  return 0;
}

