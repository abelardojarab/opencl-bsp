//===- Altera OpenCL Host Utilities -===//
// vim: set ts=2 sw=2 expandtab:
//
// Copyright (c) 2011 Altera Corporation.
// All rights reserved.
//
//===----------------------------------------------------------------------===//
//
// Contains helper functions that support runtime environment creation and
// management by the host program.  Also supports creation of GPU targets
// without their proprietary helper libraries.
//
//===----------------------------------------------------------------------===//

#include "ACLHostUtils.h"
#include <stdlib.h>
#include <stdio.h>
#include <limits.h>
#include <string.h>
#include <assert.h>
#include "aocl_utils.h"

#define LINUX

// Error callback routine - passed to the CL library when creating a
// context.  On GPU this is the only way to see runtime device errors.
void acl_errorCallback(const char* errinfo, const void *private_info, size_t cb, void *user_data) {
  printf("Context error callback: %s\n", errinfo);
}

// Display error string and returned status ID
// TODO: Add a reverse message lookup here
void acl_dump_error(const char *str, cl_int status) {
  printf("%s\n", str);
  printf("Error code: %d\n", status);
}


// Query the available OpenCL platforms.  Currently only handles
// a single platform in the system.
int acl_getPlatform( cl_platform_id *platform ) {
  cl_uint num_platforms;
  int status;
  static cl_platform_id *platforms;

  status = clGetPlatformIDs(0, NULL, &num_platforms);
  if(status != CL_SUCCESS) {
    acl_dump_error("Failed clGetPlatformIDs.", status);
    return 1;
  }

  printf("Num platforms = %i\n", num_platforms);
  if(num_platforms != 1) {
    printf("Found %d platforms!  Not currently handled.\n", num_platforms);
    return 1;
  }

  platforms = new cl_platform_id[num_platforms];
  status = clGetPlatformIDs(num_platforms, platforms, NULL);
  if(status != CL_SUCCESS) {
    acl_dump_error("Failed clGetPlatformIDs.", status);
    return 1;
  }

  // Only support one platform at the moment
  *platform = platforms[0];

  // Cleanup memory
  delete[] platforms;
  return CL_SUCCESS;
}


// Query and display information about an OpenCL platform
int acl_dumpPlatformInfo( cl_platform_id &platform ) {
  int status;
  const unsigned buffer_size = 1024;

  char buf[buffer_size];
  status = clGetPlatformInfo(platform, CL_PLATFORM_VENDOR, buffer_size, buf, NULL);
  if(status != CL_SUCCESS) {
    acl_dump_error("Failed clGetPlatformInfo.", status);
    return 1;
  }
  printf("Platform vendor: %s\n", buf);
  status = clGetPlatformInfo(platform, CL_PLATFORM_NAME, buffer_size, buf, NULL);
  if(status != CL_SUCCESS) {
    acl_dump_error("Failed clGetPlatformInfo.", status);
    return 1;
  }
  printf("Platform name: %s\n", buf);
  status = clGetPlatformInfo(platform, CL_PLATFORM_VERSION, buffer_size, buf, NULL);
  if(status != CL_SUCCESS) {
    acl_dump_error("Failed clGetPlatformInfo.", status);
    return 1;
  }
  printf("Platform version: %s\n", buf);
  return CL_SUCCESS;
}

// Get a valid OpenCL device.  If building for Altera target, looks for an
// accelerator.  Else assumes that targeting GPU - if more than one GPU,
// grabs Tesla board.  If more than one FPGA device, errors out (see
// acl_getFirstDevice())
int acl_getDevice( cl_device_id *device, const cl_platform_id &platform ) {
  return acl_getDevice_internal( device, platform, false );
}

// Same as acl_getDevice, except if multiple devices, grabs the first one
// instead of erroring out
int acl_getFirstDevice( cl_device_id *device, const cl_platform_id &platform ) {
  return acl_getDevice_internal( device, platform, true );
}

// Underlying function to acquire a device
int acl_getDevice_internal( cl_device_id *device, const cl_platform_id &platform, const bool get_first_device ) {
  int status;
  cl_uint num_all_devices, num_devices;
  cl_device_id *device_id_array;
  bool found_valid_device = false;
  const unsigned buffer_size = 1024;

  // Get total number of devices
  status = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, 0, NULL, &num_all_devices);
  if(status != CL_SUCCESS) {
    acl_dump_error("Failed clGetDeviceIDs.", status);
    return 1;
  }

  printf("Found %i devices.\n", num_all_devices);

  // Storage for the detected devices
  if (num_all_devices <= 0) {
    printf("Couldn't find any OpenCL devices.\n");
    return 1;
  }
  device_id_array = new cl_device_id[num_all_devices];

  status = clGetDeviceIDs(platform, CL_DEVICE_TYPE_ALL, num_all_devices, device_id_array, &num_devices);
  if(status != CL_SUCCESS) {
    acl_dump_error("Failed clGetDeviceIDs.", status);
    return 1;
  }

  if(num_devices == 1) {
    *device = device_id_array[0];
    found_valid_device = true;
  } else {

    char str[buffer_size];

    for (unsigned i = 0; i < num_devices; i++) {
      // Get device name
      status = clGetDeviceInfo(device_id_array[i], CL_DEVICE_NAME, buffer_size, str, NULL);
      if(status != CL_SUCCESS) {
        acl_dump_error("Failed clGetDeviceInfo.", status);
        return 1;
      }
      printf("Device[%i] name = %s\n", i, str);

      if (strncmp(str,"Tesla", strlen("Tesla")) == 0) {
        *device = device_id_array[i];
        printf("Chose Tesla device[%i]: %s\n", i, str);
        found_valid_device = true;
        break;
      }
    }

    // Choose the first device.  This allows us to grab a single board even
    // on multi-device test machines
    if ( !found_valid_device && num_devices > 1 && get_first_device ) {
      printf("Found multiple devices and no Tesla GPU present, so selecting first device.\n");
      *device = device_id_array[0];
      found_valid_device = true;
    }

    if (!found_valid_device) {
      printf("Couldn't determine which device to use, so exiting.\n");
      return 1;
    }
  }

  // Cleanup memory
  delete[] device_id_array;
  return CL_SUCCESS;
}


// Create a context with the passed in platform and device
int acl_getContext( cl_context *context, const cl_platform_id &platform, const cl_device_id &device ) {
  int status;

  // Create context
  *context = clCreateContext(0, 1, &device, acl_errorCallback, NULL, &status);
  if(status != CL_SUCCESS) {
    acl_dump_error("Failed clCreateContext.", status);
    return 1;
  }
  return CL_SUCCESS;
}

// Create a command queue on the device in the passed in context
int acl_getQueue( cl_command_queue *queue, const cl_device_id &device, const cl_context &context ) {
  int status;

  // Create command queue
  *queue = clCreateCommandQueue(context, device, CL_QUEUE_PROFILING_ENABLE, &status);
  if(status != CL_SUCCESS) {
    acl_dump_error("Failed clCreateCommandQueue.", status);
    return 1;
  }
  return CL_SUCCESS;
}


int acl_createProgramFromSource_withHeader(cl_program *program, const cl_context &context, const char *f_source_name, const char *f_header_name) {
  int status;
  FILE *infile;
  size_t header_size, source_size;

  // Open header file
  infile = fopen(f_header_name, "rb");
  if (!infile) {
      printf("Couldn't open header file: %s.\n", f_header_name);
      return 1;
  }
  // Get header length
  fseek(infile, 0, SEEK_END);
  header_size = ftell(infile);
  rewind(infile);
  // Read header
  char *header_text = new char[header_size+1];
  assert(header_text != NULL);
  fread(header_text, sizeof(char), header_size, infile);
  header_text[header_size] = '\0';  // Simplify debug output
  fclose(infile);

  // Open source file
  infile = fopen(f_source_name, "rb");
  if (!infile) {
      printf("Couldn't open source file: %s.\n", f_source_name);
      return 1;
  }
  // Get source file length
  fseek(infile, 0, SEEK_END);
  source_size = ftell(infile);
  rewind(infile);
  // Read source file
  char *source_text = new char[source_size+1];
  assert(source_text != NULL);
  fread(source_text, sizeof(char), source_size, infile);
  source_text[source_size] = '\0';  // Simplify debug output
  fclose(infile);

  char *text_sources[2];
  text_sources[0] = header_text;
  text_sources[1] = source_text;

  size_t lengths[2];
  lengths[0] = header_size;
  lengths[1] = source_size;

  *program = clCreateProgramWithSource(context, 2, (const char**)&text_sources, (const size_t *)&lengths, &status);
  if (*program == NULL || status != CL_SUCCESS) {
      acl_dump_error("Failed clCreateProgramWithSource returned NULL!", status);
      return 1;
  }

  // Clean up memory
  delete[] header_text;
  delete[] source_text;

  return CL_SUCCESS;
}




int acl_createProgramFromSource(cl_program *program, const cl_context &context, const char *f_source_name) {
  int status;
  FILE *infile;
  size_t source_size;

  // Open source file
  infile = fopen(f_source_name, "rb");
  if (!infile) {
      printf("Couldn't open source file: %s.\n", f_source_name);
      return 1;
  }
  // Get source file length
  fseek(infile, 0, SEEK_END);
  source_size = ftell(infile);
  rewind(infile);
  // Read source file
  char *source_text = new char[source_size+1];
  assert(source_text != NULL);
  fread(source_text, sizeof(char), source_size, infile);
  source_text[source_size] = '\0';  // Simplify debug output
  fclose(infile);

  *program = clCreateProgramWithSource(context, 1, (const char**)&source_text, (const size_t *)&source_size, &status);
  if (*program == CL_SUCCESS) {
      acl_dump_error("Failed clCreateProgramWithSource returned NULL!", status);
      return 1;
  }

  // Clean up memory
  delete[] source_text;

  return CL_SUCCESS;
}


// Min good alignment for DMA
#define ACL_ALIGNMENT 64

#ifdef LINUX
#include <stdlib.h>
void* acl_aligned_malloc (size_t size) {
  void *result = NULL;
  posix_memalign (&result, ACL_ALIGNMENT, size);
  return result;
}
void acl_aligned_free (void *ptr) {
  free (ptr);
}

#else // WINDOWS

void* acl_aligned_malloc (size_t size) {
  return _aligned_malloc (size, ACL_ALIGNMENT);
}
void acl_aligned_free (void *ptr) {
  _aligned_free (ptr);
}

#endif // LINUX


// OS-independent random number generator
// Re-typed from "Numerical Recipes", 3rd Edition, page 357
unsigned int u, v, w1, w2;
void acl_srand(unsigned int seed) {
  v  = 2244614371U;
  w1 = 521288629U;
  w2 = 362436069U;
  u = seed ^ v;
  v = u;
}


unsigned int acl_rand(void) {
  u = u * 2891336453U+1640531513U;
  v ^= v >> 13; v ^= v << 17; v ^= v >> 5;
  w1 = 33378 * (w1 & 0xffff) + (w1 >> 16);
  w2 = 57225 * (w2 & 0xffff) + (w2 >> 16);
  int x = u ^ (u << 9); x ^= x >> 17; x ^= x << 6;
  int y = w1 ^ (w1 << 17); y ^= y >> 15; y ^= y << 5;
  return (x+v) ^ (y+w2);
}

unsigned int acl_rand_max(void) {
  return UINT_MAX;
}
