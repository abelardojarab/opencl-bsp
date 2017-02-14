/* (C) 1992-2014 Altera Corporation. All rights reserved.                          */
/* Your use of Altera Corporation's design tools, logic functions and other        */
/* software and tools, and its AMPP partner logic functions, and any output        */
/* files any of the foregoing (including device programming or simulation          */
/* files), and any associated documentation or information are expressly subject   */
/* to the terms and conditions of the Altera Program License Subscription          */
/* Agreement, Altera MegaCore Function License Agreement, or other applicable      */
/* license agreement, including, without limitation, that your use is for the      */
/* sole purpose of programming logic devices manufactured by Altera and sold by    */
/* Altera or its authorized distributors.  Please refer to the applicable          */
/* agreement for further details.                                                  */
    


struct speed {
  float fastest;
  float slowest;
  float average;
  float total;
};

void ocl_device_init( unsigned dev_num, int maxbytes);
struct speed ocl_readspeed(char * buf,int block_bytes,int bytes);
struct speed ocl_writespeed(char * buf,int block_bytes,int bytes);
int ocl_test_all_global_memory( );
