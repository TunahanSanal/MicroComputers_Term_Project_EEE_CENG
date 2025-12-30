"""
Base Connection Class for Home Automation System
"""
from abc import ABC, abstractmethod
import serial
import time

class HomeAutomationSystemConnection(ABC):
    def __init__(self, com_port: str, baud_rate: int = 9600):
        self.com_port = com_port
        self.baud_rate = baud_rate
        self.serial_connection = None
        self.is_connected = False
    
    def open(self) -> bool:
        try:
            if self.serial_connection is not None and self.serial_connection.is_open:
                self.close()
            
            self.serial_connection = serial.Serial(
                port=self.com_port,
                baudrate=self.baud_rate,
                timeout=4.0,  # <-- 4 saniye timeout (Simülasyon yavaş olduğu için)
                write_timeout=2.0
            )
            
            # PIC başlangıç gürültüsü için UZUN bekleme
            time.sleep(5) 
            self.serial_connection.reset_input_buffer()
            self.serial_connection.reset_output_buffer()
            
            self.is_connected = True
            print(f"Bağlantı başarılı: {self.com_port}")
            return True
            
        except Exception as e:
            print(f"Bağlantı Hatası ({self.com_port}): {e}")
            self.is_connected = False
            return False
    
    def close(self) -> None:
        try:
            if self.serial_connection and self.serial_connection.is_open:
                self.serial_connection.close()
                print(f"Bağlantı kapatıldı: {self.com_port}")
        except Exception as e:
            print(f"Kapatma hatası: {e}")
        finally:
            self.serial_connection = None
            self.is_connected = False
    
    @abstractmethod
    def update(self) -> bool:
        pass