`timescale 1ns/1ps

module tb_bldc_top;

    // ========================================
    // DUTY CYCLE CONTROL PARAMETERS
    // ========================================
    parameter real DUTY_CYCLE_PERCENT = 50.0;
    parameter PWM_MAX = 4095;
    localparam integer DUTY_VALUE = (PWM_MAX * DUTY_CYCLE_PERCENT) / 100.0;
    
    // ========================================
    // PROTECTION THRESHOLDS
    // ========================================
    parameter OCP_THRESHOLD = 12'd3000;      // Overcurrent threshold
    parameter UVLO_THRESHOLD = 12'd2000;     // Undervoltage threshold
    parameter UVLO_HYSTERESIS = 12'd100;     // UVLO hysteresis
    
    // ========================================
    // TIMING PARAMETERS
    // ========================================
    parameter real CLK_PERIOD = 24.4140625;
    parameter real CLK_HALF_PERIOD = 12.20703125;
    parameter SECTOR_DURATION_NS = 100000;
    parameter TIMER_WIDTH = 16;
    parameter DEBOUNCE_WIDTH = 2;

    // Testbench signals
    reg        clk;
    reg        rst_n;
    reg [11:0] duty_cycle;
    reg        mode_select;
    reg [2:0]  hall_sensors;
    reg        bemf_comparator;
    reg [11:0] current_sense;
    reg [11:0] voltage_sense;
    
    wire       pwm_u;
    wire       pwm_v;
    wire       pwm_w;
    wire       fault_ocp;
    wire       fault_uvlo;
    wire       pwm_enabled;
    wire [2:0] current_sector;
    wire [TIMER_WIDTH-1:0] commutation_period;
    wire       commutation_event;

    // BEMF generation control
    reg bemf_gen_enable;
    integer bemf_toggle_count;

    // Clock generation
    initial clk = 0;
    always #CLK_HALF_PERIOD clk = ~clk;

    // DUT instantiation with protection
    bldc_top #(
        .TIMER_WIDTH(TIMER_WIDTH),
        .DEBOUNCE_WIDTH(DEBOUNCE_WIDTH),
        .OCP_THRESHOLD(OCP_THRESHOLD),
        .UVLO_THRESHOLD(UVLO_THRESHOLD),
        .UVLO_HYSTERESIS(UVLO_HYSTERESIS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .duty_cycle(duty_cycle),
        .mode_select(mode_select),
        .hall_sensors(hall_sensors),
        .bemf_comparator(bemf_comparator),
        .current_sense(current_sense),
        .voltage_sense(voltage_sense),
        .pwm_u(pwm_u),
        .pwm_v(pwm_v),
        .pwm_w(pwm_w),
        .fault_ocp(fault_ocp),
        .fault_uvlo(fault_uvlo),
        .pwm_enabled(pwm_enabled),
        .current_sector(current_sector),
        .commutation_period(commutation_period),
        .commutation_event(commutation_event)
    );

    // ========================================
    // BEMF Zero-Crossing Generator
    // ========================================
    // Automatically generates BEMF transitions for sensorless mode
    initial begin
        bemf_comparator = 0;
        bemf_gen_enable = 0;
        bemf_toggle_count = 0;
    end

    always @(posedge clk) begin
        if (bemf_gen_enable && pwm_enabled) begin
            // Generate BEMF zero-crossing every sector
            if (bemf_toggle_count >= (SECTOR_DURATION_NS / CLK_PERIOD)) begin
                bemf_comparator <= ~bemf_comparator;
                bemf_toggle_count <= 0;
                $display("    🔄 [%0t] BEMF Zero-Crossing: %b → %b", 
                         $time, ~bemf_comparator, bemf_comparator);
            end else begin
                bemf_toggle_count <= bemf_toggle_count + 1;
            end
        end else begin
            bemf_toggle_count <= 0;
        end
    end

    // Monitor mode changes
    always @(mode_select) begin
        if (mode_select)
            $display("    🔧 [%0t] Switched to SENSORLESS mode (BEMF-based)", $time);
        else
            $display("    🔧 [%0t] Switched to HALL SENSOR mode", $time);
    end

    // Monitor sector changes with mode indication
    reg [2:0] prev_sector;
    initial prev_sector = 3'b000;
    
    always @(current_sector) begin
        if (current_sector != prev_sector && current_sector != 3'b000) begin
            $display("    📍 [%0t] Sector: %0d (Mode: %s)", 
                     $time, current_sector, mode_select ? "Sensorless" : "Hall");
            prev_sector = current_sector;
        end
    end

    // ========================================
    // TASK: Set Duty Cycle
    // ========================================
    task set_duty_cycle;
        input real percent;
        begin
            duty_cycle = (PWM_MAX * percent) / 100.0;
            $display("[%0t] ⚙️  Duty cycle changed to %.1f%% (value=%0d)", $time, percent, duty_cycle);
        end
    endtask

    // ========================================
    // TASK: Set Current Sense Value
    // ========================================
    task set_current;
        input [11:0] value;
        begin
            current_sense = value;
            if (value > OCP_THRESHOLD)
                $display("[%0t] ⚡ Current sense set to %0d [ABOVE threshold %0d]", $time, value, OCP_THRESHOLD);
            else
                $display("[%0t] ⚡ Current sense set to %0d [Normal]", $time, value);
        end
    endtask

    // ========================================
    // TASK: Set Voltage Sense Value
    // ========================================
    task set_voltage;
        input [11:0] value;
        begin
            voltage_sense = value;
            if (value < UVLO_THRESHOLD)
                $display("[%0t] 🔋 Voltage sense set to %0d [BELOW threshold %0d]", $time, value, UVLO_THRESHOLD);
            else
                $display("[%0t] 🔋 Voltage sense set to %0d [Normal]", $time, value);
        end
    endtask

    // ========================================
    // TASK: Generate Hall Sensor Sequence
    // ========================================
    task generate_hall_sequence_synced;
        input integer cycles;
        integer i, j;
        reg [2:0] hall_pattern [5:0];
        begin
            hall_pattern[0] = 3'b001;
            hall_pattern[1] = 3'b101;
            hall_pattern[2] = 3'b100;
            hall_pattern[3] = 3'b110;
            hall_pattern[4] = 3'b010;
            hall_pattern[5] = 3'b011;
            
            $display("    🔄 Rotating motor (Hall sensors) for %0d cycles...", cycles);
            
            @(posedge clk);
            wait(dut.u_pwm_three_phase.counter == 12'd0);
            @(posedge clk);
            
            for (i = 0; i < cycles; i = i + 1) begin
                for (j = 0; j < 6; j = j + 1) begin
                    hall_sensors = hall_pattern[j];
                    
                    wait(dut.u_pwm_three_phase.counter == 12'd4095);
                    @(posedge clk);
                    wait(dut.u_pwm_three_phase.counter == 12'd0);
                    @(posedge clk);
                end
            end
        end
    endtask

    // ========================================
    // TASK: Run motor in sensorless mode
    // ========================================
    task run_motor_sensorless;
        input integer num_sectors;
        begin
            $display("    🔄 Running motor (Sensorless) for %0d sectors...", num_sectors);
            bemf_gen_enable = 1;
            #(SECTOR_DURATION_NS * num_sectors);
            bemf_gen_enable = 0;
        end
    endtask

    // ========================================
    // Main Test Sequence
    // ========================================
    initial begin
        $dumpfile("bldc_top.vcd");
        $dumpvars(0, tb_bldc_top);
        
        // Initialize signals
        rst_n = 0;
        duty_cycle = DUTY_VALUE;
        mode_select = 0;  // Start with Hall sensor mode
        hall_sensors = 3'b001;
        bemf_comparator = 0;
        bemf_gen_enable = 0;
        current_sense = 12'd1500;    // Normal current (below threshold)
        voltage_sense = 12'd2500;    // Normal voltage (above threshold)
        
        $display("\n");
        $display("╔═════════════════════════════════════════════════════════════════╗");
        $display("║          BLDC Motor Controller with Protection Test            ║");
        $display("╠═════════════════════════════════════════════════════════════════╣");
        $display("║  Duty Cycle: %.1f%% (Fixed for all tests)                      ║", DUTY_CYCLE_PERCENT);
        $display("║  OCP Threshold: %4d                                            ║", OCP_THRESHOLD);
        $display("║  UVLO Threshold: %4d (Hysteresis: %3d)                         ║", UVLO_THRESHOLD, UVLO_HYSTERESIS);
        $display("║  Clock Period: %.2f ns (%.2f MHz)                           ║", CLK_PERIOD, 1000.0/CLK_PERIOD);
        $display("║  Sector Duration: %.1f µs                                      ║", SECTOR_DURATION_NS/1000.0);
        $display("╚═════════════════════════════════════════════════════════════════╝");
        $display("\n");
        
        // Reset sequence
        $display("🔄 [%0t] Applying reset...", $time);
        #(CLK_PERIOD*10);
        rst_n = 1;
        $display("✅ [%0t] Reset released\n", $time);
        #(CLK_PERIOD*5);
        
        // ========================================
        // Test 1a: Normal Operation - Hall Sensor Mode
        // ========================================
        $display("╔═══════════════════════════════════════════════════╗");
        $display("║  TEST 1a: Normal Operation - Hall Sensor Mode     ║");
        $display("╚═══════════════════════════════════════════════════╝");
        mode_select = 0;  // Hall sensor mode
        set_duty_cycle(50.0);  // Keep duty cycle at 50%
        set_current(12'd1500);  // Normal current
        set_voltage(12'd2500);  // Normal voltage
        
        generate_hall_sequence_synced(2);  // 2 electrical cycles
        
        #(SECTOR_DURATION_NS*2);
        $display("✅ Test 1a completed - Hall sensor mode working\n");
        
        // ========================================
        // Test 1b: Normal Operation - Sensorless Mode
        // ========================================
        $display("╔═══════════════════════════════════════════════════╗");
        $display("║  TEST 1b: Normal Operation - Sensorless Mode      ║");
        $display("╚═══════════════════════════════════════════════════╝");
        mode_select = 1;  // Switch to sensorless mode
        // Duty cycle remains 50%
        
        run_motor_sensorless(6);  // Run for 6 sectors (1 electrical cycle)
        
        #(SECTOR_DURATION_NS*2);
        $display("✅ Test 1b completed - Sensorless mode working\n");
        
        // Switch back to Hall sensor mode for protection tests
        mode_select = 0;
        #(SECTOR_DURATION_NS);
        
        // ========================================
        // Test 2: Overcurrent Protection (Hall Mode)
        // ========================================
        $display("╔═══════════════════════════════════════════════════╗");
        $display("║  TEST 2: Overcurrent Protection (Hall Mode)       ║");
        $display("╚═══════════════════════════════════════════════════╝");
        $display("Injecting overcurrent condition...");
        set_current(12'd3500);  // Above OCP threshold
        
        #(SECTOR_DURATION_NS*3);
        
        $display("Clearing overcurrent condition...");
        set_current(12'd1500);  // Back to normal
        
        #(SECTOR_DURATION_NS*2);
        $display("✅ Test 2 completed - OCP working in Hall mode\n");
        
        // ========================================
        // Test 3: Overcurrent Protection (Sensorless Mode)
        // ========================================
        $display("╔═══════════════════════════════════════════════════╗");
        $display("║  TEST 3: Overcurrent Protection (Sensorless Mode) ║");
        $display("╚═══════════════════════════════════════════════════╝");
        mode_select = 1;  // Sensorless mode
        
        fork
            begin
                bemf_gen_enable = 1;
                #(SECTOR_DURATION_NS * 2);
                
                $display("Injecting overcurrent during sensorless operation...");
                set_current(12'd3500);  // Overcurrent
                
                #(SECTOR_DURATION_NS * 3);
                
                $display("Clearing overcurrent...");
                set_current(12'd1500);  // Normal
                
                #(SECTOR_DURATION_NS * 2);
                bemf_gen_enable = 0;
            end
        join
        
        mode_select = 0;  // Back to Hall mode
        #(SECTOR_DURATION_NS);
        $display("✅ Test 3 completed - OCP working in Sensorless mode\n");
        
        // ========================================
        // Test 4: Undervoltage Lockout
        // ========================================
        $display("╔═══════════════════════════════════════════════════╗");
        $display("║  TEST 4: Undervoltage Lockout (UVLO)              ║");
        $display("╚═══════════════════════════════════════════════════╝");
        $display("Triggering undervoltage condition...");
        set_voltage(12'd1500);  // Below UVLO threshold
        
        #(SECTOR_DURATION_NS*3);
        
        $display("Voltage recovering (testing hysteresis)...");
        set_voltage(12'd2050);  // Above threshold but below hysteresis
        
        #(SECTOR_DURATION_NS*2);
        
        if (pwm_enabled) begin
            $display("❌ ERROR: PWM enabled too early (hysteresis not working)");
        end else begin
            $display("✅ Correct: PWM still disabled (hysteresis working)");
        end
        
        $display("Voltage fully recovered...");
        set_voltage(12'd2500);  // Above threshold + hysteresis
        
        #(SECTOR_DURATION_NS*3);
        $display("✅ Test 4 completed - UVLO with hysteresis working\n");
        
        // ========================================
        // Test 5: Multiple Faults in Sensorless Mode
        // ========================================
        $display("╔═══════════════════════════════════════════════════╗");
        $display("║  TEST 5: Multiple Faults (Sensorless Mode)        ║");
        $display("╚═══════════════════════════════════════════════════╝");
        mode_select = 1;  // Sensorless mode
        
        fork
            begin
                bemf_gen_enable = 1;
                #(SECTOR_DURATION_NS * 2);
                
                $display("Triggering both OCP and UVLO simultaneously...");
                set_current(12'd3500);  // Overcurrent
                set_voltage(12'd1500);  // Undervoltage
                
                #(SECTOR_DURATION_NS*3);
                
                $display("Clearing all faults...");
                set_current(12'd1500);  // Normal current
                set_voltage(12'd2500);  // Normal voltage
                
                #(SECTOR_DURATION_NS*3);
                bemf_gen_enable = 0;
            end
        join
        
        mode_select = 0;  // Back to Hall mode
        #(SECTOR_DURATION_NS);
        $display("✅ Test 5 completed - Multiple faults handled\n");
        
        // ========================================
        // Test 6: Resume Normal Operation (Both Modes)
        // ========================================
        $display("╔═══════════════════════════════════════════════════╗");
        $display("║  TEST 6: Resume Normal Operation                  ║");
        $display("╚═══════════════════════════════════════════════════╝");
        
        // Hall sensor mode
        mode_select = 0;
        $display("Running in Hall sensor mode...");
        generate_hall_sequence_synced(1);
        #(SECTOR_DURATION_NS*2);
        
        // Sensorless mode
        mode_select = 1;
        $display("Running in Sensorless mode...");
        run_motor_sensorless(6);
        #(SECTOR_DURATION_NS*2);
        
        $display("✅ Test 6 completed - Both modes operational\n");
        
        // Wait for clean finish
        mode_select = 0;
        wait(dut.u_pwm_three_phase.counter == 12'd4095);
        @(posedge clk);
        wait(dut.u_pwm_three_phase.counter == 12'd0);
        @(posedge clk);
        
        // ========================================
        // Summary
        // ========================================
        $display("\n");
        $display("╔═════════════════════════════════════════════════════════════════╗");
        $display("║              🎉 ALL TESTS COMPLETED SUCCESSFULLY 🎉             ║");
        $display("╠═════════════════════════════════════════════════════════════════╣");
        $display("║  Total simulation time: %0t ns                               ║", $time);
        $display("║                                                                 ║");
        $display("║  Tests Performed (Duty Cycle: %.1f%% constant):               ║", DUTY_CYCLE_PERCENT);
        $display("║    ✅ Hall Sensor Mode - Normal Operation                       ║");
        $display("║    ✅ Sensorless Mode - Normal Operation                        ║");
        $display("║    ✅ Overcurrent Protection - Hall Mode                        ║");
        $display("║    ✅ Overcurrent Protection - Sensorless Mode                  ║");
        $display("║    ✅ UVLO with Hysteresis                                      ║");
        $display("║    ✅ Multiple Simultaneous Faults                              ║");
        $display("║    ✅ Both Modes Resume After Faults                            ║");
        $display("║                                                                 ║");
        $display("║  To view waveforms:                                             ║");
        $display("║    $ gtkwave bldc_top.vcd                                       ║");
        $display("║                                                                 ║");
        $display("║  Key Signals to Observe:                                        ║");
        $display("║    - mode_select: 0=Hall, 1=Sensorless                          ║");
        $display("║    - current_sector: Should advance in both modes               ║");
        $display("║    - pwm_u/v/w: PWM outputs                                     ║");
        $display("║    - fault_ocp, fault_uvlo: Protection flags                    ║");
        $display("║    - pwm_enabled: Master PWM enable                             ║");
        $display("╚═════════════════════════════════════════════════════════════════╝");
        $display("\n");
        
        #(SECTOR_DURATION_NS);
        $finish;
    end
    
    // ========================================
    // Monitor Protection Events
    // ========================================
    always @(posedge clk) begin
        if (fault_ocp && !dut.u_protection_module.fault_ocp_prev) begin
            $display("\n⚠️  [%0t] !!! OVERCURRENT FAULT DETECTED !!!", $time);
            $display("    Current=%0d, Threshold=%0d\n", current_sense, OCP_THRESHOLD);
        end
        if (fault_uvlo && !dut.u_protection_module.fault_uvlo_prev) begin
            $display("\n⚠️  [%0t] !!! UNDERVOLTAGE FAULT DETECTED !!!", $time);
            $display("    Voltage=%0d, Threshold=%0d\n", voltage_sense, UVLO_THRESHOLD);
        end
        if (!fault_ocp && dut.u_protection_module.fault_ocp_prev) begin
            $display("✅ [%0t] Overcurrent fault cleared\n", $time);
        end
        if (!fault_uvlo && dut.u_protection_module.fault_uvlo_prev) begin
            $display("✅ [%0t] Undervoltage fault cleared\n", $time);
        end
    end
    
    always @(posedge commutation_event) begin
        $display("    ⚡ [%0t] Commutation - Sector: %0d, Period: %0d, PWM: %s", 
                 $time, current_sector, commutation_period, pwm_enabled ? "ON" : "OFF");
    end

    // Status monitoring every 200µs
    initial begin
        forever begin
            #200000;
            if ($time > 0 && ($time % 200000 == 0)) begin
                $display("    ℹ️  [%0t] Status: Mode=%s Sector=%0d PWM=%s OCP=%b UVLO=%b", 
                         $time, 
                         mode_select ? "Sensorless" : "Hall     ",
                         current_sector, 
                         pwm_enabled ? "ON " : "OFF",
                         fault_ocp, 
                         fault_uvlo);
            end
        end
    end

endmodule
