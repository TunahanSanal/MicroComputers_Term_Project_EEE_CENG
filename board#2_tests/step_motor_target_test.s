; --------------------------------------------------
; This STEP MOTOR LOGIC TEST code written in assembly
; and integrated by Tunahan Sanal for Home
; Automation MicroComputer Project_Board_2
; --------------------------------------------------

#include <xc.inc>

; CONFIGURATION BITS
    CONFIG FOSC = XT      ; external crystal
    CONFIG WDTE = OFF     ; watchdog disabled
    CONFIG PWRTE = ON     ; power up timer enabled
    CONFIG BOREN = OFF    ; brown out disabled
    CONFIG LVP = OFF      ; low voltage programing disabled
    CONFIG CPD = OFF      ; code protection disabled
    CONFIG WRT = OFF      ; write protection disabled
    CONFIG CP = OFF       ; code protect disabled

;====================================================================
; VARIABLES
;====================================================================
PSECT udata_bank0
    DELAY_VAR1:      DS 1    ; delay counter
    DELAY_VAR2:      DS 1    ; second delay counter
    TEMP_RES:        DS 1    ; temporary result
    BCD_H:           DS 1    ; hundreds digit
    BCD_T:           DS 1    ; tens digit
    BCD_O:           DS 1    ; ones digit
    
    ; Motor Control Variables
    MOTOR_VAL:       DS 1    ; coil state (0000 0001 etc.)
    CURRENT_POS:     DS 1    ; motors current position (0-255)
    TARGET_POS:      DS 1    ; desired position (pot value)

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
    call    INIT_ADC        ; enable ADC
    
    ; Initial Settings
    movlw   0b00000001
    movwf   MOTOR_VAL
    movwf   PORTB           ; set motor to first step
    clrf    CURRENT_POS     ; assume position is 0

loop:
    ; --- 1. DETERMINE TARGET (READ POT) ---
    movlw   1               ; channel 1 (potentiometer)
    call    READ_ADC
    movwf   TARGET_POS      ; save read value as TARGET

    ; --- 2. UPDATE DISPLAY ---
    
    ; First line: Target (Hedef in Turkish)
    movlw   0x80
    call    LCD_SEND_CMD
    movlw   'H'             ; Target
    call    LCD_SEND_CHAR
    movlw   'e'
    call    LCD_SEND_CHAR
    movlw   'd'
    call    LCD_SEND_CHAR
    movlw   'e'
    call    LCD_SEND_CHAR
    movlw   'f'
    call    LCD_SEND_CHAR
    movlw   ':'
    call    LCD_SEND_CHAR
    
    movf    TARGET_POS, w   ; write target value
    movwf   TEMP_RES
    call    SEND_NUMBER

    ; Second line: Current (Motor position)
    movlw   0xC0
    call    LCD_SEND_CMD
    movlw   'M'             ; Current
    call    LCD_SEND_CHAR
    movlw   'o'
    call    LCD_SEND_CHAR
    movlw   't'
    call    LCD_SEND_CHAR
    movlw   'o'
    call    LCD_SEND_CHAR
    movlw   'r'
    call    LCD_SEND_CHAR
    movlw   ':'
    call    LCD_SEND_CHAR
    
    movf    CURRENT_POS, w  ; write current position
    movwf   TEMP_RES
    call    SEND_NUMBER

    ; --- 3. MOTOR CONTROL LOGIC (COMPARISON) ---
    
    movf    TARGET_POS, w
    subwf   CURRENT_POS, w  ; W = Current - Target
    
    btfsc   STATUS, 2       ; Z=1 means they are equal
    goto    stop_motor      ; stop motor
    
    btfss   STATUS, 0       ; C=0 means (Target > Current) -> negative result
    goto    go_cw           ; target is bigger, go forward
    
    goto    go_ccw          ; target is smaller, go backward (C=1)

go_cw:
    call    ROTATE_CW       ; clockwise 1 step
    incf    CURRENT_POS, f  ; increase position
    goto    motor_delay

go_ccw:
    call    ROTATE_CCW      ; counter-clockwise 1 step
    decf    CURRENT_POS, f  ; decrease position
    goto    motor_delay

stop_motor:
    ; Keep motor at current position (or can cut power but holding is better)
    goto    loop_end

motor_delay:
    ; Wait so movement is visible
    movlw   50              ; 50ms (speed adjustment here)
    call    DELAY_MS

loop_end:
    goto    loop

;====================================================================
; MOTOR DRIVERS
;====================================================================
ROTATE_CW:
    rlf     MOTOR_VAL, f    ; shift left
    btfss   MOTOR_VAL, 4    ; did 5th bit overflow?
    goto    output_motor
    movlw   0b00000001      ; wrap to begining (Bit 0)
    movwf   MOTOR_VAL
    goto    output_motor

ROTATE_CCW:
    bcf     STATUS, 0       ; clear carry (Important!)
    rrf     MOTOR_VAL, f    ; shift right
    btfsc   STATUS, 0       ; did carry become 1? (Bit 0 fell out?)
    goto    reload_ccw      ; yes, wrap around
    
    movf    MOTOR_VAL, w    ; also check if value became 0
    btfsc   STATUS, 2       ; zero flag check
    goto    reload_ccw
    goto    output_motor

reload_ccw:
    movlw   0b00001000      ; wrap to end (Bit 3)
    movwf   MOTOR_VAL

output_motor:
    movf    MOTOR_VAL, w
    andlw   0x0F            ; only lower 4 bits
    movwf   PORTB
    return

;====================================================================
; ADC and LCD FUNCTIONS (Kept Same)
;====================================================================
READ_ADC:
    andlw   0x07            ; clean channel number
    movwf   TEMP_RES
    rlf     TEMP_RES, f     ; shift left 3 times
    rlf     TEMP_RES, f
    rlf     TEMP_RES, f
    movlw   0b11000111      ; mask to clear channel
    andwf   ADCON0, f
    movf    TEMP_RES, w     ; set new channel
    iorwf   ADCON0, f
    movlw   2               ; acquisition time
    call    DELAY_MS
    bsf     ADCON0, 2       ; start conversion
wait_adc:
    btfsc   ADCON0, 2       ; wait for completion
    goto    wait_adc
    movf    ADRESH, w       ; read result
    return

SEND_NUMBER:
    ; Extract and display 3-digit number
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
    movf    TEMP_RES, w
    addlw   '0'
    call    LCD_SEND_CHAR
    return

INIT_PORTS:
    ; Configure all ports as needed
    BANKSEL TRISB
    clrf    TRISB           ; motor outputs
    clrf    TRISD           ; LCD data outputs
    clrf    TRISE           ; LCD control outputs
    movlw   0b00000100      ; ADC configuration
    movwf   ADCON1
    movlw   0b00000011      ; analog inputs
    movwf   TRISA
    BANKSEL PORTB
    clrf    PORTB           ; clear all ports
    clrf    PORTD
    clrf    PORTE
    return

INIT_ADC:
    ; Enable ADC module with Fosc/8 clock
    BANKSEL ADCON0
    movlw   0b01000001
    movwf   ADCON0
    return

LCD_INIT:
    ; Standard LCD initialization sequence
    movlw   20
    call    DELAY_MS
    movlw   0x30
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
    ; Send command to LCD
    movwf   PORTD
    bcf     PORTE, 0        ; RS = 0 for command
    call    PULSE_E
    movlw   2
    call    DELAY_MS
    return

LCD_CMD_NOWAIT:
    ; Send command without delay (init only)
    movwf   PORTD
    bcf     PORTE, 0
    call    PULSE_E
    return

LCD_SEND_CHAR:
    ; Send character to LCD
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


