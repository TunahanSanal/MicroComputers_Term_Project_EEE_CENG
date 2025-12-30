#!/bin/bash

echo "Installing Home Automation System Dependencies..."
echo ""

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed!"
    echo "Please install Python 3.7 or higher"
    exit 1
fi

echo "Python version:"
python3 --version
echo ""

# Upgrade pip
echo "Upgrading pip..."
python3 -m pip install --upgrade pip

echo ""
echo "Installing required packages..."
python3 -m pip install -r requirements.txt

if [ $? -ne 0 ]; then
    echo ""
    echo "ERROR: Installation failed!"
    exit 1
fi

echo ""
echo "Installation completed successfully!"
echo ""
echo "You can now run the application with: python3 main.py"
echo ""

