`timescale 1ns/1ps
`default_nettype none
// Glitch-safe latch-based clock gate. Use a library ICG cell in ASIC flows.
module clock_gate (
  input  logic clk,
  input  logic enable,
  input  logic test_enable,
  output logic gclk
);
  logic en_latched;
  always_latch begin
    if (!clk) en_latched <= enable | test_enable;
  end
  assign gclk = clk & en_latched;
endmodule
`default_nettype wire
