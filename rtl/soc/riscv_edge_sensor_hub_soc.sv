`timescale 1ns/1ps
`default_nettype none
module riscv_edge_sensor_hub_soc #(
  parameter int SRAM_WORDS = 256,
  parameter int UART_CLKS_PER_BIT = 8,
  parameter string BOOT_HEX = "firmware/boot.hex"
) (
  input  logic        sys_clk,
  input  logic        spi_sclk,
  input  logic        arst_n,
  input  logic        spi_cs_n,
  input  logic        spi_mosi,
  output logic        uart_tx,
  output logic        irq_o,
  input  logic        ecc_inject_valid,
  input  logic [$clog2(SRAM_WORDS)-1:0] ecc_inject_word,
  input  logic [38:0] ecc_inject_mask,
  output logic        debug_halted,
  output logic        debug_fault,
  output logic [31:0] debug_pc,
  output logic        debug_dma_done,
  output logic        debug_acc_done,
  output logic signed [31:0] debug_acc_result,
  output logic        debug_ecc_corrected,
  output logic        debug_ecc_uncorrectable,
  output logic [7:0]  debug_uart_byte,
  output logic        debug_uart_strobe
);
  localparam logic [31:0] SRAM_BASE = 32'h1000_0000;
  localparam logic [31:0] SPI_BASE  = 32'h2000_0000;
  localparam logic [31:0] DMA_BASE  = 32'h2000_1000;
  localparam logic [31:0] ACC_BASE  = 32'h2000_2000;
  localparam logic [31:0] IRQ_BASE  = 32'h2000_3000;
  localparam logic [31:0] UART_BASE = 32'h2000_4000;

  logic sys_rst_n, spi_rst_n;
  reset_sync u_reset_sync (.clk(sys_clk), .arst_n(arst_n), .srst_n(sys_rst_n));
  reset_sync u_spi_reset_sync (.clk(spi_sclk), .arst_n(arst_n), .srst_n(spi_rst_n));

  logic [31:0] imem_addr, imem_rdata;
  logic cpu_req, cpu_we, cpu_ready, cpu_error;
  logic [31:0] cpu_addr, cpu_wdata, cpu_rdata;
  logic [3:0] cpu_wstrb;

  boot_rom #(.HEX_FILE(BOOT_HEX)) u_boot_rom (
    .addr(imem_addr), .rdata(imem_rdata)
  );
  rv32i_control_core u_cpu (
    .clk(sys_clk), .rst_n(sys_rst_n),
    .imem_addr(imem_addr), .imem_rdata(imem_rdata),
    .d_req(cpu_req), .d_we(cpu_we), .d_addr(cpu_addr),
    .d_wdata(cpu_wdata), .d_wstrb(cpu_wstrb),
    .d_ready(cpu_ready), .d_rdata(cpu_rdata), .d_error(cpu_error),
    .halted(debug_halted), .fault(debug_fault), .debug_pc(debug_pc)
  );

  // SPI receive clock domain -> byte FIFO -> system clock domain.
  logic [7:0] spi_byte, fifo_data;
  logic spi_byte_valid, fifo_full, fifo_overflow;
  logic fifo_empty, fifo_rd_en, fifo_rd_valid, fifo_underflow;
  spi_sensor_rx u_spi_rx (
    .sclk(spi_sclk), .rst_n(spi_rst_n), .cs_n(spi_cs_n), .mosi(spi_mosi),
    .byte_data(spi_byte), .byte_valid(spi_byte_valid)
  );
  async_fifo #(.WIDTH(8), .DEPTH(16)) u_sensor_fifo (
    .wr_clk(spi_sclk), .wr_rst_n(spi_rst_n), .wr_en(spi_byte_valid),
    .wr_data(spi_byte), .full(fifo_full), .overflow(fifo_overflow),
    .rd_clk(sys_clk), .rd_rst_n(sys_rst_n), .rd_en(fifo_rd_en),
    .rd_data(fifo_data), .rd_valid(fifo_rd_valid), .empty(fifo_empty),
    .underflow(fifo_underflow)
  );
  logic overflow_sys;
  pulse_sync u_overflow_sync (
    .src_clk(spi_sclk), .src_rst_n(spi_rst_n), .src_pulse(fifo_overflow),
    .dst_clk(sys_clk), .dst_rst_n(sys_rst_n), .dst_pulse(overflow_sys)
  );

  logic sel_sram, sel_spi, sel_dma, sel_acc, sel_irq, sel_uart;
  always_comb begin
    sel_sram = cpu_req && (cpu_addr >= SRAM_BASE) &&
               (cpu_addr < (SRAM_BASE + SRAM_WORDS*4)) && (cpu_addr[1:0] == 2'b00);
    sel_spi  = cpu_req && (cpu_addr[31:12] == SPI_BASE[31:12]);
    sel_dma  = cpu_req && (cpu_addr[31:12] == DMA_BASE[31:12]);
    sel_acc  = cpu_req && (cpu_addr[31:12] == ACC_BASE[31:12]);
    sel_irq  = cpu_req && (cpu_addr[31:12] == IRQ_BASE[31:12]);
    sel_uart = cpu_req && (cpu_addr[31:12] == UART_BASE[31:12]);
  end

  logic [31:0] sram_cpu_rdata;
  logic sram_cpu_ready, sram_cpu_corr, sram_cpu_unc;
  logic eng_req, eng_we, eng_ready, eng_error, eng_addr_valid;
  logic sram_eng_req, sram_eng_ready, eng_corr, eng_unc;
  logic [31:0] eng_addr, eng_wdata, eng_rdata;
  logic [3:0] eng_wstrb;
  logic mem_collision;

  ecc_sram #(.WORDS(SRAM_WORDS)) u_sram (
    .clk(sys_clk), .rst_n(sys_rst_n),
    .cpu_req(sel_sram), .cpu_we(cpu_we), .cpu_addr(cpu_addr - SRAM_BASE),
    .cpu_wdata(cpu_wdata), .cpu_wstrb(cpu_wstrb), .cpu_rdata(sram_cpu_rdata),
    .cpu_ready(sram_cpu_ready), .cpu_corrected(sram_cpu_corr),
    .cpu_uncorrectable(sram_cpu_unc),
    .eng_req(sram_eng_req), .eng_we(eng_we), .eng_addr(eng_addr - SRAM_BASE),
    .eng_wdata(eng_wdata), .eng_wstrb(eng_wstrb), .eng_rdata(eng_rdata),
    .eng_ready(sram_eng_ready), .eng_corrected(eng_corr),
    .eng_uncorrectable(eng_unc),
    .inj_valid(ecc_inject_valid), .inj_word(ecc_inject_word),
    .inj_mask(ecc_inject_mask), .write_collision(mem_collision)
  );
  assign debug_ecc_corrected = sram_cpu_corr | eng_corr;
  assign debug_ecc_uncorrectable = sram_cpu_unc | eng_unc;

  logic [31:0] dma_rdata;
  logic dma_ready, dma_mem_req, dma_mem_we, dma_mem_ready;
  logic [31:0] dma_mem_addr, dma_mem_wdata;
  logic [3:0] dma_mem_wstrb;
  logic dma_done_pulse, dma_error_pulse, dma_active;
  logic [15:0] dma_count;
  sensor_dma u_dma (
    .clk(sys_clk), .rst_n(sys_rst_n),
    .reg_req(sel_dma), .reg_we(cpu_we), .reg_offset(cpu_addr[5:0]),
    .reg_wdata(cpu_wdata), .reg_wstrb(cpu_wstrb),
    .reg_rdata(dma_rdata), .reg_ready(dma_ready),
    .fifo_rd_en(fifo_rd_en), .fifo_rd_data(fifo_data),
    .fifo_rd_valid(fifo_rd_valid), .fifo_empty(fifo_empty),
    .mem_req(dma_mem_req), .mem_we(dma_mem_we), .mem_addr(dma_mem_addr),
    .mem_wdata(dma_mem_wdata), .mem_wstrb(dma_mem_wstrb),
    .mem_ready(dma_mem_ready), .mem_error(eng_error),
    .done_pulse(dma_done_pulse), .error_pulse(dma_error_pulse),
    .active(dma_active), .transferred(dma_count)
  );
  assign debug_dma_done = dma_done_pulse;

  logic [31:0] acc_rdata;
  logic acc_ready, acc_mem_req, acc_mem_ready, acc_active;
  logic acc_mem_we;
  logic [31:0] acc_mem_addr, acc_mem_wdata;
  logic [3:0] acc_mem_wstrb;
  logic acc_done_pulse, acc_error_pulse;
  int8_dot_product u_acc (
    .clk(sys_clk), .rst_n(sys_rst_n),
    .reg_req(sel_acc), .reg_we(cpu_we), .reg_offset(cpu_addr[5:0]),
    .reg_wdata(cpu_wdata), .reg_rdata(acc_rdata), .reg_ready(acc_ready),
    .mem_req(acc_mem_req), .mem_we(acc_mem_we), .mem_addr(acc_mem_addr),
    .mem_wdata(acc_mem_wdata), .mem_wstrb(acc_mem_wstrb),
    .mem_ready(acc_mem_ready), .mem_rdata(eng_rdata), .mem_error(eng_error),
    .done_pulse(acc_done_pulse), .error_pulse(acc_error_pulse),
    .active(acc_active), .result(debug_acc_result)
  );
  assign debug_acc_done = acc_done_pulse;

  // DMA has priority on the single engine port. Firmware sequences the engines,
  // while the arbitration remains deterministic if software starts both.
  always_comb begin
    if (dma_mem_req) begin
      eng_req = 1'b1;
      eng_we = dma_mem_we;
      eng_addr = dma_mem_addr;
      eng_wdata = dma_mem_wdata;
      eng_wstrb = dma_mem_wstrb;
    end else begin
      eng_req = acc_mem_req;
      eng_we = acc_mem_we;
      eng_addr = acc_mem_addr;
      eng_wdata = acc_mem_wdata;
      eng_wstrb = acc_mem_wstrb;
    end
  end

  // Keep response routing separate from the request mux. Besides making the
  // direction of the handshake explicit, this prevents tools from treating an
  // always_comb block's complete sensitivity set as a false combinational loop
  // through the SRAM decode outputs.
  assign eng_addr_valid = (eng_addr >= SRAM_BASE) &&
                          (eng_addr < (SRAM_BASE + SRAM_WORDS*4)) &&
                          (eng_addr[1:0] == 2'b00);
  assign sram_eng_req = eng_req && eng_addr_valid;
  assign eng_ready = eng_req && (eng_addr_valid ? sram_eng_ready : 1'b1);
  assign eng_error = eng_req && (!eng_addr_valid || eng_unc);
  assign dma_mem_ready = dma_mem_req && eng_ready;
  assign acc_mem_ready = acc_mem_req && !dma_mem_req && eng_ready;

  logic [31:0] irq_rdata;
  logic irq_ready;
  logic [4:0] irq_sources;
  assign irq_sources = {overflow_sys,
                        debug_ecc_uncorrectable,
                        debug_ecc_corrected,
                        (acc_done_pulse | acc_error_pulse),
                        (dma_done_pulse | dma_error_pulse)};
  interrupt_controller #(.SOURCES(5)) u_irq (
    .clk(sys_clk), .rst_n(sys_rst_n), .source_pulse(irq_sources),
    .reg_req(sel_irq), .reg_we(cpu_we), .reg_offset(cpu_addr[3:0]),
    .reg_wdata(cpu_wdata), .reg_rdata(irq_rdata), .reg_ready(irq_ready), .irq(irq_o)
  );

  logic [31:0] uart_rdata;
  logic uart_ready, uart_busy;
  uart_tx_mmio #(.CLKS_PER_BIT(UART_CLKS_PER_BIT)) u_uart (
    .clk(sys_clk), .rst_n(sys_rst_n),
    .reg_req(sel_uart), .reg_we(cpu_we), .reg_offset(cpu_addr[3:0]),
    .reg_wdata(cpu_wdata), .reg_rdata(uart_rdata), .reg_ready(uart_ready),
    .tx(uart_tx), .busy(uart_busy),
    .accepted_byte(debug_uart_byte), .accepted_strobe(debug_uart_strobe)
  );

  logic [31:0] spi_rdata;
  assign spi_rdata = {28'b0, fifo_underflow, overflow_sys, fifo_full, fifo_empty};

  always_comb begin
    cpu_rdata = 32'b0;
    cpu_ready = 1'b0;
    cpu_error = 1'b0;
    if (sel_sram) begin
      cpu_rdata = sram_cpu_rdata;
      cpu_ready = sram_cpu_ready;
      cpu_error = sram_cpu_unc;
    end else if (sel_spi) begin
      cpu_rdata = spi_rdata;
      cpu_ready = 1'b1;
    end else if (sel_dma) begin
      cpu_rdata = dma_rdata;
      cpu_ready = dma_ready;
    end else if (sel_acc) begin
      cpu_rdata = acc_rdata;
      cpu_ready = acc_ready;
    end else if (sel_irq) begin
      cpu_rdata = irq_rdata;
      cpu_ready = irq_ready;
    end else if (sel_uart) begin
      cpu_rdata = uart_rdata;
      cpu_ready = uart_ready;
    end else if (cpu_req) begin
      cpu_rdata = 32'hdeaf_bad0;
      cpu_ready = 1'b1;
      cpu_error = 1'b1;
    end
  end

  soc_assertions u_assertions (
    .clk(sys_clk), .rst_n(sys_rst_n), .cpu_req(cpu_req), .cpu_ready(cpu_ready),
    .dma_active(dma_active), .dma_count(dma_count), .fifo_full(fifo_full),
    .spi_byte_valid(spi_byte_valid), .mem_collision(mem_collision),
    .acc_active(acc_active)
  );
endmodule
`default_nettype wire
