// ***************************************************************************
// Copyright (c) 2017, Intel Corporation
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// * Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// * Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
// * Neither the name of Intel Corporation nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// ***************************************************************************

`ifndef fpga_defines
`define fpga_defines  
        `define     FPGA_TOP                                    // FPGA_TOP (fiu_top + afu) sim/synth 
        `define     SKXP                                        // SKXP vs BDXP features 
                                                                //-------------------------------------------------------------------
                                                                // Simulation Text Message Display 
                                                                //-------------------------------------------------------------------  
//      `define     PROTOCOL_MSG                                // Display KTI Protocol Text Message 
//      `define     LINK_MSG                                    // Display KTI Link Layer Messages   
//      `define     TAG_MSG                                     // Display Tag Access Text Message 
//      `define     CACHE_MSG                                   // Display Cache Access Text Message     
//      `define     CCI_MSG                                     // Display CCI interface Text Message 
//      `define     AFU_MSG                                     // Display AFU Message (User defined)
                                                                //--------------------------------------------------------------------
                                                                // Hardware Configuration
                                                                //--------------------------------------------------------------------
//      `define     TAG_SWIZZLE                                 // Enable Tag Swizzle for optimal parallel linear streams
        `define     DUAL_CHANNEL                                // Dual Protocol Channels 
        `define     ADD_DATA_PIPE                               // Add tx/rx data pipe stage for easier timing closure, but adds 2 clk latency
//      `define     IOPLL                                       // Use IO PLL for clocking (instead of FPLL)
//      `define     TEST_CREDIT                                 // Reduce VNA/ACK credits to 16 for VNA/VN0/ACK throttle testing
//      `define     RTID_SEARCH                                 // Use RTID search logic (vs. FIFO)
//      `define     CONFLICT_WB                                 // Perform immediate WbMtoI after an early conflict between InvItoE and SnpX
        `define     DISABLE_PARITY_HANDLING                     /* FIXMEL Flag to be removed after debugging error */
        `define     MASK_PCIe0_ERROR                            // FIXME Flag to be removed after debugging the PCIe0 format type error
        `define     DISABLE_MBP_CAPTURE                         /* FIXME  Flag to be removed after PO */
        `define     DISABLE_KTI_ERRORS                          /* FIXME  Flag to be removed after PO */
                                                                //
        `define     INCLUDE_PARITY                              // Include parity for memory blocks  
        `define     INCLUDE_CA                                  // Include Cache Agent 
        `define     INCLUDE_ERR                                 // Include Error Reporting Logic
        `define     INCLUDE_KTI                                 // Include KTI        
        `define     INCLUDE_FME                                 // Include FPGA Management Engine
        `define     INCLUDE_IOMMU                               // Include IOMMU  
        `define     INCLUDE_SMBUS                               // Include SMBus
        `define     INCLUDE_PCIE0                               // Include PCI-E EP port0
        `define     INCLUDE_PCIE1                               // Include PCI-E EP port1 
//      `define     INCLUDE_PCIE_RP0                            // Include PCI-E RP port0
//      `define     INCLUDE_PCIE_RP1                            // Include PCI-E RP port1 
        `define     INCLUDE_GPIO                                // Include GPIO 
        `define     INCLUDE_NLB                                 // Include Native Loopback Module 
//      `define     INCLUDE_HA                                  // Include Home Agent
//      `define     INCLUDE_MC                                  // Include Memory Controller 
//      `define     INCLUDE_DMA                                 // Include DMA Engine
//      `define     INCLUDE_TASK                                // Include task manager 
        `define     INCLUDE_PR                                  // Include Partial Reconfig
//        `define     INCLUDE_REMOTE_STP                          // Include Remote SignalTap
//      `define     ONCHIP_RAM                                  // Use Onchip Block Ram as Memory instead of DDR
//      `define     DDR_TEST                                    // Turn on DDR standalone test for signal integrity
`ifndef  SIM_MODE  `define INCLUDE_PHY                          // Include Physical Layer
`else
        `define SIMULATION_MODE
`endif
                                                                //-------------------------------------------------------------------
                                                                // Debug Signals 
                                                                //-------------------------------------------------------------------
//      `define     DEBUG_PROTO                                 // Include protocol layer signaltaps   
//      `define     DEBUG_LINK                                  // Include link layer signaltaps
//      `define     DEBUG_ERR                                   // Include Error signaltaps
//      `define     DEBUG_CCI                                   // Include cci debug signaltaps 
//      `define     DEBUG_CCIP                                  // Include ccip debug signaltaps 
//      `define     DEBUG_IOMMU                                 // Include iommu debug signaltaps 
//      `define     DEBUG_PHY                                   // Include cci debug signaltaps
//      `define     DEBUG_IO                                    // Include IO Agent debug signaltaps
//      `define     DEBUG_MC                                    // Include Memory Controller debug signaltaps
//      `define     DEBUG_DMA                                   // Include DMA Engine debug signaltaps
//      `define     DEBUG_SMBUS                                 // Include SMBus debug signaltaps
//      `define     DEBUG_NLB                                   // Include Native Loopback Module debug signaltaps
//      `define     DEBUG_PCI0                                  // Include PCI-E port0 debug signaltaps
//      `define     DEBUG_PCI1                                  // Include PCI-E port1 debug signaltaps
//      `define     DEBUG_HSSI                                  // Include HSSI port debug signaltaps
//      `define     DEBUG_AFU0                                  // Include default AFU debug signaltaps
                                                                //-------------------------------------------------------------------
                                                                // Misc
                                                                //-------------------------------------------------------------------
//        `define     EXTENDED_SCRATCHPAD                       // Instatiate scratch pad CSRs in the FPGA
                                                                //--------------------------------------------------------------------
                                                                //  Technology
                                                                //--------------------------------------------------------------------                                                                
        `define     VENDOR_ALTERA                               // For Altera FPGA
        `define     TOOL_QUARTUS                                // Use Altera Quartus Tool        
`endif       

`define BITSTREAM_ID_64b   64'h00000002974d6932
`define BITSTREAM_MD_64b   64'h0000000001611210
`define FME_PR_IF_ID_L_64b 64'hFEDCBA9876543210
`define FME_PR_IF_ID_H_64b 64'h0123456789ABCDEF
`define E_UC_FPLL_RF100M
//`define INCLUDE_ETHERNET
