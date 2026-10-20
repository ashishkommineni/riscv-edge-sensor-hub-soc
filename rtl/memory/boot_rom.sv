`timescale 1ns/1ps
`default_nettype none
module boot_rom #(
  parameter int WORDS = 256,
  parameter string HEX_FILE = "firmware/boot.hex"
) (
  input  logic [31:0] addr,
  output logic [31:0] rdata
);
  logic [31:0] mem [0:WORDS-1];
  integer i;
  initial begin
    for (i = 0; i < WORDS; i = i + 1) mem[i] = 32'h0000_0013;
    $readmemh(HEX_FILE, mem);
  end
  always_comb begin
    rdata = (addr[31:2] < WORDS) ? mem[addr[31:2]] : 32'h0010_0073;
  end
endmodule
`default_nettype wire
