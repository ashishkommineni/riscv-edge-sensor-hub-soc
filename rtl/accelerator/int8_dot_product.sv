`timescale 1ns/1ps
`default_nettype none
// Reads one signed byte per 32-bit word and applies fixed signed coefficients
// [1,-1,2,-2,3,-3,4,-4], repeating for lengths above eight.
module int8_dot_product (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        reg_req,
  input  logic        reg_we,
  input  logic [5:0]  reg_offset,
  input  logic [31:0] reg_wdata,
  output logic [31:0] reg_rdata,
  output logic        reg_ready,
  output logic        mem_req,
  output logic        mem_we,
  output logic [31:0] mem_addr,
  output logic [31:0] mem_wdata,
  output logic [3:0]  mem_wstrb,
  input  logic        mem_ready,
  input  logic [31:0] mem_rdata,
  input  logic        mem_error,
  output logic        done_pulse,
  output logic        error_pulse,
  output logic        active,
  output logic signed [31:0] result
);
  logic [31:0] src_base;
  logic [15:0] length, index;
  logic done_sticky, error_sticky, irq_enable;
  logic signed [31:0] accumulator;

  function automatic logic signed [7:0] weight(input logic [2:0] idx);
    unique case (idx)
      3'd0: weight = 8'sd1;
      3'd1: weight = -8'sd1;
      3'd2: weight = 8'sd2;
      3'd3: weight = -8'sd2;
      3'd4: weight = 8'sd3;
      3'd5: weight = -8'sd3;
      3'd6: weight = 8'sd4;
      default: weight = -8'sd4;
    endcase
  endfunction

  assign reg_ready = reg_req;
  always_comb begin
    unique case (reg_offset[5:2])
      4'h0: reg_rdata = {28'b0, irq_enable, error_sticky, done_sticky, active};
      4'h1: reg_rdata = src_base;
      4'h2: reg_rdata = {16'b0, length};
      4'h3: reg_rdata = {16'b0, index};
      4'h4: reg_rdata = result;
      default: reg_rdata = 32'b0;
    endcase
  end

  always_comb begin
    mem_req   = active;
    mem_we    = 1'b0;
    mem_addr  = src_base + {14'b0, index, 2'b00};
    mem_wdata = 32'b0;
    mem_wstrb = 4'b0;
  end

  logic signed [15:0] product;
  logic signed [31:0] next_acc;
  always_comb begin
    product = $signed(mem_rdata[7:0]) * weight(index[2:0]);
    next_acc = accumulator + {{16{product[15]}}, product};
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      src_base <= 32'h1000_0000;
      length <= 16'b0;
      index <= 16'b0;
      accumulator <= 32'sd0;
      result <= 32'sd0;
      active <= 1'b0;
      done_sticky <= 1'b0;
      error_sticky <= 1'b0;
      irq_enable <= 1'b0;
      done_pulse <= 1'b0;
      error_pulse <= 1'b0;
    end else begin
      done_pulse <= 1'b0;
      error_pulse <= 1'b0;
      if (reg_req && reg_we) begin
        unique case (reg_offset[5:2])
          4'h0: begin
            irq_enable <= reg_wdata[3];
            if (reg_wdata[1]) done_sticky <= 1'b0;
            if (reg_wdata[2]) error_sticky <= 1'b0;
            if (reg_wdata[0] && !active && (length != 0)) begin
              active <= 1'b1;
              index <= 16'b0;
              accumulator <= 32'sd0;
              done_sticky <= 1'b0;
              error_sticky <= 1'b0;
            end
          end
          4'h1: src_base <= reg_wdata;
          4'h2: length <= reg_wdata[15:0];
          default: ;
        endcase
      end
      if (active && mem_ready) begin
        if (mem_error) begin
          active <= 1'b0;
          error_sticky <= 1'b1;
          error_pulse <= irq_enable;
        end else if (index + 1'b1 >= length) begin
          result <= next_acc;
          accumulator <= next_acc;
          index <= index + 1'b1;
          active <= 1'b0;
          done_sticky <= 1'b1;
          done_pulse <= irq_enable;
        end else begin
          accumulator <= next_acc;
          index <= index + 1'b1;
        end
      end
    end
  end
endmodule
`default_nettype wire
