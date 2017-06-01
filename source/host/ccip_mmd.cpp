// Copyright(c) 2007-2016, Intel Corporation
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
/// @file HelloALIVTPNLB.cpp
/// @brief Basic ALI AFU interaction.
/// @ingroup HelloALIVTPNLB
/// @verbatim
/// Intel(R) Accelerator Abstraction Layer Sample Application
///
///    This application is for example purposes only.
///    It is not intended to represent a model for developing commercially-
///       deployable applications.
///    It is designed to show working examples of the AAL programming model and APIs.
///
/// AUTHORS: Joseph Grecco, Intel Corporation.
///
/// This Sample demonstrates how to use the basic ALI APIs including VTP.
///
/// This sample is designed to be used with the xyzALIAFU Service.
///
/// HISTORY:
/// WHEN:          WHO:     WHAT:
/// 12/15/2015     JG       Initial version started based on older sample code.@endverbatim
//****************************************************************************
#include <aalsdk/AALTypes.h>
#include <aalsdk/Runtime.h>
#include <aalsdk/AALLoggerExtern.h>

#include <aalsdk/service/IALIAFU.h>
#include <aalsdk/aalclp/aalclp.h>
#include "aalsdk/mpf/IMPF.h"

#include <string.h>
#include "aocl_mmd.h"
#include "pkg_editor.h"
//****************************************************************************
// UN-COMMENT appropriate #define in order to enable either Hardware or ASE.
//    DEFAULT is to use Software Simulation.
//****************************************************************************


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

// Print/don't print the event ID's entered in the event handlers.
#if 1
# define EVENT_CASE(x) case x : MSG(#x);
#else
# define EVENT_CASE(x) case x :
#endif

#ifndef CL
# define CL(x)                     ((x) * 64)
#endif // CL
#ifndef LOG2_CL
# define LOG2_CL                   6
#endif // LOG2_CL
#ifndef MB
# define MB(x)                     ((x) * 1024 * 1024)
#endif // MB

#define LPBK1_BUFFER_OFFSET      (0)

#define LPBK1_DSM_SIZE           MB(4)
#define CSR_SRC_ADDR             0x0120
#define CSR_DST_ADDR             0x0128
#define CSR_CTL                  0x0138
#define CSR_CFG                  0x0140
#define CSR_NUM_LINES            0x0130
#define DSM_STATUS_TEST_COMPLETE 0x40
#define CSR_AFU_DSM_BASEL        0x0110
#define CSR_AFU_DSM_BASEH        0x0114
#	define NLB_TEST_MODE_PCIE0		0x2000

#define CCIP_FME_AFUID              "BFAF2AE9-4A52-46E3-82FE-38F0F9E17764"
#define DEBUG_PRINT(...) printf(__VA_ARGS__)
#define HW_LOCK ;
#define HW_UNLOCK ;

#ifdef SIM

//#define SLOW
#define  ASEAFU
#define WORKSPACE_SIZE        (MB(64))


#define DEBUG_PRINT(...) printf(__VA_ARGS__)
#define SPEED_LIMIT()  SleepMicro(1000)
#define INIT_SPEED_LIMIT()  SleepMicro(2000*1000)
#else
#define  HWAFU


//#define SLOW
#define WORKSPACE_SIZE        (GB(4))
#define WORKSPACE_SIZE        (MB(64))
#define WORKSPACE_SIZE        (GB(1))
#define DEBUG_PRINT(...) printf(__VA_ARGS__)
#define DEBUG_PRINT(...)
#define SPEED_LIMIT() 
#define SPEED_LIMIT()  SleepMicro(1000)
#define INIT_SPEED_LIMIT()  SleepMicro(1000)

#endif


#define DCP_DEBUG_MEM(...) 
//#define DCP_DEBUG_MEM(...) printf(__VA_ARGS__)


#define NO_FME_SUPPORT



//#define AOCL_IRQ_POLLING_BASE (0x1000)

#define MMDHANDLE 1


//#define NO_VTP_INIT



#define HW_LOCK ;
#define HW_UNLOCK ;


//#define DISABLE_MPF



#define DISABLE_PR
// Define handle values for kernel, kernel_clk (pLL), and global memory
typedef enum {
  CCIP_DFH_RANGE = 0x0000,  
  AOCL_IRQ_POLLING_BASE = 0x0100,  
  QPI_ADDR_RANGE = 0x2000,  
  DEBUG_ADDR_RANGE = 0x3000,  
  AOCL_MMD_KERNEL = 0x4000,      /* Control interface into kernel interface */
  AOCL_MMD_MEMORY = 0x100000,      /* Data interface to device memory */
  AOCL_MMD_PLL = 0xb000,         /* Interface for reconfigurable PLL */
  AOCL_MMD_PR_BASE_ID = 0xcf80,
  AOCL_MMD_VERSION_ID = 0xcfc0
} aocl_mmd_interface_t;


static long unsigned int workspace_size;
int jtag_ndx;

// Kernel Interrup handler
aocl_mmd_interrupt_handler_fn kernel_interrupt = NULL;
void * kernel_interrupt_user_data;

aocl_mmd_status_handler_fn event_update = NULL;
void * event_update_user_data;

static int verbose;

// static helper functions
static bool check_for_svm_env();
static bool blob_has_elf_signature( void* data, size_t data_size );
int pr_base_id_test(unsigned int pr_import_version);

/// @addtogroup HelloALIVTPNLB
/// @{


/// @brief   Since this is a simple application, our App class implements both the IRuntimeClient and IServiceClient
///           interfaces.  Since some of the methods will be redundant for a single object, they will be ignored.
///
class CCIPMMD: public CAASBase, public IRuntimeClient, public IServiceClient, IALIReconfigure_Client
{
public:

   CCIPMMD();
   ~CCIPMMD();

   btInt open();      ///< Return 0 if success
   btInt close();     ///< Return 0 if success
   btInt reprogram(); ///< Return 0 if success

   // <begin IServiceClient interface>
   void serviceAllocated(IBase *pServiceBase,
                         TransactionID const &rTranID);

   void serviceAllocateFailed(const IEvent &rEvent);

   void serviceReleased(const AAL::TransactionID&);
   void serviceReleaseRequest(IBase *pServiceBase, const IEvent &rEvent);
   void serviceReleaseFailed(const AAL::IEvent&);

   void serviceEvent(const IEvent &rEvent);
   // <end IServiceClient interface>

   // <begin IRuntimeClient interface>
   void runtimeCreateOrGetProxyFailed(IEvent const &rEvent){};    // Not Used

   void runtimeStarted(IRuntime            *pRuntime,
                       const NamedValueSet &rConfigParms);

   void runtimeStopped(IRuntime *pRuntime);

   void runtimeStartFailed(const IEvent &rEvent);

   void runtimeStopFailed(const IEvent &rEvent);

   void runtimeAllocateServiceFailed( IEvent const &rEvent);

   void runtimeAllocateServiceSucceeded(IBase               *pClient,
                                        TransactionID const &rTranID);

   void runtimeEvent(const IEvent &rEvent);

   btBool isOK()  {return m_bIsOK;}
	 int MMIOWrite(size_t Addr, const void* buffer, size_t len);
	 int MMIORead(size_t Addr, void* buffer, size_t len);
	 int MMIOWriteFast(size_t Addr, const void* buffer, size_t len);
	 int MMIOReadFast(size_t Addr, void* buffer, size_t len);
	void getPerfCounters();
   void* bufferAlloc(size_t len);
   
   void bufferFree(void* ptr);
   void printStats();
   void* getWorkspace();
   // <end IRuntimeClient interface>

   // <IALIReconfigure_Client interface>
   virtual void deactivateSucceeded( TransactionID const &rTranID );
   virtual void deactivateFailed( IEvent const &rEvent );
   virtual void configureSucceeded( TransactionID const &rTranID );
   virtual void configureFailed( IEvent const &rEvent );
   virtual void activateSucceeded( TransactionID const &rTranID );
   virtual void activateFailed( IEvent const &rEvent );
   // <end IALIReconfigure_Client interface>

   void PrintReconfExceptionDescription(IEvent const &theEvent);

protected:
   Runtime        m_Runtime;                ///< AAL Runtime
   IBase         *m_pALIAFU_AALService;     ///< The generic AAL Service interface for the AFU.
   IBase         *m_pFMEService;       ///< The generic AAL Service interface for the AFU.
   IALIBuffer    *m_pALIBufferService;      ///< Pointer to Buffer Service
   IALIMMIO      *m_pALIMMIOService;        ///< Pointer to MMIO Service
   IALIReset     *m_pALIResetService;       ///< Pointer to AFU Reset Service
   IALIPerf      *m_pALIPerf;          ///< ALI Performance Monitor
   CSemaphore     m_Sem;                    ///< For synchronizing with the AAL runtime.
   btInt          m_Result;                 ///< Returned result value; 0 if success
   TransactionID  m_ALIAFUTranID;           ///< TransactionID used for service allocation

   // VTP service-related information
   IBase         *m_pVTP_AALService;        ///< The generic AAL Service interface for the VTP.
   IMPFVTP          *m_pVTPService;            ///< Pointer to VTP buffer service
   IMPFVCMAP         *m_pVCMAPService;     ///< Pointer to VC Map service
   IMPFWRO        *m_pWROService;
   TransactionID  m_WROTranID;
   //IMPFPWRITE     *m_pIMPFPWRITEService;
   btCSROffset    m_VTPDFHOffset;           ///< VTP DFH offset
   TransactionID  m_VTPTranID;              ///< TransactionID used for service allocation
   TransactionID  m_VCMAPTranID;              ///< TransactionID used for service allocation
   TransactionID  m_FMETranID;  

   // Reconfigure service-related information
   IBase         *m_pReconf_AALService;
   IALIReconfigure      *m_pALIReconfService; ///< Pointer to Buffer Service
   TransactionID  m_ReconfTranID;              ///< TransactionID used for service allocation

   // Workspace info
   btVirtAddr     m_pDSM;                   ///< DSM workspace virtual address.
   btWSSize       m_DSMSize;                ///< DSM workspace size in bytes.
   btVirtAddr     m_pWorkspace;                 ///< Input workspace virtual address.
   btWSSize       m_WorkspaceSize;              ///< Input workspace size in bytes.
   btVirtAddr     m_pOutput;                ///< Output workspace virtual address.
   btWSSize       m_OutputSize;             ///< Output workspace size in bytes.
};

///////////////////////////////////////////////////////////////////////////////
///
///  Implementation
///
///////////////////////////////////////////////////////////////////////////////

/// @brief   Constructor registers this objects client interfaces and starts
///          the AAL Runtime. The member m_bisOK is used to indicate an error.
///
CCIPMMD::CCIPMMD() :
   m_Runtime(this),
   m_pALIAFU_AALService(NULL),
   m_pALIBufferService(NULL),
   m_pALIMMIOService(NULL),
   m_pALIResetService(NULL),
   m_pALIReconfService(NULL),
   m_pVTP_AALService(NULL),
   m_pVTPService(NULL),
   m_pVCMAPService(NULL),
   m_pWROService(NULL),
   //m_pIMPFPWRITEService(NULL),
   m_VTPDFHOffset(-1),
   m_Result(0),
   m_pDSM(NULL),
	m_pALIPerf(NULL),
   m_DSMSize(0),
   m_pWorkspace(NULL),
   m_WorkspaceSize(0),
   m_pOutput(NULL),
   m_OutputSize(0),
   m_ALIAFUTranID(),
   m_VTPTranID(),
   m_VCMAPTranID(),
   m_WROTranID(),
   m_ReconfTranID(),
   m_FMETranID()
{
   // Register our Client side interfaces so that the Service can acquire them.
   //   SetInterface() is inherited from CAASBase
   SetInterface(iidServiceClient, dynamic_cast<IServiceClient *>(this));
   SetInterface(iidRuntimeClient, dynamic_cast<IRuntimeClient *>(this));
//pAALLogger()->AddToMask(LM_All, /*LOG_INFO*/ LOG_DEBUG);
   SetInterface(iidALI_CONF_Service_Client, dynamic_cast<IALIReconfigure_Client *>(this));



   // Initialize our internal semaphore
   m_Sem.Create(0, 1);

   // Start the AAL Runtime, setting any startup options via a NamedValueSet

   // Using Hardware Services requires the Remote Resource Manager Broker Service
   //  Note that this could also be accomplished by setting the environment variable
   //   AALRUNTIME_CONFIG_BROKER_SERVICE to librrmbroker
   NamedValueSet configArgs;
   NamedValueSet configRecord;

#if defined( HWAFU )
   // Specify that the remote resource manager is to be used.
   configRecord.Add(AALRUNTIME_CONFIG_BROKER_SERVICE, "librrmbroker");
   configArgs.Add(AALRUNTIME_CONFIG_RECORD, &configRecord);
#endif

   // Start the Runtime and wait for the callback by sitting on the semaphore.
   //   the runtimeStarted() or runtimeStartFailed() callbacks should set m_bIsOK appropriately.
   if(!m_Runtime.start(configArgs)){
	   m_bIsOK = false;
      return;
   }
   m_Sem.Wait();
   m_bIsOK = true;
}

/// @brief   Destructor
///
CCIPMMD::~CCIPMMD()
{
   m_Sem.Destroy();
}

/// @brief   open() is called from main performs the following:
///             - Allocate the appropriate ALI Service depending
///               on whether a hardware, ASE or software implementation is desired.
///             - Allocates the necessary buffers to be used by the NLB AFU algorithm

 void CCIPMMD::serviceReleaseRequest(IBase *pServiceBase, const IEvent &rEvent)
 {
    MSG("Service unexpected requested back");
    if(NULL != m_pALIAFU_AALService){
       IAALService *pIAALService = dynamic_ptr<IAALService>(iidService, m_pALIAFU_AALService);
       ASSERT(pIAALService);
       pIAALService->Release(TransactionID());
    }
 }
btInt CCIPMMD::open()
{

 //pAALLogger()->AddToMask(LM_All, LOG_DEBUG);
   // Request the Servcie we are interested in.

   // NOTE: This example is bypassing the Resource Manager's configuration record lookup
   //  mechanism.  Since the Resource Manager Implementation is a sample, it is subject to change.
   //  This example does illustrate the utility of having different implementations of a service all
   //  readily available and bound at run-time.
   NamedValueSet Manifest;
   NamedValueSet ConfigRecord;
   NamedValueSet featureFilter;
   btcString sGUID = MPF_VTP_BBB_GUID;

   // test counters
   bt64bitInt errpos = -1;
   btVirtAddr p1;
   btVirtAddr p2;

#if defined( HWAFU )                /* Use FPGA hardware */
   // Service Library to use
   ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_SERVICE_NAME, "libALI");

   // the AFUID to be passed to the Resource Manager. It will be used to locate the appropriate device.
   //ConfigRecord.Add(keyRegAFU_ID,"C000C966-0D82-4272-9AEF-FE5F84570612");
   if(check_for_svm_env())
   {
   	   ConfigRecord.Add(keyRegAFU_ID,"3A00972E-7AAC-41DE-BBD1-3901124E8CDA");
   }
   else
   {
   	   ConfigRecord.Add(keyRegAFU_ID,"18B79FFA-2EE5-4AA0-96EF-4230DAFACB5F");
   }

   // indicate that this service needs to allocate an AIAService, too to talk to the HW
   ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_AIA_NAME, "libaia");
#elif defined ( ASEAFU )         /* Use ASE based RTL simulation */
   Manifest.Add(keyRegHandle, 20);

    Manifest.Add(ALIAFU_NVS_KEY_TARGET, ali_afu_ase);
   ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_SERVICE_NAME, "libALI");
   ConfigRecord.Add(AAL_FACTORY_CREATE_SOFTWARE_SERVICE,true);

#else                            /* default is Software Simulator */
#if 0 // NOT CURRRENTLY SUPPORTED
   ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_SERVICE_NAME, "libSWSimALIAFU");
   ConfigRecord.Add(AAL_FACTORY_CREATE_SOFTWARE_SERVICE,true);
#endif
   return -1;
#endif

   // Add the Config Record to the Manifest describing what we want to allocate
   Manifest.Add(AAL_FACTORY_CREATE_CONFIGRECORD_INCLUDED, &ConfigRecord);

   // in future, everything could be figured out by just giving the service name
   //Manifest.Add(AAL_FACTORY_CREATE_SERVICENAME, "Hello ALI NLB");

   //MSG("Allocating ALIAFU Service");

   // Allocate the Service and wait for it to complete by sitting on the
   //   semaphore. The serviceAllocated() callback will be called if successful.
   //   If allocation fails the serviceAllocateFailed() should set m_bIsOK appropriately.
   //   (Refer to the serviceAllocated() callback to see how the Service's interfaces
   //    are collected.)
   //  Note that we are passing a custom transaction ID (created during app
   //   construction) to be able in serviceAllocated() to identify which
   //   service was allocated. This is only necessary if you are allocating more
   //   than one service from a single AAL service client.

 m_Runtime.allocService(dynamic_cast<IBase *>(this), Manifest,m_ALIAFUTranID );
 m_Sem.Wait();
 
 if(!m_bIsOK){
    ERR("ALIAFU allocation failed\n");
    //goto done_0;
  return -1;
 }   
#ifndef SIM
#ifndef NO_FME_SUPPORT
   Manifest.Delete(AAL_FACTORY_CREATE_CONFIGRECORD_INCLUDED);
   ConfigRecord.Delete(keyRegAFU_ID);


   ConfigRecord.Add(keyRegAFU_ID,CCIP_FME_AFUID);
   Manifest.Add(AAL_FACTORY_CREATE_CONFIGRECORD_INCLUDED, &ConfigRecord);
   {
      // Allocate the AFU
    
      m_Runtime.allocService(dynamic_cast<IBase *>(this), Manifest, m_FMETranID);
      m_Sem.Wait();
      if(!m_bIsOK){
         ERR("Allocation failed\n");
         return -1;
      }
   }
#endif
#endif

   // Ask the ALI service for the VTP device feature header (DFH)
//   featureFilter.Add(ALI_GETFEATURE_ID_KEY, static_cast<ALI_GETFEATURE_ID_DATATYPE>(25));
   /*featureFilter.Add(ALI_GETFEATURE_TYPE_KEY, static_cast<ALI_GETFEATURE_TYPE_DATATYPE>(2));
   featureFilter.Add(ALI_GETFEATURE_GUID_KEY, static_cast<ALI_GETFEATURE_GUID_DATATYPE>(sGUID));
   if (true != m_pALIMMIOService->mmioGetFeatureOffset(&m_VTPDFHOffset, featureFilter)) {
      ERR("No VTP feature\n");
      m_bIsOK = false;
      m_Result = -1;
      //goto done_1;
	  return -1;
   }*/
if(check_for_svm_env()) {
   // Reuse Manifest and Configrecord for VTP service
   Manifest.Empty();
   ConfigRecord.Empty();

   // Allocate VTP service
   // Service Library to use
   ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_SERVICE_NAME, "libMPF_AAL");
   ConfigRecord.Add(AAL_FACTORY_CREATE_SOFTWARE_SERVICE,true);

   // Add the Config Record to the Manifest describing what we want to allocate
   Manifest.Add(AAL_FACTORY_CREATE_CONFIGRECORD_INCLUDED, &ConfigRecord);

   // the VTPService will reuse the already established interfaces presented by
   // the ALIAFU service
   Manifest.Add(ALIAFU_IBASE_KEY, static_cast<ALIAFU_IBASE_DATATYPE>(m_pALIAFU_AALService));

   // the location of the VTP device feature header
   Manifest.Add(MPF_FEATURE_ID_KEY, static_cast<MPF_FEATURE_ID_DATATYPE>(1));

   // in future, everything could be figured out by just giving the service name
   Manifest.Add(AAL_FACTORY_CREATE_SERVICENAME, "VTP");

   //MSG("Allocating VTP Service");

   m_Runtime.allocService(dynamic_cast<IBase *>(this), Manifest, m_VTPTranID);
   m_Sem.Wait();
   if(!m_bIsOK){
      ERR("VTP Service allocation failed\n");

      //goto done_0;
    return -1;
   }

   
   
     // Reuse Manifest and Configrecord for VCMAP service
   Manifest.Empty();
   ConfigRecord.Empty();

   // Allocate VTP service
   // Service Library to use
   ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_SERVICE_NAME, "libMPF_AAL");
   ConfigRecord.Add(AAL_FACTORY_CREATE_SOFTWARE_SERVICE,true);

   // Add the Config Record to the Manifest describing what we want to allocate
   Manifest.Add(AAL_FACTORY_CREATE_CONFIGRECORD_INCLUDED, &ConfigRecord);

   // the VTPService will reuse the already established interfaces presented by
   // the ALIAFU service
   Manifest.Add(ALIAFU_IBASE_KEY, static_cast<ALIAFU_IBASE_DATATYPE>(m_pALIAFU_AALService));

   // the location of the VCMAP device feature header
   Manifest.Add(MPF_FEATURE_ID_KEY, static_cast<MPF_FEATURE_ID_DATATYPE>(1));

   // in future, everything could be figured out by just giving the service name
   Manifest.Add(AAL_FACTORY_CREATE_SERVICENAME, "VCMAP");

   //MSG("Allocating VTP Service");

   m_Runtime.allocService(dynamic_cast<IBase *>(this), Manifest, m_VCMAPTranID);
   m_Sem.Wait();
   if(!m_bIsOK){
      ERR("VCMAP Service allocation failed\n");

      //goto done_0;
    return -1;
   } 
 

   Manifest.Empty();
   ConfigRecord.Empty();

   // Allocate VTP service
   // Service Library to use
   ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_SERVICE_NAME, "libMPF_AAL");
   ConfigRecord.Add(AAL_FACTORY_CREATE_SOFTWARE_SERVICE,true);

   // Add the Config Record to the Manifest describing what we want to allocate
   Manifest.Add(AAL_FACTORY_CREATE_CONFIGRECORD_INCLUDED, &ConfigRecord);

   // the VTPService will reuse the already established interfaces presented by
   // the ALIAFU service
   Manifest.Add(ALIAFU_IBASE_KEY, static_cast<ALIAFU_IBASE_DATATYPE>(m_pALIAFU_AALService));

   // the location of the VCMAP device feature header
   Manifest.Add(MPF_FEATURE_ID_KEY, static_cast<MPF_FEATURE_ID_DATATYPE>(1));

   // in future, everything could be figured out by just giving the service name
   Manifest.Add(AAL_FACTORY_CREATE_SERVICENAME, "WRO"); 
   m_Runtime.allocService(dynamic_cast<IBase *>(this), Manifest, m_WROTranID);
   m_Sem.Wait();
   if(!m_bIsOK){
      ERR("WRO Service allocation failed\n");

      //goto done_0;
    return -1;
   }   
   
   


   // Now that we have the Service and have saved the IMPFVTP interface pointer
   //  we can now Allocate the 3 Workspaces used by the NLB algorithm. The buffer allocate
   //  function is synchronous so no need to wait on the semaphore

   // Note that we now hold two buffer interfaces, m_pALIBufferService and
   //  m_pVTPService. The latter will allocate shared memory buffers and update
   //  the VTP block's memory mapping table, and thus allow AFUs to access the
   //  shared buffer using virtual addresses. The former will only allocate the
   //  shred memory buffers, requiring the AFU to use physical addresses to
   //  access them.

   // Device Status Memory (DSM) is a structure defined by the NLB implementation.
   // FIXME: shouldn't these appear as a private feature header for the NLB AFU?

   // User Virtual address of the pointer is returned directly in the function
   // Remember, we're using VTP, so no need to convert to physical addresses
   if( ali_errnumOK != m_pVTPService->bufferAllocate(LPBK1_DSM_SIZE, &m_pDSM)){
      m_bIsOK = false;
      m_Result = -1;
      //goto done_2;
	  return -1;
   }

   // Save the size
   m_DSMSize = LPBK1_DSM_SIZE;

   // Repeat for the Input and Output Buffers
   if(!getenv("ALLOC_PER_BUFFER")){
	   if( ali_errnumOK != m_pVTPService->bufferAllocate(WORKSPACE_SIZE, &m_pWorkspace)){
		  m_bIsOK = false;
		  m_Sem.Post(1);
		  m_Result = -1;
		  //goto done_3;
		  return -1;
	   }
	}
   m_WorkspaceSize = WORKSPACE_SIZE;

}

   //=============================
   // Now we have the NLB Service
   //   now we can use it
   //=============================
  /* //MSG("Running Test");
   //MSG("  Test size:   " << m_WorkspaceSize);
   //MSG("  Test offset: " << LPBK1_BUFFER_OFFSET);*/
   if(true == m_bIsOK){

      // Clear the DSM
      ::memset( m_pDSM, 0, m_DSMSize);

     
      m_pALIResetService->afuReset();
      INIT_SPEED_LIMIT();

      // AFU Reset clear VTP, too, so reinitialize that
      // NOTE: this interface is likely to change in future releases of AAL.
if(check_for_svm_env())
      m_pVTPService->vtpReset();

      btUnsigned32bitInt id = 0;
      m_pALIMMIOService->mmioRead32(0x8000 ,&id);
      INIT_SPEED_LIMIT();

      // Wait for test completion

      //MSG("About to read");
      //while( id !=  0xa0c00001) {
        m_pALIMMIOService->mmioRead32(AOCL_MMD_KERNEL ,&id);
        MSG("Read id as " << id);
        INIT_SPEED_LIMIT();
     // }

    
	  
   }
   
   if(m_pVCMAPService)
   {
   //if(getenv("USE_VCMAP")){
if(check_for_svm_env()) {
      //m_pVCMAPService->vcmapSetMapAll(true);
      m_pVCMAPService->vcmapSetMode(true,true,12);
      
    if(getenv("USE_VCMAP_THRESH")){  
      m_pVCMAPService->vcmapSetLowTrafficThreshold(0x3f);
    }
   //}
   
  if(getenv("USE_VL0")){
  
      printf("################ USING VL0 ONLY #################\n");
      m_pVCMAPService->vcmapSetMapAll(true);
      m_pVCMAPService->vcmapSetFixedMapping(true, 64);
   
   }
  if(getenv("USE_VH")){
  
      printf("################ USING VH ONLY #################\n");
      m_pVCMAPService->vcmapSetMapAll(true);
      m_pVCMAPService->vcmapSetFixedMapping(true, 0);
   
   }
   
     if(getenv("USE_VCMAP_FIXED")){
  
      printf("################ USING FIXED VC MAPPING  #################\n");
      m_pVCMAPService->vcmapSetMapAll(true);
      m_pVCMAPService->vcmapSetFixedMapping(true, 15);
   
   }
}
     // m_pVCMAPService->vcmapSetMapAll(true);
    //  m_pVCMAPService->vcmapSetFixedMapping(true, 21);
   }

#ifndef DISABLE_PR
  Manifest.Empty();
  ConfigRecord.Empty();

  ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_SERVICE_NAME, "libHWALIAFU");
  ConfigRecord.Add(keyRegAFU_ID,ALI_AFUID_UAFU_CONFIG);
  ConfigRecord.Add(keyRegSubDeviceNumber,0);
  ConfigRecord.Add(AAL_FACTORY_CREATE_CONFIGRECORD_FULL_AIA_NAME, "libaia");

  Manifest.Add(AAL_FACTORY_CREATE_CONFIGRECORD_INCLUDED, &ConfigRecord);
  Manifest.Add(AAL_FACTORY_CREATE_SERVICENAME, "ALI Conf AFU");

  m_Runtime.allocService(dynamic_cast<IBase *>(this), Manifest, m_ReconfTranID);
  m_Sem.Wait();
#endif 
   if(getenv("MMD_DEBUG")){
     getPerfCounters(); 
   }

   return m_Result;
}



///     btInt CCIPMMD::close()
///             - Cleans up.
///
btInt CCIPMMD::close()
{
   // Clean-up and return
//done_5:
   m_pALIBufferService->bufferFree(m_pOutput);
//done_4:
   m_pALIBufferService->bufferFree(m_pWorkspace);
//done_3:
   m_pALIBufferService->bufferFree(m_pDSM);

//done_2:
   // Freed all three so now Release() the VTP Service through the Services IAALService::Release() method
   (dynamic_ptr<IAALService>(iidService, m_pVTP_AALService))->Release(TransactionID());
   m_Sem.Wait();

//done_1:
   // Freed all three so now Release() the HWALIAFU Service through the Services IAALService::Release() method
   (dynamic_ptr<IAALService>(iidService, m_pALIAFU_AALService))->Release(TransactionID());
   m_Sem.Wait();

//done_0:
   m_Runtime.stop();
   m_Sem.Wait();

}


void CCIPMMD::printStats()
{
  t_cci_mpf_wro_stats  wro_stats;  
  m_pWROService->wroGetStats(&wro_stats);
  printf("numConflictCyclesRR: %lu\n",  wro_stats.numConflictCyclesRR);
  printf("numConflictCyclesRW: %lu\n",  wro_stats.numConflictCyclesRW);
  printf("numConflictCyclesWR: %lu\n",  wro_stats.numConflictCyclesWR);
  printf("numConflictCyclesWW: %lu\n",  wro_stats.numConflictCyclesWW);

}


btInt CCIPMMD::reprogram()
{
  NamedValueSet nvs;
  
#ifndef DISABLE_PR
  if(true == m_bIsOK){
    nvs.Add(AALCONF_FILENAMEKEY,"PRbitstream_temp.rbf");

    // ReConfigure AFU Resource
    m_pALIReconfService->reconfConfigure(TransactionID(), nvs);
    m_Sem.Wait();
  }

  m_pALIResetService->afuReset();
  m_pVTPService->vtpReset();
#endif
  return 0;
}



//=================
//  IServiceClient
//=================

// <begin IServiceClient interface>
void CCIPMMD::serviceAllocated(IBase *pServiceBase,
                                      TransactionID const &rTranID)
{
   // This application will allocate two different services (HWALIAFU and
   //  VTPService). We can tell them apart here by looking at the TransactionID.
   if (rTranID ==  m_ALIAFUTranID) {

      // Save the IBase for the Service. Through it we can get any other
      //  interface implemented by the Service
      m_pALIAFU_AALService = pServiceBase;
      ASSERT(NULL != m_pALIAFU_AALService);
      if ( NULL == m_pALIAFU_AALService ) {
         m_bIsOK = false;
         return;
      }

      // Documentation says HWALIAFU Service publishes
      //    IALIBuffer as subclass interface. Used in Buffer Allocation and Free
      m_pALIBufferService = dynamic_ptr<IALIBuffer>(iidALI_BUFF_Service, pServiceBase);
      ASSERT(NULL != m_pALIBufferService);
      if ( NULL == m_pALIBufferService ) {
         m_bIsOK = false;
         return;
      }

      // Documentation says HWALIAFU Service publishes
      //    IALIMMIO as subclass interface. Used to set/get MMIO Region
      m_pALIMMIOService = dynamic_ptr<IALIMMIO>(iidALI_MMIO_Service, pServiceBase);
      ASSERT(NULL != m_pALIMMIOService);
      if ( NULL == m_pALIMMIOService ) {
         m_bIsOK = false;
         return;
      }

      // Documentation says HWALIAFU Service publishes
      //    IALIReset as subclass interface. Used for resetting the AFU
      m_pALIResetService = dynamic_ptr<IALIReset>(iidALI_RSET_Service, pServiceBase);
      ASSERT(NULL != m_pALIResetService);
      if ( NULL == m_pALIResetService ) {
         m_bIsOK = false;
         return;
      }
   }else if (rTranID == m_FMETranID) {
      m_pFMEService = pServiceBase;
       ASSERT(NULL != m_pFMEService);
       if ( NULL == m_pFMEService ) {
          m_bIsOK = false;
          return;
       }

       // Documentation says HWALIAFU Service publishes
       //    IALIBuffer as subclass interface. Used in Buffer Allocation and Free
       m_pALIPerf = dynamic_ptr<IALIPerf>(iidALI_PERF_Service, pServiceBase);
       ASSERT(NULL != m_pALIPerf);
       if ( NULL == m_pALIPerf ) {
          m_bIsOK = false;
          return;
       }
       
   }

   else if (rTranID == m_VTPTranID) {

      // Save the IBase for the VTP Service.
       m_pVTP_AALService = pServiceBase;
       ASSERT(NULL != m_pVTP_AALService);
       if ( NULL == m_pVTP_AALService ) {
          m_bIsOK = false;
          return;
       }

       // Documentation says VTP Service publishes
       //    IMPFVTP as subclass interface. Used for allocating shared
       //    buffers that support virtual addresses from AFU
       m_pVTPService = dynamic_ptr<IMPFVTP>(iidMPFVTPService, pServiceBase);
       ASSERT(NULL != m_pVTPService);
       if ( NULL == m_pVTPService ) {
          m_bIsOK = false;
          return;
       }

   }
   else if(rTranID == m_VCMAPTranID){
      //DCP doesn't have this so it is OK if m_pVCMAPService is NULL
      m_pVCMAPService = dynamic_ptr<IMPFVCMAP>(iidMPFVCMAPService, pServiceBase);
   }
   else if(rTranID == m_WROTranID){
   
      m_pWROService = dynamic_ptr<IMPFWRO>(iidMPFWROService, pServiceBase);
          ASSERT(NULL != m_pWROService);
       if ( NULL == m_pWROService ) {
          m_bIsOK = false;
          return;
       }
   
   }   
   else if (rTranID == m_ReconfTranID) {
      // Save the IBase for the VTP Service.
       m_pReconf_AALService = pServiceBase;
       ASSERT(NULL != m_pReconf_AALService);
       if ( NULL == m_pReconf_AALService ) {
          m_bIsOK = false;
          return;
       }


      m_pALIReconfService = dynamic_ptr<IALIReconfigure>(iidALI_CONF_Service, pServiceBase);
      ASSERT(NULL != m_pALIReconfService);
      if ( NULL == m_pALIReconfService ) {
         m_bIsOK = false;
         return;
      }

   }
   else
   {
      MSG("Unknown transaction ID encountered on serviceAllocated().");
      /*m_bIsOK = false;
      return;*/
   }

   //MSG("Service Allocated");
   m_Sem.Post(1);
}

void CCIPMMD::getPerfCounters()
 {
    NamedValueSet PerfMon;
	btUnsigned64bitInt     value;

 	if(m_pALIPerf == NULL)
 	{
 		MSG("\n ************* NO AAL PERF SUPPORT  ******************\n \n");
 		return;
 	}
    m_pALIPerf->performanceCountersGet(&PerfMon);

    MSG("\n ************* PERFORMANCE COUNTERS START  ******************\n \n");

    if (PerfMon.Has(AALPERF_VERSION)) {
       PerfMon.Get( AALPERF_VERSION, &value);
       printf("AALPERF_VERSION %llu \n",value);
    }
    if (PerfMon.Has(AALPERF_READ_HIT)) {
       PerfMon.Get( AALPERF_READ_HIT, &value);
       printf("AALPERF_READ_HIT %llu \n",value);
    }
    if (PerfMon.Has(AALPERF_WRITE_HIT)) {
       PerfMon.Get( AALPERF_WRITE_HIT, &value);
       printf("AALPERF_WRITE_HIT %llu \n",value);
    }
    if (PerfMon.Has(AALPERF_READ_MISS)) {
       PerfMon.Get( AALPERF_READ_MISS, &value);
       printf("AALPERF_READ_MISS %llu \n",value);
    }
    if (PerfMon.Has(AALPERF_WRITE_MISS)) {
       PerfMon.Get( AALPERF_WRITE_MISS, &value);
       printf("AALPERF_WRITE_MISS %llu \n",value);
    }
    if (PerfMon.Has(AALPERF_EVICTIONS)) {
         PerfMon.Get( AALPERF_EVICTIONS, &value);
         printf("AALPERF_EVICTIONS %llu \n",value);
     }

    if (PerfMon.Has(AALPERF_PCIE0_READ)) {
         PerfMon.Get( AALPERF_PCIE0_READ, &value);
         printf("AALPERF_PCIE0_READ %llu \n",value);
     }

    if (PerfMon.Has(AALPERF_PCIE0_WRITE)) {
         PerfMon.Get( AALPERF_PCIE0_WRITE, &value);
         printf("AALPERF_PCIE0_WRITE %llu \n",value);
     }

    if (PerfMon.Has(AALPERF_PCIE1_READ)) {
         PerfMon.Get( AALPERF_PCIE1_READ, &value);
         printf("AALPERF_PCIE1_READ %llu \n",value);
     }

    if (PerfMon.Has(AALPERF_PCIE1_WRITE)) {
         PerfMon.Get( AALPERF_PCIE1_WRITE, &value);
         printf("AALPERF_PCIE1_WRITE %llu \n",value);
     }


    if (PerfMon.Has(AALPERF_UPI_READ)) {
         PerfMon.Get( AALPERF_UPI_READ, &value);
         printf("AALPERF_UPI_READ %llu \n",value);
     }

    if (PerfMon.Has(AALPERF_UPI_WRITE)) {
           PerfMon.Get( AALPERF_UPI_WRITE, &value);
           printf("AALPERF_UPI_WRITE %llu \n",value);
    }

    MSG("\n \n ************* PERFORMANCE COUNTERS END ****************** \n");

    PerfMon.Empty();
 }

void CCIPMMD::serviceAllocateFailed(const IEvent &rEvent)
{
   ERR("Failed to allocate Service");
    PrintExceptionDescription(rEvent);
    

   ++m_Result;                     // Remember the error
   m_bIsOK = false;

   m_Sem.Post(1);
}

 void CCIPMMD::serviceReleased(TransactionID const &rTranID)
{
    //MSG("Service Released");
   // Unblock Main()
   m_Sem.Post(1);
}

 void CCIPMMD::serviceReleaseFailed(const IEvent        &rEvent)
 {
    ERR("Failed to release a Service");
    PrintExceptionDescription(rEvent);
    m_bIsOK = false;
    m_Sem.Post(1);
 }


 void CCIPMMD::serviceEvent(const IEvent &rEvent)
{
   ERR("unexpected event 0x" << hex << rEvent.SubClassID());
   // The state machine may or may not stop here. It depends upon what happened.
   // A fatal error implies no more messages and so none of the other Post()
   //    will wake up.
   // OTOH, a notification message will simply print and continue.
}
// <end IServiceClient interface>


void CCIPMMD::deactivateSucceeded( TransactionID const &rTranID )
{
   //MSG("deactivateSucceeded");
   m_Sem.Post(1);
}
void CCIPMMD::deactivateFailed( IEvent const &rEvent )
{
   ERR("Failed deactivate");
   PrintExceptionDescription(rEvent);
   PrintReconfExceptionDescription(rEvent);
   ++m_Result;                     // Remember the error
   m_bIsOK = false;
   m_Sem.Post(1);
}

void CCIPMMD::configureSucceeded( TransactionID const &rTranID )
{
   //MSG("configureSucceeded");
   m_Sem.Post(1);
}
void CCIPMMD::configureFailed( IEvent const &rEvent )
{
   ERR("configureFailed");
   PrintExceptionDescription(rEvent);
   PrintReconfExceptionDescription(rEvent);
   ++m_Result;                     // Remember the error
   m_bIsOK = false;
   m_Sem.Post(1);
}
void CCIPMMD::activateSucceeded( TransactionID const &rTranID )
{
   //MSG("activateSucceeded");
   m_Sem.Post(1);
}
void CCIPMMD::activateFailed( IEvent const &rEvent )
{
   ERR("activateFailed");
   PrintExceptionDescription(rEvent);
   PrintReconfExceptionDescription(rEvent);
   ++m_Result;                     // Remember the error
   m_bIsOK = false;
   m_Sem.Post(1);
}


 //=================
 //  IRuntimeClient
 //=================

  // <begin IRuntimeClient interface>
 // Because this simple example has one object implementing both IRuntieCLient and IServiceClient
 //   some of these interfaces are redundant. We use the IServiceClient in such cases and ignore
 //   the RuntimeClient equivalent e.g.,. runtimeAllocateServiceSucceeded()

 void CCIPMMD::runtimeStarted( IRuntime            *pRuntime,
                                      const NamedValueSet &rConfigParms)
 {
    m_bIsOK = true;
    m_Sem.Post(1);
 }

 void CCIPMMD::runtimeStopped(IRuntime *pRuntime)
  {
     //MSG("Runtime stopped");
     m_bIsOK = false;
     m_Sem.Post(1);
  }

 void CCIPMMD::runtimeStartFailed(const IEvent &rEvent)
 {
    ERR("Runtime start failed");
    PrintExceptionDescription(rEvent);
 }

 void CCIPMMD::runtimeStopFailed(const IEvent &rEvent)
 {
     //MSG("Runtime stop failed");
     m_bIsOK = false;
     m_Sem.Post(1);
 }

 void CCIPMMD::runtimeAllocateServiceFailed( IEvent const &rEvent)
 {
    ERR("Runtime AllocateService failed");
    PrintExceptionDescription(rEvent);
 }

 void CCIPMMD::runtimeAllocateServiceSucceeded(IBase *pClient,
                                                     TransactionID const &rTranID)
 {
     //MSG("Runtime Allocate Service Succeeded");
 }

 void CCIPMMD::runtimeEvent(const IEvent &rEvent)
 {
     //MSG("Generic message handler (runtime)");
 }
//#define WORKAROUND_MMIO_BIT_6
#define BIT_TO_MASK 6
int CCIPMMD::MMIOWriteFast(size_t Addr, const void* buffer, size_t len){

 {
    const unsigned long int* src_dw = (unsigned long int*)buffer;
    unsigned  int* src_w = (unsigned int*)buffer;
    unsigned long  int i = 0;
    for(i = 0; i < ((len+7)/8); i++) {
      #ifdef WORKAROUND_MMIO_BIT_6
      size_t final_addr = ((Addr+8*i)&( 0xFFFFFFFF >> (32-BIT_TO_MASK)) ) | (((Addr+8*i)&(0xFFFFFFFF<<BIT_TO_MASK)) << 1);
      DEBUG_PRINT("mmd write word: address = %09x, final_addr = %09x\n",Addr+8*i,final_addr); 
      #else
      size_t final_addr = Addr+8*i;
      #endif 
      if(len-i*8 > 4){
        m_pALIMMIOService->mmioWrite64(final_addr ,src_dw[i]);
      } else {
        m_pALIMMIOService->mmioWrite32(final_addr ,src_w[2*i]);  
      }
      
      
      DEBUG_PRINT("mmd write word: address = %09x, data = %08x\n",Addr+8*i,src_dw[i]); 
    }
  }
  
	return 0;
}

int CCIPMMD::MMIOWrite(size_t Addr, const void* buffer, size_t len){
  MMIOWriteFast(Addr, buffer, len);
  SPEED_LIMIT();
	return 0;
}


int CCIPMMD::MMIORead(size_t Addr, void* buffer, size_t len){
    MMIOReadFast(Addr, buffer, len);
  SPEED_LIMIT();
	return 0;
}

int CCIPMMD::MMIOReadFast(size_t Addr, void* buffer, size_t len){

 {
    unsigned long int* src_dw = (unsigned long int*)buffer;
    unsigned  int* src_w = (unsigned int*)buffer;
    unsigned long int write_word;
    unsigned long  int i = 0;

    
  #if 1
    for(i = 0; i < ((len+7)/8); i++) { 
    
      #ifdef WORKAROUND_MMIO_BIT_6
      size_t final_addr = ((Addr+8*i)&( 0xFFFFFFFF >> (32-BIT_TO_MASK)) ) | (((Addr+8*i)&(0xFFFFFFFF<<BIT_TO_MASK)) << 1);
      DEBUG_PRINT("mmd read: address = %09x, final_addr = %09x\n",Addr+8*i,final_addr); 
      #else
      size_t final_addr = Addr+8*i;
      #endif 
      if((len-i*8) > 4){
        m_pALIMMIOService->mmioRead64(final_addr ,&src_dw[i]);
        DEBUG_PRINT("mmd read qword: address = %09x, data = %08llx\n",Addr+8*i,src_dw[i]); 
		/*#ifdef SIM
        m_pALIMMIOService->mmioRead64(final_addr ,&src_dw[i]);
        DEBUG_PRINT("mmd read qword: address = %09x, data = %08llx\n",Addr+8*i,src_dw[i]); 
        m_pALIMMIOService->mmioRead64(final_addr ,&src_dw[i]);
        DEBUG_PRINT("mmd read qword: address = %09x, data = %08llx\n",Addr+8*i,src_dw[i]); 
        m_pALIMMIOService->mmioRead64(final_addr ,&src_dw[i]);
        DEBUG_PRINT("mmd read qword: address = %09x, data = %08llx\n",Addr+8*i,src_dw[i]); 		
		
		
		#endif*/
      } else {
		/*#ifdef SIM
        m_pALIMMIOService->mmioRead32(final_addr ,(unsigned  int*)&src_w[2*i]);  
        DEBUG_PRINT("mmd read dword: address = %09x, data = %08x\n",Addr+8*i,src_w[2*i]); 
        m_pALIMMIOService->mmioRead32(final_addr ,(unsigned  int*)&src_w[2*i]);  
        DEBUG_PRINT("mmd read dword: address = %09x, data = %08x\n",Addr+8*i,src_w[2*i]); 
        
        m_pALIMMIOService->mmioRead32(final_addr ,(unsigned  int*)&src_w[2*i]);  
        DEBUG_PRINT("mmd read dword: address = %09x, data = %08x\n",Addr+8*i,src_w[2*i]); 
         
        m_pALIMMIOService->mmioRead32(final_addr ,(unsigned  int*)&src_w[2*i]);  
        DEBUG_PRINT("mmd read dword: address = %09x, data = %08x\n",Addr+8*i,src_w[2*i]); 
		#endif*/
        m_pALIMMIOService->mmioRead32(final_addr ,(unsigned  int*)&src_w[2*i]);  
        DEBUG_PRINT("mmd read dword: address = %09x, data = %08x\n",Addr+8*i,src_w[2*i]); 
      }
      
      
    }
    #else
      for(i = 0; i < ((len+3)/4); i++) { 
        m_pALIMMIOService->mmioRead32(Addr+4*i ,&src_w[i]);
        DEBUG_PRINT("mmd read dword: address = %09x, data = %08llx\n",Addr+3*i,src_w[i]); 
    }
    
    
    
    #endif
  }
	return 0;
}
 
void*  CCIPMMD::bufferAlloc(size_t len){
  btVirtAddr pointer; 
  
   if( ali_errnumOK != m_pVTPService->bufferAllocate(len, &pointer)){

	  return 0;
   }  
  
  return pointer;
}

void*  CCIPMMD::getWorkspace(){

  return m_pWorkspace;
}
void CCIPMMD::bufferFree(void* ptr){

  //m_pVTPService->bufferAllocate(WORKSPACE_SIZE+LPBK1_BUFFER_OFFSET, &m_pWorkspace)
}
 
 // <begin IRuntimeClient interface>

 
 
/// @} group HelloALINLB



 CCIPMMD* pCCIPMMD;
void* cr_dsm_base;


#define DSM_BASE_REG 0x2000+3*8*16
#define NUM_RULES 16
unsigned rule_offset;
int cci_set_access_type(void *base_addr, size_t size, unsigned flags) 
{
  if(rule_offset >= NUM_RULES) return 1;
  //base
  aocl_mmd_write(NULL,NULL, 8,&base_addr, QPI_ADDR_RANGE, 8*rule_offset);
  //size
  aocl_mmd_write(NULL,NULL, 8,&size, QPI_ADDR_RANGE, 8*NUM_RULES+8*rule_offset);
  //flags
  aocl_mmd_write(NULL,NULL, 8,&flags, QPI_ADDR_RANGE, 2*8*NUM_RULES+8*rule_offset);

  return 0;
}

size_t current_alloc_offset;


void cci_clear_rules()
{
  unsigned long clear = 0;
  for(int i = 0; i < 3*8*NUM_RULES; i++){
    aocl_mmd_write(NULL,NULL, 8,&clear, QPI_ADDR_RANGE, 8*i);  
  }
  rule_offset = 0;
}






void CCIPMMD::PrintReconfExceptionDescription(IEvent const &rEvent)
 {

    if ( rEvent.Has(iidExTranEvent) ) {

      std::cerr << "Description  " << dynamic_ref<IExceptionTransactionEvent>(iidExTranEvent, rEvent).Description() << std::endl;
      std::cerr << "ExceptionNumber:  " << dynamic_ref<IExceptionTransactionEvent>(iidExTranEvent, rEvent).ExceptionNumber() << std::endl;
      std::cerr << "Reason:  " << dynamic_ref<IExceptionTransactionEvent>(iidExTranEvent, rEvent).Reason() << std::endl;

     }
 }




// These allow allocate/free shared memory, with physical addressing on the FPGA side
//#define MAX_SHARED_BUFFERS 16
//ICCIWorkspace* pCCIUserBuffer[MAX_SHARED_BUFFERS];
#define ALIGNMENT 1024
#define ALIGNMENT_2 1024

#define TOP_BUFFER 1024*1024
#define BACK_BUFFER  1024*1024
AOCL_MMD_CALL void * aocl_mmd_shared_mem_alloc( int handle, size_t size, unsigned long long *device_ptr_out )
{
  DEBUG_PRINT("ALLOCATING %d buffer!\n",size);
  if(getenv("ALLOC_PER_BUFFER")){
  
	printf("ALLOCATING %d VIA bufferAlloc\n", size);
    size_t bump = size%ALIGNMENT_2 ?    (1+(size/ALIGNMENT_2))*ALIGNMENT_2 : size;
    void* ptr = pCCIPMMD->bufferAlloc(bump+TOP_BUFFER+BACK_BUFFER);
    if(ptr == NULL) {
      printf("Allocation Error\n");
      return 0;
    }
    ptr=ptr+TOP_BUFFER;
    
    
    printf("Address of pointer is %p\n", (void *)ptr);  
     *device_ptr_out = (unsigned long long) ptr;
    return ptr;
  } else {

  
    
  size_t bump = size%ALIGNMENT ?    (1+(size/ALIGNMENT))*ALIGNMENT : size;
  void* pointer = pCCIPMMD->getWorkspace()+current_alloc_offset;
  current_alloc_offset += bump;
  
  if(current_alloc_offset > WORKSPACE_SIZE) { 
    DEBUG_PRINT("Alloc failed, %d > %d\n",current_alloc_offset, workspace_size);
    return NULL; }
  
  *device_ptr_out = (unsigned long long) pointer;
  return pointer;
  
  }

}

AOCL_MMD_CALL void aocl_mmd_shared_mem_free ( int handle, void* host_ptr, size_t size )
{
if(getenv("ALLOC_PER_BUFFER")){
  pCCIPMMD->bufferFree(host_ptr);
  }
  DEBUG_PRINT("DEALLOCATING %d buffer!\n",size);

}



// Reprogram the device
int AOCL_MMD_CALL aocl_mmd_reprogram(int handle, void *data, size_t data_size)
{
  if(getenv("DISABLE_PR")){
    return MMDHANDLE;
  }
  HW_LOCK;

  int reprogram_failed = 1; // assume failure
  int rbf_or_hash_not_provided = 1; // assume no rbf or hash are provided in fpga.bin
  int hash_mismatch = 1; // assume base revision and import revision hashes do not match

  const char *BITSTREAMNAME = "PRbitstream_temp.rbf";
  size_t core_rbf_len = 0, pr_import_version_len = 0;

  // assuming the an ELF-formatted blob.
  if ( !blob_has_elf_signature( data, data_size ) ) {
    fprintf(stderr, "bdw_reprogram: Package file is not ELF-formatted!\n");
    exit(1);
  }

  //fprintf(stderr, "aocl_mmd_reprogram: Starting to program device...\n");

  struct acl_pkg_file *pkg = acl_pkg_open_file_from_memory( (char*)data, data_size, ACL_PKG_SHOW_ERROR );
  if(pkg == NULL) {
    fprintf(stderr, "bdw_reprogram: Cannot open file from memory using pkg editor.\n");
    exit(1);
  } 

  // checking that rbf and hash sections exist in fpga.bin
  if( acl_pkg_section_exists( pkg, ACL_PKG_SECTION_CORE_RBF, &core_rbf_len ) &&
      acl_pkg_section_exists( pkg, ACL_PKG_SECTION_HASH, &pr_import_version_len ) ) {

    rbf_or_hash_not_provided = 0;
    //fprintf(stderr, "aocl_mmd_reprogram: Programming kernel region using PR with rbf file size %d\n", (int) core_rbf_len);

    // read rbf and hash from fpga.bin
    char *core_rbf = NULL;
    int read_core_rbf_ok = acl_pkg_read_section_transient( pkg, ACL_PKG_SECTION_CORE_RBF, &core_rbf );
    char *pr_import_version_str = NULL;
    int read_pr_import_version_ok = acl_pkg_read_section_transient( pkg, ACL_PKG_SECTION_HASH, &pr_import_version_str );

    // checking that hash was successfully read from section .acl.hash within fpga.bin
    if ( read_pr_import_version_ok ) {
      pr_import_version_str[pr_import_version_len] = '\0';
      unsigned int pr_import_version = (unsigned int) strtol(pr_import_version_str, NULL, 10);

      // checking that base revision hash matches import revision hash
      if ( pr_base_id_test(pr_import_version) == 0 ) {
        hash_mismatch = 0;

        // Kernel driver wants it aligned to 4 bytes.
        int aligned_to_4_bytes( 0 == ( 3 & (uintptr_t)(core_rbf) ) );
        reprogram_failed = 1;  // Default to fail before PRing

        // checking that rbf was successfully read from section .acl.core.rbf within fpga.bin
        if(read_core_rbf_ok && !(core_rbf_len % 4) && aligned_to_4_bytes) {

          //fprintf(stderr, "aocl_mmd_reprogram: Starting PR programming of the device...\n");   

          //fprintf(stderr, "aocl_mmd_reprogram: Writing out PRbitstream_temp.rbf...\n");
          const int wrote_rbf = acl_pkg_read_section_into_file(pkg, ACL_PKG_SECTION_CORE_RBF, BITSTREAMNAME);

          btInt reprogram_failed = pCCIPMMD->reprogram();

          //fprintf(stderr, "B: Finished PR programming of the device.\n");

          if ( reprogram_failed ) {
            fprintf(stderr, "bdw_reprogram: PR programming failed.\n");
            exit(1);
          } else {
            //fprintf(stderr, "aocl_mmd_reprogram: PR programming passed.\n");
          }

        }
      }
    }
  }

  if( rbf_or_hash_not_provided || hash_mismatch ) {
    fprintf(stderr, "bdw_reprogram: The server is loaded with an FPGA design that is not compatible with the design currently being loaded.  \nbdw_reprogram: Please reinitialize the server with a compatible design (e.g. by replacing the RBF image loaded on power-on or power-cycling and using quartus_pgm).\n");
    exit(1);
  } 
   
  // Clean up
  if ( pkg ) acl_pkg_close_file(pkg);

  HW_UNLOCK;
  
  

  return MMDHANDLE;
}

void printdebug(){

   unsigned long int pr_base_version = 0; // make sure it's not what we hope to find. 

   aocl_mmd_read(NULL,NULL, 8, &pr_base_version, 0, DEBUG_ADDR_RANGE);
   printf("DEBUG REGISTER: transaction_pending: %llu\n",pr_base_version&0xFFFFFFFF);
   aocl_mmd_read(NULL,NULL, 8, &pr_base_version, 0, DEBUG_ADDR_RANGE+8*1);
   printf("DEBUG REGISTER: write_pending: %llu\n",pr_base_version&0xFFFFFFFF);
   aocl_mmd_read(NULL,NULL, 8, &pr_base_version, 0, DEBUG_ADDR_RANGE+8*2);
   printf("DEBUG REGISTER: avmm_waitrequest: %llu\n",pr_base_version&0xFFFFFFFF);
   aocl_mmd_read(NULL,NULL, 8, &pr_base_version, 0, DEBUG_ADDR_RANGE+8*3);
   printf("DEBUG REGISTER: kernel_irq: %llu\n",pr_base_version&0xFFFFFFFF);   
   aocl_mmd_read(NULL,NULL, 8, &pr_base_version, 0, DEBUG_ADDR_RANGE+8*4);
   printf("DEBUG REGISTER: tx_c0_almostfull: %llu\n",pr_base_version&0xFFFFFFFF);   
   aocl_mmd_read(NULL,NULL, 8, &pr_base_version, 0, DEBUG_ADDR_RANGE+8*5);
   printf("DEBUG REGISTER: tx_c1_almostfull: %llu\n",pr_base_version&0xFFFFFFFF);      
   aocl_mmd_read(NULL,NULL, 8, &pr_base_version, 0, DEBUG_ADDR_RANGE+8*6);
      aocl_mmd_read(NULL,NULL, 8, &pr_base_version, 0, DEBUG_ADDR_RANGE+8*7);
   printf("DEBUG REGISTER: num_writes: %llu\n",pr_base_version&0xFFFFFFFF);   
      aocl_mmd_read(NULL,NULL, 8, &pr_base_version, 0, DEBUG_ADDR_RANGE+8*8);
   printf("DEBUG REGISTER: num_reads: %llu\n",pr_base_version&0xFFFFFFFF);   
      aocl_mmd_read(NULL,NULL, 8, &pr_base_version, 0, DEBUG_ADDR_RANGE+8*9);
   printf("DEBUG REGISTER: num_partial_writes: %llu\n",pr_base_version&0xFFFFFFFF);   
         aocl_mmd_read(NULL,NULL, 8, &pr_base_version, 0, DEBUG_ADDR_RANGE+8*10);
   printf("DEBUG REGISTER: num_stalls: %llu\n",pr_base_version&0xFFFFFFFF);

   pCCIPMMD->printStats();
   
   pCCIPMMD->getPerfCounters(); 
}
  
  
int AOCL_MMD_CALL aocl_mmd_yield(int handle)
{
  int address = AOCL_IRQ_POLLING_BASE;
  int irqval = 0;
  static int last_irqval = -1;
  static int count = 1;

  SPEED_LIMIT();

  //svm used svm shared memory polling instead od mmio polling
  if(check_for_svm_env())
  {
    int mem_value =  *(volatile uint32_t *) ( cr_dsm_base+128);
    //printf();
    DEBUG_PRINT("IRW VAL %d\n", mem_value); 
    //SleepMicro(100);
    
    if(mem_value) {
      irqval = 1;
    }
  }
  else
  {
    aocl_mmd_read(NULL,NULL, 4,&irqval ,0, address);
  }

   if(getenv("MMD_DEBUG")){
     printdebug();
     SleepMicro(1000000);
   }
  

  if ( irqval )
  {
    kernel_interrupt( handle, kernel_interrupt_user_data );
  }

  return 0;
}
/*
int AOCL_MMD_CALL aocl_mmd_yield(int handle)
{
  int address = AOCL_IRQ_POLLING_BASE;
  int irqval = 0;
  static int last_irqval = -1;
  static int count = 1;
  
  

  int mem_value =  *(volatile uint32_t *) ( pDSMUsrVirt+128);
  
  if(mem_value) {
    irqval = 1;

  }
  
  #ifdef SIM    
  sleep(1);
  printf(" MEM Value = %d\n", mem_value);
  #endif 

  #endif
  if ( irqval)
  {
  
    kernel_interrupt( handle, kernel_interrupt_user_data );
  }

  return 0;
}
*/
#define RESULT_INT(X) {*((int*)param_value) = X; if (param_size_ret) *param_size_ret=sizeof(int);}
#define RESULT_STR(X) do { \
    unsigned Xlen = strlen(X) + 1; \
    memcpy((void*)param_value,X,(param_value_size <= Xlen) ? param_value_size : Xlen); \
    if (param_size_ret) *param_size_ret=Xlen; \
  } while(0)

static bool check_for_svm_env()
{
	static bool env_checked = false;
	static bool svm_enabled = false;
	
	if(!env_checked)
	{
		if(getenv("ENABLE_DCP_OPENCL_SVM")){
			svm_enabled = true;
		}
		env_checked = true;
	}
	
	return svm_enabled;
}
  	  
int aocl_mmd_get_offline_info(
    aocl_mmd_offline_info_t requested_info_id,
    size_t param_value_size,
    void* param_value,
    size_t* param_size_ret )
{
  int mem_type_info = (int)AOCL_MMD_PHYSICAL_MEMORY;
  if(check_for_svm_env())
  	  mem_type_info = (int)AOCL_MMD_SVM_COARSE_GRAIN_BUFFER;
	
  switch(requested_info_id)
  {
    case AOCL_MMD_VERSION:              RESULT_STR("14.1"); break;
    case AOCL_MMD_NUM_BOARDS:           RESULT_INT(1); break;
    case AOCL_MMD_VENDOR_NAME:          RESULT_STR("Intel Corp"); break;
    case AOCL_MMD_BOARD_NAMES:          RESULT_STR("acl0"); break;
    case AOCL_MMD_VENDOR_ID:            RESULT_INT(0); break;
    case AOCL_MMD_USES_YIELD:           RESULT_INT(1); break;
    case AOCL_MMD_MEM_TYPES_SUPPORTED:  RESULT_INT(mem_type_info); break;
  }
  
  return 0;
}

int aocl_mmd_get_info(
    int handle,
    aocl_mmd_info_t requested_info_id,
    size_t param_value_size,
    void* param_value,
    size_t* param_size_ret )
{
  HW_LOCK;
  switch(requested_info_id)
  {
    case AOCL_MMD_BOARD_NAME:            RESULT_STR("SKX DCP FPGA OpenCL BSP"); break;
    case AOCL_MMD_NUM_KERNEL_INTERFACES: RESULT_INT(1); break;
    case AOCL_MMD_KERNEL_INTERFACES:     RESULT_INT(AOCL_MMD_KERNEL); break;
    #ifdef SIM 
    case AOCL_MMD_PLL_INTERFACES:        RESULT_INT(-1); break;
    #else
    case AOCL_MMD_PLL_INTERFACES:        RESULT_INT(-1); break;
    #endif
    case AOCL_MMD_MEMORY_INTERFACE:      RESULT_INT(AOCL_MMD_MEMORY); break;
    case AOCL_MMD_PCIE_INFO:             RESULT_STR("N/A"); break;
    case AOCL_MMD_BOARD_UNIQUE_ID:       RESULT_INT(0); break;
    case AOCL_MMD_TEMPERATURE:
      {
        float *r;
        int temp = 0;
        r = (float*)param_value;
        *r = (float)temp;
        if (param_size_ret)
          *param_size_ret = sizeof(float);
        break;
      }
  }
  HW_UNLOCK;
  return 0;
}

int AOCL_MMD_CALL aocl_mmd_set_interrupt_handler( int handle, aocl_mmd_interrupt_handler_fn fn, void* user_data )
{
  int err;
  kernel_interrupt = fn;
  kernel_interrupt_user_data = user_data;

  return 0;
}

int AOCL_MMD_CALL aocl_mmd_set_status_handler( int handle, aocl_mmd_status_handler_fn fn, void* user_data )
{
  event_update = fn;
  event_update_user_data = user_data;
  return 0;
}

#define MSGDMA_BBB_BASE	0x20000
#define MEM_WINDOW_CRTL (MSGDMA_BBB_BASE+0x200)
#define MEM_WINDOW_MEM (MSGDMA_BBB_BASE+0x1000)
#define MEM_WINDOW_SPAN (4*1024)
#define MEM_WINDOW_SPAN_MASK ((long)(MEM_WINDOW_SPAN-1))

// Host to device-global-memory write
int AOCL_MMD_CALL aocl_mmd_write(
    int handle,
    aocl_mmd_op_t op,
    size_t len,
    const void* src,
    int mmd_interface, size_t offset )
{
	if(mmd_interface == AOCL_MMD_MEMORY)
	{
		DCP_DEBUG_MEM("DCP DEBUG: aocl_mmd_write called with AOCL_MMD_MEMORY!\n");
		DCP_DEBUG_MEM("DCP DEBUG: len=%d offset = %08x, data = %08x\n", len, (unsigned)offset,((int *)src)[0]);
		
		void * host_addr = const_cast<void *>(src);
	    long dev_addr  = offset;
	    
		long cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
		pCCIPMMD->MMIOWriteFast(MEM_WINDOW_CRTL, &cur_mem_page, 8);
		DCP_DEBUG_MEM("DCP DEBUG: set page %08x\n", cur_mem_page);
		for(long i = 0; i < len/8; i++)
		{
			long mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
			if(mem_page != cur_mem_page)
			{
				cur_mem_page = mem_page;
				pCCIPMMD->MMIOWriteFast(MEM_WINDOW_CRTL, &cur_mem_page, 8);
				DCP_DEBUG_MEM("DCP DEBUG: set page %08x\n", cur_mem_page);
			}
			pCCIPMMD->MMIOWriteFast(MEM_WINDOW_MEM+(dev_addr&MEM_WINDOW_SPAN_MASK), host_addr, 8);
			DCP_DEBUG_MEM("DCP DEBUG: write data %08x %08x %016lx\n", host_addr, dev_addr, ((long *)host_addr)[0]);
			
			host_addr += 8;
			dev_addr += 8;
		}
		
		DCP_DEBUG_MEM("DCP DEBUG: aocl_mmd_write done!\n");
	}
	else
	{
	
  unsigned long int address = mmd_interface + offset; // We defined it this way
  
  HW_LOCK;

  DEBUG_PRINT("mmd write: address = %09x, offset = %08x, data = %08x\n",address, (unsigned)offset,((int *)src)[0]);

	int result = pCCIPMMD->MMIOWrite(address, src, len);
    #ifdef SIM    
  sleep(2);
  #endif
  	}
  if (op)
  {
    //assert(event_update);
    event_update(handle, event_update_user_data, op, 0);
  }
  HW_UNLOCK;

  
  return 0;
}

int AOCL_MMD_CALL aocl_mmd_read(
    int handle,
    aocl_mmd_op_t op,
    size_t len,
    void* dst,
    int mmd_interface, size_t offset )
{
	if(mmd_interface == AOCL_MMD_MEMORY)
	{
		DCP_DEBUG_MEM("DCP DEBUG: aocl_mmd_read called with AOCL_MMD_MEMORY!\n");
		DCP_DEBUG_MEM("DCP DEBUG: len: %d offset: %08x\n", len, offset);
		
		void * host_addr = const_cast<void *>(dst);
	    long dev_addr  = offset;
	    
		long cur_mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
		pCCIPMMD->MMIOWriteFast(MEM_WINDOW_CRTL, &cur_mem_page, 8);
		DCP_DEBUG_MEM("DCP DEBUG: set page %08x\n", cur_mem_page);
		for(long i = 0; i < len/8; i++)
		{
			long mem_page = dev_addr & ~MEM_WINDOW_SPAN_MASK;
			if(mem_page != cur_mem_page)
			{
				cur_mem_page = mem_page;
				pCCIPMMD->MMIOWriteFast(MEM_WINDOW_CRTL, &cur_mem_page, 8);
				DCP_DEBUG_MEM("DCP DEBUG: set page %08x\n", cur_mem_page);
			}
			pCCIPMMD->MMIOReadFast(MEM_WINDOW_MEM+(dev_addr&MEM_WINDOW_SPAN_MASK), host_addr, 8);
			DCP_DEBUG_MEM("DCP DEBUG: read data %08x %08x %016lx\n", host_addr, dev_addr, ((long *)host_addr)[0]);
			
			host_addr += 8;
			dev_addr += 8;
		}
		DCP_DEBUG_MEM("DCP DEBUG: aocl_mmd_read done!\n");
	}
	else
	{
  int address = mmd_interface + offset; // We defined it this way
  HW_LOCK;

  DEBUG_PRINT("aocl_mmd_read len: %d offset: %d mmd_interface: %d   address: %d \n", len, offset, mmd_interface, address);
  #ifdef SLOW    
  sleep(2);
  #endif 
  int result = pCCIPMMD->MMIORead(address, dst, len);

  	}  
  if (op)
  {
    //assert(event_update);
    event_update(handle, event_update_user_data, op, 0);
  }

  HW_UNLOCK;
  return 0;
}




int AOCL_MMD_CALL aocl_mmd_copy(
    int handle,
    aocl_mmd_op_t op,
    size_t len,
    int mmd_interface, size_t src_offset, size_t dst_offset )
{
  DCP_DEBUG_MEM("DCP DEBUG: aocl_mmd_copy called!\n");
  HW_LOCK;
  HW_UNLOCK;
   return 0;
}

int opened = 0;


    

int AOCL_MMD_CALL aocl_mmd_open(const char *name)
{
    
	pCCIPMMD = new CCIPMMD();
		
	if(!pCCIPMMD->isOK()){
	  fprintf(stderr, "Error: Failed to initialize the OpenCL/AAL system. \n");
	  fprintf(stderr, "Error: Ensure a correct OpenCL image is programmed on the FPGA, and that the CCI driver has been loaded. \n");
      exit(1);
   }
   btInt Result = pCCIPMMD->open();
   #ifdef SLOW
	printf("SLEEPING FOR 15 secs!\n");
	SleepMicro(15000000);
   
#endif
   if(Result != 0){
    fprintf(stderr, "Error: Failed to initialize the OpenCL/AAL system. \n");
	fprintf(stderr, "Error: Ensure a correct OpenCL image is programmed on the FPGA, and that the CCI driver has been loaded. \n");
	
    return -1;
   }
   
   if(check_for_svm_env())
   {
   unsigned long long device_ptr_out;
   cr_dsm_base =  aocl_mmd_shared_mem_alloc( 0, 256,  &device_ptr_out );
   
   aocl_mmd_write(NULL,NULL, 8,&cr_dsm_base,0, QPI_ADDR_RANGE+NUM_RULES*3*8); 
   int vl0 = 0;   
   
   unsigned long long cci_config = 0;
	if(getenv("USE_BRIDGE_MAPPING_R"))        cci_config = cci_config | (1 << 0);
	if(getenv("USE_BRIDGE_MAPPING_W"))        cci_config = cci_config | (1 << 1);   
	if(getenv("USE_VL_R")			 )        cci_config = cci_config | (1 << 2);   
	if(getenv("USE_VL_W")            )        cci_config = cci_config | (1 << 3);   
	if(getenv("USE_VH_R")            )        cci_config = cci_config | (1 << 4);   
	if(getenv("USE_VH_W")	         )        cci_config = cci_config | (1 << 5);   
	if(getenv("USE_RDLINE_I")        )        cci_config = cci_config | (1 << 6);   
	if(getenv("USE_WRLINE_I")        )        cci_config = cci_config | (1 << 7);   
	if(getenv("NOHAZARDS_RD")        )        cci_config = cci_config | (1 << 8);   
	if(getenv("NOHAZARDS_WR_FULL")   )        cci_config = cci_config | (1 << 9);   
	if(getenv("NOHAZARDS_WR_ALL")    )        cci_config = cci_config | (1 << 10);   
   
   
   aocl_mmd_write(NULL,NULL, 8,&cci_config,0, QPI_ADDR_RANGE+NUM_RULES*3*8+8); 
}


   unsigned long int version_id = 0; 
  // aocl_mmd_read(NULL,NULL, 4, &version_id, 0, AOCL_MMD_VERSION_ID); 
/*
   if( version_id != 0x4D5FEA30 ){
	fprintf(stderr, "aocl_mmd_open: Incorrect version ID\n");
	fprintf(stderr, "aocl_mmd_open: Version ID currently configured is 0x%0x\n", version_id);
	fprintf(stderr, "aocl_mmd_open: MMD expects ID to be 0x%0x\n", 0x4D5FEA30); 

     //return -1;
   };
   */
   
		opened = 1;
    current_alloc_offset = 0;
   return MMDHANDLE;
}



int AOCL_MMD_CALL  aocl_mmd_close(int handle) {

   // Clean up..
  DEBUG_PRINT("Closing MMD\n"); 
  pCCIPMMD->close();

   delete pCCIPMMD;
   
   opened = 0;
   
   return 0;

}
 // <begin IRuntimeClient interface>

/// @} group HelloALIVTPNLB


//=============================================================================
// Name: main
// Description: Entry point to the application
// Inputs: none
// Outputs: none


void write_32(size_t addr, int value){

  aocl_mmd_write(NULL,NULL, 4,value ,0, addr); 
}
int main() {
  printf("Hello from the MMD\n");
  int handle = aocl_mmd_open("name");
  int id =0; 
  sleep(1);
  aocl_mmd_write(NULL,NULL, 4,0 ,0, 16432); 
  sleep(1);
  write_32( 16408, 0); 
  sleep(1);
  write_32( 16432, 0); 
  sleep(1);
  write_32( 16416, 0); 
  sleep(1);  
  int num_lines = 1;
  write_32( 20520, 1); 
  write_32( 20524, 1); 
  write_32( 20528, 1); 
  write_32( 20532, 1); 
  write_32( 20536, 1); 
  write_32( 20540, 1); 
  write_32( 20544, 1); 
  write_32( 20548, 1); 
  write_32( 20552, 1); 
  write_32( 20556, 1); 
  write_32( 20560, 1); 
  write_32( 20564, 0); 
  write_32( 20568, 0); 
  write_32( 20572, 0); 
  /*write_32( 20576, myapp.OneLargeVirt() & 0xFFFFFFFF); 
  write_32( 20580, myapp.OneLargeVirt() >> 32); 
  write_32( 20584, myapp.OneLargeVirt() & 0xFFFFFFFF); 
  write_32( 20588, myapp.OneLargeVirt() >> 32); 
  write_32( 20592, num_lines); 
  write_32( 20480, 1); */
  sleep(10);  
  aocl_mmd_close(handle);



}



// This function checks if the input data has an ELF-formatted blob.
// Return true when it does.
static bool blob_has_elf_signature( void* data, size_t data_size )
{
   bool result = false;
   if ( data && data_size > 4 ) {
      unsigned char* cdata = (unsigned char*)data;
      const unsigned char elf_signature[4] = { 0177, 'E', 'L', 'F' }; // Little endian
      result = (cdata[0] == elf_signature[0])
            && (cdata[1] == elf_signature[1])
            && (cdata[2] == elf_signature[2])
            && (cdata[3] == elf_signature[3]);
   }
   return result;
}



// Perform a simple read to the PR base ID in the static region and compare it with the given ID
// Return 0 on success
int pr_base_id_test(unsigned int pr_import_version)
{    
   unsigned int pr_base_version = 0; // make sure it's not what we hope to find. 

   //fprintf(stderr, "pr_base_id_test: Reading PR base ID from fabric ...\n");

   aocl_mmd_read(NULL,NULL, 4, &pr_base_version, 0, AOCL_MMD_PR_BASE_ID); 

   if( pr_base_version == pr_import_version ){
     //fprintf(stderr, "pr_base_id_test: PR base and import compile IDs match\n");
     //fprintf(stderr, "pr_base_id_test: PR base ID currently configured is 0x%0x\n", pr_base_version);
     //fprintf(stderr, "pr_base_id_test: PR import compile ID is 0x%0x\n", pr_import_version);
     return 0;
   };
 
   // Kernel read command succeed, but got bad data. (version id doesn't match)
   fprintf(stderr, "bdw_reprogram: PR base and import compile IDs do not match\n");
   fprintf(stderr, "bdw_reprogram: PR base ID currently configured is 0x%0x\n", pr_base_version);
   fprintf(stderr, "bdw_reprogram: PR import compile expects ID to be 0x%0x\n", pr_import_version); 
   return -1;
}

