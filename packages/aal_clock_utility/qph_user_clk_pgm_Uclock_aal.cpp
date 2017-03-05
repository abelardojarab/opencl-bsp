// Copyright(c) 2016, Intel Corporation
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
//****************************************************************************



//****************************************************************************
//
// qph_user_clk_pgm_Uclock_aal.cpp: bdx-p & skx-p user clock
// Copyright Intel 2016
// Arthur.Sheiman@Intel.com   Created: 03-31-16
// Revised: 10-27-16  00:29
//
// Main class for User Clock, header file
//
//****************************************************************************





// User clock
// For each user clock one instance is needed (currently only 1, but with multi-AFU then 1 per AFU).


// Includes
#include <time.h>

#include "qph_user_clk_pgm_Uclock_aal.hpp"

// Private shared ROM tables (const static)
#include "qph_user_clk_pgm_Uclock_freq_template.cpp.inc"
#include "qph_user_clk_pgm_Uclock_eror_messages.cpp.inc"

// Construct the object
QUCPU_Uclock::QUCPU_Uclock()
{ // QUCPU_Uclock::QUCPU_Uclock, constructor
  i_InitzState                              = 0;
  tInitz_InitialParams.u64i_Version         = (uint64_t)0;
  tInitz_InitialParams.u64i_PLL_ID          = (uint64_t)0;
  tInitz_InitialParams.u64i_NumFrq_Intg_End = (uint64_t)0;
  tInitz_InitialParams.u64i_NumFrq_Frac_Beg = (uint64_t)0;
  tInitz_InitialParams.u64i_NumFrq_Frac_End = (uint64_t)0;
  tInitz_InitialParams.u64i_NumFrq          = (uint64_t)0;
  tInitz_InitialParams.u64i_NumReg          = (uint64_t)0;
  tInitz_InitialParams.u64i_NumRck          = (uint64_t)0;
  pu64i_PrtBaseAddrThisAFU                  = 0;
  pALIMMIOService                           = 0;
  u64i_cmd_reg_0                            = (uint64_t)0x0LLU;
  u64i_cmd_reg_1                            = (uint64_t)0x0LLU;
  u64i_AVMM_seq                             = (uint64_t)0x0LLU;
  i_Bug_First                               = 0;
  i_Bug_Last                                = 0;
} // QUCPU_Uclock::QUCPU_Uclock, constructor



int QUCPU_Uclock::fi_RunInitz(uint64_t     *pu64i_PRTbaseAddr,
                         AAL::IALIMMIO     *ptMMIO_MMIOservice,
                              QUCPU_tInitz *ptInitz_retInitz)
{ // Public: QUCPU_Uclock::fi_RunInitz
  // Initialize
  // Reinitialization okay too, since will issue machine reset

  uint64_t u64i_PrtAddr, u64i_PrtData;
  uint64_t u64i_AvmmAdr, u64i_AvmmDat;
  int      i_ReturnErr;

  // Assume return error okay, for now
  i_ReturnErr = 0;

  // Initialize default values (for error abort)
  tInitz_InitialParams.u64i_Version = 0;
  tInitz_InitialParams.u64i_PLL_ID  = 0;

  // Initialize command shadow registers
  u64i_cmd_reg_0 = ((uint64_t)0x0LLU);
  u64i_cmd_reg_1 = ((uint64_t)0x0LLU);

  // Initialize sequence IO
  u64i_AVMM_seq  = ((uint64_t)0x0LLU);

  // Static values
  tInitz_InitialParams.u64i_NumFrq_Intg_End = (uint64_t)QUCPU_INT_NUMFRQ_INTG_END;
  tInitz_InitialParams.u64i_NumFrq_Frac_Beg = (uint64_t)QUCPU_INT_NUMFRQ_FRAC_BEG;
  tInitz_InitialParams.u64i_NumFrq_Frac_End = (uint64_t)QUCPU_INT_NUMFRQ_FRAC_END;
  tInitz_InitialParams.u64i_NumFrq          = (uint64_t)QUCPU_INT_NUMFRQ;
  tInitz_InitialParams.u64i_NumReg          = (uint64_t)QUCPU_INT_NUMREG;
  tInitz_InitialParams.u64i_NumRck          = (uint64_t)QUCPU_INT_NUMRCK;

  // Compute port base address for this AFU
  pu64i_PrtBaseAddrThisAFU =   pu64i_PRTbaseAddr
                             + QUCPU_UI64_AFU_MMIO_PRT_OFFSET_QW;

  // Store pointe for AAL MMIO access
  pALIMMIOService          =   ptMMIO_MMIOservice;

  // Read version number
  if (i_ReturnErr == 0) // This always true; added for future safety
    { // Verifying User Clock version number
      u64i_PrtAddr                      = QUCPU_UI64_PRT_UCLK_STS_1;
      u64i_PrtData                      = fu64i_PrtMmioRead(u64i_PrtAddr);
      tInitz_InitialParams.u64i_Version = (u64i_PrtData & QUCPU_UI64_STS_1_VER_b63t60) >> 60;
      if (tInitz_InitialParams.u64i_Version != QUCPU_UI64_STS_1_VER_version)
        { // User Clock wrong version number
          i_ReturnErr = QUCPU_INT_UCLOCK_RUNINITZ_ERR_VER;
        } // User Clock wrong version number
    } // Verifying User Clock version number

  // Read PLL ID
  if (i_ReturnErr == 0)
    { // Waiting for fcr PLL calibration not to be busy
      i_ReturnErr = QUCPU_Uclock::fi_WaitCalDone();
    } // Waiting for fcr PLL calibration not to be busy

  if (i_ReturnErr == 0)
    { // Cycle reset and wait for any calibration to finish

      // Activating management & machine reset
      u64i_cmd_reg_0   |=  (QUCPU_UI64_CMD_0_PRS_b56);
      u64i_cmd_reg_0   &= ~(QUCPU_UI64_CMD_0_MRN_b52);
      u64i_PrtAddr      = QUCPU_UI64_PRT_UCLK_CMD_0;
      u64i_PrtData      = u64i_cmd_reg_0;
      fv_PrtMmioWrite(u64i_PrtAddr,u64i_PrtData);


      // Deasserting management & machine reset
      u64i_cmd_reg_0   |=  (QUCPU_UI64_CMD_0_MRN_b52);
      u64i_cmd_reg_0   &= ~(QUCPU_UI64_CMD_0_PRS_b56);
      u64i_PrtAddr      = QUCPU_UI64_PRT_UCLK_CMD_0;
      u64i_PrtData      = u64i_cmd_reg_0;
      fv_PrtMmioWrite(u64i_PrtAddr,u64i_PrtData);

      // Waiting for fcr PLL calibration not to be busy
      i_ReturnErr = QUCPU_Uclock::fi_WaitCalDone();
    } // Cycle reset and wait for any calibration to finish


  if (i_ReturnErr == 0)
    { // Checking fPLL ID
      u64i_AvmmAdr = QUCPU_UI64_AVMM_FPLL_IPI_200;
      i_ReturnErr  = fi_AvmmRead(u64i_AvmmAdr, &u64i_AvmmDat);
      if (i_ReturnErr == 0)
        { // Check identifier
          tInitz_InitialParams.u64i_PLL_ID = u64i_AvmmDat & 0xffLLU;
          if ( !(   tInitz_InitialParams.u64i_PLL_ID == QUCPU_UI64_AVMM_FPLL_IPI_200_IDI_RFDUAL
                 || tInitz_InitialParams.u64i_PLL_ID == QUCPU_UI64_AVMM_FPLL_IPI_200_IDI_RF100M
        	 || tInitz_InitialParams.u64i_PLL_ID == QUCPU_UI64_AVMM_FPLL_IPI_200_IDI_RF322M) )
            { // ERROR: Wrong fPLL ID Identifer
              i_ReturnErr = QUCPU_INT_UCLOCK_RUNINITZ_ERR_FPLL_ID_ILLEGAL;
            } // ERROR: Wrong fPLL ID Identifer
        } // Check identifier
    } // Checking fPLL ID


  // Copy structure, initialize, and return based on error status
  *ptInitz_retInitz = tInitz_InitialParams;
  i_InitzState      = !i_ReturnErr; // Set InitzState to 0 or 1
  return              (i_ReturnErr);

} // Public: QUCPU_Uclock::fi_RunInitz



int QUCPU_Uclock::fi_GetFreqs(QUCPU_tFreqs *ptFreqs_retFreqs)
{ // Public: QUCPU_Uclock::fi_GetFreqs
  // Read the frequency for the User clock and div2 clock

  uint64_t u64i_PrtAddr, u64i_PrtData;
  long int li_sleep_nanoseconds;
  int      i_ReturnErr;

  // Assume return error okay, for now
  i_ReturnErr = 0;

  if (!i_InitzState) i_ReturnErr = QUCPU_INT_UCLOCK_GETFREQS_ERR_INITZSTATE;
  
  if (i_ReturnErr == 0)
    { // Read div2 and 1x user clock frequency
      // Low frequency
      u64i_cmd_reg_1   &= ~QUCPU_UI64_CMD_1_MEA_b32;
      u64i_PrtAddr      = QUCPU_UI64_PRT_UCLK_CMD_1;
      u64i_PrtData      = u64i_cmd_reg_1;
      fv_PrtMmioWrite(u64i_PrtAddr,u64i_PrtData);
      
      li_sleep_nanoseconds=10000000;            // 10 ms for frequency counter
      fv_SleepShort(li_sleep_nanoseconds);
      
      u64i_PrtAddr      = QUCPU_UI64_PRT_UCLK_STS_1;
      u64i_PrtData      = fu64i_PrtMmioRead(u64i_PrtAddr);

      ptFreqs_retFreqs->u64i_Frq_DivBy2 = (u64i_PrtData & QUCPU_UI64_STS_1_FRQ_b16t00) * 10000; // Hz

      
      // High frequency
      u64i_cmd_reg_1   |=  QUCPU_UI64_CMD_1_MEA_b32;
      u64i_PrtAddr      = QUCPU_UI64_PRT_UCLK_CMD_1;
      u64i_PrtData      = u64i_cmd_reg_1;
      fv_PrtMmioWrite(u64i_PrtAddr,u64i_PrtData);
      
      li_sleep_nanoseconds=10000000;            // 10 ms for frequency counter
      fv_SleepShort(li_sleep_nanoseconds);
      
      u64i_PrtAddr      = QUCPU_UI64_PRT_UCLK_STS_1;
      u64i_PrtData      = fu64i_PrtMmioRead(u64i_PrtAddr);

      ptFreqs_retFreqs->u64i_Frq_ClkUsr = (u64i_PrtData & QUCPU_UI64_STS_1_FRQ_b16t00) * 10000; // Hz
    } // Read div2 and 1x user clock frequency

  return (i_ReturnErr);
} // Public: QUCPU_Uclock::fi_GetFreqs



int QUCPU_Uclock::fi_SetFreqs(uint64_t       u64i_Refclk,
                              uint64_t       u64i_FrqInx)
{ // Public: QUCPU_Uclock::fi_SetFreqs
  // Set the user clock frequency

  uint64_t u64i_I, u64i_MifReg, u64i_PrtAddr, u64i_PrtData;
  uint64_t u64i_AvmmAdr, u64i_AvmmDat, u64i_AvmmMsk;
  long int li_sleep_nanoseconds;
  int      i_ReturnErr;

  // Assume return error okay, for now
  i_ReturnErr = 0;

  if (!i_InitzState) i_ReturnErr = QUCPU_INT_UCLOCK_SETFREQS_ERR_INITZSTATE;
  
  if (i_ReturnErr == 0)
    { // Check REFCLK
      if (u64i_Refclk == 0)
        { // 100 MHz REFCLK requested
          if ( !(   tInitz_InitialParams.u64i_PLL_ID == QUCPU_UI64_AVMM_FPLL_IPI_200_IDI_RFDUAL
        	 || tInitz_InitialParams.u64i_PLL_ID == QUCPU_UI64_AVMM_FPLL_IPI_200_IDI_RF100M) )
            i_ReturnErr = QUCPU_INT_UCLOCK_SETFREQS_ERR_REFCLK_100M_MISSING;
        } // 100 MHz REFCLK requested
      else if (u64i_Refclk == 1)
        { // 322.265625 MHz REFCLK requested
          if ( !(   tInitz_InitialParams.u64i_PLL_ID == QUCPU_UI64_AVMM_FPLL_IPI_200_IDI_RFDUAL
        	 || tInitz_InitialParams.u64i_PLL_ID == QUCPU_UI64_AVMM_FPLL_IPI_200_IDI_RF322M) )
            i_ReturnErr = QUCPU_INT_UCLOCK_SETFREQS_ERR_REFCLK_322M_MISSING;
        } // 322.265625 MHz REFCLK requested
      else i_ReturnErr = QUCPU_INT_UCLOCK_SETFREQS_ERR_REFCLK_ILLEGAL;
    } // Check REFCLK

  if (i_ReturnErr == 0)
    { // Check frequency index
      if (u64i_FrqInx > tInitz_InitialParams.u64i_NumFrq_Frac_End)
        i_ReturnErr = QUCPU_INT_UCLOCK_SETFREQS_ERR_FINDEX_OVERRANGE;
      else if (   u64i_FrqInx   < tInitz_InitialParams.u64i_NumFrq_Frac_Beg
	       && u64i_FrqInx   > tInitz_InitialParams.u64i_NumFrq_Intg_End)
        i_ReturnErr = QUCPU_INT_UCLOCK_SETFREQS_ERR_FINDEX_INTG_RANGE_BAD;
      else if (   u64i_FrqInx   < tInitz_InitialParams.u64i_NumFrq_Frac_Beg
		  && u64i_Refclk != 1) // Integer-PLL mode, exact requires 322.265625 MHz
	i_ReturnErr = QUCPU_INT_UCLOCK_SETFREQS_ERR_FINDEX_INTG_NEEDS_322M;
    } // Check frequency index

  if (i_ReturnErr == 0)
    { // Power down PLL
      // Altera bug. Power down pin doesn't work  SR #11229652.
      // WORKAROUND: Use power down port
      u64i_AvmmAdr = 0x2e0LLU;
      u64i_AvmmDat = 0x03LLU;
      u64i_AvmmMsk = 0x03LLU;
      i_ReturnErr = fi_AvmmReadModifyWriteVerify(u64i_AvmmAdr,u64i_AvmmDat,u64i_AvmmMsk);

      // Sleep 1 ms
      li_sleep_nanoseconds=1000000;
      fv_SleepShort(li_sleep_nanoseconds);
    } // Power down PLL

  if (i_ReturnErr == 0)
    { // Verifying fcr PLL not locking
      u64i_PrtAddr      = QUCPU_UI64_PRT_UCLK_STS_0;
      u64i_PrtData      = fu64i_PrtMmioRead(u64i_PrtAddr);
      if ((u64i_PrtData & QUCPU_UI64_STS_0_LCK_b60) != 0)
        { // fcr PLL is locked but should be unlocked
          i_ReturnErr = QUCPU_INT_UCLOCK_SETFREQS_ERR_PLL_NO_UNLOCK;
        } // fcr PLL is locked but should be unlocked
    } // Verifying fcr PLL not locking

  if (i_ReturnErr == 0)
    { // Select reference and push table
      // Selecting desired reference clock
      u64i_cmd_reg_0   &= ~QUCPU_UI64_CMD_0_SR1_b58;
      if (u64i_Refclk) u64i_cmd_reg_0 |= QUCPU_UI64_CMD_0_SR1_b58;
      u64i_PrtAddr      = QUCPU_UI64_PRT_UCLK_CMD_0;
      u64i_PrtData      = u64i_cmd_reg_0;
      fv_PrtMmioWrite(u64i_PrtAddr,u64i_PrtData);

      // Sleep 1 ms
      li_sleep_nanoseconds=1000000;
      fv_SleepShort(li_sleep_nanoseconds);


      // Pushing the table
      for (u64i_MifReg=0; u64i_MifReg<tInitz_InitialParams.u64i_NumReg; u64i_MifReg++)
        { // Write each register in the diff mif
          u64i_AvmmAdr = (uint64_t)(scu32ia3d_DiffMifTbl[(int)u64i_FrqInx][(int)u64i_MifReg][(int)u64i_Refclk]             ) >> 16;
          u64i_AvmmDat = (uint64_t)(scu32ia3d_DiffMifTbl[(int)u64i_FrqInx][(int)u64i_MifReg][(int)u64i_Refclk] & 0x000000ff)      ;
          u64i_AvmmMsk = (uint64_t)(scu32ia3d_DiffMifTbl[(int)u64i_FrqInx][(int)u64i_MifReg][(int)u64i_Refclk] & 0x0000ff00) >>  8;
          i_ReturnErr = fi_AvmmReadModifyWriteVerify(u64i_AvmmAdr,u64i_AvmmDat,u64i_AvmmMsk);

 	  if (i_ReturnErr) break;
        } // Write each register in the diff mif
    } // Select reference and push table

  if (i_ReturnErr == 0)
    { // Waiting for fcr PLL calibration not to be busy
      i_ReturnErr = QUCPU_Uclock::fi_WaitCalDone();
    } // Waiting for fcr PLL calibration not to be busy

  if (i_ReturnErr == 0)
    { // Recalibrating

      // "Request user access to the internal configuration bus"
      // and "Wait for reconfig_waitrequest to be deasserted."
      // Note that the Verify operation performs the post "wait."
     
      u64i_AvmmAdr = 0x000LLU;
      u64i_AvmmDat = 0x02LLU;
      u64i_AvmmMsk = 0xffLLU;
      i_ReturnErr = fi_AvmmReadModifyWriteVerify(u64i_AvmmAdr,u64i_AvmmDat,u64i_AvmmMsk);

      if (i_ReturnErr == 0)
        { // "To calibrate the fPLL, Read-Modify-Write:" set B1 of 0x100 high
          u64i_AvmmAdr = 0x100LLU;
          u64i_AvmmDat = 0x02LLU;
          u64i_AvmmMsk = 0x02LLU;
          i_ReturnErr = fi_AvmmReadModifyWrite(u64i_AvmmAdr,u64i_AvmmDat,u64i_AvmmMsk);
        } // "To calibrate the fPLL, Read-Modify-Write:" set B1 of 0x100 high

      if (i_ReturnErr == 0)
        { // "Release the internal configuraiton bus to PreSICE to perform recalibration"
          u64i_AvmmAdr = 0x000LLU;
          u64i_AvmmDat = 0x01LLU;
          i_ReturnErr = fi_AvmmWrite(u64i_AvmmAdr,u64i_AvmmDat);

          // Sleep 1 ms
          li_sleep_nanoseconds=1000000;
          fv_SleepShort(li_sleep_nanoseconds);
        } // "Release the internal configuraiton bus to PreSICE to perform recalibration"
    } // Recalibrating

  if (i_ReturnErr == 0)
    { // Waiting for fcr PLL calibration not to be busy
      i_ReturnErr = QUCPU_Uclock::fi_WaitCalDone();
    } // Waiting for fcr PLL calibration not to be busy

  if (i_ReturnErr == 0)
    { // Power up PLL
      // Altera bug. Power down pin doesn't work  SR #11229652.
      // WORKAROUND: Use power down port
      u64i_AvmmAdr = 0x2e0LLU;
      u64i_AvmmDat = 0x02LLU;
      u64i_AvmmMsk = 0x03LLU;
      i_ReturnErr = fi_AvmmReadModifyWriteVerify(u64i_AvmmAdr,u64i_AvmmDat,u64i_AvmmMsk);
    } // Power up PLL

  if (i_ReturnErr == 0)
    { // Wait for PLL to lock
      u64i_PrtAddr      = QUCPU_UI64_PRT_UCLK_STS_0;
      for (u64i_I=0; u64i_I<100; u64i_I++)
        { // Poll with 100 ms timeout
          u64i_PrtData      = fu64i_PrtMmioRead(u64i_PrtAddr);
          if ((u64i_PrtData & QUCPU_UI64_STS_0_LCK_b60) != 0) break;

          // Sleep 1 ms
          li_sleep_nanoseconds=1000000;
          fv_SleepShort(li_sleep_nanoseconds);
        } // Poll with 100 ms timeout

      if ((u64i_PrtData & QUCPU_UI64_STS_0_LCK_b60) == 0)
        { // fcr PLL lock error
          i_ReturnErr = QUCPU_INT_UCLOCK_SETFREQS_ERR_PLL_LOCK_TO;
        } // fcr PLL lock error
    } // Verifying fcr PLL is locking

  return (i_ReturnErr);
} // Public: QUCPU_Uclock::fi_SetFreqs



const char * QUCPU_Uclock::fpac_GetErrMsg(int i_ErrMsgInx)
{ // Public: QUCPU_Uclock::fpac_GetErrMsg
  // Read the frequency for the User clock and div2 clock
  const char * pac_ErrMsgStr;

  // Extra "+1" message has index range error message
  pac_ErrMsgStr = pac_UclockErrorMsg[QUCPU_INT_UCLOCK_NUM_ERROR_MESSAGES + 1 -1];

  // Check index range
  if (    i_ErrMsgInx >= 0
       || i_ErrMsgInx  < QUCPU_INT_UCLOCK_NUM_ERROR_MESSAGES );
    { // All okay, set the message string
      pac_ErrMsgStr = pac_UclockErrorMsg[i_ErrMsgInx];
    } // All okay, set the message string

    return (pac_ErrMsgStr);
} // Public: QUCPU_Uclock::fpac_GetErrMsg



int QUCPU_Uclock::fi_WaitCalDone(void)
{ // Private: QUCPU_Uclock::fi_WaitCalDone
  // Wait for calibration to be done

  uint64_t u64i_PrtAddr, u64i_PrtData;
  uint64_t u64i_I;
  long int li_sleep_nanoseconds;
  int      i_ReturnErr;

  // Assume return error okay, for now
  i_ReturnErr = 0;

  // Waiting for fcr PLL calibration not to be busy
  u64i_PrtAddr      = QUCPU_UI64_PRT_UCLK_STS_0;
  for (u64i_I=0; u64i_I<1000; u64i_I++)
    { // Poll with 1000 ms timeout
      u64i_PrtData = fu64i_PrtMmioRead(u64i_PrtAddr);
      if ((u64i_PrtData & QUCPU_UI64_STS_0_BSY_b61) == 0) break;

      // Sleep 1 ms
      li_sleep_nanoseconds=1000000;
      fv_SleepShort(li_sleep_nanoseconds);
    } // Poll with 1000 ms timeout

  if ((u64i_PrtData & QUCPU_UI64_STS_0_BSY_b61) != 0)
    { // ERROR: calibration busy too long
      i_ReturnErr = QUCPU_INT_UCLOCK_WAITCALDONE_ERR_BSY_TO;
    } // ERROR: calibration busy too long

  return(i_ReturnErr);
} // Private: QUCPU_Uclock::fi_WaitCalDone



void QUCPU_Uclock::fv_PrtMmioWrite(uint64_t u64i_PrtAddr, uint64_t u64i_PrtData)
{ // Private: QUCPU_Uclock::fv_PrtMmioWrite
  AAL::btCSROffset            btcoAbsAddr;
  AAL::btUnsigned64bitInt     btu64iWriteData;

  // pu64i_PrtBaseAddrThisAFU[u64i_PrtAddr] = u64i_PrtData;
  btcoAbsAddr = (AAL::btCSROffset)(u64i_PrtAddr << 3);
  btu64iWriteData = (AAL::btUnsigned64bitInt)u64i_PrtData;
  pALIMMIOService->mmioWrite64(btcoAbsAddr,btu64iWriteData);

  return;
} // Private: QUCPU_Uclock::fv_PrtMmioWrite



uint64_t QUCPU_Uclock::fu64i_PrtMmioRead(uint64_t u64i_PrtAddr)
{ // Private: QUCPU_Uclock::fu64i_PrtMmioRead
  uint64_t u64i_DataRead;

  AAL::btCSROffset            btcoAbsAddr;
  AAL::btUnsigned64bitInt     btu64iDataRead;

  // u64i_DataRead = (uint64_t)pu64i_PrtBaseAddrThisAFU[u64i_PrtAddr];
  btcoAbsAddr = (AAL::btCSROffset)(u64i_PrtAddr << 3);
  pALIMMIOService->mmioRead64(btcoAbsAddr,&btu64iDataRead);
  u64i_DataRead = (uint64_t)btu64iDataRead;

  return(u64i_DataRead);
} // Private: QUCPU_Uclock::fu64i_PrtMmioRead



uint64_t QUCPU_Uclock::fu64i_GetAVMM_seq()
{ // Private: QUCPU_Uclock::fu64i_GetAVMM_seq
  // Increment seq
  u64i_AVMM_seq++;
  u64i_AVMM_seq &= 0x03LLU;

  return(u64i_AVMM_seq);
} // Private: QUCPU_Uclock::fu64i_GetAVMM_seq



int QUCPU_Uclock::fi_AvmmReadModifyWriteVerify(uint64_t u64i_AvmmAdr,
                                                       uint64_t u64i_AvmmDat,
                                                       uint64_t u64i_AvmmMsk)
{ // Private: QUCPU_Uclock::fi_AvmmReadModifyWriteVerify
  int      i_ReturnErr;
  uint64_t u64i_VerifyData;
  i_ReturnErr = fi_AvmmReadModifyWrite(u64i_AvmmAdr, u64i_AvmmDat, u64i_AvmmMsk);

  if (i_ReturnErr == 0)
    { // Read back the data and verify mask-enabled bits
      i_ReturnErr = fi_AvmmRead(u64i_AvmmAdr, &u64i_VerifyData);

      if (i_ReturnErr == 0)
        { // Perform verify
          if ((u64i_VerifyData & u64i_AvmmMsk) != (u64i_AvmmDat & u64i_AvmmMsk))
            { // Verify failure
              i_ReturnErr = QUCPU_INT_UCLOCK_AVMMRMWV_ERR_VERIFY;
            } // Verify failure
        } // Perform verify
    } // Read back the data and verify mask-enabled bits

  return(i_ReturnErr);
} // Private: QUCPU_Uclock::fi_AvmmReadModifyWriteVerify



int QUCPU_Uclock::fi_AvmmReadModifyWrite(uint64_t u64i_AvmmAdr,
                                         uint64_t u64i_AvmmDat,
                                         uint64_t u64i_AvmmMsk)
{ // Private: QUCPU_Uclock::fi_AvmmReadModifyWrite
  uint64_t u64i_ReadData,u64i_WriteData;
  int      i_ReturnErr;

  // Read data
  i_ReturnErr = fi_AvmmRead(u64i_AvmmAdr, &u64i_ReadData);

  if (i_ReturnErr == 0)
    { // Modify the read data and write it
      u64i_WriteData = (u64i_ReadData & ~u64i_AvmmMsk) | (u64i_AvmmDat & u64i_AvmmMsk);
      i_ReturnErr    = fi_AvmmWrite(u64i_AvmmAdr, u64i_WriteData);
    } // Modify the read data and write it

  return(i_ReturnErr);
} // Private: QUCPU_Uclock::fi_AvmmReadModifyWrite



int QUCPU_Uclock::fi_AvmmRWcom(int           i_CmdWrite,
                               uint64_t   u64i_AvmmAdr,
                               uint64_t   u64i_WriteData,
                               uint64_t *pu64i_ReadData)
{ // Private: QUCPU_Uclock::fi_AvmmRWcom
  uint64_t u64i_SeqCmdAddrData,u64i_SeqCmdAddrData_seq_2,u64i_SeqCmdAddrData_wrt_1;
  uint64_t u64i_SeqCmdAddrData_adr_10,u64i_SeqCmdAddrData_dat_32;
  uint64_t u64i_PrtAddr,u64i_PrtData;
  uint64_t u64i_DataX;
  uint64_t u64i_FastPoll,u64i_SlowPoll;
  long int li_sleep_nanoseconds;
  int      i_ReturnErr;

  // Assume return error okay, for now
  i_ReturnErr = 0;

  // Common portion
  u64i_SeqCmdAddrData_seq_2  = fu64i_GetAVMM_seq();
  u64i_SeqCmdAddrData_adr_10 = u64i_AvmmAdr;

  if (i_CmdWrite == 1)
    { // Write data
      u64i_SeqCmdAddrData_wrt_1  = 0x1LLU;
      u64i_SeqCmdAddrData_dat_32 = u64i_WriteData;
    } // Write data
  else
    { // Read data
      u64i_SeqCmdAddrData_wrt_1  = 0x0LLU;
      u64i_SeqCmdAddrData_dat_32 = 0x0LLU;
    } // Read data

  u64i_SeqCmdAddrData =  (u64i_SeqCmdAddrData_seq_2  & 0x00000003LLU) << 48  // [49:48]
                       | (u64i_SeqCmdAddrData_wrt_1  & 0x00000001LLU) << 44  // [   44]
                       | (u64i_SeqCmdAddrData_adr_10 & 0x000003ffLLU) << 32  // [41:32]
                       | (u64i_SeqCmdAddrData_dat_32 & 0xffffffffLLU) <<  0; // [31:00]

  u64i_cmd_reg_0   &= ~QUCPU_UI64_CMD_0_AMM_b51t00;
  u64i_cmd_reg_0   |=  u64i_SeqCmdAddrData;

  // Write register 0 to kick it off
  u64i_PrtAddr      = QUCPU_UI64_PRT_UCLK_CMD_0;
  u64i_PrtData      = u64i_cmd_reg_0;
  fv_PrtMmioWrite(u64i_PrtAddr,u64i_PrtData);

  // Poll register 0 for completion.
  // CCI is synchronous and needs only 1 read with matching sequence.
  u64i_PrtAddr      = QUCPU_UI64_PRT_UCLK_STS_0;
  for (u64i_SlowPoll=0; u64i_SlowPoll<100; ++u64i_SlowPoll)  // 100 ms
    { // Poll 0, slow outer loop with 1 ms sleep
      for (u64i_FastPoll=0; u64i_FastPoll<100; ++u64i_FastPoll)
        { // Poll 0, fast inner loop with no sleep
          u64i_DataX = fu64i_PrtMmioRead(u64i_PrtAddr);
          if (   (u64i_DataX & QUCPU_UI64_STS_0_SEQ_b49t48) == (u64i_SeqCmdAddrData & QUCPU_UI64_STS_0_SEQ_b49t48) )
            { // Have result
              goto GOTO_LABEL_HAVE_RESULT;
            } // Have result
        } // Poll 0, fast inner loop with no sleep

      // Sleep 1 ms
      li_sleep_nanoseconds=1000000;
      fv_SleepShort(li_sleep_nanoseconds);
    } // Poll 0, slow outer loop with 1 ms sleep

  i_ReturnErr = QUCPU_INT_UCLOCK_AVMMRWCOM_ERR_TIMEOUT; // Error

  GOTO_LABEL_HAVE_RESULT:                               // No error

  if (i_CmdWrite == 0) *pu64i_ReadData = u64i_DataX;
  return(i_ReturnErr);
} // Private: QUCPU_Uclock::fi_AvmmRWcom



int QUCPU_Uclock::fi_AvmmRead(uint64_t u64i_AvmmAdr, uint64_t *pu64i_ReadData)
{ // Private: QUCPU_Uclock::fi_AvmmRead
  int         i_CmdWrite;
  uint64_t u64i_WriteData;
  int         i_ReturnErr;

  // Perform read with common code
  i_CmdWrite     = 0;
  u64i_WriteData = 0; // Not used for read
  i_ReturnErr    = fi_AvmmRWcom(i_CmdWrite, u64i_AvmmAdr, u64i_WriteData, pu64i_ReadData);

  // Return error status
  return(i_ReturnErr);
} // Private: QUCPU_Uclock::fi_AvmmRead



int QUCPU_Uclock::fi_AvmmWrite(uint64_t u64i_AvmmAdr, uint64_t u64i_WriteData)
{ // Private: QUCPU_Uclock::fi_AvmmWrite
  int         i_CmdWrite;
  uint64_t u64i_ReadData;  // Read data is not used
  int         i_ReturnErr;

  // Perform write with common code
  i_CmdWrite     = 1;
  i_ReturnErr    = fi_AvmmRWcom(i_CmdWrite, u64i_AvmmAdr, u64i_WriteData, &u64i_ReadData);

  // Return error status
  return(i_ReturnErr);
} // Private: QUCPU_Uclock::fi_AvmmWrite



void QUCPU_Uclock::fv_SleepShort(long int li_sleep_nanoseconds)
{ // Private: QUCPU_Uclock::fv_SleepShort
  // Sleep for nanoseconds

  struct timespec timespecRemaining;
  struct timespec timespecWait;

  int i_RetVal;

  timespecRemaining.tv_nsec = li_sleep_nanoseconds; timespecRemaining.tv_sec=0;

  do
    { // Wait, and retry if wait ended early
      timespecWait = timespecRemaining;
      i_RetVal = nanosleep(&timespecWait, &timespecRemaining);
      if (i_RetVal != 0  && i_RetVal != -1)
        { // BUG: unexpected nanosleep return value
          fv_BugLog(QUCPU_INT_UCLOCK_BUG_SLEEP_SHORT);
        } // BUG: unexpected nanosleep return value
    } // Wait, and retry if wait ended early
      while (i_RetVal != 0);

  return;
} // Private: QUCPU_Uclock::fv_SleepShort



void QUCPU_Uclock::fv_BugLog(int i_BugID)
{ // Private: QUCPU_Uclock::fv_BugLog
  // Log first and last bugs

  if (i_Bug_First)
    { // This is not the first bug
      i_Bug_Last = i_BugID;
    } // This is not the first bug
  else
    { // This is the first bug
      i_Bug_First = i_BugID;
    } // This is the first bug

  return;
} // Private: QUCPU_Uclock::fv_BugLog
