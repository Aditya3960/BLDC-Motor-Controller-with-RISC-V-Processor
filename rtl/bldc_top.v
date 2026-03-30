`timescale 1ns/1ps

module bldc_top #(
    parameter TIMER_WIDTH = 16,
    parameter DEBOUNCE_WIDTH = 2,
    parameter OCP_THRESHOLD = 12'd3000,   // Overcurrent threshold
    parameter UVLO_THRESHOLD = 12'd2000,  // Undervoltage threshold
    parameter UVLO_HYSTERESIS = 12'd100,  // UVLO hysteresis
    parameter DEADTIME_CLOCKS = 4         // Deadtime in clock cycles
)(
    // System inputs
    input  wire        clk,
    input  wire        rst_n,
    
    // Control inputs
    input  wire [11:0] duty_cycle,      // 12-bit duty cycle (0-4095)
    input  wire        mode_select,     // 0=Hall sensor mode, 1=Sensorless mode
    
    // Hall sensor inputs (for sensored mode)
    input  wire [2:0]  hall_sensors,
    
    // BEMF input (for sensorless mode)
    input  wire        bemf_comparator,
    
    // Protection inputs
    input  wire [11:0] current_sense,   // Current sensor reading (12-bit ADC)
    input  wire [11:0] voltage_sense,   // Voltage sensor reading (12-bit ADC)
    
    // PWM outputs - 6 signals (3 high-side + 3 low-side)
    output wire        pwm_uh,          // Phase U high-side
    output wire        pwm_ul,          // Phase U low-side
    output wire        pwm_vh,          // Phase V high-side
    output wire        pwm_vl,          // Phase V low-side
    output wire        pwm_wh,          // Phase W high-side
    output wire        pwm_wl,          // Phase W low-side
    
    // Protection outputs
    output wire        fault_ocp,       // Overcurrent fault flag
    output wire        fault_uvlo,      // Undervoltage fault flag
    output wire        pwm_enabled,     // PWM enable status
    
    // Debug outputs
    output wire [2:0]  current_sector,
    output wire [TIMER_WIDTH-1:0] commutation_period,
    output wire        commutation_event
);

    // Internal signals
    wire [2:0] hall_debounced;
    wire [2:0] hall_sector;
    wire [2:0] sensorless_sector_out;
    wire [2:0] selected_sector;
    wire       zcd_pulse;
    wire       comm_event;
    wire [TIMER_WIDTH-1:0] period;
    wire       enable_pwm_internal;
    wire       pwm_uh_internal;
    wire       pwm_ul_internal;
    wire       pwm_vh_internal;
    wire       pwm_vl_internal;
    wire       pwm_wh_internal;
    wire       pwm_wl_internal;

    // ========================================
    // Protection Module
    // ========================================
    protection_module #(
        .OCP_THRESHOLD(OCP_THRESHOLD),
        .UVLO_THRESHOLD(UVLO_THRESHOLD),
        .UVLO_HYSTERESIS(UVLO_HYSTERESIS)
    ) u_protection_module (
        .clk(clk),
        .rst_n(rst_n),
        .current_sense(current_sense),
        .voltage_sense(voltage_sense),
        .enable_pwm(enable_pwm_internal),
        .fault_ocp(fault_ocp),
        .fault_uvlo(fault_uvlo)
    );

    // ========================================
    // Hall Sensor Path (Sensored Mode)
    // ========================================
    
    // Debounce hall sensors
    hall_debounce #(
        .W(3),
        .DB_CNT_WIDTH(DEBOUNCE_WIDTH)
    ) u_hall_debounce (
        .clk(clk),
        .rst_n(rst_n),
        .hall_in(hall_sensors),
        .hall_out(hall_debounced)
    );
    
    // Convert hall sensor values to sector
    hall_to_sector u_hall_to_sector (
        .clk(clk),
        .rst_n(rst_n),
        .hall(hall_debounced),
        .sector(hall_sector)
    );

    // ========================================
    // Sensorless Path (Sensorless Mode)
    // ========================================
    
    // Zero-crossing detection
    zcd_logic u_zcd_logic (
        .clk(clk),
        .rst_n(rst_n),
        .bemf_in(bemf_comparator),
        .zcd_pulse(zcd_pulse)
    );
    
    // Commutation timer
    comm_timer #(
        .WIDTH(TIMER_WIDTH)
    ) u_comm_timer (
        .clk(clk),
        .rst_n(rst_n),
        .zcd_pulse(zcd_pulse),
        .period(period),
        .comm_event(comm_event)
    );
    
    // Sensorless sector generation
    sensorless_sector u_sensorless_sector (
        .clk(clk),
        .rst_n(rst_n),
        .comm_event(comm_event),
        .sector(sensorless_sector_out)
    );

    // ========================================
    // Mode Selection
    // ========================================
    
    // Select between hall sensor and sensorless sector
    assign selected_sector = mode_select ? sensorless_sector_out : hall_sector;

    // ========================================
    // PWM Generation (6 outputs with deadtime)
    // ========================================
    
    pwm_six_step #(
        .DEADTIME_CLOCKS(DEADTIME_CLOCKS)
    ) u_pwm_six_step (
        .clk(clk),
        .rst_n(rst_n),
        .duty(duty_cycle),
        .sector(selected_sector),
        .pwm_uh(pwm_uh_internal),
        .pwm_ul(pwm_ul_internal),
        .pwm_vh(pwm_vh_internal),
        .pwm_vl(pwm_vl_internal),
        .pwm_wh(pwm_wh_internal),
        .pwm_wl(pwm_wl_internal)
    );

    // ========================================
    // PWM Output Gating (Protection Module Override)
    // ========================================
    // When protection is active, force all PWM outputs LOW
    assign pwm_uh = enable_pwm_internal ? pwm_uh_internal : 1'b0;
    assign pwm_ul = enable_pwm_internal ? pwm_ul_internal : 1'b0;
    assign pwm_vh = enable_pwm_internal ? pwm_vh_internal : 1'b0;
    assign pwm_vl = enable_pwm_internal ? pwm_vl_internal : 1'b0;
    assign pwm_wh = enable_pwm_internal ? pwm_wh_internal : 1'b0;
    assign pwm_wl = enable_pwm_internal ? pwm_wl_internal : 1'b0;

    // ========================================
    // Debug Outputs
    // ========================================
    assign current_sector = selected_sector;
    assign commutation_period = period;
    assign commutation_event = comm_event;
    assign pwm_enabled = enable_pwm_internal;

endmodule
