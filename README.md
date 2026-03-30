# 🚀 BLDC Motor Controller with RISC-V (PicoRV32)

## 📌 Overview

This project implements a **complete FPGA-based BLDC motor controller** using a **PicoRV32 RISC-V soft-core processor**.

The system supports:

- 🟢 **Hall sensor-based commutation**
- 🔵 **Sensorless commutation (Back-EMF based)**

It is deployed on a **Xilinx PYNQ-Z2 FPGA** and uses a **custom-built 3-phase inverter circuit** using **IR2101 gate drivers and MOSFET half-bridges**.

---

## 🎯 What This Project Demonstrates

✔ FPGA-based real-time motor control  
✔ Hardware + software co-design  
✔ RISC-V embedded system integration  
✔ Power electronics + digital design integration  

---

## ⚙️ System Architecture
RISC-V CPU → Registers → PWM Generator → Gate Driver → BLDC Motor
↑
Hall Sensors / BEMF Feedback
↓
Protection Module


---

## 🧠 Key Features

### 🔹 Control Modes

- Hall-based commutation (6-step)
- Sensorless mode using zero-cross detection

### 🔹 PWM Generation

- 6 PWM outputs (UH, UL, VH, VL, WH, WL)
- 12-bit resolution
- Complementary switching
- Deadtime insertion (~80ns)

### 🔹 Protection

- ⚠️ Overcurrent Protection (OCP)
- ⚠️ Undervoltage Lockout (UVLO)
- Automatic PWM shutdown on fault

### 🔹 CPU Control

- Memory-mapped register interface
- Real-time control using RISC-V firmware

---

## ⚡ Hardware Setup

### 🔧 Components Used

- FPGA: Xilinx PYNQ-Z2
- Gate Driver: IR2101
- Power Stage: 3-phase MOSFET inverter
- Inputs:
  - Hall sensors OR
  - BEMF comparator
- Supply: 12V motor drive

---

## 📁 Project Structure

rtl/ → Verilog design files
tb/ → Testbenches
firmware/ → RISC-V C program
sim/ → Simulation outputs
constraints/ → XDC pin mapping
docs/ → Schematics


---

## 🧩 RTL Design Overview

The hardware design is divided into modular blocks:

- **bldc_top.v** → Top-level controller
- **pwm_six_step.v** → PWM generation
- **hall_to_sector.v** → Hall decoding
- **zcd_logic.v** → Sensorless detection
- **comm_timer.v** → Timing calculation
- **sensorless_sector.v** → Sector generation
- **protection_module.v** → Fault handling
- **bldc_peripheral.v** → CPU interface

---

## 💻 RISC-V Firmware Control

The CPU interacts with hardware using **memory-mapped registers**.

### 📍 Register Map

| Address       | Function        |
|--------------|----------------|
| 0x40000000   | Duty Cycle     |
| 0x40000004   | Enable         |
| 0x40000008   | Mode Select    |
| 0x40000010   | Current Sense  |
| 0x40000014   | Voltage Sense  |


## ⚙️ Build & Run Instructions

### 🟢 1. Compile Firmware (C → HEX)

```bash
~/xpack-riscv-none-elf-gcc-12.3.0-1/bin/riscv-none-elf-gcc \
-march=rv32i \
-mabi=ilp32 \
-Os -ffreestanding -nostdlib \
-Wl,-Ttext=0x0 \
-o firmware.elf bldc_firmware.c

🟢 2. Convert ELF → HEX (for FPGA)
~/xpack-riscv-none-elf-gcc-12.3.0-1/bin/riscv-none-elf-objcopy \
-O verilog \
--verilog-data-width=4 \
firmware.elf program.hex

### 🟢 3. Run Simulation (Icarus Verilog)

iverilog -g2012 -o soc_bldc_sim \
picorv32.v ram.v bldc_top.v protection_module.v pwm_six_step.v \
hall_to_sector.v hall_debounce.v zcd_logic.v comm_timer.v \
sensorless_sector.v bldc_peripheral.v soc_bldc_top.v tb_soc_bldc1.v

vvp soc_bldc_sim 2>&1 | tee sim_output.txt

gtkwave soc_bldc.vcd

## 📌 Summary

This project presents a complete implementation of a **BLDC motor controller on FPGA** using a **PicoRV32 RISC-V processor**.

The system integrates:
- Real-time PWM generation in hardware  
- Dual commutation modes (Hall and sensorless)  
- Memory-mapped CPU control interface  
- Hardware-based protection mechanisms  

Time-critical operations such as commutation, deadtime insertion, and fault handling are implemented in RTL, while high-level control is managed through RISC-V firmware.

The design is fully verified through simulation and successfully deployable on FPGA with a custom-built power stage using IR2101 gate drivers and MOSFET half-bridges.

This project demonstrates a complete **hardware-software co-design approach** combining:
- FPGA-based control systems  
- Embedded RISC-V processing  
- Power electronics integration  
- End-to-end system validation  
