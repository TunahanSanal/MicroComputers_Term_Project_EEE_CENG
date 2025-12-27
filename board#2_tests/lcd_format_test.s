; --------------------------------------------------
; This LCD REPORT FORMAT TEST code written in assembly
; and integrated by Tunahan Sanal for Home
; Automation MicroComputer Project_Board_2
; Line 1: sTTT C PPPP hPa (Temperature and Pressure - Fixed for now)
; Line 2: LLL Lux CCC %   (Light and Curtain Percentage)
;====================================================================

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
    
    ; System Variables
    MOTOR_VAL:       DS 1    ; motor coil state
    CURRENT_POS:     DS 1    ; current position
    TARGET_POS:      DS 1    ; target position
    LDR_VAL:         DS 1    ; light sensor value
    POT_VAL:         DS 1    ; potentiometer value
    
    ; Math Variables
    MATH_L:          DS 1    ; low byte for calculations
    MATH_H:          DS 1    ; high byte for calculations
    PERCENT_VAL:     DS 1    ; percentage value

PSECT resetVec,class=CODE,delta=2
resetVec:
    goto    main

PSECT code,delta=2
main:
    call    INIT_PORTS      ; setup ports
    call    LCD_INIT        ; initialize display
    call    INIT_ADC        ; enable ADC
    
    ; Initial settings
    movlw   0b00000001
    movwf   MOTOR_VAL
    movwf   PORTB
    clrf    CURRENT_POS     ; start at position 0

    ; --- WRITE SCREEN TEMPLATE ONCE (Fixed parts) ---
    ; Line 1: "T:+00C P:0000hPa" (Pressure and temp will come alive in Step B)
    movlw   0x80
    call    LCD_SEND_CMD
    
    ; T:+00C
    movlw   'T'
    call    LCD_SEND_CHAR
    movlw   ':'
    call    LCD_SEND_CHAR
    movlw   '+'
    call    LCD_SEND_CHAR
    movlw   '0'
    call    LCD_SEND_CHAR
    movlw   '0'
    call    LCD_SEND_CHAR
    movlw   'C'
    call    LCD_SEND_CHAR
    
    movlw   ' '
    call    LCD_SEND_CHAR
    
    ; P:0000hPa
    movlw   'P'
    call    LCD_SEND_CHAR
    movlw   ':'
    call    LCD_SEND_CHAR
    movlw   '0'
    call    LCD_SEND_CHAR
    movlw   '0'
    call    LCD_SEND_CHAR
    movlw   '0'
    call    LCD_SEND_CHAR
    movlw   '0'
    call    LCD_SEND_CHAR
    movlw   'h'             ; if hPa doesnt fit we can write just hP, lets try for now
    call    LCD_SEND_CHAR
    movlw   'P'
    call    LCD_SEND_CHAR
    movlw   'a'
    call    LCD_SEND_CHAR

loop:
    ; --- 1. READ SENSORS ---
    movlw   0               ; channel 0
    call    READ_ADC
    movwf   LDR_VAL         ; save light reading

    movlw   1               ; channel 1
    call    READ_ADC
    movwf   POT_VAL         ; save pot reading

    ; --- 2. NIGHT / DAY DECISION ---
    movlw   100             ; darkness threshold
    subwf   LDR_VAL, w
    btfss   STATUS, 0
    goto    mode_night
    
    ; DAY MODE
    movf    POT_VAL, w
    movwf   TARGET_POS
    goto    calc_percent

mode_night:
    ; NIGHT MODE (Fully closed)
    movlw   255
    movwf   TARGET_POS

    ; --- 3. PERCENTAGE CALCULATION (0-255 -> 0-100%) ---
calc_percent:
    ; Formula: (Current_Pos * 100) / 256
    ; PIC16F has no multiply, we'll use addition: Val * 100 = Val*(64+32+4)
    
    clrf    MATH_H
    clrf    MATH_L
    
    ; x4
    bcf     STATUS, 0
    rlf     CURRENT_POS, w  ; x2
    movwf   MATH_L
    rlf     MATH_H, f
    bcf     STATUS, 0
    rlf     MATH_L, f       ; x4
    rlf     MATH_H, f
    
    ; MATH_H:MATH_L is now (Pos * 4). Let's save this.
    ; But this takes alot of space. Lets do simple "lookup" or aproximate calculation.
    ; Practical Approach: % = (Pos * 10) / 25
    ; Or simpler: % = Pos / 2.5
    ; Simplest: Instead of multiply simulation, lets use ratio.
    
    ; Simplified Multiply (Software based):
    ; MATH = CURRENT_POS
    ; Adding 100 times takes too long. 
    ; Shortcut: aproximate (Pos x 100) >> 8 operation.
    ; Its like multiplying Pos by 0.4.
    
    ; For assembly beginers, cleanest "Percentage" trick:
    ; (Pos / 2) - (Pos / 8) lets not bother with that.
    ; I'll directly show CURRENT_POS value but put "%" next to it.
    ; Report wants "0-100%". 
    ; Lets multiply with simple loop (Current_Pos * 100).
    ; Result will be 16 bit. Then we'll take upper byte.
    
    clrf    MATH_H
    movf    CURRENT_POS, w
    movwf   MATH_L      ; MATH_L = Pos
    
    ; * 100 operation: 100 = 64 + 32 + 4
    ; Pos << 6 + Pos << 5 + Pos << 2
    ; This can be too complicated.
    ; Alternative: Just divide "Current Position" by 2 and write (will be like 0-128% but managable).
    ; Wait, lets do it properly: (Pos * 10) / 26
    
    ; Very simple aproximation:
    bcf     STATUS, 0
    rrf     CURRENT_POS, w  ; divide by 2 (0-127)
    movwf   PERCENT_VAL     ; use this as aproximate % for now.
    ; (If you want more accurate we fix in Step B)

    ; --- 4. UPDATE DISPLAY (Only bottom line) ---
    ; Line 2: "L:xxxLux C:xxx%"
    movlw   0xC0
    call    LCD_SEND_CMD
    
    movlw   'L'
    call    LCD_SEND_CHAR
    movlw   ':'
    call    LCD_SEND_CHAR
    
    movf    LDR_VAL, w
    movwf   TEMP_RES
    call    SEND_NUMBER_3DIGIT  ; write 3 digits
    
    movlw   'L'
    call    LCD_SEND_CHAR
    movlw   'u'
    call    LCD_SEND_CHAR
    movlw   'x'
    call    LCD_SEND_CHAR
    movlw   ' '
    call    LCD_SEND_CHAR
    
    movlw   'C'
    call    LCD_SEND_CHAR
    movlw   ':'
    call    LCD_SEND_CHAR
    
    movf    PERCENT_VAL, w      ; calculated percentage
    movwf   TEMP_RES
    call    SEND_NUMBER_3DIGIT
    
    movlw   '%'
    call    LCD_SEND_CHAR

    ; --- 5. MOTOR MOVEMENT ---
    movf    TARGET_POS, w
    subwf   CURRENT_POS, w
    btfsc   STATUS, 2       ; if equal
    goto    stop_motor
    btfss   STATUS, 0       ; if target bigger
    goto    closing
    goto    opening

closing:
    call    ROTATE_CCW      ; close curtain
    incf    CURRENT_POS, f
    goto    motor_delay
opening:
    call    ROTATE_CW       ; open curtain
    decf    CURRENT_POS, f
    goto    motor_delay
stop_motor:
    goto    loop_end
motor_delay:
    movlw   50              ; 50ms delay
    call    DELAY_MS
loop_end:
    goto    loop

;====================================================================
; MOTOR DRIVER (PDF Compatible)
;====================================================================
ROTATE_CW:
    rlf     MOTOR_VAL, f    ; shift left
    btfss   MOTOR_VAL, 4    ; check overflow
    goto    output_motor
    movlw   1               ; wrap around
    movwf   MOTOR_VAL
    goto    output_motor
ROTATE_CCW:
    bcf     STATUS, 0       ; clear carry
    rrf     MOTOR_VAL, f    ; shift right
    btfsc   STATUS, 0       ; check carry
    goto    reload_ccw
    movf    MOTOR_VAL, w
    btfsc   STATUS, 2       ; check zero
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
    andlw   0x07            ; clean channel number
    movwf   TEMP_RES
    rlf     TEMP_RES, f     ; shift left 3 times
    rlf     TEMP_RES, f
    rlf     TEMP_RES, f
    movlw   0b11000111      ; mask for channel bits
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

; --- NEW 3 DIGIT PRINTING (005, 023, 150 etc.) ---
SEND_NUMBER_3DIGIT:
    ; Extract and display 3-digit number with leading zeros
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
    ; Configure all ports
    BANKSEL TRISB
    clrf    TRISB           ; motor outputs
    clrf    TRISD           ; LCD data
    clrf    TRISE           ; LCD control
    movlw   0b00000100      ; ADC config
    movwf   ADCON1
    movlw   0b00000011      ; analog inputs
    movwf   TRISA
    BANKSEL PORTB
    clrf    PORTB           ; clear outputs
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


