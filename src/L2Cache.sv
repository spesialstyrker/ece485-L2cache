//**************************************************
// L2 Cache module
//
//**************************************************

`include "Comparator.sv"
`include "Encoder.sv"
`include "Multiplexor.sv"

module L2Cache(command, L1Bus, operationBus, snoopBus, sharedBus, hit, miss, read, write);
  // Establish parameters that can be used for dynamic sizing of cache
  parameter byteSelect= 6;    // Number of byte select bits according to line size
  parameter indexBits = 14;   // Number of bits from the address used for indexing to a set in way
  parameter lineSize  = 512;  // Size of the line of data in a set and used for shared bus size
  parameter L1BusSize = 256;  // Size of Bus to communicate with the L1
  parameter tagBits   = 12;   // Number of bits from the address used for tag for validating index
  parameter ways      = 8;    // Number of ways for set associativity
  parameter R         = "R";   // Read operation
  parameter W         = "W";   // Write operation
  parameter M         = "M";   // Modify operation
  parameter I         = "I";   // Invalidate operation

  // Declare inputs and outputs
  input   [7:0]             command;      // This will bring in the command operation from the trace file
  inout   [L1BusSize - 1:0] L1Bus;        // Bus used for communicating with L1
  inout   [7:0]             operationBus; // Bus used to designate read/write/modify/invalidate
  inout   [1:0]             snoopBus;     // Bus for getting/putting snoops
  inout   [lineSize - 1:0]  sharedBus;    // FSB used by other processors and DRAM

  output hit;
  output miss;
  output read;
  output write;

  // Establish wires/registers for use by the module
  reg[tagBits - 1:0]        addressTag;   // Current operation's tag from address
  reg[indexBits - 1:0]      index;        // Current operation's index from address
  reg[$clog2(ways) - 1:0]   selectedWay;  // Current operation's selected way according to LRU
  reg[lineSize - 1:0]       data;         // This will be used for holding data (in this case MESI bits) from cache to give it to
                                          //  output the necessary output for according the MESI protocol and the operation command
                                          //  received from the bus
  
  
  wire[tagBits - 1:0]       CACHE_TAG;            // Current operation's tag from cache according to cache walk
  wire[lineSize - 1:0]      CACHE_DATA;           // Current operation's data (MESI bits) according to cache walk
  wire[$clog2(ways) - 1:0]  COMPARATOR_OUT;       
  wire[lineSize - 1:0]      SELECTED_CACHE_DATA;
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
  task QueryLRU; begin
      automatic integer LRUvalue = 0;
      automatic bit[indexBits - 1:0] Index;
      automatic integer i;

      // Assign unpacked index input to our word using
      // the streaming operator
      {>>{Index}} = index;

      // Loop through each way to find which way is LRU
      //  i is used to keep track of the current way during the loop
      for (i = 0;i < ways; i = i + 1)
        if (Storage[i][Index].lru > LRUvalue) begin
          LRUvalue = Storage[i][Index].lru;
          selectedWay = i;
        end
      end
  endtask

  task UpdateLRU; begin
      automatic bit[indexBits - 1:0] Index;
      automatic integer i, j;

      // Array to store the LRU bits from each way (LRU = 3 bits per x ways)
      reg[$clog2(ways) - 1:0][2:0] LRUbits;

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
  wire[ways * lineSize - 1:0] CACHE_DATA_OUT;
  genvar i;
  generate
    for (i = 0; i < ways; i = i + 1)
      //This works, but it does not select a particular way, so I need to fix
      //Comparator #(ways) comparator(.addressTag(addressTag), .cacheTag(CACHE_TAG[i * tagBits + tagBits - 1:i * tagBits]), .match(COMPARATOR_OUT[i]));
      Comparator #(ways) comparator(.addressTag(addressTag), .cacheTag(Storage[i][L1Bus[byteSelect + indexBits - 1:0]].cacheTag), .match(COMPARATOR_OUT[i]));
  endgenerate

  // Instantiate our encoder for n ways
  Encoder #(ways) encoder(COMPARATOR_OUT, ENCODER_OUT);

  //wire[(ways * linesize) - 1:0]  CACHE_TAG_OUT = {

  
  CACH_DATA_OUT[(i + 1) * lineSize] = Storage[i][L1Bus[byteSelect + indexBits - 1:0]].cacheTag;
  // I don't think this is quite right, but it's a stub for now
  Multiplexor #(lineSize, ways)  multiplexor(.select(ENCODER_OUT), .in(CACHE_DATA_OUT), .out(MUX_OUT));

  // Code such that all (tagBits - 1) comparator outputs and valid
  // bits are ANDed together, and each output/valid pair are logically
  // ORed for hit detection
  // Output hit, cache data, and selected way.
  // Verify this works in the test bench otherwise see above
  //assign hit = comparator_out & valid;
  cacheLine = MUX_OUT;

  // Performs necessary tasks/functions depending on whether there is a read or right to the cache
  always@(*) begin
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
