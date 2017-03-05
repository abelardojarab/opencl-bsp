// Copyright(c) 2006-2016, Intel Corporation
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
/// @file aal_6.2.1_skx-p_user_clk.cpp
/// @brief AAL application for the programmable user clock.
/// @ingroup aal_6.2.1_skx-p_user_clk
/// @verbatim
///   This is the AAL application for the programmable user clock.
///
/// AUTHOR: Arthur.Sheiman, Intel Corporation
///
/// HISTORY:
/// WHEN:          WHO:     WHAT:
/// 01/04/2006     AS       Initial version started @endverbatim


//****************************************************************************
//
// aal_6.2.1_skx-p_user_clk.cpp: bdx-p & skx-p user clock
// Copyright Intel 2016
// Arthur.Sheiman@Intel.com   Created: 03-31-16
// Revised: 10-29-16  01:15
//
// main module program for programmable user clock
//
//   This is the AAL application for the programmable user clock.
//
//   AAL Notes and acknowledgements:
//     This makes use of the AAL example programs:
//       1) Hello_ALI_NLB, authored by Joe Grecco.
//       2) simple_app,    authored by Enno Luebbers.
//          (NOTE: Enno has useful video training material that
//                 describes Simple App).
//       3) fpgadiag,      authored by Tim Whisonant, Joe Grecco, and Sadruta Chandrashekar.
//     AAL framework code is copied.
//
//****************************************************************************



#include "qph_user_clk_pgm_Uclock_aal.hpp"

#include <aalsdk/service/IALIAFU.h>



// Prototypes
int  fi_DisplayFrequencies         (QUCPU_Uclock *pUclock_AFU);
void fv_Help                       (QUCPU_tInitz tInitz_retInitz);




// Equates
#if defined(DEF_BDX_P)
  // BDX-P:
  const char                   gac_BDX_SKX_string[4]                                = {"bdx"};

#elif defined(DEF_SKX_P)
  // SKX-P:
  const char                   gac_BDX_SKX_string[4]                                = {"skx"};
#endif

#define QUCPM_INT_NUM_OF_AFUS                                    ((int)1)                          // Number of AFUs


using namespace std;
using namespace AAL;

// Convenience macros for printing messages and errors.
#ifdef MSG
# undef MSG
#endif // MSG
#define MSG(x) std::cout << __AAL_SHORT_FILE__ << ':' << __LINE__ << ':' << __AAL_FUNC__ << "() : " << x << std::endl
#ifdef ERR
# undef ERR
#endif // ERR
#define ERR(x) std::cerr << __AAL_SHORT_FILE__ << ':' << __LINE__ << ':' << __AAL_FUNC__ << "() **Error : " << x << std::endl


// Class for the primary application
class aal_6_2_1_skx_p_user_clk: public CAASBase, public IRuntimeClient, public IServiceClient
{
public:
   aal_6_2_1_skx_p_user_clk();           // Constructor
   ~aal_6_2_1_skx_p_user_clk();          // Destructor
   btInt run(int i_Argc, char **apc_Argv);  // Primary function. Returns error code on exit.

   // <begin IServiceClient interface>  // AES: Updated to 6.2.1
   void serviceAllocated(IBase *pServiceBase, TransactionID const &rTranID);
   void serviceAllocateFailed(const IEvent &rEvent);
   void serviceReleased(TransactionID const &rTranID);
   void serviceReleaseRequest(IBase *pServiceBase, const IEvent &rEvent);
   void serviceReleaseFailed(const IEvent &rEvent);
   void serviceEvent(const IEvent &rEvent);
   // <end IServiceClient interface>

   // <begin IRuntimeClient interface>  // AES: Updated to 6.2.1
   void runtimeCreateOrGetProxyFailed(IEvent const &rEvent);    // AES: Changed to used
   void runtimeStarted(IRuntime *pRuntime, const NamedValueSet &rConfigParms);
   void runtimeStopped(IRuntime *pRuntime);
   void runtimeStartFailed(const IEvent &rEvent);
   void runtimeStopFailed(const IEvent &rEvent);
   void runtimeAllocateServiceFailed( IEvent const &rEvent);
   void runtimeAllocateServiceSucceeded(IBase *pClient, TransactionID const &rTranID);
   void runtimeEvent(const IEvent &rEvent);
   btBool isOK()  {return m_bIsOK;}
   // <end IRuntimeClient interface>

protected:
   IBase         *m_pALIAFU_AALService;     ///< The generic AAL Service interface for the AFU.
   Runtime        m_Runtime;                ///< AAL Runtime
   IALIMMIO      *m_pALIMMIOService;        ///< Pointer to MMIO Service
   IALIReset     *m_pALIResetService;       ///< Pointer to AFU Reset Service
   CSemaphore     m_Sem;                    ///< For synchronizing with the AAL runtime.
   btInt          m_Result;                 ///< Returned result value; 0 if success
};


// Constructor
aal_6_2_1_skx_p_user_clk::aal_6_2_1_skx_p_user_clk() :
  m_pALIAFU_AALService(NULL),
  m_Runtime(this),
  m_pALIMMIOService(NULL),
  m_pALIResetService(NULL),
  m_Result(0)
{ // aal_6_2_1_skx_p_user_clk::aal_6_2_1_skx_p_user_clk
  SetInterface(iidServiceClient, dynamic_cast<IServiceClient *>(this));
  SetInterface(iidRuntimeClient, dynamic_cast<IRuntimeClient *>(this));
  m_Sem.Create(0, 1);
  NamedValueSet configArgs;
  NamedValueSet configRecord;
  configRecord.Add(AALRUNTIME_CONFIG_BROKER_SERVICE, "librrmbroker");
  configArgs.Add(AALRUNTIME_CONFIG_RECORD, &configRecord);
  if(!m_Runtime.start(configArgs))
    {
      m_bIsOK = false;
      return;
    }
  m_Sem.Wait();
  m_bIsOK = true;
} // aal_6_2_1_skx_p_user_clk::aal_6_2_1_skx_p_user_clk


// Destructor
aal_6_2_1_skx_p_user_clk::~aal_6_2_1_skx_p_user_clk()
{ // aal_6_2_1_skx_p_user_clk::~aal_6_2_1_skx_p_user_clk
  m_Runtime.stop(); // AES added to 6.2.1
  m_Sem.Destroy();
} // aal_6_2_1_skx_p_user_clk::~aal_6_2_1_skx_p_user_clk


// The primary function
btInt aal_6_2_1_skx_p_user_clk::run(int i_Argc, char **apc_Argv)
{ // btInt aal_6_2_1_skx_p_user_clk::run
  NamedValueSet Manifest;
  NamedValueSet ConfigRecord;

  ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_SERVICE_NAME, "libALI");
  ConfigRecord.Add(keyRegAFU_ID,"3AB49893-138D-42EB-9642-B06C6B355B87"); // 1st Port
  Manifest.Add(AAL_FACTORY_CREATE_CONFIGRECORD_INCLUDED, &ConfigRecord);
  Manifest.Add(AAL_FACTORY_CREATE_SERVICENAME, "USER_CLOCK");

  m_Runtime.allocService(dynamic_cast<IBase *>(this), Manifest);
  m_Sem.Wait();
  if(!m_bIsOK)
    { // Error, allocation failed.
      ERR("ALIAFU allocation failed\n");
      exit(1);
    } // Error, allocation failed.

  if(true == m_bIsOK)
    { // Run test
      IALIMMIO                *pALIMMIOService;                          // MMIO service pointer
      int                     i_afu_inx;                                 // AFU index: 0=AFU-0, 1=AFU-1, etc
      int                     i_rck_inx;                                 // REFCLK index: 0=100 MHz SYSCLK, 1=322.265625 MHz
      int                     i_frq_inx;                                 // Frequency index, see fv_Help()
      uint64_t               *pau64i_PRTbaseAddr[QUCPM_INT_NUM_OF_AFUS];
      QUCPU_tInitz            atInitz_retInitz[QUCPM_INT_NUM_OF_AFUS];   // Initialization parameters
      int                     i_RetErrorCode;
      int                     i_errno_afu_inx,   i_errno_rck_inx,    i_errno_frq_inx;
      int                     i_I;
    
      // MMIO access.
      pALIMMIOService = m_pALIMMIOService;
    
      // Set Port base addresses for each AFUs; Port+AFU spaced 512 KiB, 64 KIQW (QWORDS)
      for (i_I  = 0;  i_I < QUCPM_INT_NUM_OF_AFUS;  ++i_I)
        { // Set Port base address for this AFU
          pau64i_PRTbaseAddr[i_I]= (uint64_t*)(i_I * 0x10000);
        } // Set Port base address for this AFU
    
    
      // Instantiate the User Clock for AFUs, then initialize
      QUCPU_Uclock Uclock_AFU[QUCPM_INT_NUM_OF_AFUS]; 
      for (i_I  = 0;  i_I < QUCPM_INT_NUM_OF_AFUS;  ++i_I)
        { // Instantiate each user clock )
          i_RetErrorCode = Uclock_AFU[i_I].fi_RunInitz(pau64i_PRTbaseAddr[i_I],
                                                       pALIMMIOService,
                                                      &atInitz_retInitz[i_I]);
          if (i_RetErrorCode)
            { // ERROR: User clock initialization failed
              printf("main: ERROR: User clock initialization failed on AFU #%d.\n"
                     "      %s\n"
                     ,i_I,Uclock_AFU[i_I].fpac_GetErrMsg(i_RetErrorCode));
              exit(1);
            } // ERROR: User clock initialization failed
        } // Instantiate each user clock )
    
    
      // Default arguments
      i_afu_inx       =   0; // AFU index, i.e., which AFU for multi-AFU
      i_rck_inx       =  -1; // -1 is special flag to just read the current frequency and end
      i_frq_inx       =   0;
      i_errno_afu_inx = i_errno_rck_inx = i_errno_frq_inx = 0; // No error
    
      // Parse command line settings
      if (i_Argc < 1)
        { // ERROR: Unknown i_Argc error
          printf("main: ERROR: Unknown i_Argc error.\n");
          exit(1);
        } // ERROR: Unknown i_Argc error
      else if (    i_Argc < 3   // 1 or 2 (0 or 1 after executable)
                || i_Argc > 4 ) // 5 & up (4 & up after executable)
        { // Incorrect number of arguments. Error help
          fv_Help(atInitz_retInitz[0]);
          exit(1);
        } // Incorrect number of arguments. Error help
      else if (    i_Argc >= 2+1
    	    && i_Argc <= 3+1 )
        { // Collect arguments, 2 or 3 after executable
          i_errno_afu_inx = errno = 0;  i_afu_inx = (int)strtol(apc_Argv[1 +  0],NULL,10);
    
          i_errno_rck_inx = errno = 0;  i_rck_inx = (int)strtol(apc_Argv[2 +  0],NULL,10);
    
          if (i_Argc == 3+1)
            { // Frequemcy index is specified
              i_errno_frq_inx = errno = 0;  i_frq_inx = (int)strtol(apc_Argv[3 +  0],NULL,10);
            } // Frequemcy index is specified
        } // Collect arguments, 2 or 3 after executable
      else
        { // BUG: 000
          printf("main: BUG: 000.\n");
          exit(1);
        } // BUG: 000
    
      if (i_errno_afu_inx || i_errno_rck_inx || i_errno_frq_inx)
        { // Argument conversion error
          printf("main: ERROR: Command line afgument conversion error(s).\n");
          if (i_errno_afu_inx) printf("             AFU       index unreadable.\n");
          if (i_errno_rck_inx) printf("             REFCLK    index unreadable.\n");
          if (i_errno_frq_inx) printf("             Frequency index unreadable.\n");
          exit(1);
        } // Argument conversion error
    
    
    
      // Display requested settings
      printf("Requested Program Mode Settings:\n"
              "  afu       index  = %d.\n"
              "  ref-clock index  = %d.\n"
      	  ,i_afu_inx,i_rck_inx);
      if (i_Argc == 3+1) printf("  frequency index  = %d.\n"
    	                   ,i_frq_inx);
      printf("\n");
    
    
    
      // Check settings
      if (    i_afu_inx  < 0
           || i_afu_inx >= QUCPM_INT_NUM_OF_AFUS )
        { // Illegal AFU index
          printf("main: ERROR: Illegal AFU index = %d.\n",i_afu_inx);
          exit(1);
        } // Illegal AFU index
    
      if (i_Argc == 2+1) // 2 after executable
        { // -1 allowed for REFCLK index to read frequency
          if (i_rck_inx != -1)
            { // Error with request to read frequency
              printf("main: ERROR: To read frequency use REFLCK index = -1.\n");
              exit(1);
            } // Error with frequency index
        } // -1 allowed for REFCLK index to read frequency
      else
        { // Check REFCLK and frequency index for normal operation
          if (    i_rck_inx < 0
               || i_frq_inx < 0 )
            { // Error due to negative index
              printf("main: ERROR: Indices must be non-negative to set frequency.\n");
              exit(1);
            } // Error due to negative index
        } // Check REFCLK and frequency index for normal operation
    
    
    
      fflush(stdout);
    
    
    
      // Initial frequency
      printf("Initial frequency: \n");
    
      i_RetErrorCode = fi_DisplayFrequencies(&Uclock_AFU[i_afu_inx]);
      if (i_RetErrorCode)
        { // ERROR: Could not display frequencies
          printf("main: ERROR: Could not display frequencies.\n"
                 "      %s\n"
                 ,Uclock_AFU[i_I].fpac_GetErrMsg(i_RetErrorCode));
          exit(1);
        } // ERROR: Could not display frequencies
      printf("\n");
    
    
    
      // Set the frequency, if frequency index supplied
      if ((i_Argc == 3+1))
        { // Update the frequency
          i_RetErrorCode = Uclock_AFU[i_afu_inx].fi_SetFreqs((uint64_t)i_rck_inx, (uint64_t)i_frq_inx);
          if (i_RetErrorCode)
            { // ERROR: Could not set frequencies
              printf("main: ERROR: Could not set frequencies.\n"
                     "      %s\n"
                     ,Uclock_AFU[i_I].fpac_GetErrMsg(i_RetErrorCode));
              exit(1);
            } // ERROR: Could not set frequencies
    
    
          // Updated frequency
          printf("Updated frequency: \n");
    
          i_RetErrorCode = fi_DisplayFrequencies(&Uclock_AFU[i_afu_inx]);
          if (i_RetErrorCode)
            { // ERROR: Could not display frequencies
              printf("main: ERROR: Could not display frequencies.\n"
                     "      %s\n"
                     ,Uclock_AFU[i_I].fpac_GetErrMsg(i_RetErrorCode));
              exit(1);
            } // ERROR: Could not display frequencies
        } // Update the frequency
    
    } // Run test

  (dynamic_ptr<IAALService>(iidService, m_pALIAFU_AALService))->Release(TransactionID());
  m_Sem.Wait();


  m_Runtime.stop();
  m_Sem.Wait();

  if (m_Result)
    { // Abnormal termination
      printf("\n!!! ABNORMAL TERMINATION !!!\n"
               "    m_Result = %ld.\n",(long int)m_Result);
      exit(1);
    } // Abnormal termination
  else
    { // Normal termination
      printf("\nNormal termination.\n");
    } // Normal termination

  return m_Result;
} // btInt aal_6_2_1_skx_p_user_clk::run


//=================
//  IServiceClient
//=================

// <begin IServiceClient interface>  // AES: Updated to 6.2.1
void aal_6_2_1_skx_p_user_clk::serviceAllocated(IBase *pServiceBase, TransactionID const &rTranID)
{
   // Save the IBase for the Service. Through it we can get any other
   //  interface implemented by the Service
   m_pALIAFU_AALService = pServiceBase;
   ASSERT(NULL != m_pALIAFU_AALService);
   if ( NULL == m_pALIAFU_AALService ) {
      m_bIsOK = false;
      return;
   }

   // Documentation says HWALIAFU Service publishes
   //    IALIMMIO and IALIReset as subclass interface.
   m_pALIMMIOService = dynamic_ptr<IALIMMIO>(iidALI_MMIO_Service, pServiceBase);
   ASSERT(NULL != m_pALIMMIOService);
   if ( NULL == m_pALIMMIOService ) {
      m_bIsOK = false;
      return;
   }

   m_Sem.Post(1);
}

void aal_6_2_1_skx_p_user_clk::serviceAllocateFailed(const IEvent &rEvent)
{
   ERR("Failed to allocate Service");
    PrintExceptionDescription(rEvent);
   ++m_Result;                     // Remember the error
   m_bIsOK = false;

   m_Sem.Post(1);
}

 void aal_6_2_1_skx_p_user_clk::serviceReleased(TransactionID const &rTranID)
{
   // Unblock Main()
   m_Sem.Post(1);
}

 void aal_6_2_1_skx_p_user_clk::serviceReleaseRequest(IBase *pServiceBase, const IEvent &rEvent)
  {  // AES: Updated to 6.2.1  // From TempPowMon.cpp, but updated IBase pointer name
     MSG("Service unexpected requested back");
     if(NULL != m_pALIAFU_AALService){
        IAALService *pIAALService = dynamic_ptr<IAALService>(iidService, m_pALIAFU_AALService);
        ASSERT(pIAALService);
        pIAALService->Release(TransactionID());
     }
  }

 void aal_6_2_1_skx_p_user_clk::serviceReleaseFailed(const IEvent        &rEvent)
 {
    ERR("Failed to release a Service");
    PrintExceptionDescription(rEvent);
    m_bIsOK = false;
    m_Sem.Post(1);
 }


 void aal_6_2_1_skx_p_user_clk::serviceEvent(const IEvent &rEvent)
{
   ERR("unexpected event 0x" << hex << rEvent.SubClassID());
   // The state machine may or may not stop here. It depends upon what happened.
   // A fatal error implies no more messages and so none of the other Post()
   //    will wake up.
   // OTOH, a notification message will simply print and continue.
}
// <end IServiceClient interface>


 //=================
 //  IRuntimeClient
 //=================

  // <begin IRuntimeClient interface>  // AES: Updated to 6.2.1
 // Because this simple example has one object implementing both IRuntieCLient and IServiceClient
 //   some of these interfaces are redundant. We use the IServiceClient in such cases and ignore
 //   the RuntimeClient equivalent e.g.,. runtimeAllocateServiceSucceeded()

void aal_6_2_1_skx_p_user_clk::runtimeCreateOrGetProxyFailed(IEvent const &rEvent)
{  // AES: Updated to 6.2.1  // From TempPowMon.cpp
   MSG("Runtime Create or Get Proxy failed");
   m_bIsOK = false;
   m_Sem.Post(1);
}

 void aal_6_2_1_skx_p_user_clk::runtimeStarted( IRuntime            *pRuntime,
                                      const NamedValueSet &rConfigParms)
 {
    m_bIsOK = true;
    m_Sem.Post(1);
 }

 void aal_6_2_1_skx_p_user_clk::runtimeStopped(IRuntime *pRuntime)
  {
     m_bIsOK = false;
     m_Sem.Post(1);
  }

 void aal_6_2_1_skx_p_user_clk::runtimeStartFailed(const IEvent &rEvent)
 {
    ERR("Runtime start failed");
    PrintExceptionDescription(rEvent);
 }

 void aal_6_2_1_skx_p_user_clk::runtimeStopFailed(const IEvent &rEvent)
 {
     ERR("Runtime stop failed");
     m_bIsOK = false;
     m_Sem.Post(1);
 }

 void aal_6_2_1_skx_p_user_clk::runtimeAllocateServiceFailed( IEvent const &rEvent)
 {
    ERR("Runtime AllocateService failed. Is the AFUID correct and found?");
    PrintExceptionDescription(rEvent);
 }

 void aal_6_2_1_skx_p_user_clk::runtimeAllocateServiceSucceeded(IBase *pClient,
                                                     TransactionID const &rTranID)
 {
     //MSG("Runtime Allocate Service Succeeded");
 }

 void aal_6_2_1_skx_p_user_clk::runtimeEvent(const IEvent &rEvent)
 {
     //MSG("Generic message handler (runtime)");
 }
 // <begin IRuntimeClient interface>



int main(int i_Argc, char **apc_Argv)
{
  // Sign on with parameters*/
  printf("%s-p_user_clk: %s-p user clock program\n"
         "Copyright Intel 2016\n"
//         "Arthur.Sheiman@Intel.com   Created: 03-04-16\n"
         "Revised: 10-29-16  01:15\n\n",gac_BDX_SKX_string,gac_BDX_SKX_string);

  // Consruct the application
  aal_6_2_1_skx_p_user_clk aal_6_2_1_skx_p_user_clk_application;

  if(!aal_6_2_1_skx_p_user_clk_application.isOK())
    { // Error, runtime failed to start
      printf("\nmain: ERROR: Runtime Failed to Start. DID YOU LOAD THE CCI DRIVER???\n");
      exit(1);
    } // Error, runtime failed to start

  // Application is ready, start it
  btInt Result = aal_6_2_1_skx_p_user_clk_application.run(i_Argc, apc_Argv);

  return Result;
}



int fi_DisplayFrequencies(QUCPU_Uclock *pUclock_AFU)
{ // fi_DisplayFrequencies
  QUCPU_tFreqs            tFreqs_retFreqs;    // Frequency read in Hz of user clock
  double                  dFreqMHz_Low,dFreqMHz_High;
  int                     i_RetErrorCode;

  i_RetErrorCode = pUclock_AFU->fi_GetFreqs(&tFreqs_retFreqs);
  if (i_RetErrorCode == 0)
    { // No error, so display it
      dFreqMHz_Low  = (double)tFreqs_retFreqs.u64i_Frq_DivBy2 / 1.0e6;
      dFreqMHz_High = (double)tFreqs_retFreqs.u64i_Frq_ClkUsr / 1.0e6;
      printf("  Approximate frequency:\n"
             "    High clock = %5.1f MHz\n"
             "    Low  clock = %5.1f MHz\n",
             dFreqMHz_High,dFreqMHz_Low);
    } // No error, so display it
  return (i_RetErrorCode);
} // fi_DisplayFrequencies



void fv_Help(QUCPU_tInitz tInitz_retInitz)
{ // fv_Help
  printf("\n"
         "HELP: Command line arguments:\n"
         "  Usage:\n"
         "    ./%s-p_user_clk.bin <afu_number {0..N-1}>  <refclk {0, 1}>  <freq_index {0..%d}>\n"
         "\n"
         "  Example: Display help:\n"
         "    ./%s-p_user_clk.bin\n"
         "\n"
         "  Example: Read current frequency from AFU #2 (third AFU):\n"
         "    ./%s-p_user_clk.bin 2 -1\n"
         "  NOTE: Frequency Counter reference is SYSCLK.\n"
         "        If SSC is on, then SYSCLK is about 1/4%% low, so for 322.65625 MHz\n"
         "        reference clock, frequency will read high by about 1/4%%.\n"
         "        For 100 MHz reference clock, it is same as SYSCLK, so frequency\n"
         "        will read correct, but average frequency will be 1/4%% low.\n"
         "        Additinoal errors:  +/- 1 count;   SYSCLK frequency accuracy.\n"
         "        Resolution is 10 kHz.\n"
         "\n"
         "  Example: Using 322.265625 MHz reference, AFU #3 (4th) generates EXACT 257.812500 MHz clock:\n"
         "    ./%s-p_user_clk.bin 3 1 0\n"
         "\n"
         "  Example: Using 322.265625 MHz reference, AFU #0 (1st) generates EXACT 312.500000 MHz clock:\n"
         "    ./%s-p_user_clk.bin 0 1 1\n"
         "\n"
         "  Example: Using 322.265625 MHz reference, AFU #3 (3rd) generates EXACT 322.265625 MHz clock:\n"
         "    ./%s-p_user_clk.bin 3 1 2\n"
         "\n"
         "  Example: Using 322.265625 MHz reference, AFU #0 (1st) generates APPROXIMATE  231 MHz clock:\n"
         "    ./%s-p_user_clk.bin 0 1 231\n"
         "  NOTE: Range is %d MHz to %d MHz.\n"
         "\n"
         "  Example: Using SYSCLK 100 MHz reference, AFU #1 (2nd) generates APPROXIMATE  357 MHz clock:\n"
         "    ./%s-p_user_clk.bin 1 0 357\n"
         "  NOTE: Range is %d MHz to %d MHz.\n"
         "        If SSC is on, then average frequency is about 1/4%% low.\n"
         "        Use of 322.265625 MHz reference is preferred.\n"
         "        Some motherboards do not support the 322.265625 MHz reference\n"
         "        to 1 or more sockets.\n"
         "\n"
         ,gac_BDX_SKX_string,(int)tInitz_retInitz.u64i_NumFrq_Frac_End,gac_BDX_SKX_string,gac_BDX_SKX_string
         ,gac_BDX_SKX_string,gac_BDX_SKX_string,gac_BDX_SKX_string,gac_BDX_SKX_string
         ,(int)tInitz_retInitz.u64i_NumFrq_Frac_Beg,(int)tInitz_retInitz.u64i_NumFrq_Frac_End
         ,gac_BDX_SKX_string,(int)tInitz_retInitz.u64i_NumFrq_Frac_Beg,(int)tInitz_retInitz.u64i_NumFrq_Frac_End);

  return;
} // fv_Help
