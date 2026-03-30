`timescale 1ns/1ps
module sensorless_sector (
    input  wire clk,
    input  wire rst_n,       // renamed to match PWM module
    input  wire comm_event,
    output reg [2:0] sector
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sector <= 3'd1;
    end else if (comm_event) begin
      if (sector == 3'd6)
        sector <= 3'd1;
      else
        sector <= sector + 1'b1;
    end
  end

endmodule
