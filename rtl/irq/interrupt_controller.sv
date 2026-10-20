`timescale 1ns/1ps
`default_nettype none
module interrupt_controller #(
  parameter int SOURCES = 5
) (
  input  logic               clk,
  input  logic               rst_n,
  input  logic [SOURCES-1:0] source_pulse,
  input  logic               reg_req,
  input  logic               reg_we,
  input  logic [3:0]         reg_offset,
  input  logic [31:0]        reg_wdata,
  output logic [31:0]        reg_rdata,
  output logic               reg_ready,
  output logic               irq
);
  logic [SOURCES-1:0] pending, mask;
  assign reg_ready = reg_req;
  assign irq = |(pending & mask);
  always_comb begin
    unique case (reg_offset[3:2])
      2'd0: reg_rdata = {{(32-SOURCES){1'b0}}, pending};
      2'd1: reg_rdata = {{(32-SOURCES){1'b0}}, mask};
      default: reg_rdata = 32'b0;
    endcase
  end
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pending <= '0;
      mask <= '0;
    end else begin
      pending <= pending | source_pulse;
      if (reg_req && reg_we) begin
        if (reg_offset[3:2] == 2'd0) pending <= (pending | source_pulse) & ~reg_wdata[SOURCES-1:0];
        if (reg_offset[3:2] == 2'd1) mask <= reg_wdata[SOURCES-1:0];
      end
    end
  end
endmodule
`default_nettype wire
