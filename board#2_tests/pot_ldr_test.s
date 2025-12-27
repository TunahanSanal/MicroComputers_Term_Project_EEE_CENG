; --------------------------------------------------
; This SENSOR READ TEST code written in assembly
; and integrated by Tunahan Sanal for Home
; Automation MicroComputer Project_Board_2
; --------------------------------------------------
    

#include <xc.inc>

;====================================================================
; CONFIGURATION BITS
;====================================================================
    CONFIG FOSC = XT      ; external crystal oscillator
    CONFIG WDTE = OFF     ; watchdog timer off
    CONFIG PWRTE = ON     ; power up timer on
    CONFIG BOREN = OFF    ; brown out reset off
    CONFIG LVP = OFF      ; low voltage programing off
    CONFIG CPD = OFF      ; data memory code protection off
    CONFIG WRT = OFF      ; flash write protection off
    CONFIG CP = OFF       ; code protection off

;====================================================================
; VARIABLES (RAM)
;====================================================================
PSECT udata_bank0
    DELAY_VAR1:      DS 1    ; delay counter variable
    DELAY_VAR2:      DS 1    ; second delay variable
    TEMP_RES:        DS 1    ; temporary storage for ADC result
    BCD_H:           DS 1    ; hundreds digit for BCD conversion
    BCD_T:           DS 1    ; tens digit
    BCD_O:           DS 1    ; ones digit

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
    call    INIT_PORTS      ; setup all ports first
    call    LCD_INIT        ; initialize LCD display
    call    INIT_ADC        ; enable ADC module

loop:
    ; --- READ POTENTIOMETER (AN1) ---
    ; Set cursor to first line begining
    movlw   0x80
    call    LCD_SEND_CMD
    
    ; Write "Pot: " to display
    movlw   'P'
    call    LCD_SEND_CHAR
    movlw   'o'
    call    LCD_SEND_CHAR
    movlw   't'
    call    LCD_SEND_CHAR
    movlw   ':'
    call    LCD_SEND_CHAR
    
    ; Read AN1 Channel (Potentiometer)
    movlw   1               ; select channel 1
    call    READ_ADC
    movwf   TEMP_RES        ; store result
    call    SEND_NUMBER     ; display number on LCD

    ; --- READ LDR (AN0) ---
    ; Set cursor to second line begining
    movlw   0xC0
    call    LCD_SEND_CMD
    
    ; Write "LDR: " to display
    movlw   'L'
    call    LCD_SEND_CHAR
    movlw   'D'
    call    LCD_SEND_CHAR
    movlw   'R'
    call    LCD_SEND_CHAR
    movlw   ':'
    call    LCD_SEND_CHAR
    
    ; Read AN0 Channel (LDR sensor)
    movlw   0               ; select channel 0
    call    READ_ADC
    movwf   TEMP_RES
    call    SEND_NUMBER

    ; Wait a bit so numbers dont flicker too fast
    movlw   100
    call    DELAY_MS

    goto    loop            ; repeat forever

;====================================================================
; PORT AND CONFIGURATION SETUP
;====================================================================
INIT_PORTS:
    BANKSEL TRISD
    clrf    TRISD           ; LCD Data pins as output
    clrf    TRISE           ; LCD Control pins as output
    
    ; ADC Configuration: Left Justified -> ADRESH gives 8-bit reading
    ; PCFG=0100 (AN0, AN1, AN3 are Analog inputs)
    movlw   0b00000100      
    movwf   ADCON1
    
    movlw   0b00000011      ; RA0, RA1 as inputs for sensors
    movwf   TRISA

    BANKSEL PORTD
    clrf    PORTD           ; clear output ports
    clrf    PORTE
    return

INIT_ADC:
    ; ADC Clock: Fosc/8 setting
    BANKSEL ADCON0
    movlw   0b01000001      ; ADCS=01 (Fosc/8), ADON=1 (ADC enabled)
    movwf   ADCON0
    return

;====================================================================
; ADC READING SUBROUTINE
; Input: W register (Channel Number: 0 or 1)
; Output: W register (ADC Result from ADRESH)
;====================================================================
READ_ADC:
    ; Channel Selection (Bits 5-3 in ADCON0)
    andlw   0x07            ; mask for safety
    movwf   TEMP_RES        ; save temporarly
    
    ; Shift left 3 times (00000XXX -> 00XXX000)
    rlf     TEMP_RES, f
    rlf     TEMP_RES, f
    rlf     TEMP_RES, f
    
    ; Update channel without affecting other ADCON0 bits
    movlw   0b11000111      ; mask to clear channel bits (Bits 5-3 = 0)
    andwf   ADCON0, f
    
    movf    TEMP_RES, w
    iorwf   ADCON0, f       ; set new channel
    
    ; Acquisition Time (wait after channel change)
    movlw   2
    call    DELAY_MS
    
    bsf     ADCON0, 2       ; start conversion (GO/DONE = 1)
wait_adc:
    btfsc   ADCON0, 2       ; check if GO/DONE became 0
    goto    wait_adc        ; if not, keep waiting
    
    movf    ADRESH, w       ; read result to W (upper byte because left justified)
    return

;====================================================================
; DISPLAY NUMBER ON LCD (range 0-255)
; Input: number in TEMP_RES variable
;====================================================================
SEND_NUMBER:
    ; 1. Hundreds digit extraction
    clrf    BCD_H
sub_100:
    movlw   100
    subwf   TEMP_RES, w
    btfss   STATUS, 0       ; check Carry flag
    goto    print_100
    movwf   TEMP_RES
    incf    BCD_H, f
    goto    sub_100
print_100:
    movf    BCD_H, w
    addlw   '0'             ; convert to ASCII
    call    LCD_SEND_CHAR

    ; 2. Tens digit extraction
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

    ; 3. Ones digit (remaining value)
    movf    TEMP_RES, w
    addlw   '0'
    call    LCD_SEND_CHAR
    return

;====================================================================
; LCD DRIVER (kept same as before)
;====================================================================
LCD_INIT:
    ; Standard LCD initialization sequence
    movlw   20              ; wait for LCD power up
    call    DELAY_MS
    movlw   0x30            ; reset command
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
    movlw   0x01            ; clear display
    call    LCD_SEND_CMD
    movlw   0x06            ; entry mode
    call    LCD_SEND_CMD
    return

LCD_SEND_CMD:
    ; Send command to LCD with delay
    movwf   PORTD
    bcf     PORTE, 0        ; RS = 0 for command
    call    PULSE_E
    movlw   2
    call    DELAY_MS
    return

LCD_CMD_NOWAIT:
    ; Send command without waiting (init only)
    movwf   PORTD
    bcf     PORTE, 0
    call    PULSE_E
    return

LCD_SEND_CHAR:
    ; Send character data to LCD
    movwf   PORTD
    bsf     PORTE, 0        ; RS = 1 for data
    call    PULSE_E
    movlw   1
    call    DELAY_MS
    return

PULSE_E:
    ; Generate enable pulse
    bsf     PORTE, 1        ; EN high
    nop
    nop
    bcf     PORTE, 1        ; EN low
    return

;====================================================================
; DELAY FUNCTION
;====================================================================
DELAY_MS:
    ; Aproximate millisecond delay
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


