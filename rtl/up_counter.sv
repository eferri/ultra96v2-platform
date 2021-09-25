
module up_counter (
    input  logic        clk,
    input  logic        reset,
    output logic [31:0] count
);

  logic [31:0] counter_up;

  always_ff @(posedge clk) begin
    if (!reset) begin
      counter_up <= '0;
    end else begin
      counter_up <= counter_up + 1;
    end
  end

  assign count = counter_up;

endmodule
