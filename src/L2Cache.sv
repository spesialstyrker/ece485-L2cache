//**************************************************
// L2 Cache module
//
//**************************************************

`include "Comparator.v"
`include "Encoder.v"
`include "Multiplexor.v"

module L2Cache(command, L1Bus, operationBus, snoopBus, sharedBus);
  // Establish parameters that can be used for dynamic sizing of cache
  parameter ways      = 8;    // Number of ways for set associativity
  parameter indexBits = 14;   // Number of bits from the address used for indexing to a set in way
  parameter tagBits   = 12;   // Number of bits from the address used for tag for validating index
  parameter lineSize  = 512;  // Size of the line of data in a set and used for shared bus size
  parameter L1BusSize = 256;  // Size of Bus to communicate with the L1
  parameter R         = 82;   // Read operation
  parameter W         = 87;   // Write operation
  parameter M         = 77;   // Modify operation
  parameter I         = 73;   // Invalidate operation

  // Declare inputs and outputs
  input   [7:0]             command;      // This will bring in the command operation from the trace file
  inout   [L1BusSize - 1:0] L1Bus;        // Bus used for communicating with L1
  inout   [7:0]             operationBus; // Bus used to designate read/write/modify/invalidate
  inout   [1:0]             snoopBus;     // Bus for getting/putting snoops
  inout   [lineSize - 1:0]  sharedBus;    // FSB used by other processors and DRAM

  reg[tagBits - 1:0]        addressTag;
  reg[indexBits - 1:0]      index;
  reg[$clog2(ways) - 1:0]   selectedWay;
  reg[lineSize - 1:0]       data;         // This will be used for holding data (in this case MESI bits) from cache to give it to
                                          // output the necessary output for according the MESI protocol and the operation command
                                          // received from the bus

  wire[tagBits - 1:0]   CACHE_TAG;            
  wire[lineSize - 1:0]  CACHE_DATA;
  wire[$clog2(ways) - 1:0] COMPARATOR_OUT;
  wire[lineSize - 1:0]  SELECTED_CACHE_DATA;
  wire HIT;
  wire[3:0] MESI;

  // Cache line structure
  typedef struct {
    bit[tagBits - 1:0] cacheTag;
    bit[lineSize - 1:0] cacheData;
    bit[3:0] mesi;
    bit[$clog2(ways) - 1:0] lru;
  } line;

  // Generate n ways using n structs x m sets
  line Storage[$clog2(ways) - 1:0][indexBits - 1:0];

// Loop through the set array at row[index]
// Set the way to the least recently used column
  task QueryLRU;
    begin
      automatic integer LRUvalue = 0;
      automatic bit[indexBits - 1:0] Index;
      automatic integer i;

      // Assign unpacked index input to our word using
      // the streaming operator
      {>>{Index}} = index;

      for (i = 0;i < ways; i = i + 1)
        if (Storage[i][Index].lru > LRUvalue)
        begin
          LRUvalue = Storage[i][Index].lru;
          selectedWay = i;
        end
      end
  endtask

  task UpdateLRU;
    begin
      automatic bit[indexBits - 1:0] Index;
      automatic integer i, j;

      // Array to store the LRU bits from each way
      reg[$clog2(ways) - 1:0][$clog2(ways) - 1:0] LRUbits;

      // Assign unpacked index input to our word using
      // the streaming operator
      {>>{Index}} = index;

      // Loop through the set array at row[index]
      // Store each lru bit in the way in to the matching
      // position in the temporary LRUbits array
      for (i = 0; i < ($clog2(ways) - 1); i = i + 1)
        for (j = 0; j < ($clog2(ways) - 1); j = j  +1)
          LRUbits[i][j] = Storage[i][Index].lru[j];

        // Run LRU logic to update fields given
        // Initialise all the bits to '0' first
        // The accessed line is set to '0' (in later cases it is brought down to '0' but here its already 0 and remains same )
        // After that increment all the bits assigned to other lines by 1
        // In this case take one more condition like if the line already has a higher bit than any other bit , then it remains same
        // So, if it is already highest , keep it the same
        // If more than one line has same bit assigned to it, then evict the line that comes first from left
        // which way is being read/written to
    end
  endtask

  /*
  * TIE ALL CACHE DATA OUTPUTS IN TO ONE WIDE CHANNEL TO SEND TO OUTPUT BLOCK
  */
  // Instantiate the cache output block and wire it to the storage block
  //OutputBlock #(indexBits, lineSize, tagBits, ways) CacheOutput(MESI[0], addressTag, CACHE_TAG, HIT, SELECTED_CACHE_DATA);
  // Generate parameter "ways" amount of comparators
  genvar i;
  generate
    for (i = 0; i < ways; i = i + 1)
      //This works, but it does not select a particular way, so I need to fix
      Comparator #(ways) comparator(.addressTag(addressTag), .cacheTag(CACHE_TAG[i * tagBits + tagBits - 1:i * tagBits]), .match(COMPARATOR_OUT[i]));
  endgenerate

  // Instantiate our encoder for n ways
  Encoder #(ways) encoder(comparator_out, encoder_out);

  // I don't think this is quite right, but it's a stub for now
  Multiplexor #(lineSize, ways)  multiplexor(.select(ENCODER_OUT), .in(cacheData[cacheData]), .out(MUX_OUT));

  // Code such that all (tagBits - 1) comparator outputs and valid
  // bits are ANDed together, and each output/valid pair are logically
  // ORed for hit detection
  // Output hit, cache data, and selected way.
  // Verify this works in the test bench otherwise see above
  //assign hit = comparator_out & valid;
  assign cacheLine = MUX_OUT;

  // Performs necessary tasks/functions depending on whether there is a read or right to the cache
  always@(*)
  begin
    if (operationBus == R) begin
      // read cache
      //ReadCache(Storage,index,;
      // Need a way to set the selected way
      UpdateLRU;
    end
    else begin
      // read for ownership on shared bus

      // Update the selected way for the least recently used. Once this is
      // done we write to the cache and update the LRU bits in the set.
      QueryLRU;
      // write cache
      UpdateLRU;
    end
  end
endmodule