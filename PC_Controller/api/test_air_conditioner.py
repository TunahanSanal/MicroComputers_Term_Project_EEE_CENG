
# Canan MUTLU -152120211092



import time
import sys
import os


sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from api.air_conditioner import AirConditionerSystemConnection

def main():
    print("==============================================")
    print("   KLİMA (AC) SİSTEMİ - KONSOL TESTİ          ")
    print("==============================================")

    
    PORT = "COM10"  
    BAUD = 9600

    print(f"[{PORT}] Portuna bağlanılıyor...")
    ac_sys = AirConditionerSystemConnection(com_port=PORT, baud_rate=BAUD)

    if ac_sys.open():
        print("✅ BAĞLANTI BAŞARILI!")
    else:
        print("❌ BAĞLANTI BAŞARISIZ!")
        print(f"Lütfen {PORT} portunun açık ve doğru olduğundan emin olun.")
        return

    try:
        # --- AŞAMA 1: SENSÖR OKUMA TESTİ (5 Saniye) ---
        print("\n--- AŞAMA 1: MEVCUT VERİLER OKUNUYOR (5 sn) ---")
        print("PICSimLab üzerinden sıcaklığı (LM35) değiştirip gözlemleyin.")
        
        for i in range(5):
            success = ac_sys.update()
            
            if success:
                amb = ac_sys.ambient_temp
                des = ac_sys.desired_temp
                fan = ac_sys.fan_speed
                print(f"[{i+1}/5] Ortam: {amb:.1f}°C | Hedef: {des:.1f}°C | Fan: {fan} RPS")
            else:
                print(f"[{i+1}/5] ⚠️ Veri okunamadı (Timeout veya Hata)")
            
            time.sleep(1.5) # Okumalar arasında biraz bekle

        # --- AŞAMA 2: SICAKLIK AYARLAMA TESTİ ---
        print("\n--- AŞAMA 2: HEDEF SICAKLIK GÖNDERME TESTİ ---")
        target_val = 26.5
        print(f"Komut Gönderiliyor: Hedef Sıcaklığı {target_val}°C yap...")
        
        if ac_sys.set_desired_temperature(target_val):
            print("✅ Komut başarıyla gönderildi.")
        else:
            print("❌ Komut gönderilemedi.")

        print("Sonucun PIC tarafından işlenmesi bekleniyor...")
        time.sleep(1)

        # --- AŞAMA 3: DOĞRULAMA (READ BACK) ---
        print("\n--- AŞAMA 3: DOĞRULAMA ---")
        print("PIC'ten gelen veri güncellendi mi kontrol ediliyor...")
        
        for i in range(4):
            ac_sys.update()
            amb = ac_sys.ambient_temp
            des = ac_sys.desired_temp
            fan = ac_sys.fan_speed
            
            match_status = "✅ EŞLEŞTİ" if abs(des - target_val) < 0.2 else "⏳ Bekleniyor..."
            
            print(f"   -> Okunan Hedef: {des:.1f}°C ({match_status}) | Ortam: {amb:.1f}°C")
            time.sleep(1.5)

    except KeyboardInterrupt:
        print("\nTest kullanıcı tarafından durduruldu.")
    
    except Exception as e:
        print(f"\nBeklenmeyen Hata: {e}")

    finally:
        ac_sys.close()
        print("\nBağlantı kapatıldı. Test Bitti.")

if __name__ == "__main__":
    main()