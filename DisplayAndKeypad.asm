;******************************************************************************
; PROJECT: Air Conditioner Final (FIXED VERSION)
; DATE: 18.12.2025
; FIXES:
; 1. Digit 2 görüntüleme sorunu düzeltildi
; 2. Edit modundan ç?k??ta donma sorunu çözüldü
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
    ENDC
    ORG 0x000
    GOTO INIT
    ORG 0x004
    GOTO ISR
;------------------------------------------------------------------------------
; TABLO (CM GND - ORTAK KATOT: 1=YANAR)
;------------------------------------------------------------------------------
    ORG 0x010
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
    CLRF TRISD ; PORTD Ç?k??
    CLRF TRISA ; PORTA Ç?k??
    MOVLW 0x06
    MOVWF ADCON1 ; PORTA Dijital
    MOVLW b'11110000'
    MOVWF TRISB ; Keypad
    BCF OPTION_REG, 7 ; Pull-Up Aç?k
    MOVLW b'10000100' ; Timer0 1:32
    MOVWF OPTION_REG
    BCF STATUS, RP0
   
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
   
    BSF INTCON, T0IE
    BSF INTCON, GIE
;------------------------------------------------------------------------------
; ANA DÖNGÜ
;------------------------------------------------------------------------------
MAIN_LOOP:
    ; Keypad kontrolü
    CALL SCAN_KEYPAD_RAW
    XORLW d'13' ; A Tu?u
    BTFSC STATUS, Z
    GOTO ENTER_EDIT_MODE
    BTFSC IS_EDITING, 0
    GOTO MAIN_LOOP ; Edit modundaysak ekran güncellemesi yapma
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
    MOVLW d'10' ; Bo?
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
    BTFSS STATUS, C ; C=0 ise <10
    GOTO SHOW_ERROR
    MOVLW d'51'
    SUBWF INPUT_INT_VAL, W
    BTFSC STATUS, C ; C=1 ise >=51
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
   
    BCF IS_EDITING, 0 ; Edit modunu kapat
    BCF HAS_DOT, 0 ; Nokta bayra??n? temizle
    CLRF DISPLAY_STATE ; Ba?a dön
    CLRF TIMER_COUNT_L
    CLRF TIMER_COUNT_H
   
    ; ÖNEML?: Ekran? hemen güncelle
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
    MOVLW d'10' ; 4. Hane Bo?
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
    MOVLW d'11' ; 4. Hane 'C'
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
    MOVLW d'12' ; 4. Hane 'F'
    MOVWF DIGIT_4_VAL
    GOTO MAIN_LOOP
;------------------------------------------------------------------------------
; ISR (KESME) - EKRAN TARAMA
;------------------------------------------------------------------------------
ISR:
    MOVWF W_TEMP
    SWAPF STATUS, W
    MOVWF STATUS_TEMP
    MOVF PCLATH, W
    MOVWF PCLATH_TEMP
    BCF INTCON, T0IF
   
    ; Ghosting Önleme: Önce kapat
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
    BSF PORTA, 0 ; Digit 1
    INCF CURRENT_DIGIT, F
    GOTO EXIT_ISR
SHOW_D2:
    MOVLW HIGH GET_SEG_CODE
    MOVWF PCLATH
    MOVF DIGIT_2_VAL, W
    CALL GET_SEG_CODE
    MOVWF PORTD ; Önce segment kodunu PORTD'ye yaz
   
    ; Nokta Mant??? Düzeltmesi
    BTFSC IS_EDITING, 0
    GOTO CHECK_DOT_EDIT_D2
   
    ; Normal Mod: Fan de?ilse nokta yak
    MOVF DISPLAY_STATE, W
    SUBLW d'2'
    BTFSC STATUS, Z ; Fan ise nokta yakma
    GOTO SKIP_DOT_D2
    BSF PORTD, 7 ; Noktay? Yak
    GOTO SKIP_DOT_D2
CHECK_DOT_EDIT_D2:
    BTFSC HAS_DOT, 0
    BSF PORTD, 7 ; Edit modunda HAS_DOT varsa nokta yak
SKIP_DOT_D2:
    BSF PORTA, 1 ; Digit 2
    INCF CURRENT_DIGIT, F
    GOTO EXIT_ISR
SHOW_D3:
    MOVLW HIGH GET_SEG_CODE
    MOVWF PCLATH
    MOVF DIGIT_3_VAL, W
    CALL GET_SEG_CODE
    MOVWF PORTD
    BSF PORTA, 2 ; Digit 3
    INCF CURRENT_DIGIT, F
    GOTO EXIT_ISR
SHOW_D4:
    MOVLW HIGH GET_SEG_CODE
    MOVWF PCLATH
    MOVF DIGIT_4_VAL, W
    CALL GET_SEG_CODE
    MOVWF PORTD
    BSF PORTA, 3 ; Digit 4
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
    ; Önce hiçbir tu?a bas?lmad???ndan emin ol
GK_WAIT_NO_KEY:
    CALL SCAN_KEYPAD_RAW
    XORLW 0xFF
    BTFSS STATUS, Z
    GOTO GK_WAIT_NO_KEY
   
    ; ?imdi geçerli bir tu?a bas?lmas?n? bekle
GK_LOOP:
    CALL SCAN_KEYPAD_RAW
    MOVWF KEY_CODE
    XORLW 0xFF
    BTFSC STATUS, Z
    GOTO GK_LOOP
   
    ; 0-9 aras? m? kontrol et
    MOVF KEY_CODE, W
    SUBLW d'9'
    BTFSS STATUS, C
    GOTO GK_LOOP
   
    ; Geçerli tu? bulundu, debounce için bekle
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
    ; Sat?r 1
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
    RETLW d'13' ; A
    BSF PORTB, 0
    ; Sat?r 2
    BCF PORTB, 1
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'4'
    BTFSS PORTB, 5
    RETLW d'5'
    BTFSS PORTB, 6
    RETLW d'6'
    BTFSS PORTB, 7
    RETLW d'11' ; B
    BSF PORTB, 1
    ; Sat?r 3
    BCF PORTB, 2
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'7'
    BTFSS PORTB, 5
    RETLW d'8'
    BTFSS PORTB, 6
    RETLW d'9'
    BTFSS PORTB, 7
    RETLW d'12' ; C
    BSF PORTB, 2
    ; Sat?r 4
    BCF PORTB, 3
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'14' ; *
    BTFSS PORTB, 5
    RETLW d'0'
    BTFSS PORTB, 6
    RETLW d'15' ; #
    BTFSS PORTB, 7
    RETLW d'13' ; D
    BSF PORTB, 3
    RETLW 0xFF
    END