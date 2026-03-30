`timescale 1ns/1ps
module zcd_logic (
    input  wire clk,
    input  wire rst_n,       // renamed to match PWM module
    input  wire bemf_in,     // simulated comparator output: 1 if bemf > Vdc/2
    output reg  zcd_pulse    // one-clock pulse at each crossing
);

  reg bemf_d;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      bemf_d    <= 1'b0;
      zcd_pulse <= 1'b0;
    end else begin
      bemf_d    <= bemf_in;
      zcd_pulse <= (bemf_in ^ bemf_d); // pulse when bemf_in changes state
    end
  end

endmodule
