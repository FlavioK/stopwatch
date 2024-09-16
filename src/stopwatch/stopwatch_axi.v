//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 13-Sept-24  Flavio Sonnenberg     1  Initial creation
//====================================================================================

/*
    Register Offset  -- Meaning
    ----------------------------------------------------------------
    0x00                Module version - read only
    0x04                Test Value       - 32-bit value
    0x08                Control Register - Bit 0 apply test value, other bits are unused
*/


module stopwatch_axi #(
    // How many bits wide is our address bus?
    parameter AW = 7
) (

    input             clk,
    input             resetn,
    // Test value to display on the stopwatch
    output reg [31:0] test_value,
    // If set to true, the value is applied.
    output reg        apply_test_value,

    //================== This is an AXI4-Lite slave interface ==================

    // "Specify write address"              -- Master --    -- Slave --
    input  [AW-1:0] S_AXI_AWADDR,
    input           S_AXI_AWVALID,
    output          S_AXI_AWREADY,
    input  [   2:0] S_AXI_AWPROT,

    // "Write Data"                         -- Master --    -- Slave --
    input  [31:0] S_AXI_WDATA,
    input         S_AXI_WVALID,
    input  [ 3:0] S_AXI_WSTRB,
    output        S_AXI_WREADY,

    // "Send Write Response"                -- Master --    -- Slave --
    output [1:0] S_AXI_BRESP,
    output       S_AXI_BVALID,
    input        S_AXI_BREADY,

    // "Specify read address"               -- Master --    -- Slave --
    input  [AW-1:0] S_AXI_ARADDR,
    input           S_AXI_ARVALID,
    input  [   2:0] S_AXI_ARPROT,
    output          S_AXI_ARREADY,

    // "Read data back to master"           -- Master --    -- Slave --
    output [31:0] S_AXI_RDATA,
    output        S_AXI_RVALID,
    output [ 1:0] S_AXI_RRESP,
    input         S_AXI_RREADY
    //==========================================================================


);

  //=========================  AXI Register Map  =============================
  localparam REG_TEST_VALUE = 0;
  localparam REG_CONTROL = 1;
  //==========================================================================


  //==========================================================================
  // We'll communicate with the AXI4-Lite Slave core with these signals.
  //==========================================================================
  // AXI Slave Handler Interface for write requests
  wire [31:0] ashi_windx;  // Input   Write register-index
  wire [31:0] ashi_waddr;  // Input:  Write-address
  wire [31:0] ashi_wdata;  // Input:  Write-data
  wire        ashi_write;  // Input:  1 = Handle a write request
  reg  [ 1:0] ashi_wresp;  // Output: Write-response (OKAY, DECERR, SLVERR)
  wire        ashi_widle;  // Output: 1 = Write state machine is idle

  // AXI Slave Handler Interface for read requests
  wire [31:0] ashi_rindx;  // Input   Read register-index
  wire [31:0] ashi_raddr;  // Input:  Read-address
  wire        ashi_read;  // Input:  1 = Handle a read request
  reg  [31:0] ashi_rdata;  // Output: Read data
  reg  [ 1:0] ashi_rresp;  // Output: Read-response (OKAY, DECERR, SLVERR);
  wire        ashi_ridle;  // Output: 1 = Read state machine is idle
  //==========================================================================

  // The state of the state-machines that handle AXI4-Lite read and AXI4-Lite write
  reg ashi_write_state, ashi_read_state;

  // The AXI4 slave state machines are idle when in state 0 and their "start" signals are low
  assign ashi_widle = (ashi_write == 0) && (ashi_write_state == 0);
  assign ashi_ridle = (ashi_read == 0) && (ashi_read_state == 0);

  // These are the valid values for ashi_rresp and ashi_wresp
  localparam OKAY = 0;
  localparam SLVERR = 2;
  localparam DECERR = 3;

  // Create a sequence of 1-bits 'AW' bits long.
  localparam ADDR_MASK = (1 << AW) - 1;

  //==========================================================================
  // This state machine handles AXI4-Lite write requests
  //
  // Drives: ashi_write_state
  //         ashi_wresp
  //         mode,
  //         single_raw, right_raw, left_raw
  //         single_bcd, right_bcd, left_bcd
  //==========================================================================
  always @(posedge clk) begin

    // If we're in reset, initialize important registers
    if (resetn == 0) begin
      ashi_write_state <= 0;
      test_value       <= 0;
      apply_test_value <= 0;

      // If we're not in reset, and a write-request has occured...        
    end else
      case (ashi_write_state)

        0:
        if (ashi_write) begin

          // Assume for the moment that the result will be OKAY
          ashi_wresp <= OKAY;

          // Examine the register index to determine which register we're writing to
          case (ashi_windx)

            REG_TEST_VALUE: begin
              test_value <= ashi_wdata;
            end

            REG_CONTROL: begin
              apply_test_value <= ashi_wdata[0];
            end

            // Writes to any other register are a decode-error
            default: ashi_wresp <= DECERR;
          endcase
        end

        // We should never get here.
        1: ashi_write_state <= 0;

      endcase
  end
  //==========================================================================



  //==========================================================================
  // World's simplest state machine for handling AXI4-Lite read requests
  //==========================================================================
  always @(posedge clk) begin
    // If we're in reset, initialize important registers
    if (resetn == 0) begin
      ashi_read_state <= 0;

      // If we're not in reset, and a read-request has occured...        
    end else if (ashi_read) begin

      // Assume for the moment that the result will be OKAY
      ashi_rresp <= OKAY;

      // Determine which register the user wants to read
      case (ashi_rindx)

        // Allow a read from any valid register                
        REG_TEST_VALUE: ashi_rdata <= test_value;
        REG_CONTROL:    ashi_rdata <= {31'h0, apply_test_value};

        // Reads of any other register are a decode-error
        default: ashi_rresp <= DECERR;
      endcase
    end
  end
  //==========================================================================



  //==========================================================================
  // This connects us to an AXI4-Lite slave core
  //==========================================================================
  axi4_lite_slave #(ADDR_MASK) axil_slave (
      .clk   (clk),
      .resetn(resetn),

      // AXI AW channel 
      .AXI_AWADDR (S_AXI_AWADDR),
      .AXI_AWVALID(S_AXI_AWVALID),
      .AXI_AWREADY(S_AXI_AWREADY),

      // AXI W channel
      .AXI_WDATA (S_AXI_WDATA),
      .AXI_WVALID(S_AXI_WVALID),
      .AXI_WSTRB (S_AXI_WSTRB),
      .AXI_WREADY(S_AXI_WREADY),

      // AXI B channel
      .AXI_BRESP (S_AXI_BRESP),
      .AXI_BVALID(S_AXI_BVALID),
      .AXI_BREADY(S_AXI_BREADY),

      // AXI AR channel
      .AXI_ARADDR (S_AXI_ARADDR),
      .AXI_ARVALID(S_AXI_ARVALID),
      .AXI_ARREADY(S_AXI_ARREADY),

      // AXI R channel
      .AXI_RDATA (S_AXI_RDATA),
      .AXI_RVALID(S_AXI_RVALID),
      .AXI_RRESP (S_AXI_RRESP),
      .AXI_RREADY(S_AXI_RREADY),

      // ASHI write-request registers
      .ASHI_WADDR(ashi_waddr),
      .ASHI_WINDX(ashi_windx),
      .ASHI_WDATA(ashi_wdata),
      .ASHI_WRITE(ashi_write),
      .ASHI_WRESP(ashi_wresp),
      .ASHI_WIDLE(ashi_widle),

      // ASHI read registers
      .ASHI_RADDR(ashi_raddr),
      .ASHI_RINDX(ashi_rindx),
      .ASHI_RDATA(ashi_rdata),
      .ASHI_READ (ashi_read),
      .ASHI_RRESP(ashi_rresp),
      .ASHI_RIDLE(ashi_ridle)
  );
  //==========================================================================


endmodule

