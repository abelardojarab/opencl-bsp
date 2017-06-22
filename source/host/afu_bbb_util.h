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

/**
 * \fpga_dma.h
 * \brief FPGA DMA BBB API Header
 *
 * Known Limitations
 * - Driver does not support Address Span Extender
 * - Implementation is not optimized for performance. 
 *   User buffer data is copied into a DMA-able buffer before the transfer
 * - Supports only synchronous (blocking) transfers
 */

#ifndef __AFU_BBB_UTIL_H__
#define __AFU_BBB_UTIL_H__

#include <opae/fpga.h>

#define DFH_FEATURE_EOL(dfh) (((dfh >> 40) & 1) == 1)
#define DFH_FEATURE(dfh) ((dfh >> 60) & 0xf)
#define DFH_FEATURE_IS_PRIVATE(dfh) (DFH_FEATURE(dfh) == 3)
#define DFH_FEATURE_IS_BBB(dfh) (DFH_FEATURE(dfh) == 2)
#define DFH_FEATURE_IS_AFU(dfh) (DFH_FEATURE(dfh) == 1)
#define DFH_FEATURE_NEXT(dfh) ((dfh >> 16) & 0xffffff)

static bool find_dfh_by_guid(fpga_handle afc_handle, 
	uint64_t find_id_l, uint64_t find_id_h, 
	uint64_t *result_offset = NULL, uint64_t *result_next_offset = NULL)
{
	if(result_offset)
		*result_offset = 0;
	if(result_next_offset)
		*result_next_offset = 0;
	
	if(find_id_l == 0)
		return 0;
	if(find_id_l == 0)
		return 0;

	uint64_t offset = 0;
	uint64_t dfh = 0;
	
	do
	{
		fpgaReadMMIO64(afc_handle, 0, offset, &dfh);

		int is_bbb = DFH_FEATURE_IS_BBB(dfh);
		int is_afu = DFH_FEATURE_IS_AFU(dfh);
		
		if(is_afu || is_bbb)
		{
			uint64_t id_l = 0;
			uint64_t id_h = 0;
			fpgaReadMMIO64(afc_handle, 0, offset+8, &id_l);
			fpgaReadMMIO64(afc_handle, 0, offset+16, &id_h);
			if(find_id_l == id_l && find_id_h == id_h)
			{
				if(result_offset)
					*result_offset = offset;
				if(result_next_offset)
					*result_next_offset = DFH_FEATURE_NEXT(dfh);
				return 1;
			}
		}
		
		offset += DFH_FEATURE_NEXT(dfh);
	} while(!DFH_FEATURE_EOL(dfh));
	
	return 0;
}

static bool find_dfh_by_guid(fpga_handle afc_handle, 
	const char *guid_str,
	uint64_t *result_offset = NULL, uint64_t *result_next_offset = NULL)
{
	fpga_guid          guid;

	if (uuid_parse(guid_str, guid) < 0)
		return 0;
	
	uint32_t i;
	uint32_t s;
	
	uint64_t find_id_l = 0;
	uint64_t find_id_h = 0;
	
	// The API expects the MSB of the GUID at [0] and the LSB at [15].
	s = 64;
	for (i = 0; i < 8; ++i) {
		s -= 8;
		find_id_h = ((find_id_h << 8) | (0xff & guid[i]));
	}
	
	s = 64;
	for (i = 0; i < 8; ++i) {
		s -= 8;
		find_id_l = ((find_id_l << 8) | (0xff & guid[8 + i]));
	}
	
	return find_dfh_by_guid(afc_handle, find_id_l, find_id_h, 
		result_offset, result_next_offset);
}

#endif // __AFU_BBB_UTIL_H__
