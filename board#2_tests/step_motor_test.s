; --------------------------------------------------
; This STEP MOTOR TEST code written in assembly
; and integrated by Tunahan Sanal for Home
; Automation MicroComputer Project_Board_2
; --------------------------------------------------

#include <xc.inc>

; CONFIGURATION BITS
    CONFIG FOSC = XT      ; crystal oscillator
    CONFIG WDTE = OFF     ; watchdog off
    CONFIG PWRTE = ON     ; power up timer on
    CONFIG BOREN = OFF    ; brown out off
    CONFIG LVP = OFF      ; low voltage programing off
    CONFIG CPD = OFF      ; code protection off
    CONFIG WRT = OFF      ; write protection off
    CONFIG CP = OFF       ; code protect off

;====================================================================
; VARIABLES
;====================================================================
PSECT udata_bank0
    DELAY_VAR1:      DS 1    ; delay counter
    DELAY_VAR2:      DS 1    ; second delay counter
    TEMP_RES:        DS 1    ; temporary result storage
    BCD_H:           DS 1    ; hundreds digit
    BCD_T:           DS 1    ; tens digit
    BCD_O:           DS 1    ; ones digit
    MOTOR_VAL:       DS 1    ; current motor coil state

;====================================================================
; RESET VECTOR
;====================================================================
PSECT resetVec,class=CODE,delta=2
resetVec:
    goto    main

;====================================================================
; MAIN PROGRAM
;====================================================================
PSECT code,delta=2
main:
    call    INIT_PORTS      ; setup ports
    call    LCD_INIT        ; initialize display
    call    INIT_ADC        ; enable analog converter
    
    ; Motor initial value (only first coil active)
    movlw   0b00000001
    movwf   MOTOR_VAL
    movwf   PORTB

loop:
    ; --- 1. READ SENSORS ---
    
    ; --- Potentiometer (AN1) ---
    movlw   0x80            ; go to first line
    call    LCD_SEND_CMD
    
    movlw   'P'
    call    LCD_SEND_CHAR
    movlw   'o'
    call    LCD_SEND_CHAR
    movlw   't'
    call    LCD_SEND_CHAR
    movlw   ':'
    call    LCD_SEND_CHAR
    
    movlw   1               ; read channel 1
    call    READ_ADC
    movwf   TEMP_RES
    call    SEND_NUMBER

    ; --- LDR Sensor (AN0) ---
    movlw   0xC0            ; go to second line
    call    LCD_SEND_CMD
    
    movlw   'L'
    call    LCD_SEND_CHAR
    movlw   'D'
    call    LCD_SEND_CHAR
    movlw   'R'
    call    LCD_SEND_CHAR
    movlw   ':'
    call    LCD_SEND_CHAR
    
    movlw   0               ; read channel 0
    call    READ_ADC
    movwf   TEMP_RES
    call    SEND_NUMBER

    ; --- 2. ROTATE MOTOR SAFELY ---
    call    ROTATE_MOTOR    ; new safe rotation function
    
    ; Speed control (too fast makes LCD flicker and motor invisible)
    movlw   100             ; wait 100ms
    call    DELAY_MS

    goto    loop            ; go back to start

;====================================================================
; SAFE MOTOR CONTROL (Bit Shifting Method)
;====================================================================
ROTATE_MOTOR:
    ; Shift left (1 -> 2 -> 4 -> 8 -> 16...)
    rlf     MOTOR_VAL, f
    
    ; If 5th bit (Bit 4) became 1, go back to begining (Bit 0)
    btfss   MOTOR_VAL, 4
    goto    motor_ok
    
    ; Wrap around to start (0000 0001)
    movlw   0b00000001
    movwf   MOTOR_VAL

motor_ok:
    ; Send only first 4 bits to PORTB (RB0-RB3)
    movf    MOTOR_VAL, w
    andlw   0x0F            ; safety mask (only lower 4 bits)
    movwf   PORTB
    return

;====================================================================
; ADC READING (Channel Selection)
;====================================================================
READ_ADC:
    andlw   0x07            ; clean channel number
    movwf   TEMP_RES
    rlf     TEMP_RES, f     ; shift left 3 times (channel is bit 3-5)
    rlf     TEMP_RES, f
    rlf     TEMP_RES, f
    
    movlw   0b11000111      ; mask to clear current channel
    andwf   ADCON0, f
    
    movf    TEMP_RES, w     ; add new channel
    iorwf   ADCON0, f
    
    movlw   2               ; capacitor charging time
    call    DELAY_MS
    
    bsf     ADCON0, 2       ; GO/DONE = 1 (start conversion)
wait_adc:
    btfsc   ADCON0, 2       ; wait if not finished
    goto    wait_adc
    
    movf    ADRESH, w       ; get result
    return

;====================================================================
; DISPLAY NUMBER ON SCREEN (0-255)
;====================================================================
SEND_NUMBER:
    ; Extract hundreds digit
    clrf    BCD_H
sub_100:
    movlw   100
    subwf   TEMP_RES, w
    btfss   STATUS, 0
    goto    print_100
    movwf   TEMP_RES
    incf    BCD_H, f
    goto    sub_100
print_100:
    movf    BCD_H, w
    addlw   '0'
    call    LCD_SEND_CHAR

    ; Extract tens digit
    clrf    BCD_T
sub_10:
    movlw   10
    subwf   TEMP_RES, w
    btfss   STATUS, 0
    goto    print_10
    movwf   TEMP_RES
    incf    BCD_T, f
    goto    sub_10
print_10:
    movf    BCD_T, w
    addlw   '0'
    call    LCD_SEND_CHAR
    
    ; Print ones digit (remaining value)
    movf    TEMP_RES, w
    addlw   '0'
    call    LCD_SEND_CHAR
    return

;====================================================================
; CONFIGURATION and DRIVERS
;====================================================================
INIT_PORTS:
    BANKSEL TRISB
    clrf    TRISB           ; PORTB (Motor) output
    clrf    TRISD           ; PORTD (LCD Data) output
    clrf    TRISE           ; PORTE (LCD Control) output
    
    movlw   0b00000100      ; ADC Left Justified, AN0/AN1 Analog
    movwf   ADCON1
    
    movlw   0b00000011      ; RA0, RA1 as inputs
    movwf   TRISA

    BANKSEL PORTB
    clrf    PORTB           ; clear all ports
    clrf    PORTD
    clrf    PORTE
    return

INIT_ADC:
    BANKSEL ADCON0
    movlw   0b01000001      ; Fosc/8 clock, ADC enabled
    movwf   ADCON0
    return

LCD_INIT:
    ; Standard LCD initialization procedure
    movlw   20
    call    DELAY_MS
    movlw   0x30            ; reset sequence
    call    LCD_CMD_NOWAIT
    movlw   5
    call    DELAY_MS
    movlw   0x30
    call    LCD_CMD_NOWAIT
    movlw   1
    call    DELAY_MS
    movlw   0x30
    call    LCD_CMD_NOWAIT
    movlw   0x38            ; 8-bit, 2 lines
    call    LCD_SEND_CMD
    movlw   0x0C            ; display on, cursor off
    call    LCD_SEND_CMD
    movlw   0x01            ; clear screen
    call    LCD_SEND_CMD
    movlw   0x06            ; entry mode set
    call    LCD_SEND_CMD
    return

LCD_SEND_CMD:
    ; Send command with delay
    movwf   PORTD
    bcf     PORTE, 0        ; RS = 0 means command
    call    PULSE_E
    movlw   2
    call    DELAY_MS
    return

LCD_CMD_NOWAIT:
    ; Send command without waiting
    movwf   PORTD
    bcf     PORTE, 0
    call    PULSE_E
    return

LCD_SEND_CHAR:
    ; Send character to display
    movwf   PORTD
    bsf     PORTE, 0        ; RS = 1 means data
    call    PULSE_E
    movlw   1
    call    DELAY_MS
    return

PULSE_E:
    ; Generate enable pulse for LCD
    bsf     PORTE, 1        ; EN high
    nop
    nop
    bcf     PORTE, 1        ; EN low
    return

DELAY_MS:
    ; Aproximate delay in milliseconds
    movwf   DELAY_VAR2
d_outer:
    movlw   250
    movwf   DELAY_VAR1
d_inner:
    nop
    nop
    decfsz  DELAY_VAR1, f
    goto    d_inner
    decfsz  DELAY_VAR2, f
    goto    d_outer
    return

    END


