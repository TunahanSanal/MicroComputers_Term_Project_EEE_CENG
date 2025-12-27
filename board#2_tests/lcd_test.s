; --------------------------------------------------
; This LCD TEST code written in assembly
; and integrated by Tunahan Sanal for Home
; Automation MicroComputer Project_Board_2
; --------------------------------------------------
    

#include <xc.inc>

;====================================================================
; CONFIGURATION BITS (Fuse Settings)
;====================================================================
    CONFIG FOSC = XT      ; Oscillator Selection (XT crystal)
    CONFIG WDTE = OFF     ; Watchdog Timer disabled
    CONFIG PWRTE = ON     ; Power-up Timer enabled
    CONFIG BOREN = OFF    ; Brown-out Reset disabled
    CONFIG LVP = OFF      ; Low-Voltage Programing disabled
    CONFIG CPD = OFF      ; Data EEPROM Memory Code Protection off
    CONFIG WRT = OFF      ; Flash Program Memory Write disabled
    CONFIG CP = OFF       ; Flash Program Memory Code Protection off

;====================================================================
; VARIABLE DEFINITIONS (RAM - Bank 0)
;====================================================================
PSECT udata_bank0
    DELAY_VAR1:      DS 1    ; allocate 1 byte for delay counter
    DELAY_VAR2:      DS 1    ; second delay variable
    
    ; Project specific variables
    DESIRED_CURTAIN: DS 1    ; target curtain postion
    CURRENT_CURTAIN: DS 1    ; actual curtain position
    LIGHT_L:         DS 1    ; light sensor low byte
    LIGHT_H:         DS 1    ; light sensor high byte

;====================================================================
; RESET VECTOR (Starting Point)
;====================================================================
PSECT resetVec,class=CODE,delta=2
resetVec:
    goto    main

;====================================================================
; MAIN PROGRAM
;====================================================================
PSECT code,delta=2
main:
    call    INIT_PORTS      ; configure ports first
    call    LCD_INIT        ; initialize LCD display

    ; --- Write to first line: "Proje" ---
    movlw   'P'
    call    LCD_SEND_CHAR
    movlw   'r'
    call    LCD_SEND_CHAR
    movlw   'o'
    call    LCD_SEND_CHAR
    movlw   'j'
    call    LCD_SEND_CHAR
    movlw   'e'
    call    LCD_SEND_CHAR

    ; --- Move to second line ---
    movlw   0xC0            ; 0xC0 hex adress for line 2
    call    LCD_SEND_CMD

    ; --- Write to second line: "Board 2" ---
    movlw   'B'
    call    LCD_SEND_CHAR
    movlw   'o'
    call    LCD_SEND_CHAR
    movlw   'a'
    call    LCD_SEND_CHAR
    movlw   'r'
    call    LCD_SEND_CHAR
    movlw   'd'
    call    LCD_SEND_CHAR
    movlw   ' '
    call    LCD_SEND_CHAR
    movlw   '2'
    call    LCD_SEND_CHAR

loop:
    goto    loop            ; infinite loop (program stays here)

;====================================================================
; PORT CONFIGURATION (INIT_PORTS)
;====================================================================
INIT_PORTS:
    ; BANKSEL command automaticaly switchs to correct bank
    BANKSEL TRISD
    clrf    TRISD           ; PORTD (LCD Data pins) -> Output
    clrf    TRISE           ; PORTE (LCD Control pins) -> Output
    
    ; Analog/Digital Configuration
    movlw   0b10000100      ; AN0, AN1 as Analog; Vref=VDD
    movwf   ADCON1
    
    ; TRISA (Sensor Input Configuration)
    movlw   0b00000011      ; RA0 and RA1 as inputs
    movwf   TRISA

    BANKSEL PORTD
    clrf    PORTD           ; clear PORTD
    clrf    PORTE           ; clear PORTE
    return

;====================================================================
; LCD DRIVER SUBROUTINES
;====================================================================
LCD_INIT:
    ; LCD initialization sequence (standard HD44780 procedure)
    movlw   20              ; wait 20ms for LCD power stabilization
    call    DELAY_MS
    
    movlw   0x30            ; Reset command 1
    call    LCD_CMD_NOWAIT
    movlw   5               ; 5ms delay
    call    DELAY_MS
    
    movlw   0x30            ; Reset command 2
    call    LCD_CMD_NOWAIT
    movlw   1               ; 1ms delay
    call    DELAY_MS
    
    movlw   0x30            ; Reset command 3
    call    LCD_CMD_NOWAIT
    
    movlw   0x38            ; Function set: 8-bit mode, 2 lines, 5x8 font
    call    LCD_SEND_CMD
    movlw   0x0C            ; Display ON, Cursor OFF, Blink OFF
    call    LCD_SEND_CMD
    movlw   0x01            ; Clear display
    call    LCD_SEND_CMD
    movlw   0x06            ; Entry mode: increment cursor, no shift
    call    LCD_SEND_CMD
    return

LCD_SEND_CMD:               ; Send command with delay
    movwf   PORTD           ; put command on data bus
    bcf     PORTE, 0        ; RE0 (RS) = 0 means command mode
    call    PULSE_E         ; generate enable pulse
    movlw   2               ; wait 2ms for command to execute
    call    DELAY_MS
    return

LCD_CMD_NOWAIT:             ; Send command without waiting (for init only)
    movwf   PORTD
    bcf     PORTE, 0        ; RS = 0 for command
    call    PULSE_E
    return

LCD_SEND_CHAR:              ; Send character data to LCD
    movwf   PORTD           ; put character on data bus
    bsf     PORTE, 0        ; RE0 (RS) = 1 means data mode
    call    PULSE_E         ; generate enable pulse
    movlw   1               ; small delay after writting
    call    DELAY_MS
    return

PULSE_E:                    ; Generate Enable pulse for LCD
    bsf     PORTE, 1        ; EN = high
    nop                     ; small delay
    nop
    bcf     PORTE, 1        ; EN = low
    return

;====================================================================
; DELAY SUBROUTINE (aproximate timing for 4MHz clock)
;====================================================================
DELAY_MS:
    ; Simple delay function, aproximately 1ms per count
    movwf   DELAY_VAR2      ; outer loop counter
d_loop_outer:
    movlw   250             ; inner loop count
    movwf   DELAY_VAR1
d_loop_inner:
    nop                     ; waste some cycles
    nop
    decfsz  DELAY_VAR1, f   ; decrement and skip if zero
    goto    d_loop_inner
    decfsz  DELAY_VAR2, f   ; decrement outer counter
    goto    d_loop_outer
    return

    END


