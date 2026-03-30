`timescale 1ns/1ps

module hall_debounce #(
    parameter W = 3,
    parameter DB_CNT_WIDTH = 2
)(
    input  wire         clk,
    input  wire         rst_n,       // renamed to match PWM module
    input  wire [W-1:0] hall_in,
    output reg  [W-1:0] hall_out
);

  reg [W-1:0] sync1, sync2, lat;
  reg [DB_CNT_WIDTH-1:0] cnt [W-1:0];
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sync1    <= {W{1'b0}};
      sync2    <= {W{1'b0}};
      hall_out <= {W{1'b0}};
      for (i=0; i<W; i=i+1) begin
        cnt[i] <= {DB_CNT_WIDTH{1'b0}};
        lat[i] <= 1'b0;
      end
    end else begin
      sync1 <= hall_in;
      sync2 <= sync1;
      for (i=0; i<W; i=i+1) begin
        if (sync2[i] == lat[i]) begin
          // stable input, increment counter
          if (cnt[i] != {DB_CNT_WIDTH{1'b1}}) begin
            cnt[i] <= cnt[i] + 1'b1;
          end
        end else begin
          // input changed, reset counter
          cnt[i] <= {DB_CNT_WIDTH{1'b0}};
          lat[i] <= sync2[i];
        end

        // when counter saturated → update output
        if (cnt[i] == {DB_CNT_WIDTH{1'b1}})
          hall_out[i] <= lat[i];
      end
    end
  end

endmodule
