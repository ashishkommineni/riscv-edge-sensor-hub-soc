`timescale 1ns/1ps
`default_nettype none
module tb_ecc_sram_contention;
  logic clk = 0, rst_n = 0;
  logic cpu_req, cpu_we, eng_req, eng_we, inj_valid;
  logic [31:0] cpu_addr, cpu_wdata, cpu_rdata;
  logic [31:0] eng_addr, eng_wdata, eng_rdata;
  logic [3:0] cpu_wstrb, eng_wstrb;
  logic cpu_ready, cpu_corr, cpu_unc, eng_ready, eng_corr, eng_unc, collision;
  logic [3:0] inj_word;
  logic [38:0] inj_mask;
  always #5 clk = ~clk;

  ecc_sram #(.WORDS(16)) dut (
    .clk, .rst_n, .cpu_req, .cpu_we, .cpu_addr, .cpu_wdata, .cpu_wstrb,
    .cpu_rdata, .cpu_ready, .cpu_corrected(cpu_corr), .cpu_uncorrectable(cpu_unc),
    .eng_req, .eng_we, .eng_addr, .eng_wdata, .eng_wstrb,
    .eng_rdata, .eng_ready, .eng_corrected(eng_corr), .eng_uncorrectable(eng_unc),
    .inj_valid, .inj_word, .inj_mask, .write_collision(collision)
  );

  initial begin
    cpu_req=0; cpu_we=0; eng_req=0; eng_we=0; inj_valid=0;
    cpu_addr=0; eng_addr=4; cpu_wdata=32'haaaa5555; eng_wdata=32'h12345678;
    cpu_wstrb=4'hf; eng_wstrb=4'hf; inj_word=0; inj_mask=0;
    repeat (3) @(posedge clk); rst_n=1; @(posedge clk);

    // Both request writes. CPU wins and engine must observe backpressure.
    @(negedge clk); cpu_req=1; cpu_we=1; eng_req=1; eng_we=1;
    #1 if (eng_ready) $fatal(1, "engine write incorrectly acknowledged during collision");
    @(posedge clk); #1 if (!collision) $fatal(1, "collision was not reported");

    // Remove CPU request; the held engine request now completes.
    @(negedge clk); cpu_req=0; cpu_we=0;
    #1 if (!eng_ready) $fatal(1, "engine retry was not accepted");
    @(posedge clk);
    @(negedge clk); eng_we=0;
    #1 if (eng_rdata !== 32'h12345678) $fatal(1, "retried engine data was lost");

    cpu_req=1; cpu_we=0; cpu_addr=0;
    #1 if (cpu_rdata !== 32'haaaa5555) $fatal(1, "CPU-priority write was lost");
    if (cpu_unc || eng_unc) $fatal(1, "unexpected ECC error");
    $display("ECC_CONTENTION_TEST_PASS cpu_write=preserved engine_write=retried");
    $finish;
  end
endmodule
`default_nettype wire
