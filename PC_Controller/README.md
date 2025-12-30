# Home Automation System

A Python-based home automation system that communicates with two PIC16F877A microcontrollers via UART for controlling air conditioning and curtain systems.

## Project Structure

```
EvOtomasyon/
├── requirements.txt           # Python dependencies
├── main.py                    # Entry point
├── api/                       # Backend: UART Communication
│   ├── __init__.py
│   ├── base_connection.py     # Abstract Base Class
│   ├── air_conditioner.py     # Board #1 Logic
│   └── curtain_control.py      # Board #2 Logic
└── gui/                       # Frontend: Modern UI
    ├── __init__.py
    └── main_window.py         # CustomTkinter Interface
```

## Installation

1. Install Python 3.7 or higher
2. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Usage

1. Connect your PIC16F877A microcontrollers to your computer via USB-to-Serial adapters
2. Note the COM port numbers assigned to each board (e.g., COM3, COM4)
3. Run the application:
   ```bash
   python main.py
   ```
4. In the sidebar:
   - Enter COM port for Board 1 (Air Conditioner)
   - Enter COM port for Board 2 (Curtain Control)
   - Set baudrate (default: 9600)
   - Click "CONNECT"
5. Use the tabs to monitor and control each system:
   - **Air Conditioner Tab**: View ambient/desired temperature and fan speed. Set desired temperature using the slider.
   - **Curtain Control Tab**: View outdoor temperature, pressure, light intensity, and curtain status. Set curtain position (0-100%) using the slider.

## Protocol Details

### Board #1 (Air Conditioner)

**GET Requests:**
- `0x01`: Desired Temperature (Fractional part)
- `0x02`: Desired Temperature (Integral part)
- `0x03`: Ambient Temperature (Fractional part)
- `0x04`: Ambient Temperature (Integral part)
- `0x05`: Fan Speed (RPS)

**SET Requests:**
- Send Integral: Byte `11xxxxxx` (0xC0 | value)
- Send Fractional: Byte `10xxxxxx` (0x80 | value)

### Board #2 (Curtain Control)

**GET Requests:**
- `0x01`: Curtain Status (Fractional), `0x02`: Curtain Status (Integral)
- `0x03`: Outdoor Temperature (Fractional), `0x04`: Outdoor Temperature (Integral)
- `0x05`: Outdoor Pressure (Fractional), `0x06`: Outdoor Pressure (Integral)
- `0x07`: Light Intensity (Fractional), `0x08`: Light Intensity (Integral)

**SET Requests:**
- Send Integral: Byte `11xxxxxx` (0xC0 | value)
- Send Fractional: Byte `10xxxxxx` (0x80 | value)

## Features

- Modern dark-themed UI using CustomTkinter
- Real-time data polling (updates every 1 second)
- Error handling for serial communication failures
- Separate tabs for each control system
- Slider controls for setting values
- Connection status indicator

## Error Handling

The application handles:
- Serial port connection failures
- Communication timeouts
- Invalid COM port numbers
- Disconnection during operation

Errors are displayed using message boxes and console output.

