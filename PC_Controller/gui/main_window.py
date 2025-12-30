import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import customtkinter as ctk
import time
import threading

try:
    from customtkinter import CTkMessagebox
except ImportError:
    try:
        from customtkinter.messagebox import CTkMessagebox
    except ImportError:
        import tkinter.messagebox as tkmsg
        class CTkMessagebox:
            def __init__(self, title="", message="", icon="info"):
                if icon == "warning": tkmsg.showwarning(title, message)
                elif icon == "error": tkmsg.showerror(title, message)
                else: tkmsg.showinfo(title, message)

from api.air_conditioner import AirConditionerSystemConnection
from api.curtain_control import CurtainControlSystemConnection

class SmartHomeApp(ctk.CTk):
    def __init__(self):
        super().__init__()
        self.title("Home Automation System - ESOGU Term Project")
        self.geometry("900x700")
        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("blue")
        
        self.ac_connection = None
        self.curtain_connection = None
        
        self.ac_connected = False
        self.curtain_connected = False
        
        self.update_job = None
        
        self._create_sidebar()
        self._create_main_area()
    
    def _create_sidebar(self):
        sidebar = ctk.CTkFrame(self, width=250)
        sidebar.pack(side="left", fill="y", padx=10, pady=10)
        
        ctk.CTkLabel(sidebar, text="Connection Settings", font=ctk.CTkFont(size=20, weight="bold")).pack(pady=(20, 30))
        
        ctk.CTkLabel(sidebar, text="COM Port Board 1 (AC):").pack(pady=(10, 5))
        self.com1_entry = ctk.CTkEntry(sidebar, placeholder_text="COM10")
        self.com1_entry.pack(pady=5, padx=20, fill="x")
        
        ctk.CTkLabel(sidebar, text="COM Port Board 2 (Curtain):").pack(pady=(20, 5))
        self.com2_entry = ctk.CTkEntry(sidebar, placeholder_text="COM7")
        self.com2_entry.pack(pady=5, padx=20, fill="x")
        
        ctk.CTkLabel(sidebar, text="Baudrate:").pack(pady=(20, 5))
        self.baud_entry = ctk.CTkEntry(sidebar, placeholder_text="9600")
        self.baud_entry.insert(0, "9600")
        self.baud_entry.pack(pady=5, padx=20, fill="x")
        
        self.connect_button = ctk.CTkButton(sidebar, text="CONNECT", command=self._handle_connect, font=ctk.CTkFont(size=16, weight="bold"), height=40)
        self.connect_button.pack(pady=30, padx=20, fill="x")
        
        self.status_label = ctk.CTkLabel(sidebar, text="NO CONNECTION", text_color="red", font=ctk.CTkFont(size=14))
        self.status_label.pack(pady=10)
    
    def _create_main_area(self):
        main_frame = ctk.CTkFrame(self)
        main_frame.pack(side="right", fill="both", expand=True, padx=10, pady=10)
        self.tabview = ctk.CTkTabview(main_frame)
        self.tabview.pack(fill="both", expand=True, padx=10, pady=10)
        
        self.ac_tab = self.tabview.add("Air Conditioner")
        self._create_ac_tab()
        
        self.curtain_tab = self.tabview.add("Curtain Control")
        self._create_curtain_tab()
    
    def _create_ac_tab(self):
        ctk.CTkLabel(self.ac_tab, text="Air Conditioner System", font=ctk.CTkFont(size=24, weight="bold")).pack(pady=20)
        
        data_frame = ctk.CTkFrame(self.ac_tab)
        data_frame.pack(pady=20, padx=20, fill="x")
        
        ctk.CTkLabel(data_frame, text="Ambient Temperature:", font=ctk.CTkFont(size=16)).grid(row=0, column=0, padx=20, pady=15, sticky="w")
        self.ambient_temp_label = ctk.CTkLabel(data_frame, text="-- °C", font=ctk.CTkFont(size=18, weight="bold"), text_color="cyan")
        self.ambient_temp_label.grid(row=0, column=1, padx=20, pady=15, sticky="e")
        
        ctk.CTkLabel(data_frame, text="Desired Temperature:", font=ctk.CTkFont(size=16)).grid(row=1, column=0, padx=20, pady=15, sticky="w")
        self.desired_temp_label = ctk.CTkLabel(data_frame, text="-- °C", font=ctk.CTkFont(size=18, weight="bold"), text_color="cyan")
        self.desired_temp_label.grid(row=1, column=1, padx=20, pady=15, sticky="e")
        
        ctk.CTkLabel(data_frame, text="Fan Speed:", font=ctk.CTkFont(size=16)).grid(row=2, column=0, padx=20, pady=15, sticky="w")
        self.fan_speed_label = ctk.CTkLabel(data_frame, text="-- RPS", font=ctk.CTkFont(size=18, weight="bold"), text_color="cyan")
        self.fan_speed_label.grid(row=2, column=1, padx=20, pady=15, sticky="e")
        
        control_frame = ctk.CTkFrame(self.ac_tab)
        control_frame.pack(pady=30, padx=20, fill="x")
        ctk.CTkLabel(control_frame, text="PC Remote Control (via UART):", font=ctk.CTkFont(size=16, weight="bold")).pack(pady=(20, 10))
        
        self.temp_slider = ctk.CTkSlider(control_frame, from_=10, to=50, number_of_steps=400, command=self._on_temp_slider_change)
        self.temp_slider.set(25) 
        self.temp_slider.pack(pady=10, padx=40, fill="x")
        
        self.temp_value_label = ctk.CTkLabel(control_frame, text="25.0 °C", font=ctk.CTkFont(size=14))
        self.temp_value_label.pack(pady=5)
        
        self.set_temp_button = ctk.CTkButton(control_frame, text="SET THE TEMPERATURE (PC Control)", command=self._set_temperature, font=ctk.CTkFont(size=16), height=40)
        self.set_temp_button.pack(pady=20, padx=40, fill="x")

    def _create_curtain_tab(self):
        ctk.CTkLabel(self.curtain_tab, text="Curtain Control System", font=ctk.CTkFont(size=24, weight="bold")).pack(pady=10)
        
        # Sensör Verileri
        info_frame = ctk.CTkFrame(self.curtain_tab)
        info_frame.pack(pady=10, padx=20, fill="x")
        
        ctk.CTkLabel(info_frame, text="Outdoor Temp:").grid(row=0, column=0, padx=10, pady=10)
        self.out_temp_label = ctk.CTkLabel(info_frame, text="-- °C", text_color="yellow")
        self.out_temp_label.grid(row=0, column=1, padx=10, pady=10)
        
        ctk.CTkLabel(info_frame, text="Pressure:").grid(row=0, column=2, padx=10, pady=10)
        self.pressure_label = ctk.CTkLabel(info_frame, text="-- hPa", text_color="yellow")
        self.pressure_label.grid(row=0, column=3, padx=10, pady=10)
        
        ctk.CTkLabel(info_frame, text="Light (LDR):").grid(row=0, column=4, padx=10, pady=10)
        self.light_label = ctk.CTkLabel(info_frame, text="--", text_color="yellow")
        self.light_label.grid(row=0, column=5, padx=10, pady=10)

        # Mevcut Durum
        status_frame = ctk.CTkFrame(self.curtain_tab)
        status_frame.pack(pady=10, padx=20, fill="x")
        
        ctk.CTkLabel(status_frame, text="Current Curtain Status:", font=ctk.CTkFont(size=16)).pack(pady=5)
        self.curtain_status_label = ctk.CTkLabel(status_frame, text="% --", font=ctk.CTkFont(size=30, weight="bold"), text_color="#2CC985")
        self.curtain_status_label.pack(pady=5)
        
        # Kontrol Modu Göstergesi
        self.mode_indicator = ctk.CTkLabel(status_frame, text="📡 AUTOMATIC MODE (LDR + Potentiometer)", font=ctk.CTkFont(size=14, weight="bold"), text_color="green")
        self.mode_indicator.pack(pady=5)

        # PC Kontrol Alanı
        ctrl_frame = ctk.CTkFrame(self.curtain_tab)
        ctrl_frame.pack(pady=10, padx=20, fill="both", expand=True)
        
        ctk.CTkLabel(ctrl_frame, text="🖥️ PC Remote Control (via UART):", font=ctk.CTkFont(size=16, weight="bold")).pack(pady=(15, 5))
        
        self.curtain_slider = ctk.CTkSlider(ctrl_frame, from_=0, to=100, number_of_steps=100, command=self._on_curtain_slider_change)
        self.curtain_slider.set(0)
        self.curtain_slider.pack(pady=5, padx=40, fill="x")
        
        self.curtain_slider_val_label = ctk.CTkLabel(ctrl_frame, text="% 0")
        self.curtain_slider_val_label.pack(pady=2)
        
        # BUTONLAR (Proje Föyü Gereksinimi)
        btn_frame = ctk.CTkFrame(ctrl_frame, fg_color="transparent")
        btn_frame.pack(pady=20, padx=40, fill="x")
        
        # PC Kontrol Butonu
        self.set_curtain_btn = ctk.CTkButton(
            btn_frame, 
            text="🎯 SET THE CURTAIN (PC Control)", 
            command=self._set_curtain, 
            height=45, 
            font=ctk.CTkFont(size=14, weight="bold"), 
            fg_color="#1F6AA5"
        )
        self.set_curtain_btn.pack(pady=5, fill="x")
        
        # Otomatik Moda Dön Butonu
        self.release_curtain_btn = ctk.CTkButton(
            btn_frame, 
            text="🔄 TURN BACK TO AUTO MODE (Sensors will be activated)", 
            command=self._release_curtain_control, 
            height=45, 
            font=ctk.CTkFont(size=14, weight="bold"), 
            fg_color="#28A745"
        )
        self.release_curtain_btn.pack(pady=5, fill="x")
        
        # Açıklama
        info_text = ("💡 Hint:\n"
                     "• PC Control: You will set the curtain (LDR/Potentiometer are passive)\n"
                     "• AUTO Mode: Sensors will be activated, system makes decisions")
        ctk.CTkLabel(ctrl_frame, text=info_text, font=ctk.CTkFont(size=11), text_color="gray", justify="left").pack(pady=10)

    def _on_curtain_slider_change(self, value):
        self.curtain_slider_val_label.configure(text=f"% {int(value)}")

    def _handle_connect(self):
        if self.ac_connected or self.curtain_connected:
            self._disconnect()
        else:
            self._connect()
    
    def _connect(self):
        com1 = self.com1_entry.get().strip()
        com2 = self.com2_entry.get().strip()
        baud_str = self.baud_entry.get().strip()
        baud_rate = int(baud_str) if baud_str.isdigit() else 9600
        
        if com1:
            try:
                self.ac_connection = AirConditionerSystemConnection(com1, baud_rate)
                if self.ac_connection.open():
                    self.ac_connected = True
            except: pass
        
        if com2:
            try:
                self.curtain_connection = CurtainControlSystemConnection(com2, baud_rate)
                if self.curtain_connection.open():
                    self.curtain_connected = True
            except: pass
                
        if self.ac_connected or self.curtain_connected:
            self.connect_button.configure(text="DISCONNECT", fg_color="red")
            self.status_label.configure(text="CONNECTED", text_color="green")
            self._schedule_update()
        else:
            CTkMessagebox(title="Error", message="No Connections!", icon="cancel")

    def _disconnect(self):
        if self.ac_connection: self.ac_connection.close()
        if self.curtain_connection: self.curtain_connection.close()
        self.ac_connected = False
        self.curtain_connected = False
        if self.update_job: self.after_cancel(self.update_job)
        self.connect_button.configure(text="CONNECT", fg_color=["#3B8ED0", "#1F6AA5"])
        self.status_label.configure(text="No Connection", text_color="red")
        self._clear_display()

    def _clear_display(self):
        self.ambient_temp_label.configure(text="-- °C")
        self.desired_temp_label.configure(text="-- °C")
        self.fan_speed_label.configure(text="-- RPS")
        self.out_temp_label.configure(text="--")
        self.curtain_status_label.configure(text="% --")
        self.mode_indicator.configure(text="📡 AUTO Mod", text_color="green")

    def _schedule_update(self):
        if self.update_job: self.after_cancel(self.update_job)
        if self.ac_connected or self.curtain_connected:
            self.update_job = self.after(1000, self._auto_refresh_task)

    def _auto_refresh_task(self):
        if not (self.ac_connected or self.curtain_connected): return
        threading.Thread(target=self._fetch_data_thread, daemon=True).start()
        self._schedule_update()

    def _fetch_data_thread(self):
        if self.ac_connected and self.ac_connection:
            try:
                if self.ac_connection.update():
                    self.ambient_temp_label.configure(text=f"{self.ac_connection.ambient_temp:.2f} °C")
                    self.desired_temp_label.configure(text=f"{self.ac_connection.desired_temp:.2f} °C")
                    self.fan_speed_label.configure(text=f"{self.ac_connection.fan_speed} RPS")
            except: pass

        if self.curtain_connected and self.curtain_connection:
            try:
                if self.curtain_connection.update():
                    self.out_temp_label.configure(text=f"{self.curtain_connection.getOutdoorTemp()} °C")
                    self.pressure_label.configure(text=f"{self.curtain_connection.getOutdoorPress()} hPa")
                    self.light_label.configure(text=f"{self.curtain_connection.getLightIntensity()}")
                    self.curtain_status_label.configure(text=f"% {int(self.curtain_connection.curtainStatus)}")
                    
                    # Mod Göstergesini Güncelle
                    if self.curtain_connection.isPCControlMode():
                        self.mode_indicator.configure(text="🖥️ PC Control Mode (Sensors are passive)", text_color="orange")
                    else:
                        self.mode_indicator.configure(text="📡 AUTO Mode (LDR/Potentiometer will activated)", text_color="green")
            except: pass

    def _on_temp_slider_change(self, value):
        self.temp_value_label.configure(text=f"{value:.1f} °C")

    def _set_temperature(self):
        """Air Conditioner için PC kontrolü - Proje Föyü [R2.1.4-1]"""
        if not self.ac_connected:
            CTkMessagebox(title="Hata", message="Board #1 bağlı değil!", icon="warning")
            return
        val = self.temp_slider.get()
        if self.ac_connection.set_desired_temperature(val):
            CTkMessagebox(title="✅ Başarılı", message=f"Sıcaklık {val:.1f}°C olarak ayarlandı.", icon="check")
        else:
            CTkMessagebox(title="Hata", message="Sıcaklık ayarlanamadı!", icon="cancel")

    def _set_curtain(self):
        """Perde için PC kontrolü - Proje Föyü [R2.2.6-1]"""
        if not self.curtain_connected:
            CTkMessagebox(title="Hata", message="Board #2 bağlı değil!", icon="warning")
            return

        val = self.curtain_slider.get()
        if self.curtain_connection.setCurtainStatus(val):
            CTkMessagebox(
                title="✅ PC Kontrol Aktif", 
                message=f"Curtain set to %{int(val)}\n\n"
                        "⚠️ System is now under PC control!\n"
                        "• LDR is passive \n"
                        "• Potentiometer is passive\n\n"
                        "To return to AUTO Mode, press the 'Return to AUTO Mode' button",
                icon="check"
            )
        else:
            CTkMessagebox(title="Hata", message="Komut gönderilemedi.", icon="cancel")

    def _release_curtain_control(self):
        """PC kontrolünü bırak, otomatik moda geç - Proje Föyü gereksinimleri"""
        if not self.curtain_connected:
            CTkMessagebox(title="Hata", message="Board #2 bağlı değil!", icon="warning")
            return
        
        if self.curtain_connection.releaseControl():
            CTkMessagebox(
                title="✅ Auto Mode is activated", 
                message="System has switched to Auto mode!\n\n"
                        "✓ LDR is activated\n"
                        "✓ Potentiometer is activated\n\n"
                        "System started listening to its own sensors.",
                icon="check"
            )
        else:
            CTkMessagebox(title="Hata", message="Mod değiştirilemedi.", icon="cancel")

    def on_closing(self):
        self._disconnect()
        self.destroy()

if __name__ == "__main__":
    app = SmartHomeApp()
    app.protocol("WM_DELETE_WINDOW", app.on_closing)
    app.mainloop()