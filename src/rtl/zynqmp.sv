
module zynqmp (
    output logic clk_o,
    output logic rst_o
);

  localparam int ClkMhz = 100;
  localparam int ClkHalfPeriodNs = ((10 ** 9) / (ClkMhz * 10 ** 6)) / 2;

  initial begin
    rst_o = '0;
    #(ClkHalfPeriodNs * 8);
    rst_o = '1;

    forever begin
      #(ClkHalfPeriodNs) clk_o = ~clk_o;
    end
  end

endmodule
