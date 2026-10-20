`timescale 1ns/1ps
`default_nettype none

// Small, multicycle RV32I control core used by the SoC demonstrator.
// It implements the RV32I integer instructions needed by the supplied firmware
// and the usual arithmetic/branch/load/store subset. It is deliberately simple:
// one instruction is fetched and completed before the next one is issued.
module rv32i_control_core (
  input  logic        clk,
  input  logic        rst_n,
  output logic [31:0] imem_addr,
  input  logic [31:0] imem_rdata,
  output logic        d_req,
  output logic        d_we,
  output logic [31:0] d_addr,
  output logic [31:0] d_wdata,
  output logic [3:0]  d_wstrb,
  input  logic        d_ready,
  input  logic [31:0] d_rdata,
  input  logic        d_error,
  output logic        halted,
  output logic        fault,
  output logic [31:0] debug_pc
);
  typedef enum logic [1:0] {S_FETCH, S_EXEC, S_MEM, S_HALT} state_t;
  state_t state;

  logic [31:0] regs [0:31];
  logic [31:0] pc, instr;
  logic [4:0]  mem_rd;
  logic [2:0]  mem_funct3;
  logic [1:0]  mem_addr_lsb;

  wire [6:0] opcode = instr[6:0];
  wire [4:0] rd      = instr[11:7];
  wire [2:0] funct3  = instr[14:12];
  wire [4:0] rs1     = instr[19:15];
  wire [4:0] rs2     = instr[24:20];
  wire [6:0] funct7  = instr[31:25];

  wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};
  wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
  wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
  wire [31:0] imm_u = {instr[31:12], 12'b0};
  wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

  assign imem_addr = pc;
  assign debug_pc  = pc;
  assign halted    = (state == S_HALT);

  function automatic logic [31:0] load_extend(
    input logic [31:0] word,
    input logic [2:0] f3,
    input logic [1:0] lsb
  );
    logic [31:0] shifted;
    begin
      shifted = word >> (8 * lsb);
      unique case (f3)
        3'b000: load_extend = {{24{shifted[7]}},  shifted[7:0]};
        3'b001: load_extend = {{16{shifted[15]}}, shifted[15:0]};
        3'b010: load_extend = word;
        3'b100: load_extend = {24'b0, shifted[7:0]};
        3'b101: load_extend = {16'b0, shifted[15:0]};
        default: load_extend = 32'h0;
      endcase
    end
  endfunction

  integer i;
  logic branch_take;
  logic [31:0] alu_result;
  logic [31:0] eff_addr;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_FETCH;
      pc           <= 32'h0000_0000;
      instr        <= 32'h0000_0013;
      d_req        <= 1'b0;
      d_we         <= 1'b0;
      d_addr       <= 32'b0;
      d_wdata      <= 32'b0;
      d_wstrb      <= 4'b0;
      mem_rd       <= 5'b0;
      mem_funct3   <= 3'b0;
      mem_addr_lsb <= 2'b0;
      fault        <= 1'b0;
      for (i = 0; i < 32; i = i + 1) regs[i] <= 32'b0;
    end else begin
      regs[0] <= 32'b0;
      unique case (state)
        S_FETCH: begin
          instr <= imem_rdata;
          d_req <= 1'b0;
          state <= S_EXEC;
        end

        S_EXEC: begin
          branch_take = 1'b0;
          alu_result  = 32'b0;
          eff_addr    = regs[rs1] + ((opcode == 7'b0100011) ? imm_s : imm_i);
          unique case (opcode)
            7'b0110111: begin // LUI
              if (rd != 0) regs[rd] <= imm_u;
              pc <= pc + 4;
              state <= S_FETCH;
            end
            7'b0010111: begin // AUIPC
              if (rd != 0) regs[rd] <= pc + imm_u;
              pc <= pc + 4;
              state <= S_FETCH;
            end
            7'b1101111: begin // JAL
              if (rd != 0) regs[rd] <= pc + 4;
              pc <= pc + imm_j;
              state <= S_FETCH;
            end
            7'b1100111: begin // JALR
              if (rd != 0) regs[rd] <= pc + 4;
              pc <= (regs[rs1] + imm_i) & 32'hffff_fffe;
              state <= S_FETCH;
            end
            7'b1100011: begin // conditional branch
              unique case (funct3)
                3'b000: branch_take = (regs[rs1] == regs[rs2]);
                3'b001: branch_take = (regs[rs1] != regs[rs2]);
                3'b100: branch_take = ($signed(regs[rs1]) < $signed(regs[rs2]));
                3'b101: branch_take = ($signed(regs[rs1]) >= $signed(regs[rs2]));
                3'b110: branch_take = (regs[rs1] < regs[rs2]);
                3'b111: branch_take = (regs[rs1] >= regs[rs2]);
                default: branch_take = 1'b0;
              endcase
              pc <= branch_take ? (pc + imm_b) : (pc + 4);
              state <= S_FETCH;
            end
            7'b0010011: begin // OP-IMM
              unique case (funct3)
                3'b000: alu_result = regs[rs1] + imm_i;
                3'b010: alu_result = ($signed(regs[rs1]) < $signed(imm_i));
                3'b011: alu_result = (regs[rs1] < imm_i);
                3'b100: alu_result = regs[rs1] ^ imm_i;
                3'b110: alu_result = regs[rs1] | imm_i;
                3'b111: alu_result = regs[rs1] & imm_i;
                3'b001: alu_result = regs[rs1] << instr[24:20];
                3'b101: alu_result = instr[30] ? ($signed(regs[rs1]) >>> instr[24:20])
                                               : (regs[rs1] >> instr[24:20]);
                default: alu_result = 32'b0;
              endcase
              if (rd != 0) regs[rd] <= alu_result;
              pc <= pc + 4;
              state <= S_FETCH;
            end
            7'b0110011: begin // OP
              unique case (funct3)
                3'b000: alu_result = funct7[5] ? (regs[rs1] - regs[rs2]) : (regs[rs1] + regs[rs2]);
                3'b001: alu_result = regs[rs1] << regs[rs2][4:0];
                3'b010: alu_result = ($signed(regs[rs1]) < $signed(regs[rs2]));
                3'b011: alu_result = (regs[rs1] < regs[rs2]);
                3'b100: alu_result = regs[rs1] ^ regs[rs2];
                3'b101: alu_result = funct7[5] ? ($signed(regs[rs1]) >>> regs[rs2][4:0])
                                               : (regs[rs1] >> regs[rs2][4:0]);
                3'b110: alu_result = regs[rs1] | regs[rs2];
                3'b111: alu_result = regs[rs1] & regs[rs2];
                default: alu_result = 32'b0;
              endcase
              if (rd != 0) regs[rd] <= alu_result;
              pc <= pc + 4;
              state <= S_FETCH;
            end
            7'b0000011: begin // LOAD
              // Reject reserved sizes and naturally misaligned half/word
              // accesses before the word-aligned external request is formed.
              if (!((funct3 == 3'b000) || (funct3 == 3'b001) ||
                    (funct3 == 3'b010) || (funct3 == 3'b100) ||
                    (funct3 == 3'b101)) ||
                  (((funct3 == 3'b001) || (funct3 == 3'b101)) && eff_addr[0]) ||
                  ((funct3 == 3'b010) && (eff_addr[1:0] != 2'b00))) begin
                fault <= 1'b1;
                state <= S_HALT;
              end else begin
                d_req        <= 1'b1;
                d_we         <= 1'b0;
                d_addr       <= {eff_addr[31:2], 2'b00};
                d_wstrb      <= 4'b0;
                mem_rd       <= rd;
                mem_funct3   <= funct3;
                mem_addr_lsb <= eff_addr[1:0];
                state        <= S_MEM;
              end
            end
            7'b0100011: begin // STORE
              if (!((funct3 == 3'b000) || (funct3 == 3'b001) ||
                    (funct3 == 3'b010)) ||
                  ((funct3 == 3'b001) && eff_addr[0]) ||
                  ((funct3 == 3'b010) && (eff_addr[1:0] != 2'b00))) begin
                fault <= 1'b1;
                state <= S_HALT;
              end else begin
                d_req   <= 1'b1;
                d_we    <= 1'b1;
                d_addr  <= {eff_addr[31:2], 2'b00};
                unique case (funct3)
                  3'b000: begin
                    d_wstrb <= 4'b0001 << eff_addr[1:0];
                    d_wdata <= regs[rs2] << (8 * eff_addr[1:0]);
                  end
                  3'b001: begin
                    d_wstrb <= 4'b0011 << {eff_addr[1], 1'b0};
                    d_wdata <= regs[rs2] << (16 * eff_addr[1]);
                  end
                  default: begin // SW; legality checked above
                    d_wstrb <= 4'b1111;
                    d_wdata <= regs[rs2];
                  end
                endcase
                mem_rd <= 5'b0;
                state  <= S_MEM;
              end
            end
            7'b0001111: begin // FENCE is a no-op in this single-issue core
              pc <= pc + 4;
              state <= S_FETCH;
            end
            7'b1110011: begin // EBREAK/ECALL terminate the demonstration
              state <= S_HALT;
            end
            default: begin
              fault <= 1'b1;
              state <= S_HALT;
            end
          endcase
        end

        S_MEM: begin
          if (d_ready) begin
            if (!d_we && (mem_rd != 0)) regs[mem_rd] <= load_extend(d_rdata, mem_funct3, mem_addr_lsb);
            if (d_error) fault <= 1'b1;
            d_req <= 1'b0;
            pc <= pc + 4;
            state <= d_error ? S_HALT : S_FETCH;
          end
        end

        default: begin
          d_req <= 1'b0;
          state <= S_HALT;
        end
      endcase
    end
  end
endmodule

`default_nettype wire
