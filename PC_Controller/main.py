#Canan MUTLU-152120211092
"""
Home Automation System - Main Entry Point
Launches the GUI application for controlling PIC16F877A microcontrollers
"""

from gui.main_window import SmartHomeApp


def main():
    """Main entry point for the application."""
    app = SmartHomeApp()
    app.protocol("WM_DELETE_WINDOW", app.on_closing)
    app.mainloop()


if __name__ == "__main__":
    main()

