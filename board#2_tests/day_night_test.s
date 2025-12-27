; --------------------------------------------------
; This DETECT DAY/NIGHT TEST code written in assembly
; and integrated by Tunahan Sanal for Home
; Automation MicroComputer Project_Board_2
; --------------------------------------------------
    

#include <xc.inc>

; CONFIGURATION BITS
    CONFIG FOSC = XT      ; crystal oscillator
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
    DELAY_VAR2:      DS 1    ; second delay
    TEMP_RES:        DS 1    ; temporary result
    BCD_H:           DS 1    ; hundreds digit
    BCD_T:           DS 1    ; tens digit
    BCD_O:           DS 1    ; ones digit
    MOTOR_VAL:       DS 1    ; motor coil state
    CURRENT_POS:     DS 1    ; current position
    TARGET_POS:      DS 1    ; target position
    LDR_VAL:         DS 1    ; light sensor value
    POT_VAL:         DS 1    ; potentiometer value

PSECT resetVec,class=CODE,delta=2
resetVec:
    goto    main

PSECT code,delta=2
main:
    call    INIT_PORTS      ; setup all ports
    call    LCD_INIT        ; initialize display
    call    INIT_ADC        ; enable analog converter
    
    ; Initial state: Motor at 0 (Open), first coil active
    movlw   0b00000001
    movwf   MOTOR_VAL
    movwf   PORTB
    clrf    CURRENT_POS     ; start position is 0

loop:
    ; --- 1. READ SENSORS ---
    movlw   0               ; channel 0
    call    READ_ADC
    movwf   LDR_VAL         ; save LDR reading

    movlw   1               ; channel 1
    call    READ_ADC
    movwf   POT_VAL         ; save potentiometer reading

    ; --- 2. NIGHT / DAY DECISION ---
    movlw   100             ; darkness threshold
    subwf   LDR_VAL, w
    btfss   STATUS, 0       ; if LDR < 100
    goto    mode_night
    
    ; DAY MODE: Target is potentiometer value
    movf    POT_VAL, w
    movwf   TARGET_POS
    goto    update_screen

mode_night:
    ; NIGHT MODE: Target is fully closed (255)
    movlw   255
    movwf   TARGET_POS

    ; --- 3. UPDATE DISPLAY ---
update_screen:
    ; First line
    movlw   0x80
    call    LCD_SEND_CMD
    
    ; Check if night mode for message
    movlw   100
    subwf   LDR_VAL, w
    btfss   STATUS, 0
    goto    print_night_msg
    
    ; Day mode message
    movlw   'H'
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
    movf    TARGET_POS, w
    movwf   TEMP_RES
    call    SEND_NUMBER
    ; Add spaces for cleaning
    movlw   ' '
    call    LCD_SEND_CHAR
    movlw   ' '
    call    LCD_SEND_CHAR
    goto    print_row2

print_night_msg:
    ; "GECE KAPALI" message (means "NIGHT CLOSED" in Turkish)
    movlw   'G'
    call    LCD_SEND_CHAR
    movlw   'E'
    call    LCD_SEND_CHAR
    movlw   'C'
    call    LCD_SEND_CHAR
    movlw   'E'
    call    LCD_SEND_CHAR
    movlw   ' '
    call    LCD_SEND_CHAR
    movlw   'K'
    call    LCD_SEND_CHAR
    movlw   'A'
    call    LCD_SEND_CHAR
    movlw   'P'
    call    LCD_SEND_CHAR
    movlw   'A'
    call    LCD_SEND_CHAR
    movlw   'L'
    call    LCD_SEND_CHAR
    movlw   'I'
    call    LCD_SEND_CHAR

print_row2:
    ; Second line: Motor position
    movlw   0xC0
    call    LCD_SEND_CMD
    movlw   'M'
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
    movf    CURRENT_POS, w
    movwf   TEMP_RES
    call    SEND_NUMBER

    ; --- 4. MOTOR MOVEMENT CONTROL (PDF LOGIC) ---
    movf    TARGET_POS, w
    subwf   CURRENT_POS, w
    
    btfsc   STATUS, 2       ; if equal (Zero=1) -> Stop
    goto    stop_motor
    
    btfss   STATUS, 0       ; if Carry=0 (Target > Current) -> Closing
    goto    closing_action  ; number must increase, direction CCW
    
    goto    opening_action  ; if Carry=1 (Target < Current) -> Opening

closing_action:
    ; Curtain is closing (0 -> 100%)
    ; PDF says: "closes ... CCW"
    call    ROTATE_CCW      ; rotate counter-clockwise
    incf    CURRENT_POS, f  ; increase position
    goto    motor_delay

opening_action:
    ; Curtain is opening (100% -> 0)
    ; PDF says: "opens ... CW"
    call    ROTATE_CW       ; rotate clockwise
    decf    CURRENT_POS, f  ; decrease position
    goto    motor_delay

stop_motor:
    goto    loop_end

motor_delay:
    movlw   50              ; 50ms speed control
    call    DELAY_MS

loop_end:
    goto    loop

;====================================================================
; MOTOR DRIVERS
;====================================================================
ROTATE_CW:
    ; Clockwise (CW) - 1 -> 2 -> 4 -> 8
    rlf     MOTOR_VAL, f    ; shift left
    btfss   MOTOR_VAL, 4    ; check overflow
    goto    output_motor
    movlw   1               ; wrap to begining
    movwf   MOTOR_VAL
    goto    output_motor

ROTATE_CCW:
    ; Counter-Clockwise (CCW) - 8 -> 4 -> 2 -> 1
    bcf     STATUS, 0       ; clear carry
    rrf     MOTOR_VAL, f    ; shift right
    btfsc   STATUS, 0       ; check if bit fell out
    goto    reload_ccw
    movf    MOTOR_VAL, w
    btfsc   STATUS, 2       ; check zero flag
    goto    reload_ccw
    goto    output_motor
reload_ccw:
    movlw   8               ; wrap to end
    movwf   MOTOR_VAL

output_motor:
    movf    MOTOR_VAL, w
    andlw   0x0F            ; only lower 4 bits
    movwf   PORTB
    return

;====================================================================
; HELPER FUNCTIONS
;====================================================================
READ_ADC:
    ; Read ADC from selected channel
    andlw   0x07            ; clean channel number
    movwf   TEMP_RES
    rlf     TEMP_RES, f     ; shift left 3 times
    rlf     TEMP_RES, f
    rlf     TEMP_RES, f
    movlw   0b11000111      ; mask to clear channel bits
    andwf   ADCON0, f
    movf    TEMP_RES, w     ; set new channel
    iorwf   ADCON0, f
    movlw   2               ; acquisition delay
    call    DELAY_MS
    bsf     ADCON0, 2       ; start conversion
wait_adc:
    btfsc   ADCON0, 2       ; wait until done
    goto    wait_adc
    movf    ADRESH, w       ; read result
    return

SEND_NUMBER:
    ; Display 3-digit number on LCD
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
    ; Configure all ports for operation
    BANKSEL TRISB
    clrf    TRISB           ; motor outputs
    clrf    TRISD           ; LCD data
    clrf    TRISE           ; LCD control
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
    ; Enable ADC module
    BANKSEL ADCON0
    movlw   0b01000001      ; Fosc/8, ADC on
    movwf   ADCON0
    return

LCD_INIT:
    ; Standard LCD initialization
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
    movlw   0x01            ; clear screen
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
    ; Send command without delay
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


