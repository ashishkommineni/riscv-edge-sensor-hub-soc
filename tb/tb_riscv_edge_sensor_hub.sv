`timescale 1ns/1ps
`default_nettype none
module tb_riscv_edge_sensor_hub;
  logic sys_clk = 1'b0;
  logic spi_sclk = 1'b0;
  logic arst_n = 1'b0;
  logic spi_cs_n = 1'b1;
  logic spi_mosi = 1'b0;
  logic uart_tx, irq_o;
  logic ecc_inject_valid = 1'b0;
  logic [7:0] ecc_inject_word = '0;
  logic [38:0] ecc_inject_mask = '0;
  logic halted, fault;
  logic [31:0] debug_pc;
  logic dma_done, acc_done;
  logic signed [31:0] acc_result;
  logic ecc_corrected, ecc_uncorrectable;
  logic [7:0] uart_byte;
  logic uart_strobe;

  riscv_edge_sensor_hub_soc #(
    .SRAM_WORDS(256), .UART_CLKS_PER_BIT(4), .BOOT_HEX("firmware/boot.hex")
  ) dut (
    .sys_clk, .spi_sclk, .arst_n, .spi_cs_n, .spi_mosi,
    .uart_tx, .irq_o,
    .ecc_inject_valid, .ecc_inject_word, .ecc_inject_mask,
    .debug_halted(halted), .debug_fault(fault), .debug_pc,
    .debug_dma_done(dma_done), .debug_acc_done(acc_done),
    .debug_acc_result(acc_result),
    .debug_ecc_corrected(ecc_corrected),
    .debug_ecc_uncorrectable(ecc_uncorrectable),
    .debug_uart_byte(uart_byte), .debug_uart_strobe(uart_strobe)
  );

  always #5 sys_clk = ~sys_clk;

  task automatic spi_send_byte(input logic [7:0] value);
    integer bit_no;
    begin
      spi_cs_n = 1'b0;
      for (bit_no = 7; bit_no >= 0; bit_no = bit_no - 1) begin
        spi_mosi = value[bit_no];
        #7 spi_sclk = 1'b1;
        #7 spi_sclk = 1'b0;
      end
      spi_cs_n = 1'b1;
      spi_mosi = 1'b0;
      #14;
    end
  endtask

  byte uart_log[$];
  bit seen_dma, seen_acc, seen_irq, seen_correction, seen_uncorrectable;
  always @(posedge sys_clk) begin
    if (dma_done) seen_dma <= 1'b1;
    if (acc_done) seen_acc <= 1'b1;
    if (irq_o) seen_irq <= 1'b1;
    if (ecc_corrected) seen_correction <= 1'b1;
    if (ecc_uncorrectable) seen_uncorrectable <= 1'b1;
    if (uart_strobe) begin
      uart_log.push_back(uart_byte);
      $write("%c", uart_byte);
    end
  end

  // Inject a correctable error only after DMA has committed all data and before
  // the firmware starts the accelerator.
  initial begin
    wait (dma_done === 1'b1);
    @(negedge sys_clk);
    ecc_inject_word = 0;
    ecc_inject_mask = 39'b100; // flip code position 3: a protected data bit
    ecc_inject_valid = 1'b1;
    @(negedge sys_clk);
    ecc_inject_valid = 1'b0;
  end

  integer cycles;
  initial begin
    $dumpfile("results/soc.vcd");
    $dumpvars(0, tb_riscv_edge_sensor_hub);
    seen_dma = 0;
    seen_acc = 0;
    seen_irq = 0;
    seen_correction = 0;
    seen_uncorrectable = 0;
    repeat (4) @(posedge sys_clk);
    arst_n = 1'b1;
    repeat (4) @(posedge sys_clk);

    // Supply two idle SCLK edges so reset deasserts synchronously in the SPI
    // clock domain before chip-select is asserted.
    repeat (2) begin
      #7 spi_sclk = 1'b1;
      #7 spi_sclk = 1'b0;
    end

    // Signed samples 1..8. The fixed coefficients produce -10.
    for (int sample = 1; sample <= 8; sample++) spi_send_byte(sample[7:0]);

    cycles = 0;
    while (!halted && cycles < 20000) begin
      @(posedge sys_clk);
      cycles++;
    end

    if (!halted) $fatal(1, "TIMEOUT: firmware did not halt, pc=%08x", debug_pc);
    if (fault) $fatal(1, "CPU faulted at pc=%08x", debug_pc);
    if (acc_result !== -32'sd10) $fatal(1, "dot product mismatch got=%0d expected=-10", acc_result);
    if (seen_uncorrectable) $fatal(1, "unexpected uncorrectable ECC error");
    if (!(seen_dma && seen_acc && seen_irq && seen_correction))
      $fatal(1, "coverage gate failed dma=%0b acc=%0b irq=%0b ecc=%0b",
             seen_dma, seen_acc, seen_irq, seen_correction);
    if (uart_log.size() != 5 || uart_log[0] != "P" || uart_log[1] != "A" ||
        uart_log[2] != "S" || uart_log[3] != "S" || uart_log[4] != 8'h0a)
      $fatal(1, "UART log mismatch; received %0d bytes", uart_log.size());

    $display("SOC_TEST_PASS result=%0d uart=PASS dma=1 acc=1 irq=1 ecc_corrected=1 cycles=%0d",
             acc_result, cycles);
    $finish;
  end
endmodule
`default_nettype wire
