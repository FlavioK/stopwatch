//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 13-Sept-24  DWW     1  Initial creation
//====================================================================================


module stopwatch # (parameter FREQ_HZ = 100000000)

(
    input clk, resetn,
    
    // Start/Pause button
    input start,

    // The number to display
    output [31:0] display,
    // Digit-enable for a single 32-bit value
    output reg[ 7:0] digit_enable,
    // Digitpoint-enable for a single 32-bit value
    output [ 7:0] dp_enable

);  

// 32-bit BCD value
reg[31:0] bcd;

// Always enable the digit point for the enabled digits. Just because we can.
assign dp_enable = digit_enable;

// forward the bcd value to the display
assign display = bcd;

// Inidcates if the stop watch is running.
localparam STOPWATCH_PAUSED = 0;
localparam STOPWATCH_RUNNING = 1;
reg stopwatch_running;

//==========================================================================
// This block handles the start/pause button
//
//==========================================================================
always @(posedge clk) begin
   
    // Go to reset state -> dance off!
    if (resetn == 0) begin
            stopwatch_running <= STOPWATCH_PAUSED;

    end else if (start) begin
            // If the button gets pressed, start or pause the stopwatch.
            stopwatch_running <= ~stopwatch_running;
    end
end

//==========================================================================

// Used to handle the delay.
reg[31:0] reg_delay;

// This is the max number of seconds we can display.
localparam MAX_SECONDS = 99999999;
// Number of passed seconds.
reg[31:0] seconds;

reg[3:0] stopwatch_fsm_state;

//==========================================================================
// This state machine counts the seconds
//==========================================================================
always @(posedge clk) begin

    
    if((stopwatch_running == STOPWATCH_RUNNING) && reg_delay) reg_delay <= reg_delay - 1;
    
    // Go to reset state in case we get a reset signal or if we read the button and are in on state (LEDs dance is running).
    if (resetn == 0) begin
            stopwatch_fsm_state     <= 0;
            reg_delay               <= 0;
            seconds                 <= 0;

    end else case (stopwatch_fsm_state)
                   // If the timer has expired, update the pattern       
        0:   begin
                reg_delay <= FREQ_HZ;
                stopwatch_fsm_state <= stopwatch_fsm_state + 1;                
             end
             
        1:  if (reg_delay == 0) begin
               if(seconds < MAX_SECONDS) seconds <= seconds + 1;
               stopwatch_fsm_state <= 0;       
            end
    endcase

end
//==========================================================================


//=============================================================================
// double_dabble - Converts binary to BCD
//=============================================================================
reg [31:0] dd_input;
reg        dd_start;
wire[31:0] dd_output;
wire       dd_done;
double_dabble#(.INPUT_WIDTH(32), .DECIMAL_DIGITS(8))
(
    .clk    (clk),
    .resetn (resetn),
    .BINARY (dd_input),
    .START  (dd_start),
    .BCD    (dd_output),
    .DONE   (dd_done)
);
//=============================================================================


//==========================================================================
// This state machine handles the conversion from a raw number to its BCD equivalent.
//
// Drives: fsm_state, return_state
//         dd_input, dd_start
//         bcd
//==========================================================================
reg[1:0] fsm_state;
always @(posedge clk) begin

    // This strobes high for only a single cycle at a time
    dd_start <= 0;

    if (resetn == 0) begin
        fsm_state   <= 0;
        bcd  <= 0;

    end else case (fsm_state)

        // In state 0, start a dd conversion for either "single" or "right"
        0:  begin
                dd_input     <= seconds;
                dd_start     <= 1;
                fsm_state    <= 1;
            end

        // Here, we're waiting for double-dabble to complete so that
        // we can store the result into the appropriate register
        1:  if (dd_done) begin
                bcd <= dd_output;
                fsm_state  <= 0;
            end

    endcase


end
//==========================================================================



//==========================================================================
// digit_enable = bitmap of which digits in single_out are significant
//==========================================================================
always @* begin
    if      (display[31:04] == 0) digit_enable = 8'b00000001;
    else if (display[31:08] == 0) digit_enable = 8'b00000011;
    else if (display[31:12] == 0) digit_enable = 8'b00000111;
    else if (display[31:16] == 0) digit_enable = 8'b00001111;
    else if (display[31:20] == 0) digit_enable = 8'b00011111;
    else if (display[31:24] == 0) digit_enable = 8'b00111111;
    else if (display[31:28] == 0) digit_enable = 8'b01111111;
    else                             digit_enable = 8'b11111111;
end
//==========================================================================


endmodule
