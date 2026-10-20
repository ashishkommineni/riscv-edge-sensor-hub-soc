`timescale 1ns/1ps
`default_nettype none
module sensor_dma (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        reg_req,
  input  logic        reg_we,
  input  logic [5:0]  reg_offset,
  input  logic [31:0] reg_wdata,
  input  logic [3:0]  reg_wstrb,
  output logic [31:0] reg_rdata,
  output logic        reg_ready,
  output logic        fifo_rd_en,
  input  logic [7:0]  fifo_rd_data,
  input  logic        fifo_rd_valid,
  input  logic        fifo_empty,
  output logic        mem_req,
  output logic        mem_we,
  output logic [31:0] mem_addr,
  output logic [31:0] mem_wdata,
  output logic [3:0]  mem_wstrb,
  input  logic        mem_ready,
  input  logic        mem_error,
  output logic        done_pulse,
  output logic        error_pulse,
  output logic        active,
  output logic [15:0] transferred
);
  typedef enum logic [1:0] {D_IDLE, D_REQUEST, D_WAIT_VALID, D_WRITE} dstate_t;
  dstate_t state;
  logic [31:0] dst_base;
  logic [15:0] length;
  logic [7:0] captured;
  logic done_sticky, error_sticky, irq_enable;

  assign reg_ready = reg_req;
  always_comb begin
    unique case (reg_offset[5:2])
      4'h0: reg_rdata = {28'b0, irq_enable, error_sticky, done_sticky, active};
      4'h1: reg_rdata = dst_base;
      4'h2: reg_rdata = {16'b0, length};
      4'h3: reg_rdata = {16'b0, transferred};
      default: reg_rdata = 32'b0;
    endcase
  end

  always_comb begin
    // Exactly one pop is issued, then the FSM waits for the registered FIFO
    // response. This prevents a held rd_en from consuming a second byte.
    fifo_rd_en = (state == D_REQUEST) && !fifo_empty;
    mem_req    = (state == D_WRITE);
    mem_we     = 1'b1;
    mem_addr   = dst_base + {14'b0, transferred, 2'b00};
    mem_wdata  = {24'b0, captured};
    mem_wstrb  = 4'hf;
    active     = (state != D_IDLE);
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= D_IDLE;
      dst_base <= 32'h1000_0000;
      length <= 16'b0;
      transferred <= 16'b0;
      captured <= 8'b0;
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
            if (reg_wdata[0] && (state == D_IDLE) && (length != 0)) begin
              transferred <= 16'b0;
              done_sticky <= 1'b0;
              error_sticky <= 1'b0;
              state <= D_REQUEST;
            end
          end
          4'h1: if (&reg_wstrb) dst_base <= reg_wdata;
          4'h2: length <= reg_wdata[15:0];
          default: ;
        endcase
      end
      unique case (state)
        D_IDLE: ;
        D_REQUEST: if (!fifo_empty) begin
          state <= D_WAIT_VALID;
        end
        D_WAIT_VALID: if (fifo_rd_valid) begin
          captured <= fifo_rd_data;
          state <= D_WRITE;
        end
        D_WRITE: if (mem_ready) begin
          if (mem_error) begin
            error_sticky <= 1'b1;
            error_pulse <= irq_enable;
            state <= D_IDLE;
          end else if (transferred + 1'b1 >= length) begin
            transferred <= transferred + 1'b1;
            done_sticky <= 1'b1;
            done_pulse <= irq_enable;
            state <= D_IDLE;
          end else begin
            transferred <= transferred + 1'b1;
            state <= D_REQUEST;
          end
        end
        default: state <= D_IDLE;
      endcase
    end
  end
endmodule
`default_nettype wire
