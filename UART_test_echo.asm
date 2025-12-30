;******************************************************************************
;   PROJECT: Air Conditioner Static Tester
;   FILE:    AC_Static_Test.asm
;   AUTHOR:  Gemini
;   TARGET:  PIC16F877A @ 4MHz
;
;   DESCRIPTION:
;   This program acts as a static server for the Python App.
;   It holds FIXED values for Ambient Temp (24.5) and Fan Speed (150).
;   It allows setting Desired Temp via UART.
;
;   DEFAULT VALUES ON STARTUP:
;     - Ambient Temp: 24.5 C
;     - Fan Speed:    150 RPS
;     - Desired Temp: 25.0 C
;******************************************************************************

    LIST P=16F877A
    #include "P16F877A.INC"

    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _CP_OFF

;------------------------------------------------------------------------------
; VARIABLES
;------------------------------------------------------------------------------
    CBLOCK 0x20
        DESIRED_TEMP_INT    ; Writeable
        DESIRED_TEMP_FRAC   ; Writeable
        AMBIENT_TEMP_INT    ; Read-Only (Static)
        AMBIENT_TEMP_FRAC   ; Read-Only (Static)
        FAN_SPEED           ; Read-Only (Static)
        RX_TEMP             ; Buffer
    ENDC

    ORG     0x000
    GOTO    INIT

    ORG     0x004
    RETFIE

;------------------------------------------------------------------------------
; INITIALIZATION
;------------------------------------------------------------------------------
INIT:
    ; --- UART SETUP (9600 Baud) ---
    BSF     STATUS, RP0     ; Bank 1
    BCF     TRISC, 6        ; TX Output
    BSF     TRISC, 7        ; RX Input
    MOVLW   d'25'           ; Baud 9600
    MOVWF   SPBRG
    MOVLW   b'00100100'     ; TXEN=1, BRGH=1
    MOVWF   TXSTA
    BCF     STATUS, RP0     ; Bank 0
    MOVLW   b'10010000'     ; SPEN=1, CREN=1
    MOVWF   RCSTA

    ; --- SET STATIC VALUES (DE?ERLER? BURADAN BEL?RL?YORUZ) ---
    
    ; 1. Ambient Temp = 24.5 Derece (Sabit)
    MOVLW   d'24'
    MOVWF   AMBIENT_TEMP_INT
    MOVLW   d'50'           ; 0.50 demek (Python kodu %100 mant???yla çal???yor)
    MOVWF   AMBIENT_TEMP_FRAC

    ; 2. Fan Speed = 150 (Sabit)
    MOVLW   d'150'
    MOVWF   FAN_SPEED

    ; 3. Desired Temp = 25.0 (Ba?lang?ç, ama Uygulama bunu de?i?tirebilir)
    MOVLW   d'25'
    MOVWF   DESIRED_TEMP_INT
    MOVLW   d'0'
    MOVWF   DESIRED_TEMP_FRAC

;------------------------------------------------------------------------------
; MAIN LOOP
;------------------------------------------------------------------------------
MAIN_LOOP:
    ; Wait for a command from Python
    BTFSS   PIR1, RCIF
    GOTO    MAIN_LOOP       ; No data, keep waiting

    ; Data received!
    CALL    HANDLE_COMMAND
    GOTO    MAIN_LOOP

;------------------------------------------------------------------------------
; COMMAND HANDLER
;------------------------------------------------------------------------------
HANDLE_COMMAND:
    MOVF    RCREG, W        ; Read the incoming byte
    MOVWF   RX_TEMP

    ; --- Check if it is a SET command (Bit 7 is 1) ---
    BTFSC   RX_TEMP, 7
    GOTO    PROCESS_SET_COMMAND

    ; --- Check for GET Commands (0x01 - 0x05) ---
    
    ; Request 0x01: Get Desired Fractional
    MOVF    RX_TEMP, W
    SUBLW   0x01
    BTFSC   STATUS, Z
    GOTO    SEND_DES_FRAC

    ; Request 0x02: Get Desired Integral
    MOVF    RX_TEMP, W
    SUBLW   0x02
    BTFSC   STATUS, Z
    GOTO    SEND_DES_INT

    ; Request 0x03: Get Ambient Fractional
    MOVF    RX_TEMP, W
    SUBLW   0x03
    BTFSC   STATUS, Z
    GOTO    SEND_AMB_FRAC

    ; Request 0x04: Get Ambient Integral
    MOVF    RX_TEMP, W
    SUBLW   0x04
    BTFSC   STATUS, Z
    GOTO    SEND_AMB_INT

    ; Request 0x05: Get Fan Speed
    MOVF    RX_TEMP, W
    SUBLW   0x05
    BTFSC   STATUS, Z
    GOTO    SEND_FAN_SPEED

    RETURN

; --- SEND ROUTINES ---
SEND_DES_FRAC:
    MOVF    DESIRED_TEMP_FRAC, W
    GOTO    SEND_BYTE
SEND_DES_INT:
    MOVF    DESIRED_TEMP_INT, W
    GOTO    SEND_BYTE
SEND_AMB_FRAC:
    MOVF    AMBIENT_TEMP_FRAC, W
    GOTO    SEND_BYTE
SEND_AMB_INT:
    MOVF    AMBIENT_TEMP_INT, W
    GOTO    SEND_BYTE
SEND_FAN_SPEED:
    MOVF    FAN_SPEED, W
    GOTO    SEND_BYTE

SEND_BYTE:
    ; Send W register via UART
    BSF     STATUS, RP0
WAIT_TX:
    BTFSS   TXSTA, TRMT
    GOTO    WAIT_TX
    BCF     STATUS, RP0
    MOVWF   TXREG
    RETURN

; --- SET ROUTINES (Uygulama De?er Gönderirse) ---
PROCESS_SET_COMMAND:
    ; Check Bit 6 to distinguish Integral vs Fractional
    BTFSC   RX_TEMP, 6
    GOTO    SET_INTEGRAL
    
    ; Case: Set Fractional (10xxxxxx)
    MOVLW   b'00111111'     ; Mask to get value
    ANDWF   RX_TEMP, W
    MOVWF   DESIRED_TEMP_FRAC
    RETURN

SET_INTEGRAL:
    ; Case: Set Integral (11xxxxxx)
    MOVLW   b'00111111'     ; Mask to get value
    ANDWF   RX_TEMP, W
    MOVWF   DESIRED_TEMP_INT
    RETURN

    END