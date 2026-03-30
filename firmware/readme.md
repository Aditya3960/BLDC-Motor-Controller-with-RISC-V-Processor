# Firmware (RISC-V)

## Overview
This directory contains firmware executed on the PicoRV32 RISC-V processor.

The firmware provides high-level control of the BLDC motor while delegating time-critical operations to hardware.

---

## Role of Firmware

The CPU is responsible for:
- Setting PWM duty cycle
- Enabling/disabling motor operation
- Selecting control mode (Hall or sensorless)
- Monitoring system parameters (current and voltage)

---

## Control Mechanism

The system uses **memory-mapped I/O**, allowing direct communication between CPU and hardware.

### Register Map

| Address       | Function        |
|--------------|----------------|
| 0x40000000   | Duty Cycle     |
| 0x40000004   | Enable         |
| 0x40000008   | Mode Select    |
| 0x40000010   | Current Sense  |
| 0x40000014   | Voltage Sense  |

---

## Execution Flow

1. Initialize system
2. Set duty cycle
3. Enable motor
4. Select control mode
5. Continuously monitor system status

---

## Example
