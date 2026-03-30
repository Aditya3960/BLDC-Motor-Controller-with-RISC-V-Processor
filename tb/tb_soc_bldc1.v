`timescale 1ns/1ps

module tb_soc_bldc;

    parameter CLK_PERIOD = 20;  // 50 MHz
    
    reg        clk;
    reg        resetn;
    reg [2:0]  hall_sensors;
    reg        bemf_comparator;
    
    wire       pwm_uh, pwm_ul;
    wire       pwm_vh, pwm_vl;
    wire       pwm_wh, pwm_wl;
    wire [2:0] debug_sector;
    wire       debug_fault;
    
    // Clock
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;
    
    // DUT
    soc_bldc_top dut (
        .clk(clk),
        .resetn(resetn),
        .hall_sensors(hall_sensors),
        .bemf_comparator(bemf_comparator),
        .pwm_uh(pwm_uh),
        .pwm_ul(pwm_ul),
        .pwm_vh(pwm_vh),
        .pwm_vl(pwm_vl),
        .pwm_wh(pwm_wh),
        .pwm_wl(pwm_wl),
        .debug_sector(debug_sector),
        .debug_fault(debug_fault)
    );
    
    // Hall sensor sequence
    reg [2:0] hall_seq [0:5];
    integer hall_idx;
    
    initial begin
        hall_seq[0] = 3'b001;
        hall_seq[1] = 3'b101;
        hall_seq[2] = 3'b100;
        hall_seq[3] = 3'b110;
        hall_seq[4] = 3'b010;
        hall_seq[5] = 3'b011;
        hall_idx = 0;
        hall_sensors = hall_seq[0];
    end
    
    // *** FIX: 500us per sector (was 10us) ***
    // PWM period = 81.92us, so 500us gives ~6 PWM pulses per sector
    // This simulates ~333 Hz electrical = realistic low-speed motor
    always #500000 begin
        hall_idx = (hall_idx + 1) % 6;
        hall_sensors = hall_seq[hall_idx];
    end
    
    // BEMF — toggle every 500us to match hall timing
    initial bemf_comparator = 0;
    always #500000 bemf_comparator = ~bemf_comparator;
    
    // =========================================================
    // MONITORING
    // =========================================================
    
    // CPU memory accesses
    always @(posedge clk) begin
        if (dut.mem_valid && dut.mem_ready) begin
            if (|dut.mem_wstrb) begin
                $display("[%0t] CPU WRITE: addr=0x%08x data=0x%08x (RAM=%b BLDC=%b)", 
                         $time, dut.mem_addr, dut.mem_wdata,
                         dut.sel_ram, dut.sel_bldc);
                if (dut.sel_bldc) begin
                    case (dut.mem_addr)
                        32'h40000000: $display("         --> DUTY_CYCLE = %0d (%.1f%%)", 
                                               dut.mem_wdata, dut.mem_wdata*100.0/4096.0);
                        32'h40000004: $display("         --> ENABLE = %0d", dut.mem_wdata);
                        32'h40000008: $display("         --> MODE = %s", 
                                               dut.mem_wdata[0] ? "SENSORLESS" : "HALL");
                        32'h40000010: $display("         --> CURRENT = %0d", dut.mem_wdata);
                        32'h40000014: $display("         --> VOLTAGE = %0d", dut.mem_wdata);
                    endcase
                end
            end
        end
    end
    
    // PWM changes
    reg [5:0] prev_pwm;
    initial prev_pwm = 6'b0;
    always @(posedge clk) begin
        if ({pwm_uh,pwm_ul,pwm_vh,pwm_vl,pwm_wh,pwm_wl} != prev_pwm) begin
            prev_pwm = {pwm_uh,pwm_ul,pwm_vh,pwm_vl,pwm_wh,pwm_wl};
            $display("[%0t] PWM: UH=%b UL=%b VH=%b VL=%b WH=%b WL=%b  Sector=%0d  Fault=%b",
                     $time, pwm_uh,pwm_ul,pwm_vh,pwm_vl,pwm_wh,pwm_wl,
                     debug_sector, debug_fault);
        end
    end

    // Sector changes
    reg [2:0] prev_sector;
    initial prev_sector = 0;
    always @(posedge clk) begin
        if (debug_sector != prev_sector) begin
            prev_sector = debug_sector;
            $display("[%0t] SECTOR CHANGE -> %0d", $time, debug_sector);
        end
    end

    // Periodic status every 500us
    always @(posedge clk) begin
        if (resetn && ($time % 500000 == 0)) begin
            $display("[%0t] STATUS: sector=%0d  enable_pwm=%b  counter=%0d  duty=%0d  fault=%b",
                     $time,
                     debug_sector,
                     dut.bldc_periph.bldc_controller.pwm_enabled,
                     dut.bldc_periph.bldc_controller.u_pwm_six_step.counter,
                     dut.bldc_periph.bldc_controller.u_pwm_six_step.duty,
                     debug_fault);
        end
    end
    
    // =========================================================
    // TEST SEQUENCE
    // =========================================================
    initial begin
        $dumpfile("soc_bldc.vcd");
        $dumpvars(0, tb_soc_bldc);
        
        $display("\n=================================================");
        $display("  RISC-V BLDC Motor Controller Simulation");
        $display("  PWM period = 81.92us @ 50MHz / 12-bit counter");
        $display("  Sector duration = 500us -> ~6 PWM pulses/sector");
        $display("=================================================\n");
        
        resetn = 0;
        #(CLK_PERIOD * 10);
        resetn = 1;
        $display("[%0t] Reset released - CPU starting...\n", $time);
        
        // *** FIX: 20ms run time (was 500us) ***
        // 6 sectors * 500us = 3ms per electrical cycle
        // 20ms gives ~6 full electrical cycles to observe
        #5000000;
        
        $display("\n=================================================");
        $display("  Simulation complete — view: gtkwave soc_bldc.vcd");
        $display("  Zoom to 500us/div to see PWM pulses within sectors");
        $display("  Zoom to 50ns/div to see individual PWM switching");
        $display("=================================================\n");
        
        $finish;
    end

endmodule
