module flash #(
    NBITS = 28
) (
    input  logic i_clk,
    input  logic i_reset,
    output logic o_led
);
  logic [NBITS-1:0] counter;

  always_ff @(posedge i_clk) begin
    if (!i_reset) begin
      counter <= '0;
    end else begin
      counter <= counter + 1;
    end
  end
  assign o_led = counter[NBITS-1];
endmodule
