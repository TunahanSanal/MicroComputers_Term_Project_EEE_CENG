;******************************************************************************
; PROJECT: Air Conditioner (Board #1) - V6.2 FINAL (High Precision ADC)
; AUTHOR: Yigit Dombayli & Gemini
; DATE: 20.12.2025
;******************************************************************************
    LIST P=16F877A
    #include "P16F877A.INC"
    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _CP_OFF
    
    ERRORLEVEL -302 ; Bank uyar?lar?n? gizle

;------------------------------------------------------------------------------
; DE???KENLER
;------------------------------------------------------------------------------
    CBLOCK 0x20
        ; Ekran ve Keypad
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
        KEY_DELAY_3
        TEMP_VAL
        HUNDREDS
        TENS
        ONES
        W_TEMP
        STATUS_TEMP
        PCLATH_TEMP
        
        ; Sistem De?i?kenleri
        DESIRED_TEMP_INT 
        DESIRED_TEMP_FRAC
        AMBIENT_TEMP_INT
        AMBIENT_TEMP_FRAC
        FAN_SPEED
        UART_RX_BUFFER
        UART_CMD_FLAG
        
        ; Yeni Hassas ADC De?i?kenleri
        ADC_L
        ADC_H
        UART_TX_SAVE ; ?leti?im çak??mas?n? önlemek için
    ENDC

    ORG 0x000
    GOTO INIT
   
    ORG 0x004
    GOTO ISR

;------------------------------------------------------------------------------
; TABLO (CM GND - ORTAK KATOT)
;------------------------------------------------------------------------------
    ORG 0x100
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
    RETLW b'00000000' ; 10 (Bo?)
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
    CLRF TRISD      ; Display
    CLRF TRISA      
    BSF  TRISA, 0   ; Analog Input
    
    MOVLW b'11110000'
    MOVWF TRISB     ; Keypad
    
    ; RC0=Input, RC2=Cooler, RC5=Heater, RC6=TX, RC7=RX
    MOVLW b'10000001' 
    MOVWF TRISC

    ; --- ADC AYARI (HASSAS MOD - RIGHT JUSTIFIED) ---
    ; Bit 7 (ADFM) = 1 yap?ld?. 10-bit sonuç sa?a dayal? olacak.
    MOVLW b'10001110' 
    MOVWF ADCON1
   
    ; Timer0 (AKICI EKRAN AYARI: 1:32)
    BCF OPTION_REG, 7 
    MOVLW b'10000100' 
    MOVWF OPTION_REG
    
    ; UART
    MOVLW d'32'
    MOVWF SPBRG
    BSF TXSTA, TXEN
    BCF TXSTA, SYNC
    BCF TXSTA, BRGH
    BSF PIE1, RCIE
   
    BCF STATUS, RP0
   
    BSF RCSTA, SPEN
    BSF RCSTA, CREN
    
    MOVLW b'10000001' 
    MOVWF ADCON0

    ; Temizlik
    CLRF PORTA
    CLRF PORTD
    CLRF PORTC
    CLRF DIGIT_1_VAL
    CLRF DIGIT_2_VAL
    CLRF DIGIT_3_VAL
    CLRF DIGIT_4_VAL
    CLRF IS_EDITING
    CLRF HAS_DOT
    CLRF DISPLAY_STATE
    CLRF UART_CMD_FLAG
    
    MOVLW d'25'
    MOVWF DESIRED_TEMP_INT
    MOVLW d'0'
    MOVWF DESIRED_TEMP_FRAC
    
    BSF INTCON, T0IE
    BSF INTCON, PEIE
    BSF INTCON, GIE
    
    CALL DELAY_STARTUP

;------------------------------------------------------------------------------
; ANA DÖNGÜ
;------------------------------------------------------------------------------
MAIN_LOOP:
    BTFSC UART_CMD_FLAG, 0
    CALL PROCESS_UART_CMD
    
    ; Edit modunda de?ilsek sensörleri oku
    BTFSS IS_EDITING, 0
    CALL READ_SENSORS_AND_CONTROL

    ; Keypad Kontrolü
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
; ED?T MODU
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
    CALL WAIT_KEY_RELEASE ; A'dan elini çekmesini bekle
    
    ; 1. RAKAM
    CALL GET_VALID_KEY
    MOVWF INPUT_INT_VAL
    MOVWF DIGIT_1_VAL
    CALL WAIT_KEY_RELEASE 
    
    ; 2. RAKAM
    CALL GET_VALID_KEY
    MOVWF TEMP_VAL
    MOVWF DIGIT_2_VAL
    
    ; Hesaplama
    MOVF INPUT_INT_VAL, W
    MOVWF CALC_TEMP
    BCF STATUS, C
    RLF CALC_TEMP, F 
    BCF STATUS, C
    RLF CALC_TEMP, F 
    MOVF CALC_TEMP, W
    ADDWF INPUT_INT_VAL, F 
    BCF STATUS, C
    RLF INPUT_INT_VAL, F 
    MOVF TEMP_VAL, W
    ADDWF INPUT_INT_VAL, F
    CALL WAIT_KEY_RELEASE 
    
    ; '*' BEKLE
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
    
    ; '#' BEKLE
WAIT_HASH:
    CALL SCAN_KEYPAD_RAW
    XORLW d'15'
    BTFSS STATUS, Z
    GOTO WAIT_HASH
    CALL WAIT_KEY_RELEASE
    
    ; L?M?T KONTROLÜ
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
    
    ; Uzun bekleme
    CALL DELAY_LONG_MSG
    GOTO EXIT_EDIT

SHOW_ERROR:
    MOVLW d'14' ; "E"
    MOVWF DIGIT_1_VAL
    MOVLW d'10'
    MOVWF DIGIT_2_VAL
    MOVWF DIGIT_3_VAL
    MOVWF DIGIT_4_VAL
    CALL DELAY_LONG_MSG

EXIT_EDIT:
    CALL WAIT_KEY_RELEASE
    BCF IS_EDITING, 0
    BCF HAS_DOT, 0
    CLRF DISPLAY_STATE
    CLRF TIMER_COUNT_L
    CLRF TIMER_COUNT_H
    
    CALL READ_SENSORS_AND_CONTROL
    CALL LOAD_DESIRED_TEMP_INTERNAL
    GOTO MAIN_LOOP

;------------------------------------------------------------------------------
; SENSÖR VE FAN (GÜNCELLENM?? HASSAS OKUMA)
;------------------------------------------------------------------------------
READ_SENSORS_AND_CONTROL:
    BSF ADCON0, GO
WAIT_ADC:
    BTFSC ADCON0, GO
    GOTO WAIT_ADC
    
    ; --- 10-BIT ADC OKUMA VE DÖNÜ?TÜRME ---
    ; Right Justified (ADFM=1) oldu?u için:
    ; ADRESH = Üst 2 bit
    ; ADRESL = Alt 8 bit
    ; S?cakl?k = ADC_Value / 2  (LM35 simülasyonunda 1 derece ~ 2 ad?m)
    
    BANKSEL ADRESL
    MOVF ADRESL, W
    BCF STATUS, RP0 ; Bank 0
    MOVWF ADC_L
    
    BANKSEL ADRESH
    MOVF ADRESH, W
    BCF STATUS, RP0
    MOVWF ADC_H
    
    ; 16-Bit Sa?a Kayd?rma (Bölü 2)
    ; Carry bayra??n? temizle
    BCF STATUS, C
    RRF ADC_H, F ; Üst byte kayd?r, ta?an bit Carry'ye geçer
    RRF ADC_L, F ; Alt byte kayd?r, Carry'den gelen bit 7. bite girer
    
    ; ADC_L art?k tam say? k?sm?d?r (Integer)
    MOVF ADC_L, W
    MOVWF AMBIENT_TEMP_INT
    
    ; Carry bayra?? d??ar? ç?kan son bit'tir (0.5'lik k?s?m)
    ; E?er Carry=1 ise ondal?k k?s?m .5, Carry=0 ise .0
    CLRF AMBIENT_TEMP_FRAC
    BTFSC STATUS, C
    GOTO SET_HALF_DEG
    GOTO CHECK_FAN
    
SET_HALF_DEG:
    MOVLW d'5'
    MOVWF AMBIENT_TEMP_FRAC

CHECK_FAN:
    MOVF DESIRED_TEMP_INT, W
    SUBWF AMBIENT_TEMP_INT, W 
    
    BTFSS STATUS, C    
    GOTO ACTIVATE_HEATER
    BTFSC STATUS, Z    
    GOTO ACTIVATE_OFF
    GOTO ACTIVATE_COOLER 

ACTIVATE_HEATER:
    BSF PORTC, 5       
    BCF PORTC, 2       
    CLRF FAN_SPEED
    RETURN

ACTIVATE_COOLER:
    BCF PORTC, 5       
    BSF PORTC, 2       
    MOVLW d'50'        
    MOVWF FAN_SPEED
    RETURN

ACTIVATE_OFF:
    BCF PORTC, 5
    BCF PORTC, 2
    CLRF FAN_SPEED
    RETURN

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
; ISR (KESME) - Ak?c? Ekran
;------------------------------------------------------------------------------
ISR:
    MOVWF W_TEMP
    SWAPF STATUS, W
    MOVWF STATUS_TEMP
    MOVF PCLATH, W
    MOVWF PCLATH_TEMP

    BTFSC PIR1, RCIF
    GOTO ISR_UART

    BTFSS INTCON, T0IF
    GOTO EXIT_ISR
    
    BCF INTCON, T0IF
    CLRF PORTA
    CLRF PORTD
    
    BTFSC IS_EDITING, 0
    GOTO SKIP_TIMER
    
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
    
    BTFSC IS_EDITING, 0
    GOTO CHECK_DOT_EDIT
    MOVF DISPLAY_STATE, W
    SUBLW d'2'
    BTFSC STATUS, Z 
    GOTO SKIP_DOT
    BSF PORTD, 7 
    GOTO SKIP_DOT
CHECK_DOT_EDIT:
    BTFSC HAS_DOT, 0
    BSF PORTD, 7
SKIP_DOT:
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

ISR_UART:
    MOVF RCREG, W
    MOVWF UART_RX_BUFFER
    BSF UART_CMD_FLAG, 0
    BCF PIR1, RCIF
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
; KEYPAD & UART FONKS?YONLARI
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
    CALL DELAY_DEBOUNCE 
    MOVF KEY_CODE, W
    RETURN

WAIT_KEY_RELEASE:
    CALL DELAY_DEBOUNCE
WR_LOOP:
    CALL SCAN_KEYPAD_RAW
    XORLW 0xFF
    BTFSS STATUS, Z
    GOTO WR_LOOP
    CALL DELAY_DEBOUNCE
    CALL SCAN_KEYPAD_RAW
    XORLW 0xFF
    BTFSS STATUS, Z
    GOTO WR_LOOP
    RETURN

SCAN_KEYPAD_RAW:
    CLRF PORTB
    MOVLW b'11111110'
    MOVWF PORTB
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'1'
    BTFSS PORTB, 5
    RETLW d'2'
    BTFSS PORTB, 6
    RETLW d'3'
    BTFSS PORTB, 7
    RETLW d'13'

    MOVLW b'11111101'
    MOVWF PORTB
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'4'
    BTFSS PORTB, 5
    RETLW d'5'
    BTFSS PORTB, 6
    RETLW d'6'
    BTFSS PORTB, 7
    RETLW d'11'

    MOVLW b'11111011'
    MOVWF PORTB
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'7'
    BTFSS PORTB, 5
    RETLW d'8'
    BTFSS PORTB, 6
    RETLW d'9'
    BTFSS PORTB, 7
    RETLW d'12'

    MOVLW b'11110111'
    MOVWF PORTB
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'14'
    BTFSS PORTB, 5
    RETLW d'0'
    BTFSS PORTB, 6
    RETLW d'15'
    BTFSS PORTB, 7
    RETLW d'13'
    RETLW 0xFF

PROCESS_UART_CMD:
    MOVF UART_RX_BUFFER, W
    MOVWF TEMP_VAL
    BTFSC TEMP_VAL, 7
    GOTO CHECK_SET_CMDS
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
CHECK_SET_CMDS:
    BTFSS TEMP_VAL, 6
    GOTO UART_SET_DES_FRAC
    GOTO UART_SET_DES_INT
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
UART_SET_DES_FRAC:
    MOVF TEMP_VAL, W
    ANDLW b'00111111'
    MOVWF DESIRED_TEMP_FRAC
    GOTO UART_CMD_END
UART_SET_DES_INT:
    MOVF TEMP_VAL, W
    ANDLW b'00111111'
    MOVWF DESIRED_TEMP_INT
    GOTO UART_CMD_END
UART_CMD_END:
    BCF UART_CMD_FLAG, 0
    RETURN

UART_SEND_DECIMAL:
    MOVWF TEMP_VAL
    CALL BIN_TO_BCD
    MOVF HUNDREDS, W
    ADDLW '0'
    CALL UART_SEND_RAW
    MOVF TENS, W
    ADDLW '0'
    CALL UART_SEND_RAW
    MOVF ONES, W
    ADDLW '0'
    CALL UART_SEND_RAW
    MOVLW d'13'
    CALL UART_SEND_RAW
    RETURN
UART_SEND_RAW:
    MOVWF UART_TX_SAVE ; KESME GÜVENL? DE???KEN
UART_SEND_WAIT:
    BSF STATUS, RP0
    BTFSS TXSTA, TRMT
    GOTO UART_SEND_WAIT
    BCF STATUS, RP0
    MOVF UART_TX_SAVE, W
    MOVWF TXREG
    RETURN
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

; Gecikmeler
DELAY_DEBOUNCE:
    MOVLW d'200'
    MOVWF KEY_DELAY_1
DD_L1:
    MOVLW d'250'
    MOVWF KEY_DELAY_2
DD_L2:
    DECFSZ KEY_DELAY_2, F
    GOTO DD_L2
    DECFSZ KEY_DELAY_1, F
    GOTO DD_L1
    RETURN

DELAY_LONG_MSG:
    MOVLW d'15'
    MOVWF KEY_DELAY_3
DM_L3:
    CALL DELAY_DEBOUNCE
    DECFSZ KEY_DELAY_3, F
    GOTO DM_L3
    RETURN

DELAY_STARTUP:
    MOVLW d'10'
    MOVWF KEY_DELAY_3
DS_L0:
    CALL DELAY_DEBOUNCE
    DECFSZ KEY_DELAY_3, F
    GOTO DS_L0
    RETURN

DELAY_SMALL:
    MOVLW d'50'
    MOVWF KEY_DELAY_2
DS_LOOP:
    DECFSZ KEY_DELAY_2, F
    GOTO DS_LOOP
    RETURN
    END