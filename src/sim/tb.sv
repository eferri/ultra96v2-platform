module tb;

  /* verilator lint_off UNUSEDSIGNAL */
  logic led_1;
  logic led_2;
  /* verilator lint_on UNUSEDSIGNAL */

  top top (
      .led_1_o(led_1),
      .led_2_o(led_2)
  );


  initial begin
    #5000;
    $finish();
  end

endmodule
