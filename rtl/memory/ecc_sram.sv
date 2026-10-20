`timescale 1ns/1ps
`default_nettype none
// 32-bit, SECDED-protected SRAM. Six Hamming parity bits cover a 38-bit
// codeword; bit 38 is the overall parity bit. CPU and engine ports are
// combinational-read/synchronous-write for a portable educational model.
module ecc_sram #(
  parameter int WORDS = 256
) (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        cpu_req,
  input  logic        cpu_we,
  input  logic [31:0] cpu_addr,
  input  logic [31:0] cpu_wdata,
  input  logic [3:0]  cpu_wstrb,
  output logic [31:0] cpu_rdata,
  output logic        cpu_ready,
  output logic        cpu_corrected,
  output logic        cpu_uncorrectable,
  input  logic        eng_req,
  input  logic        eng_we,
  input  logic [31:0] eng_addr,
  input  logic [31:0] eng_wdata,
  input  logic [3:0]  eng_wstrb,
  output logic [31:0] eng_rdata,
  output logic        eng_ready,
  output logic        eng_corrected,
  output logic        eng_uncorrectable,
  input  logic        inj_valid,
  input  logic [$clog2(WORDS)-1:0] inj_word,
  input  logic [38:0] inj_mask,
  output logic        write_collision
);
  typedef struct packed {
    logic [31:0] data;
    logic corrected;
    logic uncorrectable;
  } dec_t;

  logic [38:0] mem [0:WORDS-1];

  function automatic logic [38:0] encode(input logic [31:0] d);
    logic [38:0] c;
    integer pos, di, p;
    logic parity;
    begin
      c = '0;
      di = 0;
      for (pos = 1; pos <= 38; pos = pos + 1) begin
        if ((pos != 1) && (pos != 2) && (pos != 4) &&
            (pos != 8) && (pos != 16) && (pos != 32)) begin
          c[pos-1] = d[di];
          di = di + 1;
        end
      end
      for (p = 1; p <= 32; p = p << 1) begin
        parity = 1'b0;
        for (pos = 1; pos <= 38; pos = pos + 1)
          if ((pos & p) != 0) parity = parity ^ c[pos-1];
        c[p-1] = parity;
      end
      c[38] = ^c[37:0];
      encode = c;
    end
  endfunction

  function automatic dec_t decode(input logic [38:0] c_in);
    dec_t r;
    logic [38:0] c;
    logic [5:0] syndrome;
    logic overall;
    logic parity;
    integer pos, di, p;
    begin
      c = c_in;
      syndrome = 6'b0;
      for (p = 1; p <= 32; p = p << 1) begin
        parity = 1'b0;
        for (pos = 1; pos <= 38; pos = pos + 1)
          if ((pos & p) != 0) parity = parity ^ c[pos-1];
        if (parity) syndrome = syndrome | p[5:0];
      end
      overall = ^c;
      r.corrected = 1'b0;
      r.uncorrectable = 1'b0;
      if ((syndrome != 0) && overall) begin
        if (syndrome <= 38) c[syndrome-1] = ~c[syndrome-1];
        r.corrected = 1'b1;
      end else if ((syndrome == 0) && overall) begin
        c[38] = ~c[38];
        r.corrected = 1'b1;
      end else if ((syndrome != 0) && !overall) begin
        r.uncorrectable = 1'b1;
      end
      r.data = '0;
      di = 0;
      for (pos = 1; pos <= 38; pos = pos + 1) begin
        if ((pos != 1) && (pos != 2) && (pos != 4) &&
            (pos != 8) && (pos != 16) && (pos != 32)) begin
          r.data[di] = c[pos-1];
          di = di + 1;
        end
      end
      decode = r;
    end
  endfunction

  function automatic logic [31:0] merge_bytes(
    input logic [31:0] old_data,
    input logic [31:0] new_data,
    input logic [3:0]  strb
  );
    logic [31:0] m;
    integer b;
    begin
      m = old_data;
      for (b = 0; b < 4; b = b + 1)
        if (strb[b]) m[b*8 +: 8] = new_data[b*8 +: 8];
      merge_bytes = m;
    end
  endfunction

  dec_t cpu_dec, eng_dec;
  logic [$clog2(WORDS)-1:0] cpu_idx, eng_idx;
  assign cpu_idx = cpu_addr[$clog2(WORDS)+1:2];
  assign eng_idx = eng_addr[$clog2(WORDS)+1:2];

  always_comb begin
    cpu_dec = decode(mem[cpu_idx]);
    eng_dec = decode(mem[eng_idx]);
    cpu_rdata = cpu_dec.data;
    eng_rdata = eng_dec.data;
    cpu_corrected = cpu_req && cpu_dec.corrected;
    cpu_uncorrectable = cpu_req && cpu_dec.uncorrectable;
    eng_corrected = eng_req && eng_dec.corrected;
    eng_uncorrectable = eng_req && eng_dec.uncorrectable;
    // Fault injection is an out-of-band debug operation. Stall both clients for
    // that cycle so a normal access is never acknowledged and then discarded by
    // the injection write's priority in the sequential block.
    cpu_ready = cpu_req && !inj_valid;
    // CPU write has priority. A simultaneous engine write is explicitly stalled,
    // so its requester retries rather than counting a silently dropped transfer.
    eng_ready = eng_req && !inj_valid && !(cpu_req && cpu_we && eng_we);
  end

  integer i;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      write_collision <= 1'b0;
      // Blocking assignment is intentional in this reset loop. It gives the
      // same post-edge state and is accepted by portable Verilator releases
      // that reject delayed assignments to unpacked arrays inside loops.
      for (i = 0; i < WORDS; i = i + 1) mem[i] = encode(32'b0);
    end else begin
      write_collision <= !inj_valid && cpu_req && cpu_we && eng_req && eng_we;
      if (inj_valid) begin
        mem[inj_word] <= mem[inj_word] ^ inj_mask;
      end else begin
        if (cpu_req && cpu_we)
          mem[cpu_idx] <= encode(merge_bytes(cpu_dec.data, cpu_wdata, cpu_wstrb));
        if (eng_req && eng_we && !(cpu_req && cpu_we))
          mem[eng_idx] <= encode(merge_bytes(eng_dec.data, eng_wdata, eng_wstrb));
      end
    end
  end
endmodule
`default_nettype wire
