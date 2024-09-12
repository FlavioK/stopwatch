//=============================================================================
// sevenseg_driver - Drives 8 seven-segment modules, with common cathodes
//
// Each 4 bits of "display" correspond to a digit
// Display of digits is gated by "digit_enable" bitmap.
//
// Author: D. Wolf
//=============================================================================
module sevenseg_driver # (parameter CLOCK_FREQ = 100000000)
(
    // Clock and rese3t
    input   clk, resetn,
    
    // The value to display, 4 bits per digit
    input[31:0] display,
    
    // Digit enable
    input[7:0] digit_enable, 

    // Enable the decimal point
    input[7:0] dp_enable,
    
    // Active-low cathode and anode for the 7-seg digits
    output[7:0] ANODE,
    output reg[7:0] CATHODE
);

// Compute the number of clock cycles in 1 millisecond
localparam ONE_MS = CLOCK_FREQ / 1000;


//=============================================================================
// This block repeatedly drives "display" out to the physical 7-segment
// display, 4 bits at a time, pausing for 1 millisecond between digits.
//
// Drives:
//  anode (and therefore, ANODE)
//  counter
//  shifter
//=============================================================================
reg[ 7:0] anode;
reg[31:0] shifter;
reg[31:0] counter;
//-----------------------------------------------------------------------------
always @(posedge clk) begin

    // The counter is always counting down to 0
    if (counter) counter <= counter - 1;

    // If we're in reset, disable the output
    if (resetn == 0) begin
        anode   <= 0;
        counter <= 0;
    end
    
    // If we're not in reset, we're outputting digits from
    // right to left.
    else if (counter == 0) begin
        if (anode == 8'b1000_0000 || anode == 0) begin
            anode   <= 1;
            shifter <= display;
        end else begin
            anode   <= anode << 1;
            shifter <= shifter >> 4;
        end
        counter <= ONE_MS;
   end
   
end

// The ANODE output is active low
assign ANODE = ~anode;
//=============================================================================



//=============================================================================
// This block reads the bottom 4 bits of "shifter" and drives the CATHODE pins
// of the 7-segment display to the correct values to display the character
//
// Inputs: anode        = Bitmap of which anode (i.e., 7-seg display) is active
//         digit_enable = Bitmap of which digits should be output
//         dp_enable    = Bitmap of which decimal point should be output
//         shifter      = bottom 4 bits map to the digit to be displayed
//
// Output: CATHODE = Driven to display the selected digit
//=============================================================================
always @* begin
    if ((digit_enable & anode) == 0)
        CATHODE = ~(8'b0000_0000);
    else case (shifter[3:0])
        // Set the MSB to 1 in case we have the decimal point enabled for this anode.
        4'h0  : CATHODE = ~({(dp_enable & anode) != 0, 7'b011_1111});
        4'h1  : CATHODE = ~({(dp_enable & anode) != 0, 7'b000_0110});
        4'h2  : CATHODE = ~({(dp_enable & anode) != 0, 7'b101_1011});
        4'h3  : CATHODE = ~({(dp_enable & anode) != 0, 7'b100_1111});
        4'h4  : CATHODE = ~({(dp_enable & anode) != 0, 7'b110_0110});
        4'h5  : CATHODE = ~({(dp_enable & anode) != 0, 7'b110_1101});
        4'h6  : CATHODE = ~({(dp_enable & anode) != 0, 7'b111_1101});
        4'h7  : CATHODE = ~({(dp_enable & anode) != 0, 7'b000_0111});
        4'h8  : CATHODE = ~({(dp_enable & anode) != 0, 7'b111_1111});
        4'h9  : CATHODE = ~({(dp_enable & anode) != 0, 7'b110_0111});
        4'hA  : CATHODE = ~({(dp_enable & anode) != 0, 7'b111_0111});
        4'hB  : CATHODE = ~({(dp_enable & anode) != 0, 7'b111_1100});
        4'hC  : CATHODE = ~({(dp_enable & anode) != 0, 7'b011_1001});
        4'hD  : CATHODE = ~({(dp_enable & anode) != 0, 7'b101_1110});
        4'hE  : CATHODE = ~({(dp_enable & anode) != 0, 7'b111_1001});
        4'hF  : CATHODE = ~({(dp_enable & anode) != 0, 7'b111_0001});
    endcase
end
//=============================================================================


endmodule

