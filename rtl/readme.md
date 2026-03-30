# RTL Design

## Overview
This directory contains the complete RTL implementation of the BLDC motor controller.  
The design is structured as a hardware-accelerated control system where time-critical operations such as PWM generation, commutation, and protection are implemented in Verilog.

The system operates at a 50 MHz clock and supports both Hall-based and sensorless commutation.

---
## Module Breakdown

### 1. Top-Level Integration
**bldc_top.v**
- Connects all submodules
- Selects between Hall and sensorless modes
- Routes PWM outputs to the inverter stage
- Interfaces with protection signals

---

### 2. PWM Generation
**pwm_six_step.v**
- Generates 6-step commutation signals
- Produces complementary high-side and low-side outputs
- Inserts deadtime to prevent shoot-through in MOSFETs
- Uses a 12-bit counter for duty cycle control

---

### 3. Hall-Based Control Path

**hall_debounce.v**
- Removes noise from Hall sensor inputs
- Ensures stable transitions

**hall_to_sector.v**
- Converts 3-bit Hall input into one of 6 commutation sectors
- Determines which phase should be driven

---

### 4. Sensorless Control Path

**zcd_logic.v**
- Detects zero-crossing of back-EMF signal
- Generates timing pulses for commutation

**comm_timer.v**
- Measures time between zero-cross events
- Used to estimate rotor speed

**sensorless_sector.v**
- Advances commutation sector based on timing
- Replaces Hall-based logic when in sensorless mode

---

### 5. Protection Logic

**protection_module.v**
- Monitors current and voltage inputs
- Triggers fault on:
  - Overcurrent condition
  - Undervoltage condition
- Disables PWM outputs to protect hardware

---

### 6. CPU Interface

**bldc_peripheral.v**
- Implements memory-mapped registers
- Allows PicoRV32 to:
  - Set duty cycle
  - Enable/disable motor
  - Select mode
  - Read sensor values

---

## Data Flow

PWM control path:

CPU → Registers → PWM Generator → Gate Driver → Motor

Feedback path:

Motor → Hall/BEMF → Control Logic → Sector Selection → PWM

---

## Key Characteristics

- Fully synchronous design (50 MHz)
- Deterministic timing for PWM switching
- Hardware-based safety mechanisms
- Modular design for easy extension (e.g., FOC)

---

## Notes
- Deadtime insertion is critical to prevent MOSFET damage
- Sensorless mode relies on accurate zero-cross detection
- Protection logic has highest priority and overrides all control signals
