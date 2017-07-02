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

//TODO: Remove metadata parsing code duplication by using
//metadata parsing code in FPGA API

#include <stdio.h>
#include <stdlib.h>
#include <uuid/uuid.h>
#include <json-c/json.h>

#ifndef __BITSTREAM_H__
#define __BITSTREAM_H__

#define METADATA_GUID "58656F6E-4650-4741-B747-425376303031"
#define METADATA_GUID_LEN 16
#define GBS_AFU_IMAGE "afu-image"
#define BBS_INTERFACE_ID "interface-uuid"

#define PRINT_MSG printf
#define PRINT_ERR(fmt, ...) fprintf(stderr, fmt, ##__VA_ARGS__)

static fpga_result string_to_guid(const char *guid, fpga_guid *result)
{
	if (uuid_parse(guid, *result) < 0) {
		PRINT_MSG("Error parsing guid %s\n", guid);
		return FPGA_INVALID_PARAM;
	}

	return FPGA_OK;
}

static uint64_t read_int_from_bitstream(const uint8_t *bitstream, uint8_t size)
{
	uint64_t ret = 0;
	switch(size) {

	case sizeof(uint8_t):
		ret = *((uint8_t *) bitstream);
		break;
	case sizeof(uint16_t):
		ret = *((uint16_t *) bitstream);
		break;
	case sizeof(uint32_t):
		ret = *((uint32_t *) bitstream);
		break;
	case sizeof(uint64_t):
		ret = *((uint64_t *) bitstream);
		break;
	default:
		PRINT_ERR("Unknown integer size");
	}

	return ret;
}

static fpga_result get_bitstream_ifc_id(const uint8_t *bitstream, fpga_guid *guid)
{
	fpga_result result = FPGA_EXCEPTION;
	char *json_metadata = NULL;
	uint32_t json_len = 0;
	const uint8_t *json_metadata_ptr = NULL;
	json_object *root = NULL;
	json_object *afu_image = NULL;
	json_object *interface_id = NULL;

	if(check_bitstream_guid(bitstream) != FPGA_OK)
		goto out_free;

	json_len = read_int_from_bitstream(bitstream + METADATA_GUID_LEN, sizeof(uint32_t));
	if(json_len == 0) {
		PRINT_MSG("Bitstream has no metadata");
		result = FPGA_OK;
		goto out_free;
	}

	json_metadata_ptr = bitstream + METADATA_GUID_LEN + sizeof(uint32_t);

	json_metadata = (char *) malloc(json_len + 1);
	if(json_metadata == NULL) {
		PRINT_ERR("Could not allocate memory for metadata!");
		return FPGA_NO_MEMORY;
	}

	memcpy(json_metadata, json_metadata_ptr, json_len);
	json_metadata[json_len] = '\0';

	root = json_tokener_parse(json_metadata);

	if(root != NULL) {
		if(json_object_object_get_ex(root, GBS_AFU_IMAGE, &afu_image)) {
			json_object_object_get_ex(afu_image, BBS_INTERFACE_ID, &interface_id);

			if(interface_id == NULL) {
				PRINT_ERR("Invalid metadata");
				result = FPGA_INVALID_PARAM;
				goto out_free;
			}

			result = string_to_guid(json_object_get_string(interface_id), guid);
			if (result != FPGA_OK) {
				PRINT_ERR("Invalid BBS interface id ");
				goto out_free;
			}
		}
		else {
			PRINT_ERR("Invalid metadata");
			result = FPGA_INVALID_PARAM;
			goto out_free;
		}
	}

out_free:
	if(root)
		json_object_put(root);
	if(json_metadata)
		free(json_metadata);

	return result;
}

#endif
