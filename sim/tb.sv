
module tb;
  logic led_1;
  logic led_2;
  logic uart_tx;
  logic uart_rx;

  const int period = 2;

  top pl_top (
      .led_1,
      .led_2,
      .uart_rx,
      .uart_tx
  );

  initial begin
    $dumpfile("waves.vcd");
    $dumpvars;

    // minimum 16 clock pulse width delay in reset
    pl_top.zynqmp.zynqmp.inst.por_srstb_reset(1'b1);
    #(8 * period);
    pl_top.zynqmp.zynqmp.inst.por_srstb_reset(1'b0);
    pl_top.zynqmp.zynqmp.inst.fpga_soft_reset(4'hF);
    #(16 * period);
    pl_top.zynqmp.zynqmp.inst.por_srstb_reset(1'b1);
    pl_top.zynqmp.zynqmp.inst.fpga_soft_reset(4'h0);

    #(period * 1000);

    $finish;
  end

endmodule
