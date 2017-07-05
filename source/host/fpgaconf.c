// Copyright(c) 2017, Intel Corporation
//
// Redistribution  and  use  in source  and  binary  forms,  with  or  without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of  source code  must retain the  above copyright notice,
//   this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
//   this list of conditions and the following disclaimer in the documentation
//   and/or other materials provided with the distribution.
// * Neither the name  of Intel Corporation  nor the names of its contributors
//   may be used to  endorse or promote  products derived  from this  software
//   without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,  BUT NOT LIMITED TO,  THE
// IMPLIED WARRANTIES OF  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED.  IN NO EVENT  SHALL THE COPYRIGHT OWNER  OR CONTRIBUTORS BE
// LIABLE  FOR  ANY  DIRECT,  INDIRECT,  INCIDENTAL,  SPECIAL,  EXEMPLARY,  OR
// CONSEQUENTIAL  DAMAGES  (INCLUDING,  BUT  NOT LIMITED  TO,  PROCUREMENT  OF
// SUBSTITUTE GOODS OR SERVICES;  LOSS OF USE,  DATA, OR PROFITS;  OR BUSINESS
// INTERRUPTION)  HOWEVER CAUSED  AND ON ANY THEORY  OF LIABILITY,  WHETHER IN
// CONTRACT,  STRICT LIABILITY,  OR TORT  (INCLUDING NEGLIGENCE  OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,  EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

/*
 * @file fpgaconf.c
 *
 * @brief FPGA configure command line tool
 *
 * fpgaconf allows you to program green bitstream files to an FPGA supported by
 * the intel-fpga driver and API.
 *
 * Features:
 *   * Auto-discovery of compatible slots for supplied bitstream
 *   * Dry-run mode ("what would happen if...?")
 */

#include <errno.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>

#include "opae/fpga.h"

#include "fpgaconf.h"

#define FPGACONF_VERBOSITY 0

/*
 * macro to check FPGA return codes, print error message, and goto cleanup label
 * NOTE: this changes the program flow (uses goto)!
 */
#define ON_ERR_GOTO(res, label, desc)              \
	do {                                       \
		if ((res) != FPGA_OK) {            \
			print_err((desc), (res));  \
			goto label;                \
		}                                  \
	} while (0)

struct bitstream_info {
	uint8_t *data;
	size_t data_len;
};

/*
 * Print readable error message for fpga_results
 */
void print_err(const char *s, fpga_result res)
{
	fprintf(stderr, "Error %s: %s\n", s, fpgaErrStr(res));
}

/*
 * Print message depending on verbosity
 */
void print_msg(unsigned int verbosity, const char *s)
{
	if (FPGACONF_VERBOSITY >= verbosity)
		printf("%s\n", s);
}

/*
 * Find first FPGA matching the interface ID of the GBS
 *
 * @returns the total number of FPGAs matching the interface ID
 */
int find_fpga(struct find_fpga_target target, fpga_token *fpga)
{
	fpga_properties    filter = NULL;
	uint32_t           num_matches;
	fpga_result        res;
	int                retval = -1;

	/* Get number of FPGAs in system */
	res = fpgaGetProperties(NULL, &filter);
	ON_ERR_GOTO(res, out_err, "creating properties object");

	res = fpgaPropertiesSetObjectType(filter, FPGA_FPGA);
	ON_ERR_GOTO(res, out_destroy, "setting object type");

	if (-1 != target.bus) {
		res = fpgaPropertiesSetBus(filter, target.bus);
		ON_ERR_GOTO(res, out_destroy, "setting bus");
	}

	if (-1 != target.device) {
		res = fpgaPropertiesSetDevice(filter, target.device);
		ON_ERR_GOTO(res, out_destroy, "setting device");
	}

	if (-1 != target.function) {
		res = fpgaPropertiesSetFunction(filter, target.function);
		ON_ERR_GOTO(res, out_destroy, "setting function");
	}

	if (-1 != target.socket) {
		res = fpgaPropertiesSetSocketID(filter, target.socket);
		ON_ERR_GOTO(res, out_destroy, "setting socket id");
	}

	res = fpgaEnumerate(&filter, 1, fpga, 1, &num_matches);
	ON_ERR_GOTO(res, out_destroy, "enumerating FPGAs");

	if (num_matches > 0) {
		retval = (int) num_matches; /* FPGA found */
	} else {
		retval = 0; /* no FPGA found */
	}

out_destroy:
	res = fpgaDestroyProperties(&filter); /* not needed anymore */
	ON_ERR_GOTO(res, out_err, "destroying properties object");
out_err:
	return retval;
}

int program_bitstream(fpga_token token,
		uint32_t slot_num, struct bitstream_info *info)
{
	fpga_handle handle;
	fpga_result res;

	print_msg(2, "Opening FPGA");
	res = fpgaOpen(token, &handle, 0);
	ON_ERR_GOTO(res, out_err, "opening FPGA");

	print_msg(1, "Writing bitstream");
	res = fpgaReconfigureSlot(handle, slot_num, info->data, info->data_len, 0);
	ON_ERR_GOTO(res, out_close, "writing bitstream to FPGA");

	print_msg(2, "Closing FPGA");
	res = fpgaClose(handle);
	ON_ERR_GOTO(res, out_err, "closing FPGA");
	return 1;

out_close:
	res = fpgaClose(handle);
	ON_ERR_GOTO(res, out_err, "closing FPGA");
out_err:
	return -1;
}

int program_gbs_bitstream(fpga_token fpga, uint8_t *gbs_data, size_t gbs_len)
{
	int res;
	int retval = 0;
	struct bitstream_info info;
	uint32_t slot_num = 0; /* currently, we don't support multiple slots */

	info.data = gbs_data;
	info.data_len = gbs_len;

	/* program bitstream */
	print_msg(1, "Programming bitstream");
	res = program_bitstream(fpga, slot_num, &info);
	if (res < 0) {
		retval = 5;
		goto out_exit;
	}
	print_msg(1, "Done");

	/* clean up */
out_exit:
	return retval;
}
