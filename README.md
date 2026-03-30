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

### 🧪 Example Code

```c
*(volatile int*)0x40000000 = duty;
*(volatile int*)0x40000004 = 1;
*(volatile int*)0x40000008 = mode;

##⚙️ Build & Run Instructions
🟢 1. Compile Firmware (C → ELF)

~/xpack-riscv-none-elf-gcc-12.3.0-1/bin/riscv-none-elf-gcc \
-march=rv32i \
-mabi=ilp32 \
-Os -ffreestanding -nostdlib \
-Wl,-Ttext=0x0 \
-o firmware.elf bldc_firmware.c

##🟢2. Convert ELF → HEX (for FPGA)
~/xpack-riscv-none-elf-gcc-12.3.0-1/bin/riscv-none-elf-objcopy \
-O verilog \
--verilog-data-width=4 \
firmware.elf program.hex

##🟢 3. Run Simulation (Icarus Verilog)
iverilog -g2012 -o soc_bldc_sim \
picorv32.v ram.v bldc_top.v protection_module.v pwm_six_step.v \
hall_to_sector.v hall_debounce.v zcd_logic.v comm_timer.v \
sensorless_sector.v bldc_peripheral.v soc_bldc_top.v tb_soc_bldc1.v

vvp soc_bldc_sim 2>&1 | tee sim_output.txt

gtkwave soc_bldc.vcd

##🧪 Simulation Results

✔ Correct 6-step commutation
✔ PWM switching verified
✔ Deadtime insertion working
✔ Hall & sensorless modes validated
✔ Protection triggered under fault

##🛡️ Protection Behavior
Condition	Action Taken
Overcurrent	PWM Disabled
Undervoltage	System Shutdown

##📌 Summary

This project demonstrates a complete FPGA-based BLDC motor control system combining:

Real-time hardware control
RISC-V processor integration
Power electronics design
Full simulation and validation

