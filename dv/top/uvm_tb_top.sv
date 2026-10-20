`timescale 1ns/1ps
module uvm_tb_top;
  import uvm_pkg::*;
  import soc_uvm_pkg::*;
  soc_if sif();
  always #5ns sif.sys_clk = ~sif.sys_clk;

  riscv_edge_sensor_hub_soc #(.UART_CLKS_PER_BIT(4)) dut (
    .sys_clk(sif.sys_clk), .spi_sclk(sif.spi_sclk), .arst_n(sif.arst_n),
    .spi_cs_n(sif.spi_cs_n), .spi_mosi(sif.spi_mosi),
    .uart_tx(sif.uart_tx), .irq_o(sif.irq_o),
    .ecc_inject_valid(sif.ecc_inject_valid), .ecc_inject_word(sif.ecc_inject_word),
    .ecc_inject_mask(sif.ecc_inject_mask), .debug_halted(sif.halted),
    .debug_fault(sif.fault), .debug_pc(sif.debug_pc),
    .debug_dma_done(sif.dma_done), .debug_acc_done(sif.acc_done),
    .debug_acc_result(sif.acc_result), .debug_ecc_corrected(sif.ecc_corrected),
    .debug_ecc_uncorrectable(sif.ecc_uncorrectable),
    .debug_uart_byte(sif.uart_byte), .debug_uart_strobe(sif.uart_strobe)
  );

  initial begin
    repeat(4) @(posedge sif.sys_clk);
    sif.arst_n = 1'b1;
  end

  initial begin
    wait(sif.dma_done);
    @(negedge sif.sys_clk);
    sif.ecc_inject_word=0;
    sif.ecc_inject_mask=39'b100;
    sif.ecc_inject_valid=1;
    @(negedge sif.sys_clk);
    sif.ecc_inject_valid=0;
  end

  initial begin
    uvm_config_db#(virtual soc_if)::set(null,"*","vif",sif);
    run_test();
  end
endmodule
