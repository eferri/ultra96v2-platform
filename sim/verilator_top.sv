
module verilator_top (
    input  logic        clk,
    input  logic        reset,
    output logic [31:0] count
);

  up_counter counter_0 (
      .clk,
      .reset,
      .count
  );

  initial begin
    $dumpfile("waves.fst");
    $dumpvars;
  end

endmodule
