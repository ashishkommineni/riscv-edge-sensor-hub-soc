`timescale 1ns/1ps
`default_nettype none
module pulse_sync (
  input  logic src_clk,
  input  logic src_rst_n,
  input  logic src_pulse,
  input  logic dst_clk,
  input  logic dst_rst_n,
  output logic dst_pulse
);
  logic src_toggle;
  (* async_reg = "true" *) logic dst_meta, dst_sync, dst_last;
  always_ff @(posedge src_clk or negedge src_rst_n) begin
    if (!src_rst_n) src_toggle <= 1'b0;
    else if (src_pulse) src_toggle <= ~src_toggle;
  end
  always_ff @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
      dst_meta <= 1'b0;
      dst_sync <= 1'b0;
      dst_last <= 1'b0;
      dst_pulse <= 1'b0;
    end else begin
      dst_meta <= src_toggle;
      dst_sync <= dst_meta;
      dst_last <= dst_sync;
      dst_pulse <= dst_sync ^ dst_last;
    end
  end
endmodule
`default_nettype wire
