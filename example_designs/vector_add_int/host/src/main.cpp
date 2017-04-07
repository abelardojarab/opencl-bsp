// Copyright (C) 2013-2014 Altera Corporation, San Jose, California, USA. All rights reserved. 
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
// This host program executes a vector addition kernel to perform:
//  C = A + B
// where A, B and C are vectors with N elements.
//
// This host program supports partitioning the problem across multiple OpenCL
// devices if available. If there are M available devices, the problem is
// divided so that each device operates on N/M points. The host program
// assumes that all devices are of the same type (that is, the same binary can
// be used), but the code can be generalized to support different device types
// easily.
//
// Verification is performed against the same computation on the host CPU.
///////////////////////////////////////////////////////////////////////////////////

//#define __CL_ENABLE_EXCEPTIONS
//#define __NO_STD_VECTOR

#include <fstream>
#include <iostream>
#include <iterator>
#include <vector>

#include <cstdlib>
#include <sstream>

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <assert.h>

#include <CL/opencl.h>

#include <CL/cl.hpp>

#include <unistd.h> //for sleep

#define SHOW_PLATFORM
#define KERNEL_FILE "vector_add_int.aocx"

// Problem data.
const unsigned DEFAULT_PROBLEM_SIZE = 1024; // problem size

// Function prototypes
int rand_int();

// Host allocation functions
void *alignedMalloc(size_t size);
void alignedFree(void *ptr);

// Entry point.
int main(int argc, char **argv) {

	cl_int status = CL_SUCCESS;
	unsigned N = DEFAULT_PROBLEM_SIZE; // problem size

	std::vector<cl::Platform> platforms;
	status |= cl::Platform::get(&platforms);

	for (int i = 0; i < argc; ++i)
		if (!std::string("-n").compare(argv[i]))
			N = atoi(argv[++i]);
	
	cl::Platform platform = platforms[0];
#if defined(_DEBUG) | defined(SHOW_PLATFORM)
	std::cout << "Platform vendor: " << platform.getInfo<CL_PLATFORM_VENDOR>(&status) << std::endl;
	std::cout << "Platform name: " << platform.getInfo<CL_PLATFORM_NAME>(&status) << std::endl;
#endif

	cl_device_type device_type = CL_DEVICE_TYPE_ALL;
	std::vector<cl::Device> devices;
	status |= platform.getDevices(device_type, &devices);

	cl::Device device = devices[0];
	//TODO: crauer remove
	//for (int i = 0; i < argc; ++i)
	//	if (!std::string("-d").compare(argv[i]))
	//		device = devices[atoi(argv[++i])];
#if defined(_DEBUG) | defined(SHOW_PLATFORM)
	std::cout << "Device vendor: " << device.getInfo<CL_DEVICE_VENDOR>(&status) << std::endl;
	std::cout << "Device name: " << device.getInfo<CL_DEVICE_NAME>(&status) << std::endl;
	std::cout << std::endl;
#endif

	cl_context_properties context_properties[] = {CL_CONTEXT_PLATFORM, (cl_context_properties) platform(), 0};
	cl::Context context(device_type, context_properties, NULL, NULL, &status);

	cl::Program program;
	std::stringstream program_build_options;
	std::ifstream ifstream;
	
	std::string kernel_file = KERNEL_FILE;
	for (int i = 0; i < argc; ++i)
	{
		if (!std::string("-f").compare(argv[i]))
		{
			kernel_file = argv[++i];
		}
	}
	
	ifstream.open(kernel_file.c_str(), std::ios::in | std::ios::binary);
	std::string string(std::istreambuf_iterator<char>(ifstream), (std::istreambuf_iterator<char>()));
	ifstream.close();
	
	if (kernel_file.rfind(std::string(".cl")) == kernel_file.length() - std::string(".cl").length())
	{
		cl::Program::Sources sources(1, std::make_pair(string.c_str(), string.length() + 1));
		program = cl::Program(context, sources, &status);
		program_build_options << std::string("-w");
		assert(status == CL_SUCCESS);
	}
	else
	{
		cl::Program::Binaries binaries(1, std::make_pair(string.c_str(), string.length() + 1));
		program = cl::Program(context, std::vector<cl::Device>(1, device), binaries, NULL, &status);
		assert(status == CL_SUCCESS);
	}

	status |= program.build(devices, program_build_options.str().c_str());
	assert(status == CL_SUCCESS);

#if defined(_DEBUG)
	std::cout << program.getBuildInfo<CL_PROGRAM_BUILD_OPTIONS>(device, &status) << std::endl;
	std::cout << program.getBuildInfo<CL_PROGRAM_BUILD_LOG>(device, &status) << std::endl;
#endif

	cl::Kernel kernel = cl::Kernel(program, "vector_add_int", &status);
	assert(status == CL_SUCCESS);
	
	int *input_a = (int *)alignedMalloc(sizeof(int)*N);
	int *input_b = (int *)alignedMalloc(sizeof(int)*N);
	int *output = (int *)alignedMalloc(sizeof(int)*N);
	int *output_ref = (int *)alignedMalloc(sizeof(int)*N);
	for(int i = 0; i < N; i++)
	{
		input_a[i] = rand_int();
		input_b[i] = rand_int();
		output_ref[i] = input_a[i] + input_b[i];
		output[i] = 0.0f;
	}
	
	

	//create memory buffers
	cl::Buffer input_a_buffer(context, CL_MEM_READ_ONLY, N * sizeof(*input_a), NULL, &status);
	cl::Buffer input_b_buffer(context, CL_MEM_READ_ONLY, N * sizeof(*input_b), NULL, &status);
	cl::Buffer output_buffer(context, CL_MEM_WRITE_ONLY, N * sizeof(*output), NULL, &status);
	
	cl_command_queue_properties command_queue_properties = CL_QUEUE_PROFILING_ENABLE;
	cl::CommandQueue command_queue(context, device, command_queue_properties, &status);

	status |= command_queue.enqueueWriteBuffer(input_a_buffer, CL_TRUE, 0, N * sizeof(*input_a), input_a);
	status |= command_queue.enqueueWriteBuffer(input_b_buffer, CL_TRUE, 0, N * sizeof(*input_b), input_b);
	status |= command_queue.finish();
	assert(status == CL_SUCCESS);

	cl_int num_items = N;
	{
		cl_uint i = 0;
		status |= kernel.setArg(i++, input_a_buffer);
		status |= kernel.setArg(i++, input_b_buffer);
		status |= kernel.setArg(i++, output_buffer);
		status |= kernel.setArg(i++, num_items);
		assert(status == CL_SUCCESS);
	}

	cl::Event event;
	status |= command_queue.enqueueTask(kernel, NULL, &event);
	status |= command_queue.finish();
	assert(status == CL_SUCCESS);

	std::cout << "input profile: " << (double) ((event.getProfilingInfo<CL_PROFILING_COMMAND_END>() - event.getProfilingInfo<CL_PROFILING_COMMAND_START>())/1000.0/1000.0) << "ms"<< std::endl;

	status |= command_queue.enqueueReadBuffer(output_buffer, CL_TRUE, 0, N*sizeof(*output), output);
	status |= command_queue.finish();
	assert(status == CL_SUCCESS);
	
	// Verify results.
	bool pass = true;
	for(unsigned i = 0; i < N && pass; ++i) {
		if(fabsf(output[i] - output_ref[i]) > 1.0e-5f) {
			printf("Failed verification @ index %d\nOutput: %f\nReference: %f\n",
				i, output[i], output_ref[i]);
			pass = false;
		}
	}
	
	printf("Verification: %s\n", pass ? "PASS" : "FAIL");

	alignedFree(input_a);
	alignedFree(input_b);
	alignedFree(output);
	alignedFree(output_ref);
	
	return 0;
}

// Randomly generate a floating-point number between -10 and 10.
int rand_int() {
	#ifdef NO_RANDOM
		static int s_rand_int_val = 0;
		return s_rand_int_val++;
	#else
		return (int)(float(rand()) / float(RAND_MAX) * 20.0f - 10.0f);
	#endif
}


//////////////////////////////////////////
// Host allocation functions for alignment
//////////////////////////////////////////

// This is the minimum alignment requirement to ensure DMA can be used.
const unsigned AOCL_ALIGNMENT = 64;

#ifdef _WIN32 // Windows
void *alignedMalloc(size_t size) {
	return _aligned_malloc (size, AOCL_ALIGNMENT);
}

void alignedFree(void * ptr) {
	_aligned_free(ptr);
}
#else          // Linux
void *alignedMalloc(size_t size) {
	void *result = NULL;
	posix_memalign (&result, AOCL_ALIGNMENT, size);
	return result;
}

void alignedFree(void * ptr) {
	free (ptr);
}
#endif


