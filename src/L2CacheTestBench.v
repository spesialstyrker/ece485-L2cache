//**************************************************
// Test bench for the L2 cache
//**************************************************

`include "L2Cache.v"

module L2CacheTestBench();

// Configurable params for the architecture used
parameter commandSize = 8;
parameter addressSize = 32;

//Configurable params for the cache implementation
parameter ways = 8;
parameter sets = 16384;
parameter lineSize = 512;
reg [addressSize - 1:0] indexBits;
reg [addressSize - 1:0] byteSelect;
reg [addressSize - 1:0] tagBits;

wire [lineSize - 1:0]   sharedBus;
wire [255:0]            L1Bus

initial begin
  indexBits = $clog2(sets);
  byteSelect = $clog2(lineSize);
  tagBits = indexBits - byteSelect bits;
end

// File handle and I/O function return value
integer file;
integer line;

// Buffers to store the parsed in command and address
reg   [commandSize - 1:0] command;
wire  [addressSize - 1:0] L1address;
wire  [addressSize - 1:0] sharedAddress;


// Wires to connect the cache to the the GetSnoopResult module
wire [7:0]  operationBus;
wire [1:0]  snoopBus;

// Instantiate our L2 cache
L2Cache #(ways, indexBits, lineSize, tagBits) cache(.command(command), .L1Bus(L1address), .snoopBus(), .sharedBus(sharedAddress), .operationBus(operationBus));

// Instantiate GetSnoopResult
GetSnoopResult #(addressSize) snoop(.sharedBus(sharedAddress), .operation

module fileIO(L1address,sharedAdress,operationBus);
  output [addressSize - 1]L1address;

initial
begin
  // Open the trace file and start parsing in each line
  file = $fopen("cc1.din", "r");

  while(!$feof(file))
    begin
      line = $fscanf(file, "%h %h", command, address);

      case(command)
        0:  begin
              // L1 data cache read request
              $display("L1 data cache read request to address %h", address);
              
          
        1:
          // L1 data cache write request
          $display("L1 data cache write request to address %h", address);
          
        2:
          // L1 instruction cache read request
          $display("L1 instruction cache read request to address %h", address);
          
        3:
          // Snooped invalidate command
          $display("Snooped invalidate command to address %h", address);
          
        4:
          // Snooped read request
          $display("Snooped read request to address %h", address);
          
        5:
          // Snooped write request
          $display("Snooped write request to address %h", address);
          
        6:
          // Snooped read with intent to modify
          $display("Snooped read with intent to modify to address %h", address);
          
        8:
          // Clear cache & reset all states
          $display("Clear cache & reset all states");
          
        9:
          // Print contents and state of each valid
          $display("Print contents and state of each valid");
          // cache line (allow subsequent trace activity
      endcase
    end
end
endmodule
