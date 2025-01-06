
module top (
    output logic led_1_o,
    output logic led_2_o
);
  logic clk;
  logic rst;

  zynqmp zynqmp (
      .clk_o(clk),
      .rst_o(rst)
  );

  flash flash_0 (
      .clk_i(clk),
      .rst_i(rst),
      .led_o(led_1_o)
  );

  assign led_2_o = 1'b1;

endmodule
