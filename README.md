🏠 Home Automation System Project (ESOGU 2025-2026 Fall)

​This project aims to develop a home automation system that controls various sensors and drivers (temperature control, curtain management, and environment monitoring) using PIC16F877A microcontrollers. The system allows users to manage and monitor these operations via a personal computer.  

​📖 Project Overview
​The system is divided into two main architectural parts:

​Hardware Layer: Programs managing peripherals connected to two PIC16F877A microcontrollers within the PICSimLab environment.  
​
Software Layer: A PC application and an Application Programming Interface (API) that communicate with the microcontrollers via a serial (UART) interface.  

​🛠 Hardware Architecture & Components
​The system utilizes two separate boards, each managing specific home automation tasks:  
​
Board #1: Home Air Conditioner System

​Temperature Control Module: Manages a heating resistor, an LM35 temperature sensor, and a cooling fan with an infrared tachometer.  

​Keypad: A matrix keyboard used to enter the desired temperature value (triggered by pressing 'A').  

​7-Segment Display: Multiplexed display used to show desired temperature, ambient temperature, and fan speed at 2-second intervals.  

​UART: Handles serial requests to get or set temperature and fan data.  
​
Board #2: Curtain Control System
​
Step Motor: Controls curtain openness; 5 full turns (1000 steps) represent the range from fully open (0%) to fully closed (100%).  

​LDR Light Sensor: Measures room light intensity and automatically closes curtains (100%) if intensity falls below a threshold.  

​BMP180 Sensor: Measures outdoor temperature and air pressure.  
​Rotary Potentiometer: Acts as a manual switch to adjust curtain status linearly between 0% and 100%.  

​LCD (hd44780): A 2-line, 16-column display showing outdoor temperature, pressure, light intensity, and current curtain status.  

​💻 Software Architecture
​The software follows a modular structure to facilitate team collaboration:  

​1. Microcontroller Firmware (Assembly)
​All code running on the PIC16F877A must be written in Assembly language.  
​Each source file includes the name of the assigned developer and explanatory comments.  

​2. PC Side API (High-Level Language)
​The API provides high-level functions (developed in C/C++, Python, etc.) to encapsulate serial communication:  
​HomeAutomationSystemConnection: Manages port and baud rate settings.  
​AirConditionerSystemConnection: Handles ambient/desired temperature and fan speed data.  
​CurtainControlSystemConnection: Manages curtain status, outdoor weather data, and light intensity.  

​3. PC Application
​A console or GUI-based program that uses the API to provide a user menu. Users can:  
​Monitor real-time home data (ambient temperature, fan speed, etc.).  
​Set the desired home temperature.  
​Adjust the curtain openness ratio. 

Project Group Members: 

151220212123, Yiğit DOMBAYLI, EEE
152120211092, Canan MUTLU, CENG 
151220222120, Tunahan ŞANAL, EEE 
152120211102, Nurefşan Ceren DOĞAN, CENG 
151220192079, Yusuf İNAN, EEE 
152120211089, Efe Duhan ALPAY, CENG
