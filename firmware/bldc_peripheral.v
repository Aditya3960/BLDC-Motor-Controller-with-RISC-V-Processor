`timescale 1ns/1ps

module bldc_peripheral #(
    parameter TIMER_WIDTH = 16,
    parameter DEBOUNCE_WIDTH = 2,
    parameter OCP_THRESHOLD = 12'd3000,
    parameter UVLO_THRESHOLD = 12'd2000,
    parameter UVLO_HYSTERESIS = 12'd100,
    parameter DEADTIME_CLOCKS = 4
)(
    input  wire        clk,
    input  wire        rst_n,
    
    // PicoRV32 native memory interface
    input  wire        mem_valid,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_wdata,
    input  wire [3:0]  mem_wstrb,
    output reg  [31:0] mem_rdata,
    output reg         mem_ready,
    
    // Simulated sensor inputs
    input  wire [2:0]  hall_sensors_in,
    input  wire        bemf_in,
    
    // PWM outputs
    output wire        pwm_uh,
    output wire        pwm_ul,
    output wire        pwm_vh,
    output wire        pwm_vl,
    output wire        pwm_wh,
    output wire        pwm_wl,
    
    // Status outputs (for debug)
    output wire [2:0]  current_sector_out,
    output wire        fault_out
);

    //==========================================================================
    // Register addresses
    //==========================================================================
    localparam ADDR_DUTY       = 32'h40000000;
    localparam ADDR_ENABLE     = 32'h40000004;
    localparam ADDR_MODE       = 32'h40000008;
    localparam ADDR_CURRENT    = 32'h40000010;
    localparam ADDR_VOLTAGE    = 32'h40000014;
    localparam ADDR_STATUS     = 32'h40000018;
    localparam ADDR_SECTOR     = 32'h4000001C;

    //==========================================================================
    // Control registers
    //==========================================================================
    reg [11:0] duty_cycle_reg;
    reg        enable_reg;
    reg        mode_reg;
    reg [11:0] current_reg;
    reg [11:0] voltage_reg;
    
    // Status from BLDC controller
    wire       fault_ocp_internal;
    wire       fault_uvlo_internal;
    wire       pwm_enabled_internal;
    wire [2:0] current_sector_internal;
    wire [TIMER_WIDTH-1:0] commutation_period_internal;
    wire       commutation_event_internal;
    
    //==========================================================================
    // Bus interface logic
    //==========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            duty_cycle_reg <= 12'd0;
            enable_reg     <= 1'b0;
            mode_reg       <= 1'b0;
            current_reg    <= 12'd1500;
            voltage_reg    <= 12'd2500;
            mem_ready      <= 1'b0;
        end else begin
            mem_ready <= mem_valid;
            
            // Write registers
            if (mem_valid && (|mem_wstrb)) begin
                case (mem_addr)
                    ADDR_DUTY: begin
                        duty_cycle_reg <= mem_wdata[11:0];
                        $display("[%0t] *** BLDC_PERIPHERAL: DUTY written = %0d", $time, mem_wdata[11:0]);
                    end
                    ADDR_ENABLE: begin
                        enable_reg <= mem_wdata[0];
                        $display("[%0t] *** BLDC_PERIPHERAL: ENABLE written = %0d", $time, mem_wdata[0]);
                    end
                    ADDR_MODE: begin
                        mode_reg <= mem_wdata[0];
                        $display("[%0t] *** BLDC_PERIPHERAL: MODE written = %0d", $time, mem_wdata[0]);
                    end
                    ADDR_CURRENT: begin
                        current_reg <= mem_wdata[11:0];
                        $display("[%0t] *** BLDC_PERIPHERAL: CURRENT written = %0d", $time, mem_wdata[11:0]);
                    end
                    ADDR_VOLTAGE: begin
                        voltage_reg <= mem_wdata[11:0];
                        $display("[%0t] *** BLDC_PERIPHERAL: VOLTAGE written = %0d", $time, mem_wdata[11:0]);
                    end
                endcase
            end
        end
    end
    
    // Read registers
    always @(*) begin
        mem_rdata = 32'd0;
        if (mem_valid && !(|mem_wstrb)) begin
            case (mem_addr)
                ADDR_DUTY:    mem_rdata = {20'd0, duty_cycle_reg};
                ADDR_ENABLE:  mem_rdata = {31'd0, enable_reg};
                ADDR_MODE:    mem_rdata = {31'd0, mode_reg};
                ADDR_CURRENT: mem_rdata = {20'd0, current_reg};
                ADDR_VOLTAGE: mem_rdata = {20'd0, voltage_reg};
                ADDR_STATUS:  mem_rdata = {30'd0, fault_uvlo_internal, fault_ocp_internal};
                ADDR_SECTOR:  mem_rdata = {29'd0, current_sector_internal};
                default:      mem_rdata = 32'hDEADBEEF;
            endcase
        end
    end
    
    //==========================================================================
    // BLDC controller instance
    //==========================================================================
    wire [11:0] effective_duty;
    assign effective_duty = enable_reg ? duty_cycle_reg : 12'd0;
    
    bldc_top #(
        .TIMER_WIDTH(TIMER_WIDTH),
        .DEBOUNCE_WIDTH(DEBOUNCE_WIDTH),
        .OCP_THRESHOLD(OCP_THRESHOLD),
        .UVLO_THRESHOLD(UVLO_THRESHOLD),
        .UVLO_HYSTERESIS(UVLO_HYSTERESIS),
        .DEADTIME_CLOCKS(DEADTIME_CLOCKS)
    ) bldc_controller (
        .clk(clk),
        .rst_n(rst_n),
        .duty_cycle(effective_duty),
        .mode_select(mode_reg),
        .hall_sensors(hall_sensors_in),
        .bemf_comparator(bemf_in),
        .current_sense(current_reg),
        .voltage_sense(voltage_reg),
        .pwm_uh(pwm_uh),
        .pwm_ul(pwm_ul),
        .pwm_vh(pwm_vh),
        .pwm_vl(pwm_vl),
        .pwm_wh(pwm_wh),
        .pwm_wl(pwm_wl),
        .fault_ocp(fault_ocp_internal),
        .fault_uvlo(fault_uvlo_internal),
        .pwm_enabled(pwm_enabled_internal),
        .current_sector(current_sector_internal),
        .commutation_period(commutation_period_internal),
        .commutation_event(commutation_event_internal)
    );
    
    // Export status for debug
    assign current_sector_out = current_sector_internal;
    assign fault_out = fault_ocp_internal || fault_uvlo_internal;

endmodule
