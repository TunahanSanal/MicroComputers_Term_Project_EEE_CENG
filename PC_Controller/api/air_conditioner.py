"""
Air Conditioner System Connection
Handles UART communication with Board #1 (Air Conditioner Control)
PROJE FÖYÜ: [R2.1.4-1] UART Protokolü ile Sıcaklık Kontrolü
"""

from .base_connection import HomeAutomationSystemConnection
import time

class AirConditionerSystemConnection(HomeAutomationSystemConnection):
    """
    Connection class for Air Conditioner System (Board #1).
    Manages desired temperature, ambient temperature, and fan speed.
    """
    
    def __init__(self, com_port: str, baud_rate: int = 9600):
        super().__init__(com_port, baud_rate)
        self.desired_temp = 0.0
        self.ambient_temp = 0.0
        self.fan_speed = 0
        
        # Hata sayaçları (Stability için)
        self.read_error_count = 0
        self.max_errors = 3
    
    def _send_command_get_float(self, command_byte, debug_name="", timeout=1.0):
        """
        Yardımcı Fonksiyon: Komut gönderip cevabı bekler.
        GELİŞTİRİLMİŞ: Timeout ve hata kontrolü eklendi
        """
        if not self.is_connected or not self.serial_connection:
            return None
        
        try:
            # 1. Buffer'ı temizle
            self.serial_connection.reset_input_buffer()
            
            # 2. Komutu Gönder
            self.serial_connection.write(command_byte)
            
            # 3. BEKLEME (Simülasyon için yeterli süre)
            start_time = time.time()
            while (time.time() - start_time) < timeout:
                if self.serial_connection.in_waiting > 0:
                    break
                time.sleep(0.05)
            
            # 4. Cevabı Oku
            if self.serial_connection.in_waiting > 0:
                raw_data = self.serial_connection.read_until(b'\r')
                line = raw_data.decode('utf-8', errors='ignore').strip()
                
                if line and line.replace('.', '').replace('-', '').isdigit():
                    value = float(line)
                    # Makul aralık kontrolü
                    if -50 <= value <= 200:  # Geniş ama mantıklı aralık
                        return value
                    else:
                        print(f"[{debug_name}] Aralık dışı değer: {value}")
                        return None
                else:
                    print(f"[{debug_name}] Geçersiz veri: {line}")
                    return None
            else:
                print(f"[{debug_name}] Timeout - veri gelmedi")
                return None
                
        except Exception as e:
            print(f"[{debug_name}] Hata: {e}")
            return None
    
    def get_desired_temp_internal(self):
        """İstenen sıcaklığı parça parça okur - PROJE FÖYÜ [R2.1.4-1]"""
        if not self.serial_connection: 
            return 0.0
        
        try:
            # Tam kısım oku (komut '2')
            int_part = self._send_command_get_float(b'2', "Des.Temp.Int", timeout=0.5)
            if int_part is None:
                return self.desired_temp  # Son bilinen değeri döndür
            
            time.sleep(0.05)
            
            # Ondalık kısım oku (komut '1')
            frac_part = self._send_command_get_float(b'1', "Des.Temp.Frac", timeout=0.5)
            if frac_part is None:
                frac_part = 0.0
            
            # Birleştir
            temp = int_part + (frac_part / 10.0)
            
            # Mantık kontrolü
            if 10.0 <= temp <= 50.0:
                self.desired_temp = temp
                self.read_error_count = 0  # Başarılı okuma, hata sayacını sıfırla
            else:
                print(f"[AC] Desired Temp aralık dışı: {temp}")
                self.read_error_count += 1
            
            return self.desired_temp
            
        except Exception as e:
            print(f"[AC] Desired Temp okuma hatası: {e}")
            self.read_error_count += 1
            return self.desired_temp
    
    def get_ambient_temp_internal(self):
        """Ortam sıcaklığını parça parça okur - PROJE FÖYÜ [R2.1.4-1]"""
        if not self.serial_connection: 
            return 0.0
        
        try:
            # Tam kısım oku (komut '4')
            int_part = self._send_command_get_float(b'4', "Amb.Temp.Int", timeout=0.5)
            if int_part is None:
                return self.ambient_temp
            
            time.sleep(0.05)
            
            # Ondalık kısım oku (komut '3')
            frac_part = self._send_command_get_float(b'3', "Amb.Temp.Frac", timeout=0.5)
            if frac_part is None:
                frac_part = 0.0
            
            # Birleştir
            temp = int_part + (frac_part / 10.0)
            
            # Mantık kontrolü (ortam sıcaklığı)
            if 0.0 <= temp <= 60.0:
                self.ambient_temp = temp
                self.read_error_count = 0
            else:
                print(f"[AC] Ambient Temp aralık dışı: {temp}")
                self.read_error_count += 1
            
            return self.ambient_temp
            
        except Exception as e:
            print(f"[AC] Ambient Temp okuma hatası: {e}")
            self.read_error_count += 1
            return self.ambient_temp
    
    def get_fan_speed_internal(self):
        """Fan hızını okur - PROJE FÖYÜ [R2.1.4-1]"""
        if not self.serial_connection: 
            return 0
        
        try:
            # Fan hızı oku (komut '5')
            speed = self._send_command_get_float(b'5', "Fan.Speed", timeout=0.5)
            
            if speed is None:
                return self.fan_speed
            
            # Mantık kontrolü (RPS)
            if 0 <= speed <= 100:  # Makul RPS aralığı
                self.fan_speed = int(speed)
                self.read_error_count = 0
            else:
                print(f"[AC] Fan Speed aralık dışı: {speed}")
                self.read_error_count += 1
            
            return self.fan_speed
            
        except Exception as e:
            print(f"[AC] Fan Speed okuma hatası: {e}")
            self.read_error_count += 1
            return self.fan_speed
    
    def update(self) -> bool:
        """
        Tüm verileri güncelle - PROJE FÖYÜ [R2.1.4-1]
        GELİŞTİRİLMİŞ: Hata toleransı eklendi
        """
        if not self.is_connected: 
            return False
        
        # Çok fazla hata varsa bağlantıyı kes
        if self.read_error_count >= self.max_errors:
            print(f"[AC] Çok fazla okuma hatası ({self.read_error_count}), güncelleme iptal edildi")
            self.read_error_count = 0  # Sıfırla, bir sonraki denemede tekrar dene
            return False
        
        try:
            # Sırayla oku (her birinin kendi timeout'u var)
            self.get_desired_temp_internal()
            time.sleep(0.1)
            
            self.get_ambient_temp_internal()
            time.sleep(0.1)
            
            self.get_fan_speed_internal()
            
            return True
            
        except Exception as e:
            print(f"[AC] Update genel hatası: {e}")
            self.read_error_count += 1
            return False
    
    def set_desired_temperature(self, temperature: float) -> bool:
        """
        Sıcaklık Ayarla - PROJE FÖYÜ [R2.1.4-1]
        Binary maskeleme ile komut gönderimi
        """
        if not self.is_connected or not self.serial_connection: 
            return False
        
        # Aralık kontrolü
        if not (10.0 <= temperature <= 50.0):
            print(f"[AC] Hata: Sıcaklık 10-50 arasında olmalı. Girilen: {temperature}")
            return False
        
        try:
            # Tam ve ondalık kısımları ayır
            val_int = int(temperature)
            val_frac = int(round((temperature - val_int) * 10))
            
            # Binary Maskeleme (Proje Föyü protokolü)
            cmd_int = 0xC0 | (val_int & 0x3F)   # 11xxxxxx (Tam kısım)
            cmd_frac = 0x80 | (val_frac & 0x3F) # 10xxxxxx (Ondalık kısım)
            
            # Buffer temizle
            self.serial_connection.reset_input_buffer()
            self.serial_connection.reset_output_buffer()
            
            # Gönder
            self.serial_connection.write(bytes([cmd_int]))
            time.sleep(0.15)
            self.serial_connection.write(bytes([cmd_frac]))
            time.sleep(0.15)
            
            # Başarılı
            self.desired_temp = temperature
            print(f"[AC] ✅ Sıcaklık ayarlandı: {temperature}°C")
            return True
            
        except Exception as e:
            print(f"[AC] Set Sıcaklık Hatası: {e}")
            return False