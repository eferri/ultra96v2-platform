
module top (
    output logic led_1,
    output logic led_2
);
  logic clk;
  logic reset;

  zynqmp zynqmp (
      .clk,
      .reset
  );

  flash flash_0 (
      .i_clk  (clk),
      .i_reset(reset),
      .o_led  (led_1)
  );

  assign led_2 = 1'b1;

endmodule
