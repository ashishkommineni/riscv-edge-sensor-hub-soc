`timescale 1ns/1ps
`default_nettype none
module uart_tx_mmio #(
  parameter int CLKS_PER_BIT = 8
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        reg_req,
  input  logic        reg_we,
  input  logic [3:0]  reg_offset,
  input  logic [31:0] reg_wdata,
  output logic [31:0] reg_rdata,
  output logic        reg_ready,
  output logic        tx,
  output logic        busy,
  output logic [7:0]  accepted_byte,
  output logic        accepted_strobe
);
  localparam int CW = (CLKS_PER_BIT <= 2) ? 1 : $clog2(CLKS_PER_BIT);
  logic [9:0] frame;
  logic [3:0] bit_index;
  logic [CW-1:0] count;

  always_comb begin
    reg_rdata = (reg_offset[3:2] == 2'd1) ? {31'b0, busy} : 32'b0;
    reg_ready = reg_req && (!(reg_we && (reg_offset[3:2] == 2'd0)) || !busy);
    tx = busy ? frame[bit_index] : 1'b1;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy <= 1'b0;
      frame <= 10'h3ff;
      bit_index <= 4'b0;
      count <= '0;
      accepted_byte <= 8'b0;
      accepted_strobe <= 1'b0;
    end else begin
      accepted_strobe <= 1'b0;
      if (reg_req && reg_we && (reg_offset[3:2] == 2'd0) && !busy) begin
        frame <= {1'b1, reg_wdata[7:0], 1'b0};
        bit_index <= 4'b0;
        count <= '0;
        busy <= 1'b1;
        accepted_byte <= reg_wdata[7:0];
        accepted_strobe <= 1'b1;
      end else if (busy) begin
        if (count == CLKS_PER_BIT-1) begin
          count <= '0;
          if (bit_index == 4'd9) begin
            busy <= 1'b0;
            bit_index <= 4'b0;
          end else begin
            bit_index <= bit_index + 1'b1;
          end
        end else begin
          count <= count + 1'b1;
        end
      end
    end
  end
endmodule
`default_nettype wire
