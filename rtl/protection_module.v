`timescale 1ns/1ps

module protection_module (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [11:0] current_sense,   // from current sensor (e.g. ADC)
    input  wire [11:0] voltage_sense,   // from voltage sensor (e.g. ADC)
    output reg         enable_pwm,      // enable signal for PWM module
    output reg         fault_ocp,       // overcurrent fault flag
    output reg         fault_uvlo       // undervoltage fault flag
);

    // Threshold values (tunable parameters)
    parameter [11:0] OCP_THRESHOLD  = 12'd3000;  // Overcurrent threshold (e.g., 3.0 A)
    parameter [11:0] UVLO_THRESHOLD = 12'd2000;  // Undervoltage threshold (e.g., 20.0 V)
    
    // Hysteresis for UVLO to prevent oscillation
    parameter [11:0] UVLO_HYSTERESIS = 12'd100;  // e.g., 1.0 V hysteresis
    
    // Internal signals for edge detection
    reg fault_ocp_prev;
    reg fault_uvlo_prev;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            enable_pwm      <= 1'b0;
            fault_ocp       <= 1'b0;
            fault_uvlo      <= 1'b0;
            fault_ocp_prev  <= 1'b0;
            fault_uvlo_prev <= 1'b0;
        end
        else begin
            // Store previous fault states
            fault_ocp_prev  <= fault_ocp;
            fault_uvlo_prev <= fault_uvlo;
            
            // ========================================
            // Overcurrent Protection (OCP)
            // ========================================
            if (current_sense > OCP_THRESHOLD) begin
                fault_ocp <= 1'b1;
                if (!fault_ocp_prev) begin
                    // Rising edge of OCP fault - log once
                    // Synthesis tool will optimize this away, but useful for simulation
                end
            end
            else begin
                fault_ocp <= 1'b0;
            end
            
            // ========================================
            // Undervoltage Lockout (UVLO) with Hysteresis
            // ========================================
            if (fault_uvlo) begin
                // Already in fault state - need voltage to rise above threshold + hysteresis
                if (voltage_sense > (UVLO_THRESHOLD + UVLO_HYSTERESIS)) begin
                    fault_uvlo <= 1'b0;
                end
            end
            else begin
                // Normal operation - check if voltage drops below threshold
                if (voltage_sense < UVLO_THRESHOLD) begin
                    fault_uvlo <= 1'b1;
                    if (!fault_uvlo_prev) begin
                        // Rising edge of UVLO fault - log once
                    end
                end
            end
            
            // ========================================
            // PWM Enable Logic
            // ========================================
            // Disable PWM if any fault occurs
            if (fault_ocp || fault_uvlo)
                enable_pwm <= 1'b0;
            else
                enable_pwm <= 1'b1;
        end
    end

endmodule
