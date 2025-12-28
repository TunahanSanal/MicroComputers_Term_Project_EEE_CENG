# 🏠 Home Automation System
A comprehensive microcontroller-based home automation project developed using PIC16F877A, featuring intelligent temperature control and automated curtain management.

# 📋 Project Overview
This project implements a dual-board home automation system that manages:
Board #1: Air conditioning system with temperature control
Board #2: Automated curtain control based on light intensity
The system operates in both autonomous and manual modes, providing flexible control through a Python-based API interface.

# 👥 Team Members
151220212123
Yiğit DOMBAYLI
Electrical & Electronics Engineering
152120211092
Canan MUTLU
Computer Engineering
151220222120
Tunahan ŞANAL
Electrical & Electronics Engineering
152120211102
Nurefşan Ceren DOĞAN
Computer Engineering
151220192079
Yusuf İNAN
Electrical & Electronics Engineering
152120211089
Efe Duhan ALPAY
Computer Engineering

Institution: T.R. Eskişehir Osmangazi University
Course: Introduction to Microcomputers

Date: December 2025

# 🎯 Features
Board #1 - Air Conditioner System
Temperature Monitoring: Real-time ambient temperature reading via LM35 sensor
Automatic Climate Control: Intelligent heating/cooling based on desired temperature
User Interface: 4x4 keypad for manual temperature input (10.0°C - 50.0°C range)
Display: 4-digit 7-segment display showing temperature and fan speed
Serial Communication: UART interface (9600 baud) via COM9-COM10
Board #2 - Curtain Control System
Light-Based Automation: LDR sensor for ambient light detection
Stepper Motor Control: Precise curtain positioning (0-100%, 1000 steps)
Environmental Monitoring: BMP180 sensor for temperature and pressure
LCD Display: 2x16 character display showing real-time data
Software I2C: Bit-banging protocol implementation in Assembly
Serial Communication: UART interface (9600 baud) via COM6-COM7
Python API Interface
Dual Operating Modes:
Autonomous: Sensor-driven decisions
Manual: Direct user control via GUI
Real-time Monitoring: Live data synchronization with microcontrollers
User-Friendly GUI: Intuitive interface for system management

# 🛠️ Technical Stack
Hardware
Microcontroller: PIC16F877A
Sensors: LM35 (temperature), LDR (light), BMP180 (pressure/temperature)
Actuators: Heater, Cooler/Fan, Stepper Motor (ULN2003 driver)
Input: 4x4 Matrix Keypad
Display: 7-Segment (4-digit), LCD (2x16)

Software
Simulation: PICSimLab v0.9.2_241005_win64
Development:
Board #1: C language (MPLAB X IDE v5.35)
Board #2: Assembly language (MPLAB X IDE v6.25)
API: Python 3.14.2
Virtual Serial Ports: com0com (null-modem emulator)

# 📦 Installation & Setup Prerequisites
Required Software
- PICSimLab 0.9.2 (241005 Win64)
- Python 3.14.2
- com0com (virtual serial port driver)
- MPLAB X IDE v5.35 and v6.25

Python Dependencies
pip install -r requirements.txt

Serial Port Configuration
Configure virtual port pairs using com0com:
Board #1: COM9 ↔ COM10
Board #2: COM6 ↔ COM7

Running the Project
Load the .hex files into PICSimLab for both boards
Ensure virtual serial ports are active

Run the Python API:
python api_interface.py

# 📊 System Architecture
Pin Configuration
Board #1 (PIC16F877A)
RA0: LM35 Temperature Sensor (Analog)
RA1-RA3: 7-Segment Display Digit Selection
RB0-RB7: 4x4 Keypad (Matrix)
RC2: Cooler/Fan Control
RC5: Heater Control
RC6/RC7: UART (TX/RX)
RD0-RD7: 7-Segment Data
Board #2 (PIC16F877A)
RA0: LDR Sensor (Analog)
RA1: Potentiometer (Analog)
RB0-RB3: Stepper Motor Control
RC3/RC4: I2C (SCL/SDA) - Software Implementation
RC6/RC7: UART (TX/RX)
RD0-RD7: LCD Data
RE0-RE1: LCD Control

# ⚠️ Important Notes
Version Compatibility: Strictly use specified software versions to avoid communication errors
BMP180 Limitation: Operates at 5V (overload condition) due to simulation constraints
I2C Implementation: Software bit-banging required for Assembly compatibility
Demonstration Video: Included in project archive for setup guidance

# 🚀 Future Enhancements
PID control algorithm implementation
ESP8266 integration for IoT connectivity
Cloud-based monitoring platform
Mobile application support

# 📄 License
This project is developed as an academic assignment for Eskişehir Osmangazi University.

# 📧 Contact
For questions or support, please contact the team members through university channels.
Course: Introduction to Microcomputers
Department: Electrical-Electronics & Computer Engineering
University: T.R. Eskişehir Osmangazi University
