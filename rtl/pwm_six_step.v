`timescale 1ns/1ps

module pwm_six_step #(
    parameter DEADTIME_CLOCKS = 4  // Deadtime between high and low side in clock cycles
)(
    input  wire        clk,        // System clock
    input  wire        rst_n,      // Active-low reset
    input  wire [11:0] duty,       // 12-bit duty (0–4095)
    input  wire [2:0]  sector,     // Active commutation sector (1–6)
    output reg         pwm_uh,     // Phase U high-side
    output reg         pwm_ul,     // Phase U low-side
    output reg         pwm_vh,     // Phase V high-side
    output reg         pwm_vl,     // Phase V low-side
    output reg         pwm_wh,     // Phase W high-side
    output reg         pwm_wl      // Phase W low-side
);

    // 12-bit up counter for PWM timing
    reg [11:0] counter;
    reg [2:0]  sector_prev;
    
    // Deadtime counter for each phase
    reg [7:0] deadtime_counter_u;
    reg [7:0] deadtime_counter_v;
    reg [7:0] deadtime_counter_w;
    
    // Flags to indicate if we're in deadtime period
    reg in_deadtime_u;
    reg in_deadtime_v;
    reg in_deadtime_w;
    
    // PWM compare signal (before deadtime insertion)
    wire pwm_active;
    assign pwm_active = (counter < duty);
    
    // Intermediate signals for what each phase should be doing
    // 2'b00 = both off, 2'b01 = low-side on, 2'b10 = high-side PWM
    reg [1:0] phase_u_state;
    reg [1:0] phase_v_state;
    reg [1:0] phase_w_state;
    
    // Previous states to detect transitions
    reg [1:0] phase_u_state_prev;
    reg [1:0] phase_v_state_prev;
    reg [1:0] phase_w_state_prev;
    
    // Detect sector change
    wire sector_change;
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
    
    // Determine phase states according to commutation sector
    // For 6-step commutation:
    // Sector 1: U+ (PWM), V- (ON), W floating (OFF)
    // Sector 2: U+ (PWM), W- (ON), V floating (OFF)
    // Sector 3: V+ (PWM), W- (ON), U floating (OFF)
    // Sector 4: V+ (PWM), U- (ON), W floating (OFF)
    // Sector 5: W+ (PWM), U- (ON), V floating (OFF)
    // Sector 6: W+ (PWM), V- (ON), U floating (OFF)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_u_state <= 2'b00;
            phase_v_state <= 2'b00;
            phase_w_state <= 2'b00;
        end else begin
            case (sector)
                3'd1: begin // U+, V-
                    phase_u_state <= 2'b10;  // U high-side PWM
                    phase_v_state <= 2'b01;  // V low-side ON
                    phase_w_state <= 2'b00;  // W floating
                end
                3'd2: begin // U+, W-
                    phase_u_state <= 2'b10;  // U high-side PWM
                    phase_v_state <= 2'b00;  // V floating
                    phase_w_state <= 2'b01;  // W low-side ON
                end
                3'd3: begin // V+, W-
                    phase_u_state <= 2'b00;  // U floating
                    phase_v_state <= 2'b10;  // V high-side PWM
                    phase_w_state <= 2'b01;  // W low-side ON
                end
                3'd4: begin // V+, U-
                    phase_u_state <= 2'b01;  // U low-side ON
                    phase_v_state <= 2'b10;  // V high-side PWM
                    phase_w_state <= 2'b00;  // W floating
                end
                3'd5: begin // W+, U-
                    phase_u_state <= 2'b01;  // U low-side ON
                    phase_v_state <= 2'b00;  // V floating
                    phase_w_state <= 2'b10;  // W high-side PWM
                end
                3'd6: begin // W+, V-
                    phase_u_state <= 2'b00;  // U floating
                    phase_v_state <= 2'b01;  // V low-side ON
                    phase_w_state <= 2'b10;  // W high-side PWM
                end
                default: begin // Invalid sector
                    phase_u_state <= 2'b00;
                    phase_v_state <= 2'b00;
                    phase_w_state <= 2'b00;
                end
            endcase
        end
    end
    
    // Deadtime insertion logic for Phase U
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_uh <= 1'b0;
            pwm_ul <= 1'b0;
            deadtime_counter_u <= 8'd0;
            in_deadtime_u <= 1'b0;
            phase_u_state_prev <= 2'b00;
        end else begin
            phase_u_state_prev <= phase_u_state;
            
            // Detect state transition
            if (phase_u_state != phase_u_state_prev) begin
                // Start deadtime period
                in_deadtime_u <= 1'b1;
                deadtime_counter_u <= DEADTIME_CLOCKS;
                pwm_uh <= 1'b0;
                pwm_ul <= 1'b0;
            end
            else if (in_deadtime_u) begin
                // Count down deadtime
                if (deadtime_counter_u > 0) begin
                    deadtime_counter_u <= deadtime_counter_u - 1'b1;
                    pwm_uh <= 1'b0;
                    pwm_ul <= 1'b0;
                end else begin
                    // Deadtime expired, apply new state
                    in_deadtime_u <= 1'b0;
                    case (phase_u_state)
                        2'b00: begin  // Floating
                            pwm_uh <= 1'b0;
                            pwm_ul <= 1'b0;
                        end
                        2'b01: begin  // Low-side ON
                            pwm_uh <= 1'b0;
                            pwm_ul <= 1'b1;
                        end
                        2'b10: begin  // High-side PWM
                            pwm_uh <= pwm_active;
                            pwm_ul <= 1'b0;
                        end
                        default: begin
                            pwm_uh <= 1'b0;
                            pwm_ul <= 1'b0;
                        end
                    endcase
                end
            end
            else begin
                // Normal operation (no transition)
                case (phase_u_state)
                    2'b00: begin  // Floating
                        pwm_uh <= 1'b0;
                        pwm_ul <= 1'b0;
                    end
                    2'b01: begin  // Low-side ON
                        pwm_uh <= 1'b0;
                        pwm_ul <= 1'b1;
                    end
                    2'b10: begin  // High-side PWM
                        pwm_uh <= pwm_active;
                        pwm_ul <= 1'b0;
                    end
                    default: begin
                        pwm_uh <= 1'b0;
                        pwm_ul <= 1'b0;
                    end
                endcase
            end
        end
    end
    
    // Deadtime insertion logic for Phase V
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_vh <= 1'b0;
            pwm_vl <= 1'b0;
            deadtime_counter_v <= 8'd0;
            in_deadtime_v <= 1'b0;
            phase_v_state_prev <= 2'b00;
        end else begin
            phase_v_state_prev <= phase_v_state;
            
            if (phase_v_state != phase_v_state_prev) begin
                in_deadtime_v <= 1'b1;
                deadtime_counter_v <= DEADTIME_CLOCKS;
                pwm_vh <= 1'b0;
                pwm_vl <= 1'b0;
            end
            else if (in_deadtime_v) begin
                if (deadtime_counter_v > 0) begin
                    deadtime_counter_v <= deadtime_counter_v - 1'b1;
                    pwm_vh <= 1'b0;
                    pwm_vl <= 1'b0;
                end else begin
                    in_deadtime_v <= 1'b0;
                    case (phase_v_state)
                        2'b00: begin
                            pwm_vh <= 1'b0;
                            pwm_vl <= 1'b0;
                        end
                        2'b01: begin
                            pwm_vh <= 1'b0;
                            pwm_vl <= 1'b1;
                        end
                        2'b10: begin
                            pwm_vh <= pwm_active;
                            pwm_vl <= 1'b0;
                        end
                        default: begin
                            pwm_vh <= 1'b0;
                            pwm_vl <= 1'b0;
                        end
                    endcase
                end
            end
            else begin
                case (phase_v_state)
                    2'b00: begin
                        pwm_vh <= 1'b0;
                        pwm_vl <= 1'b0;
                    end
                    2'b01: begin
                        pwm_vh <= 1'b0;
                        pwm_vl <= 1'b1;
                    end
                    2'b10: begin
                        pwm_vh <= pwm_active;
                        pwm_vl <= 1'b0;
                    end
                    default: begin
                        pwm_vh <= 1'b0;
                        pwm_vl <= 1'b0;
                    end
                endcase
            end
        end
    end
    
    // Deadtime insertion logic for Phase W
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_wh <= 1'b0;
            pwm_wl <= 1'b0;
            deadtime_counter_w <= 8'd0;
            in_deadtime_w <= 1'b0;
            phase_w_state_prev <= 2'b00;
        end else begin
            phase_w_state_prev <= phase_w_state;
            
            if (phase_w_state != phase_w_state_prev) begin
                in_deadtime_w <= 1'b1;
                deadtime_counter_w <= DEADTIME_CLOCKS;
                pwm_wh <= 1'b0;
                pwm_wl <= 1'b0;
            end
            else if (in_deadtime_w) begin
                if (deadtime_counter_w > 0) begin
                    deadtime_counter_w <= deadtime_counter_w - 1'b1;
                    pwm_wh <= 1'b0;
                    pwm_wl <= 1'b0;
                end else begin
                    in_deadtime_w <= 1'b0;
                    case (phase_w_state)
                        2'b00: begin
                            pwm_wh <= 1'b0;
                            pwm_wl <= 1'b0;
                        end
                        2'b01: begin
                            pwm_wh <= 1'b0;
                            pwm_wl <= 1'b1;
                        end
                        2'b10: begin
                            pwm_wh <= pwm_active;
                            pwm_wl <= 1'b0;
                        end
                        default: begin
                            pwm_wh <= 1'b0;
                            pwm_wl <= 1'b0;
                        end
                    endcase
                end
            end
            else begin
                case (phase_w_state)
                    2'b00: begin
                        pwm_wh <= 1'b0;
                        pwm_wl <= 1'b0;
                    end
                    2'b01: begin
                        pwm_wh <= 1'b0;
                        pwm_wl <= 1'b1;
                    end
                    2'b10: begin
                        pwm_wh <= pwm_active;
                        pwm_wl <= 1'b0;
                    end
                    default: begin
                        pwm_wh <= 1'b0;
                        pwm_wl <= 1'b0;
                    end
                endcase
            end
        end
    end

endmodule
