# Nurefşan Ceren Doğan - 152120211102

import time
import re
import serial
from .base_connection import HomeAutomationSystemConnection 

class CurtainControlSystemConnection(HomeAutomationSystemConnection):
    def __init__(self, com_port: str, baud_rate: int = 9600):
        super().__init__(com_port, baud_rate)
        
        # Sensör Verileri
        self.curtainStatus = 0.0
        self.outdoorTemperature = 0.0
        self.outdoorPressure = 0.0
        self.lightIntensity = 0.0
        
        # Mock modu (Test için)
        self.MOCK_MODE = False
        
        # Kontrol Modu (True = PC kontrolü, False = Otomatik/Sensör modu)
        self.pc_control_mode = False

    def update(self) -> bool:
        """
        Sensörlerden gelen verileri okur (Sıcaklık, Işık vb.)
        """
        if not self.is_connected:
            return False

        try:
            if self.serial_connection.in_waiting > 0:
                while self.serial_connection.in_waiting > 0:
                    try:
                        line = self.serial_connection.readline().decode('ascii', errors='ignore').strip()
                        if line:
                            self._parse_data(line)
                    except:
                        pass
            return True
        except Exception as e:
            return False

    def _parse_data(self, data_str):
        """
        Gelen Veriyi Ayrıştırır: T:040 B:1037 L:006 P:100
        """
        try:
            m_temp = re.search(r'T:(\d{3})', data_str)
            if m_temp: self.outdoorTemperature = float(m_temp.group(1))

            m_press = re.search(r'B:(\d{4})', data_str)
            if m_press: self.outdoorPressure = float(m_press.group(1))

            m_light = re.search(r'L:(\d{3})', data_str)
            if m_light: self.lightIntensity = float(m_light.group(1))

            m_curt = re.search(r'P:(\d{3})', data_str)
            if m_curt:
                self.curtainStatus = float(m_curt.group(1))
        except:
            pass

    def setCurtainStatus(self, percentage: float) -> bool:
        """
        PROJE FÖYÜ GEREĞİ:
        PC'den perde değeri ayarlanır. Sistem PC KONTROL MODUNA geçer.
        Potansiyometre ve LDR sensörleri DEVRE DIŞI kalır.
        İsterlere göre: [R2.2.6-1] UART üzerinden set komutu
        """
        if self.MOCK_MODE:
            self.curtainStatus = percentage
            return True

        if not self.is_connected or not self.serial_connection:
            return False

        try:
            # 1. Değeri hazırla (0-100 arası - Proje Föyü: [R2.2.1-1])
            val_int = int(percentage)
            if val_int > 100: val_int = 100
            if val_int < 0: val_int = 0
            
            # 2. Hattı temizle
            self.serial_connection.reset_input_buffer()
            
            # 3. PC KONTROL MODUNU AÇ ('C' komutu)
            # Bu komut Arduino'ya "artık potansiyometre dinleme" der
            self.serial_connection.write(b'C')
            time.sleep(0.1)
            
            # 4. Hedef Değeri Gönder (0-100 arası byte olarak)
            self.serial_connection.write(bytes([val_int]))
            print(f"[Curtain PC Control] Perde Ayarlandı: %{val_int}")
            
            # 5. PC kontrol modunu işaretle
            self.pc_control_mode = True
            
            # ÖNEMLİ: 'A' komutu GÖNDERİLMEZ!
            # Sistem PC kontrolünde kalır, potansiyometre pasif!
            
            self.curtainStatus = percentage
            return True
            
        except Exception as e:
            print(f"Curtain Set Hatası: {e}")
            return False

    def releaseControl(self) -> bool:
        """
        PROJE FÖYÜ GEREĞİ:
        PC kontrolünü bırakır, sistemi OTOMATİK MODA döndürür.
        [R2.2.2-2]: LDR sensörü tekrar aktif olur
        [R2.2.4-1]: Potansiyometre tekrar aktif olur
        
        PIC16F877A için özel çözüm:
        1. Buffer temizle
        2. 'A' komutu gönder (Otomatik mod)
        3. PIC'in sensörleri okuması için yeterli bekle
        4. Input buffer'ı tekrar temizle (PIC'in cevapları için)
        """
        if not self.is_connected or not self.serial_connection:
            return False
        
        try:
            # 1. Önce hattı tamamen temizle
            self.serial_connection.reset_input_buffer()
            self.serial_connection.reset_output_buffer()
            time.sleep(0.05)
            
            # 2. 'A' = Automatic Mode komutu gönder
            self.serial_connection.write(b'A')
            time.sleep(0.1)
            
            # 3. PIC'e sensörleri okuması için ekstra süre ver
            # PIC ADC okuma + işleme zamanı
            time.sleep(0.3)
            
            # 4. Gelen veriyi temizle (PIC sensör verisi gönderebilir)
            self.serial_connection.reset_input_buffer()
            
            self.pc_control_mode = False
            print("[Curtain] ✅ Otomatik Mod Aktif - PIC sensörleri okuyor (LDR + Potansiyometre)")
            print("[Curtain] 💡 Potansiyometreyi ÇEVİR veya IŞIĞI DEĞİŞTİR - PIC algılayacak!")
            return True
            
        except Exception as e:
            print(f"Release Control Hatası: {e}")
            return False

    # Getterlar
    def getOutdoorTemp(self) -> float: return self.outdoorTemperature
    def getOutdoorPress(self) -> float: return self.outdoorPressure
    def getLightIntensity(self) -> float: return self.lightIntensity

    def isPCControlMode(self) -> bool: return self.pc_control_mode
