// Copyright (C) 2013-2016 Altera Corporation, San Jose, California, USA. All rights reserved.
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
#include <stdlib.h>
#include <string.h>
#include <string>
#include "AOCLUtils/aocl_utils.h"
#include <CL/opencl.h>
#include "jpeg.h"

#ifndef MB
#define MB(x)     ((x) * 1024 * 1024)
#endif // MB
// Images are processed in batches. The batches are streamed to overlap
// computation and memory access
#define STREAMS 4 // number of parallel streams
#define MAX_DATA_SIZE (STREAMS * 100000000) // memory required for a batch

using namespace aocl_utils;

cl_platform_id platform;
cl_device_id device;
cl_context context;
cl_command_queue queue[2 * COPIES + 4];
#if USE_SVM_API == 0
cl_mem d_inData[STREAMS], d_finalRGB[STREAMS];
#endif /* USE_SVM_API == 0 */
unsigned char *myrgb[STREAMS], *myentropy[STREAMS];
cl_program program;

// Kernels and their associated events
cl_kernel kernel_dct, kernel_arb;
cl_kernel kernel_reader[COPIES];
cl_kernel kernel_huffman[COPIES];
cl_event transfer_event[STREAMS], dct_event[STREAMS], finish_event[STREAMS];

// Data structures required to orchestrate image batches
int runs = 2400, batch = 24;
unsigned char *image;
unsigned int totalOffset = 0;
unsigned int outDataSize = 0;

// Data structures maintained only during parsing of image headers

int length;
const unsigned char *pos;
unsigned char *rgb;
int size;
int width, height;
bool downsample;

bool skipBytes(int count) {
  pos += count;
  size -= count;
  length -= count;
  return size >= 0;
}

bool readLength() {
  if (size < 2) return false;
  length = (pos[0] << 8) | pos[1];
  if (length > size) return false;
  return skipBytes(2);
}

// Parsing headers
bool startOfFrame() {
  readLength();
  if (length < 15) return false;
  if (pos[0] != 8) return false;
  height = (pos[1] << 8) | pos[2];
  width = (pos[3] << 8) | pos[4];
  if (pos[5] != 3) {
    printf("Unsupported JPEG type\n");
    return false; // supports only 3 component color JPEGS
  }
  skipBytes(6);
  for (int i = 0;  i < 3;  ++i) {
    int ssx, ssy;
    if (!(ssx = pos[1] >> 4)) return false;
    if (ssx & (ssx - 1)) return false;
    if (!(ssy = pos[1] & 15)) return false;
    if (ssy & (ssy - 1)) return false;
    if (ssx != ssy) {
      printf("Unsupported JPEG type\n");
      return false;
    }
    if (ssx != 1 && ssx != 2) {
      printf("Unsupported JPEG type\n");
      return false;
    }
    if (i == 0) downsample = ssx > 1;
    skipBytes(3);
  }
  rgb = (unsigned char *)malloc(width * height * 3);
  if (!rgb) return false;
  return skipBytes(length);
}

// The device requires the Huffman tables in a special format
// This function converts the Huffman tables in this format
bool computeDHT() {
  int codelen, currcnt, spread, i;
  static unsigned char counts[16];
  readLength();
  while (length >= 17) {
    i = pos[0];
    if (i & 0xEC) return false;
    if (i & 0x02) return false;
    i = (i | (i >> 3)) & 3;  // combined DC/AC + tableid value
    for (codelen = 1;  codelen <= 16;  ++codelen) {
      counts[codelen - 1] = pos[codelen];
    }
    skipBytes(17);
    spread = 65536;
    int counter = 0;
    for (codelen = 1;  codelen <= 16;  ++codelen) {
      spread >>= 1;
      currcnt = counts[codelen - 1];
      if (currcnt) {
        if (length < currcnt) return false;
      }
      unsigned short *dht = (unsigned short *)image + 4096 * i;
      unsigned short *dht2 = (unsigned short *)image + 1024 * i;
      for (int j = 0;  j < currcnt;  ++j) {
        unsigned char code = pos[j];
        for (int k = spread;  k > 0;  k-=codelen > 11 ? 1 : 32) {
          unsigned short data = (codelen + (code & 0x0F)) | (codelen << 6) | ((code & 0xF0) << 8) | (codelen > 11 ? 0x800 : 0);
          dht[2 * (counter >> 5) + 1] = data;
          if (codelen > 11) {
            data = (codelen + (code & 0x0F)) | (codelen << 6) | ((code & 0xF0) << 8);
            dht2[2 * (counter % 512)] = data;
          }
          if (codelen > 11) counter++; else counter+=32;
        }
      }
      if (currcnt) skipBytes(currcnt);
    }
  }
  return !length;
}

// Extracts the quantifier tables from the image headers
bool setDQT() {
  int i;
  readLength();
  while (length >= 65) {
    i = pos[0];
    if (i & 0xFC) return false;
    unsigned short *dqt = (unsigned short *)image + 4096;
    for (int j = 0;  j < 64;  ++j) {
      dqt[2 * (j + i * 64)] = pos[j+1];
    }
    skipBytes(65);
  }
  return !length;
}

int ceil(int x, int y) {
   return ((x + y - 1) / y) * y;
}

// Extracts the scan data from the input image - this does not decompress the
// data
bool extractScan() {
  readLength();
  if (length < 10) return false;
  if (pos[0] != 3) return false;
  skipBytes(1);
  for (int i = 0;  i < 3;  ++i) {
    if (pos[1] & 0xEE) return false;
    skipBytes(2);
  }
  if (pos[0] || (pos[1] != 63) || pos[2]) return false;
  skipBytes(length);
  unsigned short ds = downsample ? 1 : 0;
  unsigned short *config = (unsigned short *)image + 8192;
  config[0] = width;
  config[2] = ds;
  config[4] = totalOffset;
  config[6] = totalOffset >> 16;

  outDataSize = 3 * (downsample ? ceil(width, 16) * ceil(height,16) : ceil(width, 16) * ceil(height, 16));
  totalOffset += outDataSize;

  int sz = size;

  while (pos[sz-1] != 0xD9 || pos[sz - 2] != 0xFF) sz--;
  memcpy(image + 4 * 4 * 2048, pos, sz);
  while ((sz % 4) != 2) {
    image[4 * 4 * 2048 + sz - 1] = 0xFF;
    image[4 * 4 * 2048 + sz] = 0xD9;
    sz++;
  }
  image += 4 * (4 * 2048 + ((sz + 3) / 4)); // round size to cover all 4 bytes
  return true;
}

bool skipBytesMarker() {
  if (!readLength()) return false;
  skipBytes(length);
  return true;
}

// Top-level decoding of a single image
bool decode(const void* jpeg, const int sz) {
  pos = (const unsigned char*) jpeg;
  size = sz & 0x7FFFFFFF;
  if (size < 2) return false;
  if ((pos[0] ^ 0xFF) | (pos[1] ^ 0xD8)) {
    printf("Header failed\n");
    return false;
  }
  skipBytes(2);
  bool scanned = false;
  while (!scanned) {
    if ((size < 2) || (pos[0] != 0xFF)) {
      printf("Skip failed\n");
      return false;
    }
    skipBytes(2);
    switch (pos[-1]) {
      case 0xC0: if (!startOfFrame()) {
               printf("Decode SOF failed\n");
               return false;
             }
             break;
      case 0xC4: if (!computeDHT()) {
               printf("Decode DHT failed\n");
               return false;
             }
             break;
      case 0xDB: if (!setDQT()) {
               printf("Decode DQT failed\n");
               return false;
             }
             break;
      case 0xDA: if (!extractScan()) {
               printf("Decode Scan failed\n");
               return false;
             }
             scanned = true;
             break;
      default:
             if (((pos[-1] & 0xF0) == 0xE0) || (pos[-1] == 0xDD)) {
               if (!skipBytesMarker()) return false;
             } else {
               printf("Unidentified section %d\n", pos[-1]);
               return false;
             }
    }
  }
  return true;
}

bool parseWidthHeight(const void* jpeg, const int sz) {
	pos = (const unsigned char*)jpeg;
	size = sz & 0x7FFFFFFF;
	if (size < 2) return false;
	if ((pos[0] ^ 0xFF) | (pos[1] ^ 0xD8)) {
		printf("Header failed\n");
		return false;
	}
	for (int i = 2; i < size - 1; i++) {
		if (pos[i] == 0xFF && pos[i + 1] == 0xC0) {
			length = (pos[i + 2] << 8) | pos[i + 3];
			if (length < 9) return false;
			if (pos[i + 4] != 8) return false;
			height = (pos[i + 5] << 8) | pos[i + 6];
			width = (pos[i + 7] << 8) | pos[i + 8];
		}
	}
	return true;
}

cl_int clInit(void)
{
  cl_int status = CL_SUCCESS;

  // Get the OpenCL platform.
  platform = findPlatform("Intel(R) FPGA");
  if(platform == NULL) {
    printf("ERROR: Unable to find Intel(R) FPGA OpenCL platform\n");
    return false;
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

  // Create the command queues
  for (int i = 0; i < 2 * COPIES + 4; i++) {
    queue[i] = clCreateCommandQueue(context, device, CL_QUEUE_PROFILING_ENABLE, &status);
    checkError(status, "Failed to create command queue");
  }

  std::string binary_file = getBoardBinaryFile("jpeg_decoder", device);
  printf("Using AOCX: %s\n\n", binary_file.c_str());
  program = createProgramFromBinary(context, binary_file.c_str(), &device, 1);

  // Build the program that was just created.
  status = clBuildProgram(program, 0, NULL, "", NULL, NULL);
  checkError(status, "Failed to build program");

  // Create the kernels
  for (int i = 0; i < COPIES; i++) {
    char reader_name[100], huffman_name[100];
    sprintf(reader_name, "read_entropy%d", i);
    sprintf(huffman_name, "huffmanDecoder%d", i);
    kernel_reader[i] = clCreateKernel(program, reader_name, &status);
    if (status != CL_SUCCESS) printf("%s\n", reader_name);
    kernel_huffman[i] = clCreateKernel(program, huffman_name, &status);
    if (status != CL_SUCCESS) printf("%s\n", huffman_name);
  }
  kernel_dct = clCreateKernel(program, "DCTandRGB", &status);
  kernel_arb = clCreateKernel(program, "Arbiter", &status);
  if (status != CL_SUCCESS) printf("Kernel error\n");
  return status;
}

void cleanup(void)
{
  cl_int status = CL_SUCCESS;

  for (int i = 0; i < COPIES; i++) {
    status = clReleaseKernel(kernel_reader[i]);
    status = clReleaseKernel(kernel_huffman[i]);
  }
  for (int i = 0; i <= 2 * COPIES + 3; i++) {
    status = clReleaseCommandQueue(queue[i]);
  }
  status = clReleaseKernel(kernel_dct);
  status = clReleaseKernel(kernel_arb);
  status = clReleaseContext(context);
  status = clReleaseProgram(program);
}

int main(int argc, char* argv[]) {
  int sz;
  char *buf;
  FILE *f;
  Options options(argc, argv);

  if(!setCwdToExeDir()) {
    return false;
  }

  // Usage information.
  if(options.has("help")) {
    printf("Usage: %s [-in=<input.jpg>] [-out=<output.ppm>] [-runs=#] [-batch=#]\n", argv[0]);
    return 1;
  }

  // Options processing.
  if(options.has("runs")) {
    runs = options.get<unsigned>("runs");
  }
  if(options.has("batch")) {
    batch = options.get<unsigned>("batch");
  }

  // Input and output file selection.
  const std::string in_file = options.has("in") ? options.get<std::string>("in") : "1.jpeg";
  const std::string out_file = options.has("out") ? options.get<std::string>("out") : "1.ppm";

  // Read in input file.
  f = fopen(in_file.c_str(), "rb");
  if (!f) {
    printf("Error opening the input file: %s.\n", in_file.c_str());
    return 1;
  }
  fseek(f, 0, SEEK_END);
  sz = (int) ftell(f);
  buf = (char *)malloc(sz);
  if (!buf) {
    printf("Not enough memory\n");
    fclose(f);
    return 1;
  }
  fseek(f, 0, SEEK_SET);
  sz = (int) fread(buf, 1, sz, f);
  fclose(f);

  printf("Processing %d copies of %s in batches of %d\n", runs, in_file.c_str(), batch);

  cl_int status;
  clInit();
  unsigned long dataSize = MAX_DATA_SIZE; // maximum size of batch

  // Get size of global device memory in bytes
  cl_ulong devGlobMemSize;
  status = clGetDeviceInfo(device, CL_DEVICE_GLOBAL_MEM_SIZE, sizeof(devGlobMemSize), &devGlobMemSize, NULL);
  checkError(status, "Failed to get device info GLOBAL_MEM_SIZE");

  if (!parseWidthHeight(buf, sz)) {
    printf("Error parsing width and height.\n");
    free(buf);
    buf = NULL;
    cleanup();
    return 1;
  }
  unsigned long imgSize = width * height * 3;
  // Can't use all global memory, leave 1 MB free
  unsigned long availDataSize = devGlobMemSize / (2 * STREAMS) - MB(1);
  if (availDataSize < dataSize) {
    dataSize = availDataSize;
    int tmpBatch;
    if (imgSize > 0) {
      tmpBatch = dataSize / imgSize;
    }
    else {
      // This is an approximation based on file size
      tmpBatch = dataSize / (sz * 10) - 4;
    }
    if ((tmpBatch > 0) && (batch > tmpBatch)) {
      batch = tmpBatch;
      printf("Maximum batch images per invocation: %d, using that\n", batch);
    }
  }

  // Allocate host memory for a batch of images on each parallel stream

  for (int i = 0; i < STREAMS; i++) {
#if USE_SVM_API == 0
    myentropy[i] = (unsigned char *)alignedMalloc(dataSize);
    d_inData[i] = clCreateBuffer(context, CL_MEM_READ_WRITE, dataSize, NULL, &status);
    checkError(status, "Failed to create buffers");
    myrgb[i] = (unsigned char *)alignedMalloc(dataSize);
    d_finalRGB[i] = clCreateBuffer(context, CL_MEM_READ_WRITE, dataSize, NULL, &status);
    checkError(status, "Failed to create buffers");
#else
    cl_device_svm_capabilities caps = 0;

    status = clGetDeviceInfo(
      device[i],
      CL_DEVICE_SVM_CAPABILITIES,
      sizeof(cl_device_svm_capabilities),
      &caps,
      0
    );
    checkError(status, "Failed to get device info");

    if (!(caps & CL_DEVICE_SVM_COARSE_GRAIN_BUFFER)) {
      printf("The host was compiled with USE_SVM_API, however the device currently being targeted does not support SVM.\n");
      // Free the resources allocated
      free(buf);
      buf = NULL;
      cleanup();
      return 1;
    }
    myentropy[i] = (unsigned char *)clSVMAlloc(context, CL_MEM_READ_WRITE, dataSize, 0);
    myrgb[i] = (unsigned char *)clSVMAlloc(context, CL_MEM_READ_WRITE, dataSize, 0);
#endif /* USE_SVM_API == 0 */
    if (!(myentropy[i] && myrgb[i])) {
      printf("Can't allocate memory\n");
      free(buf);
      buf = NULL;
      cleanup();
      return 1;
    }
  }
  // Enqueue the arbiter, this will run forever
  clEnqueueTask(queue[2 * COPIES + 3], kernel_arb, 0, NULL, NULL);

  // Initializes events used downstream

  memset(transfer_event, 0, STREAMS * sizeof(cl_event));
  memset(dct_event, 0, STREAMS * sizeof(cl_event));
  memset(finish_event, 0, STREAMS * sizeof(cl_event));

  double start = getCurrentTimestamp();

  int stream = 0;

  // Executes all the runs in batches

  for (int i = 0; i < runs; i+= batch) {
    totalOffset = 0;
    int sizes[COPIES], images[COPIES];
    unsigned char *bases[COPIES];
    for (int j = 0; j < COPIES; j++) {
      sizes[j] = 0;
      images[j] = 0;
    }

#if USE_SVM_API == 1
    status = clEnqueueSVMMap(queue[2 * COPIES], CL_TRUE, CL_MAP_WRITE,
        (void *)myentropy[stream], dataSize, 0, NULL, NULL);
    checkError(status, "Failed to map input data");
#endif /* USE_SVM_API == 1 */

    bases[0] = myentropy[stream];

    // if initialized, wait for previous image transfer to finish
    if (transfer_event[stream]) {
      clWaitForEvents(1, &transfer_event[stream]);
      clReleaseEvent(transfer_event[stream]);
    }

    // Parse the headers of each image in the batch - extract compressed
    // image data
    for (int j = 0; j < batch; j++) {
      int where = j * COPIES / batch;
      // Determine where to extract the data for a new image
      image = bases[where] + sizes[where];
      if (!decode(buf, sz)) {
        printf("Error decoding the input file.\n");
        return 1;
      }
      sizes[where] = image - bases[where];
      images[where]++;
      for (int k = where + 1; k < COPIES; k++) bases[k] = image;
    }

    int totalSize = 0;
#if USE_SVM_API == 0
    for (int j = 0; j < COPIES; j++) totalSize += sizes[j];
    // All data has been gathered and is now being sent to the device
    status = clEnqueueWriteBuffer(queue[2 * COPIES], d_inData[stream], CL_FALSE, 0, totalSize, myentropy[stream], 0, NULL, &transfer_event[stream]);
    if(status != CL_SUCCESS) {
      printf ("Failed enqueue\n");
    }
    totalSize = 0;
#else
    status = clEnqueueSVMUnmap(queue[2 * COPIES], (void *)myentropy[stream], 0, NULL, NULL);
    checkError(status, "Failed to unmap input data");
#endif /* USE_SVM_API == 0 */
    // Enqueue all the Huffman decoders - these will run in parallel
    for (int j = 0; j < COPIES; j++) {
      int crtSize = sizes[j] / 4;
      if (crtSize > 0) {
#if USE_SVM_API == 0
        status = clSetKernelArg(kernel_reader[j], 0, sizeof(cl_mem), (void *)&d_inData[stream]);
#else
        status = clSetKernelArgSVMPointer(kernel_reader[j], 0, (void*)myentropy[stream]);
#endif /* USE_SVM_API == 0 */
        if (status != CL_SUCCESS) {
          printf("Failed to set argument 0, kernel_reader\n");
        }
        clSetKernelArg(kernel_reader[j], 1, sizeof(cl_int), (void *)&totalSize);
        clSetKernelArg(kernel_reader[j], 2, sizeof(cl_int), (void *)&crtSize);
        totalSize += crtSize;
#if USE_SVM_API == 0
        status = clEnqueueTask(queue[2 * j], kernel_reader[j], 1, &transfer_event[stream], NULL);
#else
        status = clEnqueueTask(queue[2 * j], kernel_reader[j], 0, NULL, NULL);
#endif /* USE_SVM_API == 0 */
        if(status != CL_SUCCESS) {
          printf("Failed to enqueue kernel reader\n");
        }
        size_t gws = images[j], lws = 1;
        clEnqueueNDRangeKernel(queue[2 * j + 1], kernel_huffman[j], 1, 0, &gws, &lws, 0, NULL, NULL);
      }
    }

    if (finish_event[stream]) {
      clWaitForEvents(1, &finish_event[stream]);
      clReleaseEvent(finish_event[stream]);
    }
    // Enqueue the iDCT kernel, this will consume data produced by the
    // Huffman decoders
    unsigned char write = 1;
#if USE_SVM_API == 0
    status = clSetKernelArg(kernel_dct, 0, sizeof(cl_mem), (void *)&d_finalRGB[stream]);
#else
    status = clSetKernelArgSVMPointer(kernel_dct, 0, (void*)myrgb[stream]);
#endif /* USE_SVM_API == 0 */
    checkError(status,"Failed to set argument 0, kernel_dct");
    status = clSetKernelArg(kernel_dct, 1, sizeof(cl_uchar), (void *)&write);
    checkError(status,"Failed to set argument 1, kernel_dct");
    size_t gws[2], lws[2];
    gws[1] =(downsample ? ceil(height, 16) * ceil(width, 16) : 2 * ceil(height, 8) * ceil(width, 8)) / 256 * batch;
    gws[0] = 24;
    lws[1] = 1;
    lws[0] = 24;
    status = clEnqueueNDRangeKernel(queue[2 * COPIES + 1], kernel_dct, 2, 0, gws, lws, 0, NULL, &dct_event[stream]);
    checkError(status, "Failed to launch kernel");
    // Read decompressed data back
#if USE_SVM_API == 0
    status = clEnqueueReadBuffer(queue[2 * COPIES + 2], d_finalRGB[stream], CL_FALSE, 0, totalOffset, myrgb[stream], 1, &dct_event[stream], &finish_event[stream]);
    checkError(status, "Failed to read decompressed data back");
#else
    status = clEnqueueSVMMap(queue[2 * COPIES + 2], CL_TRUE, CL_MAP_READ,
        (void *)myrgb[stream], dataSize, 0, NULL, NULL);
    checkError(status, "Failed to map decompressed data");
#endif /* USE_SVM_API == 0 */
    clReleaseEvent(dct_event[stream]);

    stream = (stream + 1) % STREAMS;
  }

  for (int i = 0; i <= 2 * COPIES + 2; i++) {
    clFinish(queue[i]);
  }
  double stop = getCurrentTimestamp();
  // At this point all hardware dcompression has terminated - verify the
  // results
  // The verification compares all images in all batches in all streams against the first image in the first stream
  bool error = false;
  int or816 = downsample ? 16 : 8;
  for (int i = 0; i < ceil(height, 16); i++) {
    for (int j = 0; j < (width + 15) / 16; j++) {
      for (int k = 0; k < 16; k++) {
        if (i * width + j * 16 + k < width * height && (j * 16 + k < width) && (i < height)) {
          int loc = 3 * (i * width + 16 * j + k);
          int srcloc = 3 * ((i / or816) * or816 * ceil(width, 16) + 16 * (j * or816 + (i % or816)) + k);
          unsigned char testr = rgb[loc] = myrgb[0][srcloc];
          unsigned char testg = rgb[loc + 1] = myrgb[0][srcloc + 1];
          unsigned char testb = rgb[loc + 2] = myrgb[0][srcloc + 2];
          for (int s = 0; s < STREAMS; s++) {
            for (int m = 0; m < batch; m++) {
              if (s * batch + m < runs) {
                unsigned char *base = myrgb[s] + m * outDataSize;
                if (testr != base[srcloc]) {
                  if (!error) {
                    printf ("Error R in stream %d, image %d @ %d %d\n", s, m, i, j);
                    error = true;
                  }
                }
                if (testg != base[srcloc + 1]) {
                  if (!error) {
                    printf ("Error G in stream %d, image %d @ %d %d\n", s, m, i, j);
                    error = true;
                  }
                }
                if (testb != base[srcloc + 2]) {
                  if (!error) {
                    printf ("Error B in stream %d, image %d @ %d %d\n", s, m, i, j);
                    error = true;
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  printf("Throughput = %.4f frames / s\n", (float)runs / (stop - start));

#if USE_SVM_API == 1
  for (int i = 0; i < STREAMS; i++) {
    status = clEnqueueSVMUnmap(queue[2 * COPIES + 2], (void *)myrgb[i], 0, NULL, NULL);
    checkError(status, "Failed to unmap decompressed data");
  }
#endif /* USE_SVM_API == 1 */

  // Dumps the first image to a file, for visual inspection

  f = fopen(out_file.c_str(), "wb");
  if (!f) {
    printf("Error opening the output file.\n");
    return 1;
  }
  fprintf(f, "P%d\n%d %d\n255\n", 6, width, height);
  fwrite(rgb, 1, width * height * 3, f);
  fclose(f);
  if (rgb) free((void*) rgb);
  for (int i = 0; i < STREAMS; i++) {
#if USE_SVM_API == 0
    if (myentropy[i])
      free(myentropy[i]);
    if (myrgb[i])
      free(myrgb[i]);
#else
    if (myentropy[i])
      clSVMFree(context, myentropy[i]);
    if (myrgb[i])
      clSVMFree(context, myrgb[i]);
#endif /* USE_SVM_API == 0 */
  }
  free(buf);
  buf = NULL;
  cleanup();
  return 0;
}

