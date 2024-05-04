//Copyright 1986-2021 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2021.1 (lin64) Build 3247384 Thu Jun 10 19:36:07 MDT 2021
//Date        : Fri May  3 23:48:43 2024
//Host        : simtool-5 running 64-bit Ubuntu 20.04.6 LTS
//Command     : generate_target top_level_wrapper.bd
//Design      : top_level_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module top_level_wrapper
   (AN,
    CLK100MHZ,
    CPU_RESETN,
    SEG,
    UART_rxd,
    UART_txd);
  output [7:0]AN;
  input CLK100MHZ;
  input CPU_RESETN;
  output [7:0]SEG;
  input UART_rxd;
  output UART_txd;

  wire [7:0]AN;
  wire CLK100MHZ;
  wire CPU_RESETN;
  wire [7:0]SEG;
  wire UART_rxd;
  wire UART_txd;

  top_level top_level_i
       (.AN(AN),
        .CLK100MHZ(CLK100MHZ),
        .CPU_RESETN(CPU_RESETN),
        .SEG(SEG),
        .UART_rxd(UART_rxd),
        .UART_txd(UART_txd));
endmodule
