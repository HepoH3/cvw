///////////////////////////////////////////
// busdp.sv
//
// Written: Ross Thompson ross1728@gmail.com January 30, 2022
// Modified: 
//
// Purpose: Bus data path.
// Bus Side logic
// register the fetch data from the next level of memory.
// This register should be necessary for timing.  There is no register in the uncore or
// ahblite controller between the memories and this cache.
// 
// A component of the Wally configurable RISC-V project.
// 
// Copyright (C) 2021 Harvey Mudd College & Oklahoma State University
//
// MIT LICENSE
// Permission is hereby granted, free of charge, to any person obtaining a copy of this 
// software and associated documentation files (the "Software"), to deal in the Software 
// without restriction, including without limitation the rights to use, copy, modify, merge, 
// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons 
// to whom the Software is furnished to do so, subject to the following conditions:
//
//   The above copyright notice and this permission notice shall be included in all copies or 
//   substantial portions of the Software.
//
//   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
//   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
//   PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS 
//   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
//   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE 
//   OR OTHER DEALINGS IN THE SOFTWARE.
////////////////////////////////////////////////////////////////////////////////////////////////

`include "wally-config.vh"

module busdp #(parameter WORDSPERLINE, LINELEN, LOGWPL, CACHE_ENABLED)
  (
  input logic                 clk, reset,
  
  // bus interface
  input logic [`XLEN-1:0]     HRDATA,
  input logic                 BusAck,
  input logic                 BusInit,
  output logic                BusWrite,
  output logic                BusRead,
  output logic [2:0]          HSIZE,
  output logic [2:0]          HBURST,
  output logic [1:0]          HTRANS,
  output logic                BusTransComplete,
  output logic [`PA_BITS-1:0] HADDR,
  output logic [LOGWPL-1:0]   WordCount,
  
  // cache interface
  input logic [`PA_BITS-1:0]  CacheBusAdr,
  input logic                 CacheFetchLine,
  input logic                 CacheWriteLine,
  output logic                CacheBusAck,
  output logic [LINELEN-1:0]  FetchBuffer, 
  output logic                SelUncachedAdr,
 
  // lsu/ifu interface
  input logic [`PA_BITS-1:0]  PAdrM,
  input logic                 IgnoreRequest,
  input logic [1:0]           RWM,
  input logic                 CPUBusy,
  input logic                 CacheableM,
  input logic [2:0]           Funct3,
  output logic                SelLSUBusWord,
  output logic                BusStall,
  output logic                BusCommittedM);
  
  localparam integer   WordCountThreshold = CACHE_ENABLED ? WORDSPERLINE - 1 : 0;
  logic [`PA_BITS-1:0]        LocalHADDR;
  logic [LOGWPL-1:0]   WordCountDelayed;
  logic                BufferCaptureEn;

  genvar                      index;
  for (index = 0; index < WORDSPERLINE; index++) begin:fetchbuffer
    logic [WORDSPERLINE-1:0] CaptureWord;
    assign CaptureWord[index] = BufferCaptureEn & (index == WordCountDelayed);
    flopen #(`XLEN) fb(.clk, .en(CaptureWord[index]), .d(HRDATA),
      .q(FetchBuffer[(index+1)*`XLEN-1:index*`XLEN]));
  end

  mux2 #(`PA_BITS) localadrmux(CacheBusAdr, PAdrM, SelUncachedAdr, LocalHADDR);
  assign HADDR = ({{`PA_BITS-LOGWPL{1'b0}}, WordCount} << $clog2(`XLEN/8)) + LocalHADDR;

  mux2 #(3) sizemux(.d0(`XLEN == 32 ? 3'b010 : 3'b011), .d1(Funct3), .s(SelUncachedAdr), .y(HSIZE));

  busfsm #(WordCountThreshold, LOGWPL, CACHE_ENABLED) busfsm(
    .clk, .reset, .IgnoreRequest, .RWM, .CacheFetchLine, .CacheWriteLine,
		.BusAck, .BusInit, .CPUBusy, .CacheableM, .BusStall, .BusWrite, .SelLSUBusWord, .BusRead, .BufferCaptureEn,
		.HBURST, .HTRANS, .BusTransComplete, .CacheBusAck, .BusCommittedM, .SelUncachedAdr, .WordCount, .WordCountDelayed);
endmodule
