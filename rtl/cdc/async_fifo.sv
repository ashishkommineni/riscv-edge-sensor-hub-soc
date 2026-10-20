`timescale 1ns/1ps
`default_nettype none
module async_fifo #(
  parameter int WIDTH = 8,
  parameter int DEPTH = 16,
  localparam int AW = $clog2(DEPTH)
) (
  input  logic             wr_clk,
  input  logic             wr_rst_n,
  input  logic             wr_en,
  input  logic [WIDTH-1:0] wr_data,
  output logic             full,
  output logic             overflow,
  input  logic             rd_clk,
  input  logic             rd_rst_n,
  input  logic             rd_en,
  output logic [WIDTH-1:0] rd_data,
  output logic             rd_valid,
  output logic             empty,
  output logic             underflow
);
  initial begin
    if ((DEPTH < 4) || ((DEPTH & (DEPTH-1)) != 0))
      $error("async_fifo DEPTH must be a power of two and at least four");
  end

  logic [WIDTH-1:0] mem [0:DEPTH-1];
  logic [AW:0] wr_bin, rd_bin;
  logic [AW:0] wr_gray, rd_gray;
  (* async_reg = "true" *) logic [AW:0] rd_gray_w1, rd_gray_w2;
  (* async_reg = "true" *) logic [AW:0] wr_gray_r1, wr_gray_r2;
  logic [AW:0] wr_bin_next, wr_gray_next;
  logic [AW:0] rd_bin_next, rd_gray_next;
  logic full_next, empty_next;

  function automatic logic [AW:0] bin2gray(input logic [AW:0] b);
    bin2gray = (b >> 1) ^ b;
  endfunction

  always_comb begin
    wr_bin_next  = wr_bin + ((wr_en && !full) ? {{AW{1'b0}}, 1'b1} : '0);
    wr_gray_next = bin2gray(wr_bin_next);
    rd_bin_next  = rd_bin + ((rd_en && !empty) ? {{AW{1'b0}}, 1'b1} : '0);
    rd_gray_next = bin2gray(rd_bin_next);
    full_next  = (wr_gray_next == {~rd_gray_w2[AW:AW-1], rd_gray_w2[AW-2:0]});
    empty_next = (rd_gray_next == wr_gray_r2);
  end

  always_ff @(posedge wr_clk or negedge wr_rst_n) begin
    if (!wr_rst_n) begin
      wr_bin <= '0;
      wr_gray <= '0;
      rd_gray_w1 <= '0;
      rd_gray_w2 <= '0;
      full <= 1'b0;
      overflow <= 1'b0;
    end else begin
      rd_gray_w1 <= rd_gray;
      rd_gray_w2 <= rd_gray_w1;
      full <= full_next;
      overflow <= wr_en && full;
      if (wr_en && !full) begin
        mem[wr_bin[AW-1:0]] <= wr_data;
        wr_bin <= wr_bin_next;
        wr_gray <= wr_gray_next;
      end
    end
  end

  always_ff @(posedge rd_clk or negedge rd_rst_n) begin
    if (!rd_rst_n) begin
      rd_bin <= '0;
      rd_gray <= '0;
      wr_gray_r1 <= '0;
      wr_gray_r2 <= '0;
      empty <= 1'b1;
      rd_data <= '0;
      rd_valid <= 1'b0;
      underflow <= 1'b0;
    end else begin
      wr_gray_r1 <= wr_gray;
      wr_gray_r2 <= wr_gray_r1;
      empty <= empty_next;
      rd_valid <= rd_en && !empty;
      underflow <= rd_en && empty;
      if (rd_en && !empty) begin
        rd_data <= mem[rd_bin[AW-1:0]];
        rd_bin <= rd_bin_next;
        rd_gray <= rd_gray_next;
      end
    end
  end
endmodule
`default_nettype wire
