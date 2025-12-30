;******************************************************************************
; PROJECT: Air Conditioner with UART (Board #1) - FIXED VERSION
; AUTHOR: Yigit Dombayli (Fix by Gemini)
; DATE: 19.12.2025
;******************************************************************************
    LIST P=16F877A
    #include "P16F877A.INC"
    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _CP_OFF

;------------------------------------------------------------------------------
; DE???KENLER
;------------------------------------------------------------------------------
    CBLOCK 0x20
        DIGIT_1_VAL
        DIGIT_2_VAL
        DIGIT_3_VAL
        DIGIT_4_VAL
        CURRENT_DIGIT
        DISPLAY_STATE
        IS_EDITING
        HAS_DOT
        TIMER_COUNT_L
        TIMER_COUNT_H
        KEY_CODE
        INPUT_INT_VAL
        INPUT_FRAC_VAL
        CALC_TEMP
        KEY_DELAY_1
        KEY_DELAY_2
        TEMP_VAL
        HUNDREDS
        TENS
        ONES
        W_TEMP
        STATUS_TEMP
        PCLATH_TEMP
        DESIRED_TEMP_INT
        DESIRED_TEMP_FRAC
        AMBIENT_TEMP_INT
        AMBIENT_TEMP_FRAC
        FAN_SPEED
        UART_RX_BUFFER
        UART_CMD_FLAG
    ENDC

    ORG 0x000
    GOTO INIT
   
    ORG 0x004
    GOTO ISR

;------------------------------------------------------------------------------
; TABLO (CM GND - ORTAK KATOT: 1=YANAR)
;------------------------------------------------------------------------------
    ORG 0x100 ; Tabloyu ISR'dan uza?a, güvenli bir yere ta??d?m
GET_SEG_CODE:
    ADDWF PCL, F
    RETLW b'00111111' ; 0
    RETLW b'00000110' ; 1
    RETLW b'01011011' ; 2
    RETLW b'01001111' ; 3
    RETLW b'01100110' ; 4
    RETLW b'01101101' ; 5
    RETLW b'01111101' ; 6
    RETLW b'00000111' ; 7
    RETLW b'01111111' ; 8
    RETLW b'01101111' ; 9
    RETLW b'00000000' ; 10 (Bo?luk)
    RETLW b'00111001' ; 11 (C)
    RETLW b'01110001' ; 12 (F)
    RETLW b'01110111' ; 13 (A)
    RETLW b'01111001' ; 14 (E)
    RETLW b'01101101' ; 15 (S)

;------------------------------------------------------------------------------
; INIT
;------------------------------------------------------------------------------
INIT:
    BSF STATUS, RP0
   
    ; Port Ayarlar?
    CLRF TRISD      ; PORTD Ç?k?? (Display)
    CLRF TRISA      ; PORTA Ç?k?? (Display Transistorleri)
    MOVLW 0x06
    MOVWF ADCON1    ; PORTA Dijital
   
    MOVLW b'11110000'
    MOVWF TRISB     ; Keypad
   
    ; --- DUZELTME: UART Pin Ayarlari ---
    ; RC7 (RX) = 1 (Input), RC6 (TX) = 0 (Output)
    MOVLW b'10000000' 
    MOVWF TRISC
   
    BCF OPTION_REG, 7 ; Pull-Up Aç?k
    MOVLW b'10000100' ; Timer0 1:32
    MOVWF OPTION_REG
   
    ; UART Ba?latma (9600 baud @ 20MHz)
    MOVLW d'32'       ; SPBRG for 9600 baud (BRGH=0)
    MOVWF SPBRG
    BSF TXSTA, TXEN   ; Transmit Enable
    BCF TXSTA, SYNC   ; Asenkron mod
    BCF TXSTA, BRGH   ; Low speed
    BSF PIE1, RCIE    ; RX Interrupt Enable
   
    BCF STATUS, RP0
   
    BSF RCSTA, SPEN   ; Serial Port Enable
    BSF RCSTA, CREN   ; Continuous Receive Enable
  
    ; RAM TEM?ZL???
    CLRF PORTA
    CLRF PORTD
    CLRF DIGIT_1_VAL
    CLRF DIGIT_2_VAL
    CLRF DIGIT_3_VAL
    CLRF DIGIT_4_VAL
    CLRF IS_EDITING
    CLRF HAS_DOT
    CLRF DISPLAY_STATE
    CLRF UART_CMD_FLAG
  
    ; Ba?lang?ç De?erleri
    MOVLW d'25'
    MOVWF DESIRED_TEMP_INT
    MOVLW d'5'
    MOVWF DESIRED_TEMP_FRAC
    MOVLW d'24'
    MOVWF AMBIENT_TEMP_INT
    MOVLW d'8'
    MOVWF AMBIENT_TEMP_FRAC
    MOVLW d'150'
    MOVWF FAN_SPEED
  
  BSF INTCON, T0IE ; Timer0 Interrupt
    BSF INTCON, PEIE ; Peripheral Interrupt
    BSF INTCON, GIE  ; Global Interrupt

    ; --- DÜZELTME BURADA ---
    ; Sistem aç?l?nca hemen veri yollama, PC ba?lans?n diye 1 sn bekle
    CALL DELAY_1SEC  
    
    ; Önce bir "Enter" (New Line) yolla ki gürültü varsa alt sat?ra geçsin
    MOVLW d'13'
    CALL UART_SEND_RAW

    ; ?imdi RDY gönder
    MOVLW 'R'
    CALL UART_SEND_RAW
    MOVLW 'D'
    CALL UART_SEND_RAW
    MOVLW 'Y'
    CALL UART_SEND_RAW
    MOVLW d'13' ; New Line
    CALL UART_SEND_RAW
    
    ; Ana döngüye git
    GOTO MAIN_LOOP

;------------------------------------------------------------------------------
; ANA DÖNGÜ
;------------------------------------------------------------------------------
MAIN_LOOP:
    ; UART Komutu Kontrolü
    BTFSC UART_CMD_FLAG, 0
    CALL PROCESS_UART_CMD
   
    ; Keypad kontrolü
    CALL SCAN_KEYPAD_RAW
    XORLW d'13' ; A Tu?u
    BTFSC STATUS, Z
    GOTO ENTER_EDIT_MODE
   
    BTFSC IS_EDITING, 0
    GOTO MAIN_LOOP
   
    ; Ekran Güncelleme
    MOVF DISPLAY_STATE, W
    SUBLW d'0'
    BTFSC STATUS, Z
    GOTO LOAD_DESIRED_TEMP
   
    MOVF DISPLAY_STATE, W
    SUBLW d'1'
    BTFSC STATUS, Z
    GOTO LOAD_AMBIENT_TEMP
   
    MOVF DISPLAY_STATE, W
    SUBLW d'2'
    BTFSC STATUS, Z
    GOTO LOAD_FAN_SPEED
   
    GOTO MAIN_LOOP

;------------------------------------------------------------------------------
; UART KOMUT ??LEME (HEM ASCII GET, HEM BINARY SET DESTEKL?)
;------------------------------------------------------------------------------
PROCESS_UART_CMD:
    MOVF UART_RX_BUFFER, W
    MOVWF TEMP_VAL
    
    ; --- 1. ADIM: SET KOMUTU MU? (BIT 7 KONTROLÜ) ---
    ; Python'dan gelen SET komutlar? 1xxxxxxx format?ndad?r (Bit 7 = 1)
    ; ASCII karakterler (Putty) ise 0011xxxx format?ndad?r (Bit 7 = 0)
    
    BTFSC TEMP_VAL, 7    ; E?er 7. bit 1 ise, bu bir SET komutudur.
    GOTO CHECK_SET_CMDS  ; SET i?lemlerine git

    ; --- 2. ADIM: GET KOMUTLARI (ASCII '1'-'5') ---
    MOVLW '1'
    SUBWF TEMP_VAL, W
    BTFSC STATUS, Z
    GOTO UART_GET_DES_FRAC
    
    MOVLW '2'
    SUBWF TEMP_VAL, W
    BTFSC STATUS, Z
    GOTO UART_GET_DES_INT
    
    MOVLW '3'
    SUBWF TEMP_VAL, W
    BTFSC STATUS, Z
    GOTO UART_GET_AMB_FRAC
    
    MOVLW '4'
    SUBWF TEMP_VAL, W
    BTFSC STATUS, Z
    GOTO UART_GET_AMB_INT
    
    MOVLW '5'
    SUBWF TEMP_VAL, W
    BTFSC STATUS, Z
    GOTO UART_GET_FAN

    GOTO UART_CMD_END

; --- SET KOMUTLARI ??LEME ---
CHECK_SET_CMDS:
    ; 11xxxxxx -> INT KISMI
    ; 10xxxxxx -> FRAC KISMI
    
    BTFSS TEMP_VAL, 6      ; 6. bite bak
    GOTO UART_SET_DES_FRAC ; 6. bit 0 ise (10xxxxxx) -> FRAC
    GOTO UART_SET_DES_INT  ; 6. bit 1 ise (11xxxxxx) -> INT

; GET Komutlar? - Cevaplar Decimal String ("25")
UART_GET_DES_FRAC:
    MOVF DESIRED_TEMP_FRAC, W
    CALL UART_SEND_DECIMAL
    GOTO UART_CMD_END
UART_GET_DES_INT:
    MOVF DESIRED_TEMP_INT, W
    CALL UART_SEND_DECIMAL
    GOTO UART_CMD_END
UART_GET_AMB_FRAC:
    MOVF AMBIENT_TEMP_FRAC, W
    CALL UART_SEND_DECIMAL
    GOTO UART_CMD_END
UART_GET_AMB_INT:
    MOVF AMBIENT_TEMP_INT, W
    CALL UART_SEND_DECIMAL
    GOTO UART_CMD_END
UART_GET_FAN:
    MOVF FAN_SPEED, W
    CALL UART_SEND_DECIMAL
    GOTO UART_CMD_END

; SET Komutlar? (Veri Kaydetme)
UART_SET_DES_FRAC:
    MOVF TEMP_VAL, W
    ANDLW b'00111111' ; Üst 2 biti temizle (Prefix'i at), sadece veriyi al
    MOVWF DESIRED_TEMP_FRAC
    GOTO UART_CMD_END

UART_SET_DES_INT:
    MOVF TEMP_VAL, W
    ANDLW b'00111111' ; Üst 2 biti temizle (Prefix'i at), sadece veriyi al
    MOVWF DESIRED_TEMP_INT
    
    ; Ekran?n güncellenmesini tetiklemek için DISPLAY_STATE'i s?f?rla (?ste?e ba?l?)
    ; Ama ana döngü zaten sürekli okudu?u için otomatik güncellenecektir.
    GOTO UART_CMD_END

UART_CMD_END:
    BCF UART_CMD_FLAG, 0 ; Bayra?? temizle
    RETURN
;------------------------------------------------------------------------------
; UART GÖNDERME FONKS?YONLARI
;------------------------------------------------------------------------------

; Sayiyi ASCII (Yazi) olarak gonderir. Ornek: W=25 ise "2" ve "5" yollar.
UART_SEND_DECIMAL:
    MOVWF TEMP_VAL
    CALL BIN_TO_BCD    ; Sayiyi Yuzler, Onlar, Birler'e ayir
   
    ; Yuzler basamagi (Sadece varsa gonder veya 0 ise atla)
    MOVF HUNDREDS, W
    BTFSS STATUS, Z    ; 0 ise atlama yapilabilir ama basitlik icin gonderelim
    GOTO SEND_HUND
    GOTO SEND_TENS     ; 100'den kucukse yuzleri gonderme
SEND_HUND:
    MOVF HUNDREDS, W
    ADDLW '0'          ; ASCII'ye cevir
    CALL UART_SEND_RAW
   
SEND_TENS:
    MOVF TENS, W
    ADDLW '0'          ; ASCII'ye cevir
    CALL UART_SEND_RAW
   
SEND_ONES:
    MOVF ONES, W
    ADDLW '0'          ; ASCII'ye cevir
    CALL UART_SEND_RAW
   
    ; Okunabilirlik icin Bosluk veya NewLine ekleyelim
    MOVLW d'13'        ; Carriage Return
    CALL UART_SEND_RAW
    RETURN

; Ham byte gonderir (Karakter basmak icin)
UART_SEND_RAW:
    MOVWF W_TEMP       ; W sakla (Send wait sirasinda bozulmasin diye)
UART_SEND_WAIT:
    BSF STATUS, RP0
    BTFSS TXSTA, TRMT  ; TX buffer bo? mu?
    GOTO UART_SEND_WAIT
    BCF STATUS, RP0
    MOVF W_TEMP, W     ; W geri al
    MOVWF TXREG        ; Gönder
    RETURN

;------------------------------------------------------------------------------
; ED?T MODU (Aynen korundu)
;------------------------------------------------------------------------------
ENTER_EDIT_MODE:
    BSF IS_EDITING, 0
    CLRF HAS_DOT
   
    ; "A" Göster
    MOVLW d'13'
    MOVWF DIGIT_1_VAL
    MOVLW d'10'
    MOVWF DIGIT_2_VAL
    MOVWF DIGIT_3_VAL
    MOVWF DIGIT_4_VAL
    CALL WAIT_KEY_RELEASE
   
    ; 1. RAKAM (Giri?)
    CALL GET_VALID_KEY
    MOVWF INPUT_INT_VAL
    MOVWF DIGIT_1_VAL
    CALL WAIT_KEY_RELEASE
   
    ; 2. RAKAM (Giri?)
    CALL GET_VALID_KEY
    MOVWF TEMP_VAL
    MOVWF DIGIT_2_VAL
  
    ; Say? Hesaplama: (Digit1 * 10) + Digit2
    MOVF INPUT_INT_VAL, W
    MOVWF CALC_TEMP
    BCF STATUS, C
    RLF CALC_TEMP, F ; x2
    BCF STATUS, C
    RLF CALC_TEMP, F ; x4
    MOVF CALC_TEMP, W
    ADDWF INPUT_INT_VAL, F ; x5
    BCF STATUS, C
    RLF INPUT_INT_VAL, F ; x10
    MOVF TEMP_VAL, W
    ADDWF INPUT_INT_VAL, F
    CALL WAIT_KEY_RELEASE
   
    ; '*' BEKLE (Nokta)
WAIT_STAR:
    CALL SCAN_KEYPAD_RAW
    XORLW d'14'
    BTFSS STATUS, Z
    GOTO WAIT_STAR
  
    BSF HAS_DOT, 0
    CALL WAIT_KEY_RELEASE
   
    ; 3. RAKAM (Ondal?k)
    CALL GET_VALID_KEY
    MOVWF INPUT_FRAC_VAL
    MOVWF DIGIT_3_VAL
    CALL WAIT_KEY_RELEASE
   
    ; '#' BEKLE (Onay)
WAIT_HASH:
    CALL SCAN_KEYPAD_RAW
    XORLW d'15'
    BTFSS STATUS, Z
    GOTO WAIT_HASH
    CALL WAIT_KEY_RELEASE
   
    ; SINIR KONTROLÜ (10 - 50)
    MOVLW d'10'
    SUBWF INPUT_INT_VAL, W
    BTFSS STATUS, C
    GOTO SHOW_ERROR
    MOVLW d'51'
    SUBWF INPUT_INT_VAL, W
    BTFSC STATUS, C
    GOTO SHOW_ERROR
   
    ; KAYIT
    MOVF INPUT_INT_VAL, W
    MOVWF DESIRED_TEMP_INT
    MOVF INPUT_FRAC_VAL, W
    MOVWF DESIRED_TEMP_FRAC
   
    ; "S" (Ba?ar?l?)
    MOVLW d'15'
    MOVWF DIGIT_1_VAL
    MOVLW d'10'
    MOVWF DIGIT_2_VAL
    MOVWF DIGIT_3_VAL
    MOVWF DIGIT_4_VAL
    CALL DELAY_1SEC
    GOTO EXIT_EDIT
SHOW_ERROR:
    ; "E" (Hata)
    MOVLW d'14'
    MOVWF DIGIT_1_VAL
    MOVLW d'10'
    MOVWF DIGIT_2_VAL
    MOVWF DIGIT_3_VAL
    MOVWF DIGIT_4_VAL
    CALL DELAY_1SEC
EXIT_EDIT:
    CALL WAIT_KEY_RELEASE
  
    BCF IS_EDITING, 0
    BCF HAS_DOT, 0
    CLRF DISPLAY_STATE
    CLRF TIMER_COUNT_L
    CLRF TIMER_COUNT_H
  
    CALL LOAD_DESIRED_TEMP_INTERNAL
  
    GOTO MAIN_LOOP

;------------------------------------------------------------------------------
; VER? YÜKLEME
;------------------------------------------------------------------------------
LOAD_DESIRED_TEMP:
    CALL LOAD_DESIRED_TEMP_INTERNAL
    GOTO MAIN_LOOP
LOAD_DESIRED_TEMP_INTERNAL:
    MOVF DESIRED_TEMP_INT, W
    MOVWF TEMP_VAL
    CALL BIN_TO_BCD
    MOVF TENS, W
    MOVWF DIGIT_1_VAL
    MOVF ONES, W
    MOVWF DIGIT_2_VAL
    MOVF DESIRED_TEMP_FRAC, W
    MOVWF DIGIT_3_VAL
    MOVLW d'10'
    MOVWF DIGIT_4_VAL
    RETURN
LOAD_AMBIENT_TEMP:
    MOVF AMBIENT_TEMP_INT, W
    MOVWF TEMP_VAL
    CALL BIN_TO_BCD
    MOVF TENS, W
    MOVWF DIGIT_1_VAL
    MOVF ONES, W
    MOVWF DIGIT_2_VAL
    MOVF AMBIENT_TEMP_FRAC, W
    MOVWF DIGIT_3_VAL
    MOVLW d'11'
    MOVWF DIGIT_4_VAL
    GOTO MAIN_LOOP
LOAD_FAN_SPEED:
    MOVF FAN_SPEED, W
    MOVWF TEMP_VAL
    CALL BIN_TO_BCD
    MOVF HUNDREDS, W
    MOVWF DIGIT_1_VAL
    MOVF TENS, W
    MOVWF DIGIT_2_VAL
    MOVF ONES, W
    MOVWF DIGIT_3_VAL
    MOVLW d'12'
    MOVWF DIGIT_4_VAL
    GOTO MAIN_LOOP

;------------------------------------------------------------------------------
; ISR (KESME)
;------------------------------------------------------------------------------
ISR:
    MOVWF W_TEMP
    SWAPF STATUS, W
    MOVWF STATUS_TEMP
    MOVF PCLATH, W
    MOVWF PCLATH_TEMP
   
    ; UART RX Kesme Kontrolü
    BTFSS PIR1, RCIF
    GOTO ISR_TIMER0
   
    ; UART Veri Oku
    MOVF RCREG, W
    MOVWF UART_RX_BUFFER
    BSF UART_CMD_FLAG, 0
    BCF PIR1, RCIF
    GOTO EXIT_ISR
ISR_TIMER0:
    BCF INTCON, T0IF
  
    ; Ghosting Önleme
    CLRF PORTA
    CLRF PORTD
   
    BTFSC IS_EDITING, 0
    GOTO SKIP_TIMER
   
    ; 2 Saniye Sayac?
    INCF TIMER_COUNT_L, F
    BTFSC STATUS, Z
    INCF TIMER_COUNT_H, F
  
    MOVF TIMER_COUNT_H, W
    SUBLW 0x01
    BTFSS STATUS, Z
    GOTO SKIP_TIMER
    MOVF TIMER_COUNT_L, W
    SUBLW 0xF0
    BTFSS STATUS, Z
    GOTO SKIP_TIMER
   
    CLRF TIMER_COUNT_L
    CLRF TIMER_COUNT_H
    INCF DISPLAY_STATE, F
    MOVF DISPLAY_STATE, W
    SUBLW d'3'
    BTFSC STATUS, Z
    CLRF DISPLAY_STATE
SKIP_TIMER:
    MOVLW HIGH MUX_TABLE
    MOVWF PCLATH
    MOVF CURRENT_DIGIT, W
    ADDWF PCL, F
MUX_TABLE:
    GOTO SHOW_D1
    GOTO SHOW_D2
    GOTO SHOW_D3
    GOTO SHOW_D4
SHOW_D1:
    MOVLW HIGH GET_SEG_CODE
    MOVWF PCLATH
    MOVF DIGIT_1_VAL, W
    CALL GET_SEG_CODE
    MOVWF PORTD
    BSF PORTA, 0
    INCF CURRENT_DIGIT, F
    GOTO EXIT_ISR
SHOW_D2:
    MOVLW HIGH GET_SEG_CODE
    MOVWF PCLATH
    MOVF DIGIT_2_VAL, W
    CALL GET_SEG_CODE
    MOVWF PORTD
   
    ; Nokta Mant???
    BTFSC IS_EDITING, 0
    GOTO CHECK_DOT_EDIT_D2
  
    MOVF DISPLAY_STATE, W
    SUBLW d'2'
    BTFSC STATUS, Z
    GOTO SKIP_DOT_D2
    BSF PORTD, 7
    GOTO SKIP_DOT_D2
CHECK_DOT_EDIT_D2:
    BTFSC HAS_DOT, 0
    BSF PORTD, 7
SKIP_DOT_D2:
    BSF PORTA, 1
    INCF CURRENT_DIGIT, F
    GOTO EXIT_ISR
SHOW_D3:
    MOVLW HIGH GET_SEG_CODE
    MOVWF PCLATH
    MOVF DIGIT_3_VAL, W
    CALL GET_SEG_CODE
    MOVWF PORTD
    BSF PORTA, 2
    INCF CURRENT_DIGIT, F
    GOTO EXIT_ISR
SHOW_D4:
    MOVLW HIGH GET_SEG_CODE
    MOVWF PCLATH
    MOVF DIGIT_4_VAL, W
    CALL GET_SEG_CODE
    MOVWF PORTD
    BSF PORTA, 3
    CLRF CURRENT_DIGIT
    GOTO EXIT_ISR
EXIT_ISR:
    MOVF PCLATH_TEMP, W
    MOVWF PCLATH
    SWAPF STATUS_TEMP, W
    MOVWF STATUS
    SWAPF W_TEMP, F
    SWAPF W_TEMP, W
    RETFIE

;------------------------------------------------------------------------------
; YARDIMCI FONKS?YONLAR
;------------------------------------------------------------------------------
BIN_TO_BCD:
    CLRF HUNDREDS
    CLRF TENS
    CLRF ONES
    MOVF TEMP_VAL, W
    MOVWF ONES
CHECK_HUND:
    MOVLW d'100'
    SUBWF ONES, W
    BTFSS STATUS, C
    GOTO CHECK_TEN
    MOVWF ONES
    INCF HUNDREDS, F
    GOTO CHECK_HUND
CHECK_TEN:
    MOVLW d'10'
    SUBWF ONES, W
    BTFSS STATUS, C
    RETURN
    MOVWF ONES
    INCF TENS, F
    GOTO CHECK_TEN
DELAY_50MS:
    MOVLW d'100'
    MOVWF KEY_DELAY_1
D50_L1:
    MOVLW d'160'
    MOVWF KEY_DELAY_2
D50_L2:
    DECFSZ KEY_DELAY_2, F
    GOTO D50_L2
    DECFSZ KEY_DELAY_1, F
    GOTO D50_L1
    RETURN
DELAY_1SEC:
    MOVLW d'20'
    MOVWF TEMP_VAL
D1S_LOOP:
    CALL DELAY_50MS
    DECFSZ TEMP_VAL, F
    GOTO D1S_LOOP
    RETURN
DELAY_SMALL:
    MOVLW d'50'
    MOVWF KEY_DELAY_2
DS_LOOP:
    DECFSZ KEY_DELAY_2, F
    GOTO DS_LOOP
    RETURN

;------------------------------------------------------------------------------
; KEYPAD OKUMA
;------------------------------------------------------------------------------
GET_VALID_KEY:
GK_WAIT_NO_KEY:
    CALL SCAN_KEYPAD_RAW
    XORLW 0xFF
    BTFSS STATUS, Z
    GOTO GK_WAIT_NO_KEY
GK_LOOP:
    CALL SCAN_KEYPAD_RAW
    MOVWF KEY_CODE
    XORLW 0xFF
    BTFSC STATUS, Z
    GOTO GK_LOOP
    MOVF KEY_CODE, W
    SUBLW d'9'
    BTFSS STATUS, C
    GOTO GK_LOOP
    CALL DELAY_50MS
    MOVF KEY_CODE, W
    RETURN
WAIT_KEY_RELEASE:
    CALL DELAY_50MS
WR_LOOP:
    CALL SCAN_KEYPAD_RAW
    XORLW 0xFF
    BTFSS STATUS, Z
    GOTO WR_LOOP
    RETURN
SCAN_KEYPAD_RAW:
    MOVLW b'11111111'
    MOVWF PORTB
    BCF PORTB, 0
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'1'
    BTFSS PORTB, 5
    RETLW d'2'
    BTFSS PORTB, 6
    RETLW d'3'
    BTFSS PORTB, 7
    RETLW d'13'
    BSF PORTB, 0
   
    BCF PORTB, 1
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'4'
    BTFSS PORTB, 5
    RETLW d'5'
    BTFSS PORTB, 6
    RETLW d'6'
    BTFSS PORTB, 7
    RETLW d'11'
    BSF PORTB, 1
   
    BCF PORTB, 2
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'7'
    BTFSS PORTB, 5
    RETLW d'8'
    BTFSS PORTB, 6
    RETLW d'9'
    BTFSS PORTB, 7
    RETLW d'12'
    BSF PORTB, 2
   
    BCF PORTB, 3
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'14'
    BTFSS PORTB, 5
    RETLW d'0'
    BTFSS PORTB, 6
    RETLW d'15'
    BTFSS PORTB, 7
    RETLW d'13'
    BSF PORTB, 3
    RETLW 0xFF
    END