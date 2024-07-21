
module zynqmp (
    output logic clk_o,
    output logic rst_o
);

  localparam int ClkMhz = 100;
  localparam int ClkHalfPeriodNs = ((10 ** 9) / (ClkMhz * 10 ** 6)) / 2;

  always begin
    if (!rst_o) begin
      #(ClkHalfPeriodNs);
      clk_o <= ~clk_o;
    end else begin
      clk_o <= '0;
    end
  end

  initial begin
    rst_o = '1;
    #(ClkHalfPeriodNs * 8);
    rst_o = '0;
  end

endmodule
