import time
import sys
import os

# Python'ın 'api' klasörünü bulabilmesi için yol ayarı
# Bu dosya 'EvOtomasyon' ana klasöründe durmalıdır.
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from api.curtain_control import CurtainControlSystemConnection

def main():
    print("==========================================")
    print("   PERDE KONTROL SİSTEMİ - KONSOL TESTİ   ")
    print("==========================================")

    # 1. BAĞLANTI AYARLARI
    # PICSimLab COM1 kullanıyorsa buraya COM2 yazın (Virtual Serial Port Pair)
    PORT = "COM2" 
    BAUD = 9600

    print(f"[{PORT}] Portuna bağlanılıyor...")
    curtain_sys = CurtainControlSystemConnection(com_port=PORT, baud_rate=BAUD)

    if curtain_sys.open():
        print("✅ BAĞLANTI BAŞARILI!")
    else:
        print("❌ BAĞLANTI BAŞARISIZ!")
        print(f"Lütfen {PORT} portunun açık ve başka program tarafından kullanılmadığından emin olun.")
        return

    try:
        # --- AŞAMA 1: SENSÖR OKUMA TESTİ (5 Saniye) ---
        print("\n--- AŞAMA 1: SENSÖR VERİLERİ OKUNUYOR (5 sn) ---")
        print("Lütfen PICSimLab üzerinde Potansiyometre veya LDR ile oynayın.")
        
        for i in range(5):
            curtain_sys.update()
            
            temp = curtain_sys.getOutdoorTemp()
            light = curtain_sys.getLightIntensity()
            status = curtain_sys.curtainStatus
            mode = "PC KONTROL" if curtain_sys.isPCControlMode() else "OTOMATİK"
            
            print(f"[{i+1}/5] Mod: {mode} | Işık: {light} | Sıcaklık: {temp}°C | Perde: %{status}")
            time.sleep(1)

        # --- AŞAMA 2: PC KONTROL MODUNA GEÇİŞ (MANUEL) ---
        print("\n--- AŞAMA 2: PC KONTROL MODU TESTİ ---")
        target_val = 50.0
        print(f"Komut Gönderiliyor: Perdeyi %{target_val} yap ('C' komutu)...")
        
        if curtain_sys.setCurtainStatus(target_val):
            print("✅ Komut gönderildi.")
        else:
            print("❌ Komut gönderilemedi.")

        print("Sonucun yansıması için bekleniyor...")
        for i in range(4):
            curtain_sys.update()
            print(f"   -> Güncel Durum: %{curtain_sys.curtainStatus} (Mod: {curtain_sys.isPCControlMode()})")
            time.sleep(1)

        # --- AŞAMA 3: OTOMATİK MODA DÖNÜŞ (RELEASE) ---
        print("\n--- AŞAMA 3: OTOMATİK MODA DÖNÜŞ TESTİ ---")
        print("Kontrol bırakılıyor ('A' komutu)... LDR sensörü tekrar aktif olmalı.")
        
        if curtain_sys.releaseControl():
            print("✅ Otomatik mod komutu gönderildi.")
        else:
            print("❌ Hata oluştu.")

        print("Sensörlerin tekrar devreye girmesi izleniyor...")
        for i in range(5):
            curtain_sys.update()
            light = curtain_sys.getLightIntensity()
            status = curtain_sys.curtainStatus
            print(f"   -> Işık: {light} | Perde: %{status} (Mod: {curtain_sys.isPCControlMode()})")
            time.sleep(1)

    except KeyboardInterrupt:
        print("\nTest kullanıcı tarafından durduruldu.")
    
    finally:
        curtain_sys.close()
        print("\nBağlantı kapatıldı. Test Bitti.")

if __name__ == "__main__":
    main()