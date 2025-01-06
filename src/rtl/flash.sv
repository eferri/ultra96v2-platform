module flash #(
    int NBITS = 28
) (
    input  logic clk_i,
    input  logic rst_i,
    output logic led_o
);
  logic [NBITS-1:0] counter;

  always_ff @(posedge clk_i) begin
    if (!rst_i) begin
      counter <= '0;
    end else begin
      counter <= counter + 1;
    end
  end
  assign led_o = counter[NBITS-1];
endmodule
