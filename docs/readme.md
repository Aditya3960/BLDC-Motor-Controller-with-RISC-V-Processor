# Documentation

## Overview
This directory contains hardware design documentation and supporting materials.

---

## Hardware Description

The BLDC motor driver consists of:

- 3-phase inverter using MOSFET half-bridges
- IR2101 gate drivers for high-side and low-side switching
- Bootstrap capacitors for high-side drive
- Current and voltage sensing circuits

---

## System Integration

- FPGA generates PWM signals (3.3V)
- IR2101 converts signals to gate drive levels (~12V)
- MOSFET inverter drives the motor phases
- Feedback signals are sent back to FPGA

---

## Included Documents

- Circuit schematics
- Driver design
- System-level diagrams

---

## Notes

- Proper deadtime is required to prevent shoot-through
- Gate driver design is critical for reliable switching
