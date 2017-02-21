`ifndef fpga_defines
`define fpga_defines  
//      `define     FPGA_TOP                                    // FPGA_TOP (fiu_top + afu) sim/synth
        `define     SKXP                                        // SKXP vs BDXP features
                                                                //-------------------------------------------------------------------
                                                                // Simulation Text Message Display 
                                                                //-------------------------------------------------------------------  
        `define     PROTOCOL_MSG                                // Display KTI Protocol Text Message 
//      `define     LINK_MSG                                    // Display KTI Link Layer Messages 
//      `define     TAG_MSG                                     // Display Tag Access Text Message 
//      `define     CACHE_MSG                                   // Display Cache Access Text Message  
//      `define     CCI_MSG                                     // Display CCI interface Text Message 
//      `define     AFU_MSG                                     // Display AFU Message (User defined)
                                                                //--------------------------------------------------------------------
                                                                // Hardware Configuration
                                                                //--------------------------------------------------------------------
//      `define     TAG_SWIZZLE                                 // Enable Tag Swizzle for optimal parallel linear streams
//      `define     ONCHIP_RAM                                  // Use Onchip Block Ram as Memory instead of DDR
//      `define     DDR_TEST                                    // Turn on DDR standalone test for signal integrity
//      `define     TEST_CREDIT                                 // Include Credit debug signals
        `define     DUAL_CHANNEL                                // Dual Protocol Channels 
        `define     ADD_DATA_PIPE                               // Add tx/rx data pipe stage for easier timing closure, but adds 2 clk latency
//      `define     RTID_SEARCH                                 // Use RTID search logic (vs. FIFO)
//      `define     INVWB_CYCLE                                 // Uses InvWb = InvItoE + WbMtoI from Proto
        `define     CONFLICT_WB                                 // Perform immediate WbMtoI after an early conflict between InvItoE and SnpX
        `define     INCLUDE_PR                                  //
        `define     INCLUDE_PARITY                              // Include parity for memory blocks  
        `define     INCLUDE_CA                                  // Include Cache Agent
        `define     INCLUDE_ERR                                 // Include Error Reporting Logic
//      `define     INCLUDE_KTI                                 // Include KTI 
        `define     INCLUDE_FME                                 // Include FPGA Management Engine
//      `define     INCLUDE_HA                                  // Include Home Agent
//      `define     INCLUDE_IOMMU                               // Include IOMMU
//      `define     INCLUDE_MC                                  // Include Memory Controller 
//      `define     INCLUDE_DMA                                 // Include DMA Engine
//      `define     INCLUDE_SMBUS                               // Include SMBus
        `define     INCLUDE_NLB                                 // Include Native Loopback Module 
        `define     INCLUDE_PCIE0                               // Include PCI-E port0
//      `define     INCLUDE_PCIE1                               // Include PCI-E port1 
//      `define     INCLUDE_HSSI0                               // Include HSSI port0
//      `define     INCLUDE_HSSI1                               // Include HSSI port1
//      `define     INCLUDE_GPIO                                // Include GPIO 
//      `define     INCLUDE_TASK                                // Include task manager
`ifndef  SIM_MODE  
//	`define INCLUDE_PHY                          // Include Physical Layer
`else
        `define SIMULATION_MODE
`endif
                                                                //-------------------------------------------------------------------
                                                                // Debug Signals 
                                                                //-------------------------------------------------------------------
        `define     DEBUG_PROTO                                 // Include protocol layer debug signaltaps  
        `define     DEBUG_LINK                                  // Include link layer debug signaltaps
        `define     DEBUG_ERR                                   // Include Error debug signaltaps
//      `define     DEBUG_CCI                                   // Include cci debug signaltaps 
//      `define     DEBUG_PHY                                   // Include UPI phy debug signaltaps
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
        `define     EXTENDED_SCRATCHPAD                         // Instatiate scratch pad CSRs in the FPGA
                                                                //--------------------------------------------------------------------
                                                                //  Technology
                                                                //--------------------------------------------------------------------                                                                
        `define     VENDOR_ALTERA                               // For Altera FPGA
        `define     TOOL_QUARTUS                                // Use Altera Quartus Tool        

        `define E_UC_FPLL_RF322M
`endif       
