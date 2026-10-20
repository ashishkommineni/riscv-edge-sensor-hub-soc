`timescale 1ns/1ps
`default_nettype none
module soc_assertions (
  input logic clk,
  input logic rst_n,
  input logic cpu_req,
  input logic cpu_ready,
  input logic dma_active,
  input logic [15:0] dma_count,
  input logic fifo_full,
  input logic spi_byte_valid,
  input logic mem_collision,
  input logic acc_active
);
`ifdef ENABLE_SVA
  logic [6:0] cpu_wait_cycles;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n || !cpu_req || cpu_ready)
      cpu_wait_cycles <= '0;
    else if (cpu_wait_cycles < 7'd81)
      cpu_wait_cycles <= cpu_wait_cycles + 1'b1;
  end

  // A procedural bounded-liveness check keeps this release compatible with
  // Portable tool release 5.020 does not accept every ranged SVA delay construct.
  always_ff @(posedge clk) begin
    if (rst_n)
      assert (!(cpu_req && !cpu_ready && (cpu_wait_cycles >= 7'd80)))
        else $error("CPU data request exceeded the 80-cycle response bound");
  end

  property p_dma_count_monotonic;
    @(posedge clk) disable iff (!rst_n)
      dma_active && $past(dma_active) |-> dma_count >= $past(dma_count);
  endproperty
  a_dma_count_monotonic: assert property (p_dma_count_monotonic);

  a_no_memory_collision: assert property (
    @(posedge clk) disable iff (!rst_n) !mem_collision
  );

  c_cpu_backpressure_seen: cover property (
    @(posedge clk) disable iff (!rst_n) cpu_req && !cpu_ready);
  c_dma_active_seen: cover property (
    @(posedge clk) disable iff (!rst_n) dma_active);
  c_accelerator_seen: cover property (
    @(posedge clk) disable iff (!rst_n) acc_active);
`endif
  // Keep unused ports visible to lint when SVA is disabled.
  wire _unused = &{1'b0, cpu_req, cpu_ready, dma_active, dma_count[0],
                   fifo_full, spi_byte_valid, mem_collision, acc_active};
endmodule
`default_nettype wire
