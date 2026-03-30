# Constraints

## Overview
This directory contains FPGA constraint files used to map logical signals to physical pins.

---

## Purpose

The constraint file defines:
- Clock input configuration
- GPIO pin assignments
- PWM output mapping
- Input signal connections
- Reset and status indicators

---

## Key Configurations

- Clock: 50 MHz input
- PWM outputs mapped to GPIO pins
- Hall/BEMF inputs connected to FPGA inputs
- LEDs used for status/debug

---

## Notes

- Correct pin mapping is critical for hardware operation
- Timing constraints ensure stable operation at target frequency
