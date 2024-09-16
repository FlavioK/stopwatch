//====================================================================================
//                        ------->  Revision History  <------
//====================================================================================
//
//   Date     Who   Ver  Changes
//====================================================================================
// 13-Sept-24  Flavio Sonnenberg     1  Initial creation
//====================================================================================


module stopwatch #(
    parameter FREQ_HZ = 100000000
) (
    // Clock and reset inputs
    input clk,
    input resetn,

    // Start/Pause button
    input start,

    // Clear button
    input clear,

    // Test value to test the digits conversion
    input [31:0] test_value,

    // Apply the test value
    input apply_test_value,

    // The time display
    output [31:0] time_display,

    // Digit-enable for a single 32-bit value
    output reg [7:0] digit_enable,

    // Digitpoint-enable for a single 32-bit value
    output [7:0] dp_enable

);

  // Inidcates if the stop watch is running.
  localparam STOPWATCH_PAUSED = 0;
  localparam STOPWATCH_RUNNING = 1;
  localparam STOPWATCH_TEST = 2;
  reg [3:0] stopwatch_mode;
  reg clear_display;
  reg trigger_test;

  //==========================================================================
  // This state machine handles the stopwatch mode (running, paused, clear and test)
  //==========================================================================
  always @(posedge clk) begin

    // Clear display is only 1 for one clock cycle.
    clear_display <= 0;
    // trigger_test is only 1 for one clock cycle.
    trigger_test  <= 0;

    // Go to reset state -> dance off!
    if (resetn == 0) begin
      stopwatch_mode <= STOPWATCH_PAUSED;

      // Stop the stop watch regardles of the state and clear the display so we are ready to apply the test value!
    end else if (apply_test_value) begin
      trigger_test   <= 1;
      stopwatch_mode <= STOPWATCH_TEST;

    end else
      case (stopwatch_mode)
        STOPWATCH_PAUSED: begin
          // Start the stopwatch if requested
          if (start) begin
            stopwatch_mode <= STOPWATCH_RUNNING;

            // Only allow display clearing in paused state!
          end else if (clear) begin
            clear_display <= 1;
          end
        end

        // Pause the stopwatch if requested
        STOPWATCH_RUNNING: if (start) stopwatch_mode <= STOPWATCH_PAUSED;

        // If we are in test mode and get a clear or start signal, clear the display and go to paused mode.
        STOPWATCH_TEST:
        if (clear || start) begin
          clear_display  <= 1;
          stopwatch_mode <= STOPWATCH_PAUSED;
        end
      endcase
  end

  //==========================================================================

  // The number of clock cycles we need to pass 10ms
  localparam CLOCK_CYCLES_PER_10MS = 1000000;  //(10  /* ms */ / 1000) * FREQ_HZ;

  // Used to handle the delay.
  reg [31:0] reg_delay;

  // This is the max number of seconds we can display.
  // This does not work, see: https://stackoverflow.com/a/23508742
  // localparam MAX_DIGIT_VALUE[7:0][7:0] = {9,9,6,9,6,9,9,9};
  localparam [31:0] MAX_DIGIT_VALUE = {4'd9, 4'd9, 4'd5, 4'd9, 4'd5, 4'd9, 4'd9, 4'd9};
  reg [3:0] digits[7:0];

  assign time_display = {
    digits[7], digits[6], digits[5], digits[4], digits[3], digits[2], digits[1], digits[0]
  };

  // "Carry flags" for the digits.
  reg [ 8:0] cf;

  reg [ 3:0] stopwatch_fsm_state;

  // Applies 'test_number´ number of ticks to the stop watch to have
  // some fast forward test of the time visualization.
  reg [31:0] test_ticks;

  //==========================================================================
  // This is the main state machine of the stop watch
  //==========================================================================
  always @(posedge clk) begin


    if ((stopwatch_mode == STOPWATCH_RUNNING) && reg_delay) reg_delay <= reg_delay - 1;

    cf[0] <= 0;

    // Go to reset state in case we get a reset or clear_display signal or if we read
    // the button and are in on state (LEDs dance is running).
    if (resetn == 0 || clear_display) begin
      stopwatch_fsm_state <= 0;
      reg_delay           <= 0;
      cf[0]               <= 0;

      // We are in testing mode. Just increment the number of ticks.
      // We could also just set the diplay with the received value. But I wanted to really
      // test the counting mechanism with this test value. Therefore we just send test_value
      // number of ticks to the counting state machine.
    end else if (trigger_test) begin
      test_ticks <= test_value;
      stopwatch_fsm_state <= 2;

    end else
      case (stopwatch_fsm_state)
        // Counting mode: We can only leave state 1 and 2 with a reset!   
        0: begin
          reg_delay <= CLOCK_CYCLES_PER_10MS;
          stopwatch_fsm_state <= stopwatch_fsm_state + 1;
        end
        // If the timer has expired, update the pattern       
        1:
        if (reg_delay == 0) begin
          cf[0] <= 1;
          stopwatch_fsm_state <= 0;
        end
        2:
        if (test_ticks > 0) begin
          test_ticks <= test_ticks - 1;
          cf[0] <= 1;
          // Go back to the initial state after we are done testing.
        end else begin
          stopwatch_fsm_state <= 0;
        end
      endcase
  end
  //==========================================================================

  //==========================================================================
  // Generate the state machines for the other digits
  //==========================================================================
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin

      always @(posedge clk) begin

        cf[i+1] <= 0;

        if (resetn == 0 || clear_display || trigger_test) begin
          digits[i] <= 0;
          cf[i+1]   <= 0;
        end
        if (cf[i]) begin
          if (digits[i] < MAX_DIGIT_VALUE[4*i+:4]) begin
            digits[i] <= digits[i] + 1;

          end else begin
            digits[i] <= 0;
            // Trigger the increment of the next digit.
            cf[i+1]   <= 1;
          end
        end
      end

    end
  endgenerate
  //==========================================================================


  //==========================================================================
  // digit_enable = bitmap of which digits in single_out are significant
  //==========================================================================
  always @* begin
    if (time_display[31:12] == 0) digit_enable = 8'b00000111;
    else if (time_display[31:16] == 0) digit_enable = 8'b00001111;
    else if (time_display[31:20] == 0) digit_enable = 8'b00011111;
    else if (time_display[31:24] == 0) digit_enable = 8'b00111111;
    else if (time_display[31:28] == 0) digit_enable = 8'b01111111;
    else digit_enable = 8'b11111111;
  end

  // Enable only the points to separate h:m:s:ms
  // 13.05.17.23
  localparam DECIMAL_POINTS_TEMPLATE = 8'b01010100;
  // Only enable the decimal points for the enabled digits.
  assign dp_enable = DECIMAL_POINTS_TEMPLATE & digit_enable;
  //==========================================================================
endmodule
