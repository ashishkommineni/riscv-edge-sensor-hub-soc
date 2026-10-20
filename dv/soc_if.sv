interface soc_if;
  logic sys_clk = 0;
  logic spi_sclk = 0;
  logic arst_n = 0;
  logic spi_cs_n = 1;
  logic spi_mosi = 0;
  logic uart_tx, irq_o;
  logic ecc_inject_valid = 0;
  logic [7:0] ecc_inject_word = 0;
  logic [38:0] ecc_inject_mask = 0;
  logic halted, fault;
  logic [31:0] debug_pc;
  logic dma_done, acc_done;
  logic signed [31:0] acc_result;
  logic ecc_corrected, ecc_uncorrectable;
  logic [7:0] uart_byte;
  logic uart_strobe;
endinterface
