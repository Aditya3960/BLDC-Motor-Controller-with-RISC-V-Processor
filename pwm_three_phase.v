`timescale 1ns/1ps

module pwm_three_phase (
    input  wire        clk,       // System clock
    input  wire        rst_n,     // Active-low reset
    input  wire [11:0] duty,      // 12-bit duty (0–4095)
    input  wire [2:0]  sector,    // Active commutation sector (1–6)
    output reg         pwm_u,     // Phase U
    output reg         pwm_v,     // Phase V
    output reg         pwm_w      // Phase W
);
    // 12-bit up counter for PWM timing
    reg [11:0] counter;
    reg [2:0]  sector_prev;
    wire       sector_change;
    
    // Detect sector change
    assign sector_change = (sector != sector_prev);
    
    // Counter increments every clock cycle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= 12'd0;
            sector_prev <= 3'd0;
        end else begin
            sector_prev <= sector;
            counter <= counter + 1'b1;
        end
    end
    
    // Generate PWM compare signal
    wire pwm_active;
    assign pwm_active = (counter < duty);
    
    // Generate PWM signals according to commutation sector
    // Updated on clock edge to avoid glitches
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_u <= 1'b0;
            pwm_v <= 1'b0;
            pwm_w <= 1'b0;
        end else begin
            case (sector)
                3'd1: begin // U+, V−
                    pwm_u <= pwm_active;  // PWM on U
                    pwm_v <= 1'b0;        // V low
                    pwm_w <= 1'bz;        // W floating
                end
                3'd2: begin // U+, W−
                    pwm_u <= pwm_active;
                    pwm_v <= 1'bz;
                    pwm_w <= 1'b0;
                end
                3'd3: begin // V+, W−
                    pwm_u <= 1'bz;
                    pwm_v <= pwm_active;
                    pwm_w <= 1'b0;
                end
                3'd4: begin // V+, U−
                    pwm_u <= 1'b0;
                    pwm_v <= pwm_active;
                    pwm_w <= 1'bz;
                end
                3'd5: begin // W+, U−
                    pwm_u <= 1'b0;
                    pwm_v <= 1'bz;
                    pwm_w <= pwm_active;
                end
                3'd6: begin // W+, V−
                    pwm_u <= 1'bz;
                    pwm_v <= 1'b0;
                    pwm_w <= pwm_active;
                end
                default: begin // Invalid sector
                    pwm_u <= 1'b0;
                    pwm_v <= 1'b0;
                    pwm_w <= 1'b0;
                end
            endcase
        end
    end
endmodule
