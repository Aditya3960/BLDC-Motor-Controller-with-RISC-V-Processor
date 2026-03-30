`timescale 1ns/1ps
module comm_timer #(
    parameter WIDTH = 16
)(
    input  wire clk,
    input  wire rst_n,       // renamed to match PWM module
    input  wire zcd_pulse,
    output reg  [WIDTH-1:0] period,
    output reg  comm_event
);

  reg [WIDTH-1:0] counter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter    <= 0;
      period     <= 0;
      comm_event <= 0;
    end else begin
      counter <= counter + 1'b1;
      comm_event <= 0;

      if (zcd_pulse) begin
        period  <= counter;
        counter <= 0;
        comm_event <= 1'b1; // commutate now
      end
    end
  end

endmodule
