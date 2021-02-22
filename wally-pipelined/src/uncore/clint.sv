///////////////////////////////////////////
// clint.sv
//
// Written: David_Harris@hmc.edu 14 January 2021
// Modified: 
//
// Purpose: Core-Local Interruptor
//   See FE310-G002-Manual-v19p05 for specifications
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
// files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, 
// modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software 
// is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES 
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
// BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT 
// OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
///////////////////////////////////////////

`include "wally-config.vh"

module clint (
  input  logic             HCLK, HRESETn,
  input  logic [1:0]       MemRWclint,
  input  logic [15:0]      HADDR, 
  input  logic [`XLEN-1:0] HWDATA,
  output logic [`XLEN-1:0] HREADCLINT,
  output logic             HRESPCLINT, HREADYCLINT,
  output logic             TimerIntM, SwIntM);

  logic [63:0] MTIMECMP, MTIME;
  logic        MSIP;

  logic [15:0] entry;
  logic            memread, memwrite;

  assign memread  = MemRWclint[1];
  assign memwrite = MemRWclint[0];
  assign HRESPCLINT = 0; // OK
  assign HREADYCLINT = 1; // Respond immediately
  
  // word aligned reads
  generate
    if (`XLEN==64)
      assign #2 entry = {HADDR[15:3], 3'b000};
    else
      assign #2 entry = {HADDR[15:2], 2'b00}; 
  endgenerate
  
  // DH 2/20/21: Eventually allow MTIME to run off a separate clock
  // This will require synchronizing MTIME to the system clock
  // before it is read or compared to MTIMECMP.
  // It will also require synchronizing the write to MTIMECMP.
  // Use req and ack signals synchronized across the clock domains.

  // register access
  generate
    if (`XLEN==64) begin
      always_comb begin
        case(entry)
          16'h0000: HREADCLINT = {63'b0, MSIP};
          16'h4000: HREADCLINT = MTIMECMP;
          16'hBFF8: HREADCLINT = MTIME;
          default:  HREADCLINT = 0;
        endcase
      end 
      always_ff @(posedge HCLK or negedge HRESETn) 
        if (~HRESETn) begin
          MSIP <= 0;
          MTIME <= 0;
          MTIMECMP <= 0;
          // MTIMECMP is not reset
        end else if (memwrite) begin
          if (entry == 16'h0000) MSIP <= HWDATA[0];
          if (entry == 16'h4000) MTIMECMP <= HWDATA;
          // MTIME Counter.  Eventually change this to run off separate clock.  Synchronization then needed
          if (entry == 16'hBFF8) MTIME <= HWDATA;
          else MTIME <= MTIME + 1;
        end
    end else begin // 32-bit
      always_comb begin
        case(entry)
          16'h0000: HREADCLINT = {31'b0, MSIP};
          16'h4000: HREADCLINT = MTIMECMP[31:0];
          16'h4004: HREADCLINT = MTIMECMP[63:32];
          16'hBFF8: HREADCLINT = MTIME[31:0];
          16'hBFFC: HREADCLINT = MTIME[63:32];
          default:  HREADCLINT = 0;
        endcase
      end 
      always_ff @(posedge HCLK or negedge HRESETn) 
        if (~HRESETn) begin
          MSIP <= 0;
          MTIME <= 0;
          MTIMECMP <= 0;
          // MTIMECMP is not reset
        end else if (memwrite) begin
          if (entry == 16'h0000) MSIP <= HWDATA[0];
          if (entry == 16'h4000) MTIMECMP[31:0] <= HWDATA;
          if (entry == 16'h4004) MTIMECMP[63:32] <= HWDATA;
          // MTIME Counter.  Eventually change this to run off separate clock.  Synchronization then needed
          if (entry == 16'hBFF8) MTIME[31:0] <= HWDATA;
          else if (entry == 16'hBFFC) MTIME[63:32]<= HWDATA;
          else MTIME <= MTIME + 1;
        end
    end
  endgenerate

  // Software interrupt when MSIP is set
  assign SwIntM = MSIP;
  // Timer interrupt when MTIME >= MTIMECMP
  assign TimerIntM = ({1'b0, MTIME} >= {1'b0, MTIMECMP}); // unsigned comparison

endmodule

