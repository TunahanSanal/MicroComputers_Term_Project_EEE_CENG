# Kurulum Rehberi (Installation Guide)

## Gereksinimler (Requirements)

- Python 3.7 veya üzeri
- Windows, Linux veya macOS işletim sistemi
- USB-to-Serial dönüştürücü (PIC16F877A mikrodenetleyicileri için)

## Hızlı Kurulum

### Windows için:

1. `install.bat` dosyasını çift tıklayarak çalıştırın
   VEYA
   Komut satırında:
   ```cmd
   pip install -r requirements.txt
   ```

### Linux/Mac için:

1. Terminal'de şu komutu çalıştırın:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```
   VEYA
   ```bash
   pip3 install -r requirements.txt
   ```

## Manuel Kurulum

1. Python'un yüklü olduğundan emin olun:
   ```bash
   python --version
   ```

2. pip'i güncelleyin:
   ```bash
   python -m pip install --upgrade pip
   ```

3. Bağımlılıkları yükleyin:
   ```bash
   pip install -r requirements.txt
   ```

## Bağımlılıklar (Dependencies)

- **pyserial**: Seri port iletişimi için
- **customtkinter**: Modern GUI arayüzü için

## Uygulamayı Çalıştırma

```bash
python main.py
```

## Sorun Giderme

### "ModuleNotFoundError" hatası alıyorsanız:
- Tüm bağımlılıkların yüklü olduğundan emin olun
- Virtual environment kullanıyorsanız, aktif olduğundan emin olun

### COM port bulunamıyorsa:
- Cihaz Yöneticisi'nde (Windows) veya `ls /dev/tty*` (Linux) ile seri portları kontrol edin
- USB-to-Serial sürücülerinin yüklü olduğundan emin olun

### GUI açılmıyorsa:
- CustomTkinter'ın doğru yüklendiğinden emin olun:
  ```bash
  pip show customtkinter
  ```

## Notlar

- İlk çalıştırmada bağımlılıklar otomatik olarak yüklenir
- Windows'ta yönetici yetkisi gerekebilir (COM port erişimi için)
- Linux'ta kullanıcınızın `dialout` grubuna eklenmesi gerekebilir:
  ```bash
  sudo usermod -a -G dialout $USER
  ```

