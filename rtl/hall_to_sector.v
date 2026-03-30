`timescale 1ns/1ps
module hall_to_sector (
    input  wire       clk,
    input  wire       rst_n,       // renamed to match PWM module
    input  wire [2:0] hall,
    output reg  [2:0] sector
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sector <= 3'd0;
    end else begin
      case (hall)
        3'b001: sector <= 3'b001;
        3'b101: sector <= 3'b010;
        3'b100: sector <= 3'b011;
        3'b110: sector <= 3'b100;
        3'b010: sector <= 3'b101;
        3'b011: sector <= 3'b110;
        default: sector <= 3'b000;
      endcase
    end
  end
endmodule
