
module top (
    output logic led_1,
    output logic led_2
);
  logic clk;
  logic reset;
  logic [31:0] count;

  zynqmp zynqmp (
      .clk,
      .reset
  );

  up_counter counter_0 (
      .clk,
      .reset,
      .count
  );

  assign {led_1, led_2} = count[25:24];

endmodule
