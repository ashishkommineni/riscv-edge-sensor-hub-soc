`timescale 1ns/1ps
`default_nettype none
// Mode-0 SPI slave receive path. MOSI is sampled on each SCLK rising edge.
// Every eight accepted bits produce a one-cycle byte_valid pulse in SCLK domain.
module spi_sensor_rx (
  input  logic       sclk,
  input  logic       rst_n,
  input  logic       cs_n,
  input  logic       mosi,
  output logic [7:0] byte_data,
  output logic       byte_valid
);
  logic [7:0] shift;
  logic [2:0] count;
  // These are intentionally combinational from the pre-edge shift state. The
  // FIFO therefore samples the completed byte on the same (eighth) SCLK edge;
  // a registered pulse would otherwise require a nonexistent ninth edge.
  always_comb begin
    byte_data  = {shift[6:0], mosi};
    byte_valid = !cs_n && (count == 3'd7);
  end
  always_ff @(posedge sclk or negedge rst_n) begin
    if (!rst_n) begin
      shift <= 8'b0;
      count <= 3'b0;
    end else begin
      if (cs_n) begin
        count <= 3'b0;
      end else begin
        shift <= {shift[6:0], mosi};
        if (count == 3'd7) begin
          count <= 3'b0;
        end else begin
          count <= count + 1'b1;
        end
      end
    end
  end
endmodule
`default_nettype wire
