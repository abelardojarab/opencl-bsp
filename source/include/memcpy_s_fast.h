/* (C) 1992-2017 Intel Corporation.                             */
/* Intel, the Intel logo, Intel, MegaCore, NIOS II, Quartus and TalkBack words     */
/* and logos are trademarks of Intel Corporation or its subsidiaries in the U.S.   */
/* and/or other countries. Other marks and brands may be claimed as the property   */
/* of others. See Trademarks on intel.com for full list of Intel trademarks or     */
/* the Trademarks & Brands Names Database (if Intel) or See www.Intel.com/legal (if Altera)  */
/* Your use of Intel Corporation's design tools, logic functions and other         */
/* software and tools, and its AMPP partner logic functions, and any output        */
/* files any of the foregoing (including device programming or simulation          */
/* files), and any associated documentation or information are expressly subject   */
/* to the terms and conditions of the Altera Program License Subscription          */
/* Agreement, Intel MegaCore Function License Agreement, or other applicable       */
/* license agreement, including, without limitation, that your use is for the      */
/* sole purpose of programming logic devices manufactured by Intel and sold by     */
/* Intel or its authorized distributors.  Please refer to the applicable           */
/* agreement for further details.                                                  */

#ifndef MEMCPY_S_FAST_H
#define MEMCPY_S_FAST_H_

// Consistency check
#if defined(MEMCPY_S_FAST_USE_MEMCPY_S) && defined(MEMCPY_S_FAST_USE_LOCAL_MEMCPY)
#undef MEMCPY_S_FAST_USE_MEMCPY_S
#endif

#ifdef MEMCPY_S_FAST_USE_LOCAL_MEMCPY
#ifdef __cplusplus
extern "C" {
#endif	// __cplusplus
	extern void *local_memcpy(void *dst, const void *src, size_t size);
#ifdef __cplusplus
	}
#endif	// __cplusplus
#endif // MEMCPY_S_FAST_USE_LOCAL_MEMCPY

#ifdef MEMCPY_S_FAST_USE_MEMCPY_S
#define memcpy_s_fast(a,b,c,d) memcpy_s(a,b,c,d)
#else	// MEMCPY_S_FAST_USE_MEMCPY_S
#ifdef MEMCPY_S_FAST_USE_LOCAL_MEMCPY
#define memcpy_s_fast(a,b,c,d) local_memcpy(a,c,d)
#else	// MEMCPY_S_FAST_USE_LOCAL_MEMCPY
#define memcpy_s_fast(a,b,c,d) memcpy(a,c,d)
#endif	// MEMCPY_S_FAST_USE_MEMCPY
#endif	// MEMCPY_S_FAST_USE_MEMCPY_S

#endif	// MEMCPY_S_FAST_H
