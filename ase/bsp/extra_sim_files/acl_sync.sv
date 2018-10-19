//// (C) 1992-2018 Intel Corporation.                            
// Intel, the Intel logo, Intel, MegaCore, NIOS II, Quartus and TalkBack words    
// and logos are trademarks of Intel Corporation or its subsidiaries in the U.S.  
// and/or other countries. Other marks and brands may be claimed as the property  
// of others. See Trademarks on intel.com for full list of Intel trademarks or    
// the Trademarks & Brands Names Database (if Intel) or See www.Intel.com/legal (if Altera) 
// Your use of Intel Corporation's design tools, logic functions and other        
// software and tools, and its AMPP partner logic functions, and any output       
// files any of the foregoing (including device programming or simulation         
// files), and any associated documentation or information are expressly subject  
// to the terms and conditions of the Altera Program License Subscription         
// Agreement, Intel MegaCore Function License Agreement, or other applicable      
// license agreement, including, without limitation, that your use is for the     
// sole purpose of programming logic devices manufactured by Intel and sold by    
// Intel or its authorized distributors.  Please refer to the applicable          
// agreement for further details.                                                 
                                             

//  Synchronization IP for Stall Latency
//  
//  DESCRIPTION
//  ===========
//  This block implements a many-to-one adapter between FIFO-like interfaces using the stall latency protocol. The comments assume the reader is
//  familiar with the stall latency protocol, which is described in detail at //depot/docs/hld/compiler/Stall_Latency_FD.docx.
//  
//  PURPOSE OF SYNC
//  ===============
//  The purpose of the many-to-one adapter is transfer one item of data to downstream (make forward progress) only when every upstream source has
//  at least one item of data. This is straightforward when one uses combinational logic to check within the same clock cycle whether all upstream
//  sources have data and downstream has space to accept the data. With the stall latency protocol, we can insert pipeline stages between the 
//  centralized control and all interfaces (upstream and downstream), but this requires extra information like almost empty from each upstream and
//  almost full from downstream.
//  
//  OVERVIEW OF INTERFACES
//  ======================
//  Multiple upstream interfaces:
//    - Read side FIFO interfaces
//    - Advertise empty and almost empty to sync
//    - Sync decides when it is safe to force a read from all upstream blocks
//  
//  Single downstream interface:
//    - Write side FIFO interface
//    - Advertise almost full to sync
//    - Sync decides when it is safe to force a write to downstream
//  
//  Beware the FIFO interfaces use the stall latency protocol, meaning that "valid" actually means forced write and "stall" means almost full.
//  
//  HIERARCHY
//  =========
//  This file contains 3 modules:
//  
//  acl_sync_stall_latency:
//    - This is the innermost module which implements the fast read/slow read state machine
//    - This block itself contains no internal latency, it uses lots of combination logic with the assumption that the S10 retimer can borrow registers
//      from the surrounding pipeline stages (external to acl_sync_stall_latency) which were intended for pipelining for routability
//    - One must merge the empty and almost empty from all upstream sources before providing it as input to this block
//    - The only output is whether or not to force a read from all upstream blocks and force a write to downstream
//    - Predication and nonblocking mode do not affect this module, this is handled outside in acl_sync_predicate_nonblocking
//  
//  acl_sync_predicate_nonblocking:
//    - This wraps acl_sync_stall_latency with pipeline registers
//    - Separate pipeline registers bring empty and almost empty from each upstream block into a centralized place (pipelining for routability), once they reach
//      the centralized place they are merged, and if using predication or nonblocking mode they can be masked, finally they go the input of acl_sync_stall_latency
//    - The output of acl_sync_stall_latency is whether to do a transaction (read all upstream, write to downstream), each destination that this signal will go to 
//      has its own copy of pipeline registers (logically equivalent but separated because they can physically route to different areas)
//  
//  acl_sync:
//    - This wraps acl_sync_predicate_nonblocking and disables predication and nonblocking mode (these two features are not needed for syncing data paths)
//    - The data path is also not connected, one must handle that externally
//
//  The idea behind having multiple hierarchy levels is that if one conforms to the pipelining template of acl_sync_predicate_nonblocking, then one may use this
//  for convenience (the pipelining is done for you). If one wants to do some custom pipelining, e.g. asymmetrical latencies from the upstream blocks, then one
//  must use acl_sync_stall_latency and create the pipelining manually. Actually acl_sync_predicate_nonblocking acts as an example which illustrates how to use
//  acl_sync_stall_latency, and acl_sync demonstrates how to tie off predication and nonblocking modes.
//  
//  PIPELINE STAGES: PHYSICAL VS LOGICAL
//  ====================================
//  The ***_LATENCY parameters describe the number of pipeline stages assuming no FIFO retiming, e.g. upstream FIFOs have STALL_IN_EARLINESS = 0 and the downstream
//  FIFO has VALID_IN_EARLINESS = 0. In other words, the FIFO-like interfaces surrounding the sync block all have no internal latency. However this is likely not
//  a realistic assumption in practice.
//  
//  As an example, suppose we set STALL_LATENCY = 5. This means there is 5 clocks cycles of latency from the time the fast read/slow read state machine decides to
//  read until an upstream FIFO actually performs the read. If the upstream FIFO had STALL_IN_EARLINESS = 0, then we would physically have 5 pipeline registers 
//  before the i_stall port of the upstream FIFO. Instead, if the upstream FIFO had STALL_IN_EARLINESS = 1 then we would only have 4 pipeline registers. In this
//  example the upstream FIFO has stolen one pipeline register for its own internal retiming. The hyper-retimer in Quartus could also do something similar, where
//  we add some registers intended for pipelining for routability, but Quartus decides to retime some registers into the read logic of the upstream FIFO. Likewise,
//  the fast read/slow read state machine, which has lots of combinational logic, could borrow some of these registers for retiming.
//  
//  The ***_LATENCY parameters specify the amount of LOGICAL pipeline register stages (latency specification), so it is advisable to set these slightly higher so
//  that after retiming the remaining PHYSICAL pipeline registers stages are sufficient for pipelining for routability.
//
//  Example of recommended settings:
//    - EMPTY_LATENCY = 2 (increase this if NUM_IFACES is large since merging of empty and almost_empty will probably borrow registers for retiming)
//    - STALL_LATENCY = 5
//    - DATA_LATENCY = 2
//    - FULL_LATENCY = 2
//    - STALL_IN_EARLINESS = 3 -> this means 5 - 3 = 2 physical registers for stall to upstream
//    - VALID_IN_EARLINESS = 3 -> this means 5 + 2 - 3 = 4 physical registers for valid to downstream

`timescale 1ns/1ps
`default_nettype none


module acl_sync #(
    //fifo config
    parameter int NUM_IFACES = 2,               // >= 2, how many upstream interfaces, for only 1 interface use acl_desync
    
    //reset config
    parameter bit ASYNC_RESET = 0,          // how do we use reset: 1 means registers are reset asynchronously, 0 means registers are reset synchronously
    parameter bit SYNCHRONIZE_RESET = 1,    // based on how reset gets to us, what do we need to do: 1 means synchronize reset before consumption (if reset arrives asynchronously), 0 means passthrough (managed externally)
    parameter bit RESET_EVERYTHING = 0,     // intended for partial reconfig debug, set to 1 to reset every register (normally async reset excludes data path and sync reset additionally excludes some control signals)
    
    //stall latency config -- the ***_LATENCY parameters below add pipeline stages to the control signals (data is managed externally from acl_sync)
    parameter int EMPTY_LATENCY=0,            // latency from i_empty/i_almost_empty ports (from upstream fifos) to central_empty/central_almost_empty signals (input to slow read/fast read state machine)
    parameter int STALL_LATENCY=0,            // latency from central_forced_read signal (from slow read/fast read state machine) to o_stall port (stall going to upstream fifos)
    parameter int DATA_LATENCY=0,             // latency from i_data port (from upstream fifos) to o_data port (to downstream fifo), same as latency from upstream read to downstream write
    parameter int FULL_LATENCY=0,             // latency from i_stall port (almost full from downstream fifo) to central_almost_full signal (input to slow read/fast read state machine)
    parameter int STALL_IN_EARLINESS = 0,   // read earliness configuration for all upstream fifos, value must not exceed STALL_LATENCY
    parameter int VALID_IN_EARLINESS = 0    // write earliness configuration for downstream fifo, value must not exceed DATA_LATENCY + STALL_LATENCY
)
(
    input  wire                         clock,
    input  wire                         resetn,
    
    //upstream - multiple fifo read side interfaces
    input  wire        [NUM_IFACES-1:0] i_empty,            //empty from upstream fifos, 1 bit from each fifo
    input  wire        [NUM_IFACES-1:0] i_almost_empty,     //almost_empty from upstream fifos, 1 bit from each fifo
    output logic       [NUM_IFACES-1:0] o_stall,            //stall_in to upstream fifos, 1 bit from each fifo
    
    //downstream - single fifo write side interface
    output logic                        o_valid,            //forced write (no backpressure) to downstream fifo
    input  wire                         i_stall,            //almost_full from downstream fifo
    
    //note that data needs to be handled externally to acl_sync

    //profiler ports
    //Index [i] asserts when upstream interface i is the only one preventing a fast_read/slow_read. In other words, o_profiler_upstream_stall_fast_read profiles when each upstream interface is purely responsible for preventing use of the
    //high-throughput mode. And o_profiler_upstream_stall_slow_read profiles when each upstream interface is purely responsible for preventing forward progress. These signals are mutually exclusive, meaning that index [i] asserts for only
    //one of them -- in other words, if an upstream port is blamed for preventing forward progress it is not also blamed for preventing fast-read mode.
    output logic               [NUM_IFACES-1:0] o_profiler_upstream_stall_fast_read,
    output logic               [NUM_IFACES-1:0] o_profiler_upstream_stall_slow_read
);

    acl_sync_predicate_nonblocking
    #(
        //fifo config
        .NUM_IFACES                 (NUM_IFACES),
        .TOTAL_DATA_WIDTH           (0),
        
        //reset config
        .ASYNC_RESET                (ASYNC_RESET),
        .SYNCHRONIZE_RESET          (SYNCHRONIZE_RESET),
        .RESET_EVERYTHING           (RESET_EVERYTHING),
        
        //stall latency fast read/slow read state machine config
        .EMPTY_PLUS_STALL_LATENCY   (EMPTY_LATENCY + STALL_LATENCY),
        
        //stall latency pipelining config
        .EMPTY_LATENCY              ({NUM_IFACES{EMPTY_LATENCY}}),
        .STALL_LATENCY              ({NUM_IFACES{STALL_LATENCY}}),
        .DATA_LATENCY               ({NUM_IFACES{DATA_LATENCY}}),
        .FULL_LATENCY               (FULL_LATENCY),
        .STALL_IN_EARLINESS         ({NUM_IFACES{STALL_IN_EARLINESS}}),
        .VALID_IN_EARLINESS         (VALID_IN_EARLINESS),
        
        //special config
        .NON_BLOCKING               (0)
    )
    acl_sync_predicate_nonblocking_inst
    (
        .clock                      (clock),
        .resetn                     (resetn),
        
        //upstream - multiple fifo read interfaces
        .i_data                     (),         //not driven -- to be managed externally from acl_sync
        .i_almost_empty             (i_almost_empty),
        .i_empty                    (i_empty),
        .o_stall                    (o_stall),
        
        //upstream predication
        .i_predicate_data           (1'b0),     //tie off
        .o_predicate_stall          (),         //ignored
        
        //downstream - single fifo write interface
        .o_valid                    (o_valid),
        .o_data                     (),         //ignored -- to be managed externally from acl_sync
        .i_stall                    (i_stall),
        
        //profiler ports
        .o_profiler_upstream_stall_fast_read    (o_profiler_upstream_stall_fast_read),
        .o_profiler_upstream_stall_slow_read    (o_profiler_upstream_stall_slow_read)
    );
    
endmodule



module acl_sync_predicate_nonblocking #(
    //fifo config
    parameter int NUM_IFACES=0,               // how many upstream interfaces: 2 or larger, 1 will produce functionally correct code but in practice we would always use desync
    parameter int DATA_WIDTH=0,               // data width of each upstream block, if an upstream blocks has a narrower width then quartus will prune away the unused bits
    
    //reset config
    parameter bit ASYNC_RESET = 0,          // how do we use reset: 1 means registers are reset asynchronously, 0 means registers are reset synchronously
    parameter bit SYNCHRONIZE_RESET = 1,    // based on how reset gets to us, what do we need to do: 1 means synchronize reset before consumption (if reset arrives asynchronously), 0 means passthrough (managed externally)
    parameter bit RESET_EVERYTHING = 0,     // intended for partial reconfig debug, set to 1 to reset every register (normally async reset excludes data path and sync reset additionally excludes some control signals)
    
    //stall latency fast read/slow read state machine config
    parameter int EMPTY_PLUS_STALL_LATENCY=0, // the round trip latency from fast read/slow read state machine through upstream i_stall through upstream o_empty and back to fast read/slow read state machine
    
    //stall latency pipelining config -- the ***_LATENCY parameters below add pipeline stages to the control signals and data signals
    //**IMPORTANT**: the latency for EACH interface can be specified, if you want to set EMPTY_LATENCY to 2 for all interfaces, then set the parameter value to {NUM_IFACES{32'd2}}
    //the parameter slice into 32 bit values per interface, e.g. interface 0 uses the value in bits 31:0, interface 1 uses the value in bits 63:32, interface 2 uses bits 95:64, etc.
    parameter bit [32*NUM_IFACES-1:0] EMPTY_LATENCY = 0,        // latency from i_empty/i_almost_empty ports (upstream fifo N) to central_empty/central_almost_empty signals (input to slow read/fast read state machine)
    parameter bit [32*NUM_IFACES-1:0] STALL_LATENCY = 0,        // latency from central_forced_read signal (slow read/fast read state machine) to o_stall port (upstream fifo N)
    parameter bit [32*NUM_IFACES-1:0] DATA_LATENCY = 0,         // latency from i_data port (upstream fifo N) to o_data port (downstream fifo data section N), same as latency from upstream read to downstream write
    parameter bit [32*         1-1:0] FULL_LATENCY = 0,         // latency from i_stall port (almost full from downstream fifo) to central_almost_full signal (input to slow read/fast read state machine)
    parameter bit [32*NUM_IFACES-1:0] STALL_IN_EARLINESS = 0,   // each values cannot exceed the corresponding STALL_LATENCY, e.g. for interface 0 STALL_IN_EARLINESS[31:0] cannot be larger than STALL_LATENCY[31:0]
    parameter bit [32*         1-1:0] VALID_IN_EARLINESS = 0,   // write earliness configuration for downstream fifo, value must not exceed DATA_LATENCY + STALL_LATENCY
    
    //**IMPORTANT**: the following constraints on the stall latency parameter values are required for proper functionality
    //for each upstream interface, all must have the same STALL_LATENCY + DATA_LATENCY so that data arrives at downstream on the same clock cycle
    //for each upsteram interface, all must have STALL_LATENCY + EMPTY_LATENCY <= EMPTY_PLUS_STALL_LATENCY, the round trip latency must be less than the waiting period for the fast read/slow read state machine
    
    //special config
    parameter int NON_BLOCKING = 0          // for st_read, set to 1 to try to read immediately even if channel is empty
)
(
    input  wire                                 clock,
    input  wire                                 resetn,
    
    //upstream - multiple fifo read side interfaces
    input  wire     [NUM_IFACES*DATA_WIDTH-1:0] i_data,             //upstream interface i drives i_data[ DATA_WIDTH*(i+1)-1 :  DATA_WIDTH*i ], upper bits of this region can be x if interface i has narrower data path
    input  wire                [NUM_IFACES-1:0] i_empty,            //empty from upstream fifos, 1 bit from each fifo
    input  wire                [NUM_IFACES-1:0] i_almost_empty,     //almost_empty from upstream fifos, 1 bit from each fifo
    output logic               [NUM_IFACES-1:0] o_stall,            //stall_in to upstream fifos, 1 bit from each fifo
    
    //upstream predication - single fifo read side interface
    //there is NO PIPELINING on this interface, so expect it to get pulled towards the acl_sync_stall_latency state machine
    input  wire                                 i_predicate_data,   //if 1 then consume only from upstream interface 0, if 0 then consume from all upstream interfaces
    output logic                                o_predicate_stall,  //backpressure to fifo
    //empty from predication fifo is not needed, read from this fifo is tied to read from upstream interface 0 if we disregard pipelining
    
    //downstream - single fifo write side interface
    output logic    [NUM_IFACES*DATA_WIDTH-1:0] o_data,             //o_data[ DATA_WIDTH*(i+1)-1 :  DATA_WIDTH*i ] comes from upstream interface i, upper bits of this region can be x if interface i has narrower data path
    output logic                                o_valid,            //forced write (no backpressure) to downstream fifo
    input  wire                                 i_stall,            //almost_full from downstream fifo

    //profiler ports
    //Index [i] asserts when upstream interface i is the only one preventing a fast_read/slow_read. In other words, o_profiler_upstream_stall_fast_read profiles when each upstream interface is purely responsible for preventing use of the
    //high-throughput mode. And o_profiler_upstream_stall_slow_read profiles when each upstream interface is purely responsible for preventing forward progress. These signals are mutually exclusive, meaning that index [i] asserts for only
    //one of them -- in other words, if an upstream port is blamed for preventing forward progress it is not also blamed for preventing fast-read mode. These signals do not assert if i_predicate_data==1 because we are able to make forward progress in this case.
    output logic               [NUM_IFACES-1:0] o_profiler_upstream_stall_fast_read,    
    output logic               [NUM_IFACES-1:0] o_profiler_upstream_stall_slow_read
);
    
    
    genvar f, g;
    
    //reset
    logic aclrn, resetn_synchronized, sclrn, sclrn_reset_everything;
    acl_reset_handler
    #(
        .ASYNC_RESET            (ASYNC_RESET),
        .USE_SYNCHRONIZER       (SYNCHRONIZE_RESET),
        .SYNCHRONIZE_ACLRN      (SYNCHRONIZE_RESET),
        .PIPE_DEPTH             (2),
        .NUM_COPIES             (1)
    )
    acl_reset_handler_inst
    (
        .clk                    (clock),
        .i_resetn               (resetn),
        .o_aclrn                (aclrn),
        .o_resetn_synchronized  (resetn_synchronized),
        .o_sclrn                (sclrn)
    );
    assign sclrn_reset_everything = (RESET_EVERYTHING) ? sclrn : 1'b1;
    
    
    
    //polarity of the pipeline stages has been chosen so that initial values of 0 will match stall/valid reset behavior of s10
    //this makes it safe for older families when not using partial reconfig, will not get spurious transactions as the power-on reset releases
    //when using partial reconfig one must use reset for control logic, reset must be held for long enough that the control signal pipelines can flush
    
    //stall latency signals
    logic  [NUM_IFACES-1:0] central_almost_empty, central_empty;
    logic                   central_predicate, central_predicate_read, central_almost_full;
    logic                   central_can_fast_read_non_predicate, central_can_slow_read_non_predicate;
    logic                   central_can_fast_read_predicate, central_can_slow_read_predicate;
    logic                   central_can_fast_read, central_can_slow_read;
    logic                   central_forced_read;
    
    
    //parameter validation
    //for each upstream interface, all must have the same STALL_LATENCY + DATA_LATENCY so that data arrives at downstream on the same clock cycle
    //for each upsteram interface, all must have STALL_LATENCY + EMPTY_LATENCY <= EMPTY_PLUS_STALL_LATENCY, the round trip latency must be less than the waiting period for the fast read/slow read state machine
    //the checks are done in Quartus pro and Modelsim, it is disabled in Quartus standard because it results in a syntax error (parser is based on an older systemverilog standard)
    //the workaround is to use synthesis translate to hide this from Quartus standard, ALTERA_RESERVED_QHD is only defined in Quartus pro, and Modelsim ignores the synthesis comment
    `ifdef ALTERA_RESERVED_QHD
    `else
    //synthesis translate_off
    `endif
    generate
    localparam int STALL_PLUS_DATA_LATENCY = STALL_LATENCY[31:0] + DATA_LATENCY[31:0];
    for (f=1; f<NUM_IFACES; f++) begin : gen_check_downtream_sync
        if (STALL_PLUS_DATA_LATENCY != (STALL_LATENCY[32*f+:32] + DATA_LATENCY[32*f+:32])) begin
            $fatal(1, "acl_sync_predicate_nonblocking: invalid STALL_PLUS_DATA_LATENCY %d, STALL_LATENCY %d, DATA_LATENCY %d, interface number %d\n",
                STALL_PLUS_DATA_LATENCY, STALL_LATENCY[32*f+:32], DATA_LATENCY[32*f+:32], f);
        end
    end
    for (f=0; f<NUM_IFACES; f++) begin : gen_check_roundtrip
        if (EMPTY_PLUS_STALL_LATENCY < (STALL_LATENCY[32*f+:32] + EMPTY_LATENCY[32*f+:32])) begin
            $fatal(1, "acl_sync_predicate_nonblocking: invalid EMPTY_PLUS_STALL_LATENCY %d, STALL_LATENCY %d, EMPTY_LATENCY %d, interface number %d\n",
                EMPTY_PLUS_STALL_LATENCY, STALL_LATENCY[32*f+:32], EMPTY_LATENCY[32*f+:32], f);
        end
    end
    endgenerate
    `ifdef ALTERA_RESERVED_QHD
    `else
    //synthesis translate_on
    `endif
    
    
    
    
    //////////////////////////////////////////////////////////////////////////////////////////
    // STAGE 1: collect pipelined versions of almost_empty and valid from all upstream fifos
    //          and collect pipelined version of almost_full from downstream fifo
    //
    generate
    for (f=0; f<NUM_IFACES; f=f+1) begin : gen_empty
        localparam int EMPTY_PIPELINE_STAGES = EMPTY_LATENCY[32*f+:32];
        `ifdef ALTERA_RESERVED_QHD
        `else
        //synthesis translate_off
        `endif
        if (EMPTY_PIPELINE_STAGES < 0) begin
            $fatal(1, "acl_sync_predicate_nonblocking: invalid EMPTY_PIPELINE_STAGES %d, interface number %d\n", EMPTY_PIPELINE_STAGES, f);
        end
        `ifdef ALTERA_RESERVED_QHD
        `else
        //synthesis translate_on
        `endif
        logic [EMPTY_PIPELINE_STAGES:0] pipe_many_available /* synthesis dont_merge */;
        logic [EMPTY_PIPELINE_STAGES:0] pipe_one_available /* synthesis dont_merge */;
        
        assign pipe_many_available[0] = ~i_almost_empty[f];
        assign pipe_one_available[0] = ~i_empty[f];
        if (EMPTY_PIPELINE_STAGES > 0) begin
            always_ff @(posedge clock or negedge aclrn) begin
                if (~aclrn) begin
                    pipe_many_available[EMPTY_PIPELINE_STAGES:1] <= '0;
                    pipe_one_available[EMPTY_PIPELINE_STAGES:1] <= '0;
                end
                else begin
                    pipe_many_available[EMPTY_PIPELINE_STAGES:1] <= pipe_many_available[EMPTY_PIPELINE_STAGES-1:0];
                    pipe_one_available[EMPTY_PIPELINE_STAGES:1] <= pipe_one_available[EMPTY_PIPELINE_STAGES-1:0];
                    if (~sclrn_reset_everything) begin
                        pipe_many_available[EMPTY_PIPELINE_STAGES:1] <= '0;
                        pipe_one_available[EMPTY_PIPELINE_STAGES:1] <= '0;
                    end
                end
            end
        end
        assign central_almost_empty[f] = ~pipe_many_available[EMPTY_PIPELINE_STAGES];
        assign central_empty[f] = ~pipe_one_available[EMPTY_PIPELINE_STAGES];
    end
    endgenerate
    
    generate
    localparam int AFULL_PIPELINE_STAGES = FULL_LATENCY[31:0];
    `ifdef ALTERA_RESERVED_QHD
    `else
    //synthesis translate_off
    `endif
    if (AFULL_PIPELINE_STAGES < 0) begin
        $fatal(1, "acl_sync_predicate_nonblocking: invalid AFULL_PIPELINE_STAGES %d\n", AFULL_PIPELINE_STAGES);
    end
    `ifdef ALTERA_RESERVED_QHD
    `else
    //synthesis translate_on
    `endif
    logic [AFULL_PIPELINE_STAGES:0] pipe_has_capacity /* synthesis dont_merge */;
    
    assign pipe_has_capacity[0] = ~i_stall;
    if (AFULL_PIPELINE_STAGES > 0) begin
        always_ff @(posedge clock or negedge aclrn) begin
            if (~aclrn) begin
                pipe_has_capacity[AFULL_PIPELINE_STAGES:1] <= '0;
            end
            else begin
                pipe_has_capacity[AFULL_PIPELINE_STAGES:1] <= pipe_has_capacity[AFULL_PIPELINE_STAGES-1:0];
                if (~sclrn_reset_everything) pipe_has_capacity[AFULL_PIPELINE_STAGES:1] <= '0;
            end
        end
    end
    assign central_almost_full = ~pipe_has_capacity[AFULL_PIPELINE_STAGES];
    endgenerate
    
    assign central_predicate = i_predicate_data;
    assign central_predicate_read = (NON_BLOCKING) ? 1'b1 : central_predicate;
    assign o_predicate_stall = ~central_forced_read;
    
    
    
    //merge information from all upstream fifos
    assign central_can_fast_read_non_predicate = ~(|central_almost_empty);  //all upstream nodes have at least EMPTY_LATENCY+1 items -> fast read
    assign central_can_slow_read_non_predicate = ~(|central_empty);         //all upstream nodes have at least 1 item -> slow read
    
    assign central_can_fast_read_predicate = ~central_almost_empty[0];      //if predicated, only source 0 needs to be read
    assign central_can_slow_read_predicate = ~central_empty[0];
    
    assign central_can_fast_read = (central_predicate_read) ? central_can_fast_read_predicate : central_can_fast_read_non_predicate;
    assign central_can_slow_read = (central_predicate_read) ? central_can_slow_read_predicate : central_can_slow_read_non_predicate;
    
    //Profiler signals
    generate
        // Check when each port is inhibiting slow-read or fast-read mode.
        // But we only assert when port-0 has unpredicated data. This point is specific to channels since a predicated transaction
        // from kernel-upstream (port 0) can make forward progress irrespective of the channel (port 1) being empty. So we don't want to count the channel as stalling forward progress in this case.
        // For a non-channel instantiation of this module (ie. normal datapath) predication is not used and is tied to 0 so it doesn't affect the logic below.
        // If NON_BLOCKING==1 (which only happens in channels), the below signals will always be 0, which makes sense since the intent is to profile when the channel stalls forward progress, which never happens
        // in a non-blocking channel by definition.
        for (f=0; f<NUM_IFACES; f=f+1) begin
            assign o_profiler_upstream_stall_slow_read[f] = (central_empty == (1'b1 << f)) && !central_predicate_read; // Check if upstream port [f] is the only one that's empty right now.
            assign o_profiler_upstream_stall_fast_read[f] = (central_almost_empty == (1'b1 << f)) && !o_profiler_upstream_stall_slow_read[f] && !central_predicate_read; // Check if upstream port [f] is the only one that's almost-empty and therefore preventing fast-read mode, but don't count if it's preventing slow-read too.
        end
    endgenerate
    
    ///////////////////////////////////
    //                               //
    //  STALL LATENCY INSTANTIATION  //
    //                               //
    ///////////////////////////////////
    
    acl_sync_stall_latency
    #(
        .EMPTY_PLUS_STALL_LATENCY   (EMPTY_PLUS_STALL_LATENCY),
        .ASYNC_RESET                (ASYNC_RESET),
        .SYNCHRONIZE_RESET          (0),
        .RESET_EVERYTHING           (RESET_EVERYTHING)
    )
    acl_sync_stall_latency_inst
    (
        .clock                      (clock),
        .resetn                     (resetn_synchronized),
        
        .can_fast_read              (central_can_fast_read),
        .can_slow_read              (central_can_slow_read),
        .no_space_for_result        (central_almost_full),
        .forced_read                (central_forced_read)
    );
    
    
    
    //////////////////////////////////////////////////////////////////////////////
    // STAGE 2: if state machine decides to force a read from all upstream fifos
    //          then send a pipelined version of stall to all upstream fifos
    //          and send a pipeline version of valid to downstream fifo
    //
    generate
    for (f=0; f<NUM_IFACES; f=f+1) begin : gen_not_stall
        localparam int STALL_PIPELINE_STAGES = STALL_LATENCY[32*f+:32] - STALL_IN_EARLINESS[32*f+:32];
        `ifdef ALTERA_RESERVED_QHD
        `else
        //synthesis translate_off
        `endif
        if (STALL_PIPELINE_STAGES < 0) begin
            $fatal(1, "acl_sync_predicate_nonblocking: invalid STALL_PIPELINE_STAGES %d, interface number %d\n", STALL_PIPELINE_STAGES, f);
        end
        `ifdef ALTERA_RESERVED_QHD
        `else
        //synthesis translate_on
        `endif
        logic [STALL_PIPELINE_STAGES:0] pipe_not_stall /* synthesis dont_merge */;
        
        assign pipe_not_stall[0] = (f==0) ? central_forced_read : central_forced_read & ~central_predicate;     //do not deassert stall if predicated, but interface 0 cannot be predicated
        if (STALL_PIPELINE_STAGES > 0) begin
            always_ff @(posedge clock or negedge aclrn) begin
                if (~aclrn) begin
                    pipe_not_stall[STALL_PIPELINE_STAGES:1] <= '0;
                end
                else begin
                    pipe_not_stall[STALL_PIPELINE_STAGES:1] <= pipe_not_stall[STALL_PIPELINE_STAGES-1:0];
                    if (~sclrn) pipe_not_stall[STALL_PIPELINE_STAGES] <= '0;    //keep stall asserted to upstream while in reset, don't wait for pipeline to flush
                    if (~sclrn_reset_everything) pipe_not_stall[STALL_PIPELINE_STAGES:1] <= '0;
                end
            end
        end
        assign o_stall[f] = ~pipe_not_stall[STALL_PIPELINE_STAGES];
    end
    endgenerate
    
    generate
    localparam int WRREQ_PIPELINE_STAGES = DATA_LATENCY[31:0] + STALL_LATENCY[31:0] - VALID_IN_EARLINESS[31:0];
    `ifdef ALTERA_RESERVED_QHD
    `else
    //synthesis translate_off
    `endif
    if (WRREQ_PIPELINE_STAGES < 0) begin
        $fatal(1, "acl_sync_predicate_nonblocking: invalid WRREQ_PIPELINE_STAGES %d\n", WRREQ_PIPELINE_STAGES);
    end
    `ifdef ALTERA_RESERVED_QHD
    `else
    //synthesis translate_on
    `endif
    logic [WRREQ_PIPELINE_STAGES:0] pipe_wrreq /* synthesis dont_merge */;
    
    assign pipe_wrreq[0] = central_forced_read;
    if (WRREQ_PIPELINE_STAGES > 0) begin
        always_ff @(posedge clock or negedge aclrn) begin
            if (~aclrn) begin
                pipe_wrreq[WRREQ_PIPELINE_STAGES:1] <= '0;
            end
            else begin
                pipe_wrreq[WRREQ_PIPELINE_STAGES:1] <= pipe_wrreq[WRREQ_PIPELINE_STAGES-1:0];
                if (~sclrn) pipe_wrreq[WRREQ_PIPELINE_STAGES] <= '0;    //do not write to downstream while in reset, don't wait for pipeline to flush
                if (~sclrn_reset_everything) pipe_wrreq[WRREQ_PIPELINE_STAGES:1] <= '0;
            end
        end
    end
    assign o_valid = pipe_wrreq[WRREQ_PIPELINE_STAGES];
    endgenerate
    
    
    
    //////////////////////////////////////////////////////////////////////////////////////////////////////////
    // STAGE 3: when a read from all upstream fifos has been forced, the data needs to be sent to downstream
    //
    generate
    for (f=0; f<NUM_IFACES; f=f+1) begin : gen_data
        localparam int DATA_PIPELINE_STAGES = DATA_LATENCY[32*f+:32];
        `ifdef ALTERA_RESERVED_QHD
        `else
        //synthesis translate_off
        `endif
        if (DATA_PIPELINE_STAGES < 0) begin
            $fatal(1, "acl_sync_predicate_nonblocking: invalid DATA_PIPELINE_STAGES %d, interface number %d\n", DATA_PIPELINE_STAGES, f);
        end
        `ifdef ALTERA_RESERVED_QHD
        `else
        //synthesis translate_on
        `endif
        if (DATA_WIDTH > 0) begin
            logic [DATA_PIPELINE_STAGES:0][DATA_WIDTH-1:0] pipe_data /* synthesis dont_merge */;
            
            assign pipe_data[0] = i_data[DATA_WIDTH*f +: DATA_WIDTH];
            for (g=1; g<=DATA_PIPELINE_STAGES; g=g+1) begin : gen_pipe_data
                always_ff @(posedge clock or negedge aclrn) begin
                    if (~aclrn) begin
                        pipe_data[g] <= (RESET_EVERYTHING) ? '0 : 'x;
                    end
                    else begin
                        pipe_data[g] <= pipe_data[g-1];
                        if (~sclrn_reset_everything) pipe_data[g] <= '0;
                    end
                end
            end
            assign o_data[DATA_WIDTH*f +: DATA_WIDTH] = pipe_data[DATA_PIPELINE_STAGES];
        end
    end
    endgenerate
    
    
endmodule




////////////////////////////////////
//                                //
//  STALL LATENCY IMPLEMENTATION  //
//                                //
////////////////////////////////////

//  Implementation of the fast read/slow read state machine, intended for use with the stall latency protocol
//
//  DESCRIPTION
//  ===========
//  As inputs, this module expects already combined empty and almost empty signals from upstream blocks, and the almost full from the downstream block.
//  This module will decide whether to force a transaction (read all upstream, write to downstream). Downstream must have space for the write, and the
//  read logic is split into two parts:
//  
//  1. Fast read mode:
//      - When all upstream blocks have almost empty off, then there is a sufficient amount of stuff in the FIFOs that we can read at full speed
//      - The idea is that even with the latency of pipeline stages, we have enough time to shut off the read so that no upstream FIFO will underflow
//  2. Slow read mode:
//      - All upstream blocks have empty off, but at least one is asserting almost empty
//      - With the latency of pipeline stages, we do not have enough time to shut off a read before an upstream FIFO underflows
//      - If we have not read in the last EMPTY_LATENCY + STALL_LATENCY clock cycles, can read once on this clock cycle
//      - Throughput in slow read mode: one item every EMPTY_LATENCY + STALL_LATENCY + 1 clock cycles
//
//  USE OF COMBINATIONAL LOGIC
//  ==========================
//  It is assumed that outside of this module, one uses combinational logic to merge the empty and almost empty from all upstream blocks. Inside this
//  module, we use lots of combinational logic. If one wants high fmax, it is assumed that there are a sufficient amount of pipeline stages surrounding
//  this module so that some registers can be borrowed for retimining into this module.

module acl_sync_stall_latency #(
    //stall latency config
    parameter int EMPTY_PLUS_STALL_LATENCY=0, // round-trip latency from the almost_empty of upstream fifo to centralized fast read/slow read state machine to i_stall of upstream fifo
    
    //reset config
    parameter bit ASYNC_RESET = 0,          // how do we use reset: 1 means registers are reset asynchronously, 0 means registers are reset synchronously
    parameter bit SYNCHRONIZE_RESET = 1,    // based on how reset gets to us, what do we need to do: 1 means synchronize reset before consumption (if reset arrives asynchronously), 0 means passthrough (managed externally)
    parameter bit RESET_EVERYTHING = 0      // intended for partial reconfig debug, set to 1 to reset every register (normally async reset excludes data path and sync reset additionally excludes some control signals)
)
(
    input  wire     clock,
    input  wire     resetn,
    
    //the following signals have all been pipelined and merged from the surrounding fifo interfaces
    input  wire     can_fast_read,          // almost_empty are all 0, pipelined and merged from all upstream fifos
    input  wire     can_slow_read,          // empty are all 0, pipelined and merged from all upstream fifos
    input  wire     no_space_for_result,    // almost_full from the single downstream fifo
    output logic    forced_read             // decide whether to force a read from all upstream fifos, which also means later forcing a write to downstream
);
    
    //reset
    logic aclrn, sclrn, sclrn_reset_everything;
    acl_reset_handler
    #(
        .ASYNC_RESET            (ASYNC_RESET),
        .USE_SYNCHRONIZER       (SYNCHRONIZE_RESET),
        .SYNCHRONIZE_ACLRN      (SYNCHRONIZE_RESET),
        .PIPE_DEPTH             (2),
        .NUM_COPIES             (1)
    )
    acl_reset_handler_inst
    (
        .clk                    (clock),
        .i_resetn               (resetn),
        .o_aclrn                (aclrn),
        .o_resetn_synchronized  (),
        .o_sclrn                (sclrn)
    );
    assign sclrn_reset_everything = (RESET_EVERYTHING) ? sclrn : 1'b1;
    
    //indicates there have been no reads over the last EMPTY_PLUS_STALL_LATENCY clocks, generated in different ways for zero, small and large values of EMPTY_PLUS_STALL_LATENCY
    logic no_recent_reads;
    
    //conditions for a transaction to happen:
    // - downstream must have space, and
    // - all upstreams have lots of stuff (can_fast_read), or all upstreams have something and we haven't read for the last EMPTY_PLUS_STALL_LATENCY clocks (can_slow_read & no_recent_reads)
    assign forced_read = ~no_space_for_result & (can_fast_read | (can_slow_read & no_recent_reads));
    
    generate
    if (EMPTY_PLUS_STALL_LATENCY == 0) begin : gen_zero_latency //this requires EMPTY_LATENCY == 0 && STALL_LATENCY == 0 -> legacy stall/valid, but DATA_LATENCY >= 1 and FULL_LATENCY >= 1 are allowed
        assign no_recent_reads = 1'b1;                          //in this case we expect empty and almost_empty from each upstream to be identical, so really forced_read = ~no_space_for_result & can_fast_read
    end
    else if (EMPTY_PLUS_STALL_LATENCY <= 2) begin : gen_small_latency
        logic [EMPTY_PLUS_STALL_LATENCY-1:0] forced_read_history;
        always_ff @(posedge clock or negedge aclrn) begin
            if (~aclrn) begin
                forced_read_history <= '0;
            end
            else begin
                forced_read_history <= (forced_read_history<<1) | forced_read;
                if (~sclrn) forced_read_history <= '0;
            end
        end
        assign no_recent_reads = ~|forced_read_history;
    end
    else begin : gen_large_latency  //EMPTY_PLUS_STALL_LATENCY >= 3
        // EMPTY_PLUS_STALL_LATENCY     SLOW_READ_COUNTER_BITS
        // 3                            2
        // 4 to 5                       3
        // 6 to 9                       4
        // 10 to 17                     5
        localparam SLOW_READ_COUNTER_BITS = $clog2(EMPTY_PLUS_STALL_LATENCY-1) + 1;
        logic [SLOW_READ_COUNTER_BITS-1:0] slow_read_counter;   //count from 1-EMPTY_PLUS_STALL_LATENCY up to 0, all values other than 0 have msb = 1 (sign bit)
        logic forced_read_prev;
        
        always_ff @(posedge clock or negedge aclrn) begin
            if (~aclrn) begin
                forced_read_prev <= 1'b0;
                slow_read_counter <= '0;
            end
            else begin
                forced_read_prev <= forced_read;
                if (forced_read_prev) slow_read_counter <= 1-EMPTY_PLUS_STALL_LATENCY;
                else if (slow_read_counter[SLOW_READ_COUNTER_BITS-1]) slow_read_counter <= slow_read_counter + 1;   //count is negative, keep going
                
                if (~sclrn) begin
                    forced_read_prev <= 1'b0;
                    slow_read_counter <= '0;
                end
            end
        end
        assign no_recent_reads = ~forced_read_prev & ~slow_read_counter[SLOW_READ_COUNTER_BITS-1];
    end
    endgenerate
    
endmodule

`default_nettype wire
