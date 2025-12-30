;******************************************************************************
;   PROJECT: Home Automation (Term Project)
;   MODULE:  Fan (Cooler) & Heater Unit Test
;   FILE:    Fan_Heater_Test.asm
;   AUTHOR:  Yigit Dombayli
;   ID:      151220212123
;
;   DESCRIPTION:
;   This is a simple test program to verify the connections of the 
;   Cooler (Fan) and Heater.
;   - Toggles COOLER (RB1) and HEATER (RB0) ON/OFF every 1 second.
;******************************************************************************

    LIST P=16F877A
    #include "P16F877A.INC"

    ; Konfigürasyon: HS Osilatör, WDT Kapal?
    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _CP_OFF

;------------------------------------------------------------------------------
; PIN TANIMLARI
;------------------------------------------------------------------------------
#DEFINE HEATER_PIN  PORTB, 0  ; Is?t?c? (K?rm?z? LED simgesi)
#DEFINE COOLER_PIN  PORTB, 1  ; Fan (Pervane simgesi)

;------------------------------------------------------------------------------
; DE???KENLER (Gecikme için)
;------------------------------------------------------------------------------
    CBLOCK 0x20
        DELAY_1
        DELAY_2
        DELAY_3
    ENDC

    ORG     0x000
    GOTO    INIT

;------------------------------------------------------------------------------
; BA?LANGIÇ AYARLARI
;------------------------------------------------------------------------------
INIT:
    ; Bank 1'e geç (TRIS ayarlar? için)
    BSF     STATUS, RP0
    
    ; PORTB'yi Ç?k?? Yap (Fan ve Is?t?c? için)
    CLRF    TRISB
    
    ; Bank 0'a dön
    BCF     STATUS, RP0
    
    ; Ba?lang?çta hepsini kapat
    CLRF    PORTB

;------------------------------------------------------------------------------
; ANA DÖNGÜ
;------------------------------------------------------------------------------
MAIN_LOOP:
    ; --- DURUM 1: FAN AÇIK, ISITICI KAPALI ---
    BSF     COOLER_PIN      ; RB1 = 1 (Fan Döner)
    BCF     HEATER_PIN      ; RB0 = 0 (Is?t?c? Söner)
    
    CALL    DELAY_SEC       ; Bekle

    ; --- DURUM 2: FAN KAPALI, ISITICI AÇIK ---
    BCF     COOLER_PIN      ; RB1 = 0 (Fan Durur)
    BSF     HEATER_PIN      ; RB0 = 1 (Is?t?c? Yanar)
    
    CALL    DELAY_SEC       ; Bekle

    GOTO    MAIN_LOOP       ; Ba?a dön

;------------------------------------------------------------------------------
; GEC?KME ALT PROGRAMI (Yakla??k 1 Saniye)
;------------------------------------------------------------------------------
DELAY_SEC:
    MOVLW   d'10'
    MOVWF   DELAY_3
LOOP_3:
    MOVLW   d'200'
    MOVWF   DELAY_2
LOOP_2:
    MOVLW   d'250'
    MOVWF   DELAY_1
LOOP_1:
    DECFSZ  DELAY_1, F
    GOTO    LOOP_1
    DECFSZ  DELAY_2, F
    GOTO    LOOP_2
    DECFSZ  DELAY_3, F
    GOTO    LOOP_3
    RETURN

    END


