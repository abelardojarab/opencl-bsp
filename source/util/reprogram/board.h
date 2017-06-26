#ifndef __BOARD_H
#define __BOARD_H

#ifdef __cplusplus
extern "C" {
#endif

#include "CL/opencl.h"

extern CL_API_ENTRY cl_program CL_API_CALL
clCreateProgramWithBinaryAndProgramDeviceIntelFPGA(cl_context                     /* context */,
                                 cl_uint                        /* num_devices */,
                                 const cl_device_id *           /* device_list */,
                                 const size_t *                 /* lengths */,
                                 const unsigned char **         /* binaries */,
                                 cl_int *                       /* binary_status */,
                                 cl_int *                       /* errcode_ret */) CL_API_SUFFIX__VERSION_1_0;

#ifdef __cplusplus
}
#endif
#endif
