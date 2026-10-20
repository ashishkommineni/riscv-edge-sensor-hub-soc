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
  property p_request_completes;
    @(posedge clk) disable iff (!rst_n) cpu_req |-> ##[0:80] cpu_ready;
  endproperty
  a_request_completes: assert property (p_request_completes);

  property p_dma_count_monotonic;
    @(posedge clk) disable iff (!rst_n)
      dma_active && $past(dma_active) |-> dma_count >= $past(dma_count);
  endproperty
  a_dma_count_monotonic: assert property (p_dma_count_monotonic);

  a_no_memory_collision: assert property (
    @(posedge clk) disable iff (!rst_n) !mem_collision
  );

  c_backpressure_seen: cover property (
    @(posedge clk) disable iff (!rst_n) dma_active ##1 dma_active[*3]
  );
  c_accelerator_seen: cover property (
    @(posedge clk) disable iff (!rst_n) $rose(acc_active) ##[1:32] $fell(acc_active)
  );
`endif
  // Keep unused ports visible to lint when SVA is disabled.
  wire _unused = &{1'b0, cpu_req, cpu_ready, dma_active, dma_count[0],
                   fifo_full, spi_byte_valid, mem_collision, acc_active};
endmodule
`default_nettype wire
