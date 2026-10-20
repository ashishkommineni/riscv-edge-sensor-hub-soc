`timescale 1ns/1ps
`default_nettype none
module reset_sync (
  input  logic clk,
  input  logic arst_n,
  output logic srst_n
);
  (* async_reg = "true" *) logic [1:0] sync;
  always_ff @(posedge clk or negedge arst_n) begin
    if (!arst_n) sync <= 2'b00;
    else sync <= {sync[0], 1'b1};
  end
  assign srst_n = sync[1];
endmodule
`default_nettype wire
