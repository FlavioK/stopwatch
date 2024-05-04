# nexys_7seg_demo

Demonstration of 7-segment display driver for the Nexys-A7 board.

Once the design is loaded into the board:

1. cd demo
2. ./demo
3. Stop the demo with ctrl-c
4. ./demo dual
5. Stop the demo with ctrl-c

---

The 7-segment driver provides 3 levels of functionality:

1. sevenseg_driver.v - By itself, provides basic hex display with minimal interfacing requirements.
2. sevenseg_fe.v     - Adds dual-display, leading zero-suppression, and option for decimal display.
3. sevenseg_axi_fe.v - Adds an AXI interface.




