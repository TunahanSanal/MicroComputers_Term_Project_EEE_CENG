; ------------------------------------------------------------------
; This UART TEST code written in assembly with serial port COM6-COM7
; and integrated by Tunahan Sanal for Home
; Automation MicroComputer Project_Board_2
; ------------------------------------------------------------------
    
#include <xc.inc>

; --- CONFIGURATION BITS ---
CONFIG FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF

; --- VARIABLES ---
PSECT udata_bank0
    DELAY_VAR1:      DS 1    ; delay counter variable
    DELAY_VAR2:      DS 1    ; second delay variable
    TEMP_W:          DS 1    ; temporary working register
    BCD_H:           DS 1    ; hundreds digit for BCD
    BCD_T:           DS 1    ; tens digit
    BCD_O:           DS 1    ; ones digit
    CURTAIN_DESIRED: DS 1    ; target curtain postion
    CURTAIN_CURRENT: DS 1    ; actual curtain position
    LIGHT_VAL:       DS 1    ; light sensor reading
    TEMP_OUT:        DS 1    ; temperature output value
    PRESS_OUT:       DS 1    ; pressure output value
    MOTOR_PHASE:     DS 1    ; motor phase state
    UART_TICK:       DS 1    ; UART transmision counter
    RX_DATA:         DS 1    ; received data buffer

PSECT resetVec,class=CODE,delta=2
resetVec:
    goto    main

PSECT code,delta=2
main:
    call    INIT_PORTS      ; initialize all ports
    call    INIT_UART       ; setup UART comunication
    call    LCD_INIT        ; initialize LCD display
    call    INIT_ADC        ; enable ADC module
    
    ; Initial motor phase setup
    movlw   0b00000001
    movwf   MOTOR_PHASE
    clrf    CURTAIN_CURRENT
    clrf    UART_TICK
    
    ; Fixed temperature and pressure values
    movlw   40              ; 40 degrees celsius
    movwf   TEMP_OUT
    movlw   37              ; for 1037 hPa pressure
    movwf   PRESS_OUT
    
    ; Send startup message to serial port
    movlw   'S'
    call    UART_TX
    movlw   'Y'
    call    UART_TX
    movlw   'S'
    call    UART_TX
    movlw   'T'
    call    UART_TX
    movlw   'E'
    call    UART_TX
    movlw   'M'
    call    UART_TX
    movlw   ' '
    call    UART_TX
    movlw   'O'
    call    UART_TX
    movlw   'K'
    call    UART_TX
    movlw   0x0D            ; carriage return
    call    UART_TX
    movlw   0x0A            ; line feed
    call    UART_TX
    
loop:
    ; 1. Read analog sensors (LDR and Potentiometer)
    movlw   0               ; select AN0 channel (LDR)
    call    READ_ADC
    movwf   LIGHT_VAL
    
    movlw   1               ; select AN1 channel (Pot for curtain position)
    call    READ_ADC
    movwf   TEMP_W
    
    ; 2. Automation logic - day/night mode decision
    movlw   100             ; threshold value
    subwf   LIGHT_VAL, w
    btfss   STATUS, 0       ; if LDR > 100 then day mode
    goto    mode_night
    
    ; Day mode: curtain position based on potentiometer
    movf    TEMP_W, w
    movwf   CURTAIN_DESIRED
    goto    do_motor
    
mode_night:
    ; Night mode: close curtain completly
    movlw   255             
    movwf   CURTAIN_DESIRED

do_motor:
    call    UPDATE_MOTOR    ; update motor position
    call    UPDATE_LCD      ; refresh LCD dispaly
    
    ; 3. Automatic UART transmision (every 30 loops)
    incf    UART_TICK, f
    movlw   30              
    subwf   UART_TICK, w
    btfss   STATUS, 2       
    goto    skip_auto
    clrf    UART_TICK       
    
    ; Send curtain position via UART
    movlw   'P'
    call    UART_TX
    movlw   ':'
    call    UART_TX
    movf    CURTAIN_CURRENT, w
    movwf   TEMP_W
    call    UART_SEND_NUMBER_3
    
skip_auto:
    ; 4. Check for incoming UART data
    call    CHECK_UART      
    
    movlw   10              ; 10ms delay
    call    DELAY_MS
    goto    loop            ; repeat main loop

; === UART COMMUNICATION FUNCTIONS ===
INIT_UART:
    bsf     STATUS, 5       ; switch to Bank 1
    
    ; UART pin configuration: RC6=TX(Output), RC7=RX(Input)
    bcf     TRISC, 6        ; RC6 = TX output
    bsf     TRISC, 7        ; RC7 = RX input
    
    ; 9600 Baud rate (for 4MHz crystal with BRGH=1)
    movlw   25
    movwf   SPBRG
    
    ; TXSTA register: enable transmit and high speed mode
    movlw   0b00100100
    movwf   TXSTA
    
    bcf     STATUS, 5       ; back to Bank 0
    
    ; RCSTA register: enable serial port and continuous receive
    movlw   0b10010000
    movwf   RCSTA
    
    movlw   10              ; small delay for UART stabilization
    call    DELAY_MS
    return

CHECK_UART:
    ; Check for overrun error
    btfsc   RCSTA, 1        ; OERR bit check
    goto    fix_uart_err
    
    ; Is there any data received?
    btfss   PIR1, 5         ; RCIF flag
    return
    
    movf    RCREG, w        ; read received byte
    movwf   RX_DATA
    
    ; Check if its '1' character (ASCII 0x31)
    sublw   '1'
    btfss   STATUS, 2
    return
    
    ; If we received '1', send response
    movlw   'O'
    call    UART_TX
    movlw   'K'
    call    UART_TX
    movlw   0x0D            ; CR
    call    UART_TX
    movlw   0x0A            ; LF
    call    UART_TX
    return

fix_uart_err:
    bcf     RCSTA, 4        ; clear CREN bit
    nop
    bsf     RCSTA, 4        ; set CREN again
    return

UART_TX:
    movwf   RX_DATA         ; save character temporarly
wait_tx:
    btfss   PIR1, 4         ; wait until TXIF is set
    goto    wait_tx
    movf    RX_DATA, w
    movwf   TXREG           ; transmit character
    return

UART_SEND_NUMBER_3:
    ; Convert 3-digit number to ASCII and send with newline
    clrf    BCD_H
    clrf    BCD_T
u3_100:
    movlw   100
    subwf   TEMP_W, w
    btfss   STATUS, 0
    goto    u3_10
    movwf   TEMP_W
    incf    BCD_H, f
    goto    u3_100
u3_10:
    movlw   10
    subwf   TEMP_W, w
    btfss   STATUS, 0
    goto    u3_send
    movwf   TEMP_W
    incf    BCD_T, f
    goto    u3_10
u3_send:
    movf    BCD_H, w
    addlw   '0'
    call    UART_TX
    movf    BCD_T, w
    addlw   '0'
    call    UART_TX
    movf    TEMP_W, w
    addlw   '0'
    call    UART_TX
    movlw   0x0D            ; CR
    call    UART_TX
    movlw   0x0A            ; LF
    call    UART_TX
    return

; === MOTOR AND LCD CONTROL ===
UPDATE_MOTOR:
    ; Compare desired and current curtain positions
    movf    CURTAIN_DESIRED, w
    subwf   CURTAIN_CURRENT, w
    btfsc   STATUS, 2       ; if equal, don't move
    return
    btfss   STATUS, 0       ; if CURRENT < DESIRED go counter-clockwise
    goto    step_ccw
    
step_cw:
    ; Clockwise rotation (curtain closing)
    rlf     MOTOR_PHASE, f
    btfsc   MOTOR_PHASE, 4
    movlw   1
    btfsc   MOTOR_PHASE, 4
    movwf   MOTOR_PHASE
    decf    CURTAIN_CURRENT, f
    goto    m_out
    
step_ccw:
    ; Counter-clockwise rotation (curtain opening)
    bcf     STATUS, 0
    rrf     MOTOR_PHASE, f
    btfsc   STATUS, 0
    movlw   8
    btfsc   STATUS, 0
    movwf   MOTOR_PHASE
    incf    CURTAIN_CURRENT, f
    
m_out:
    ; Output motor phase to PORTB
    movf    MOTOR_PHASE, w
    andlw   0x0F
    movwf   PORTB
    return

UPDATE_LCD:
    ; === FIRST LINE: +063°C 1082hPa ===
    movlw   0x80            ; set cursor to first line
    call    LCD_SEND_CMD
    
    ; Display temperature: +063°C
    movlw   '+'
    call    LCD_SEND_CHAR
    movf    TEMP_OUT, w
    movwf   TEMP_W
    call    SEND_NUMBER_3
    movlw   0xDF            ; degree symbol
    call    LCD_SEND_CHAR
    movlw   'C'
    call    LCD_SEND_CHAR
    movlw   ' '
    call    LCD_SEND_CHAR
    
    ; Display pressure: 1082hPa
    movlw   '1'
    call    LCD_SEND_CHAR
    movlw   '0'
    call    LCD_SEND_CHAR
    movf    PRESS_OUT, w
    movwf   TEMP_W
    call    SEND_NUMBER_2
    movlw   'h'
    call    LCD_SEND_CHAR
    movlw   'P'
    call    LCD_SEND_CHAR
    movlw   'a'
    call    LCD_SEND_CHAR
    
    ; === SECOND LINE: 006Lux 254% ===
    movlw   0xC0            ; set cursor to second line
    call    LCD_SEND_CMD
    
    ; Display LDR value: 006Lux
    movf    LIGHT_VAL, w
    movwf   TEMP_W
    call    SEND_NUMBER_3
    movlw   'L'
    call    LCD_SEND_CHAR
    movlw   'u'
    call    LCD_SEND_CHAR
    movlw   'x'
    call    LCD_SEND_CHAR
    movlw   ' '
    call    LCD_SEND_CHAR
    
    ; Display curtain position: 254%
    movf    CURTAIN_CURRENT, w
    movwf   TEMP_W
    call    SEND_NUMBER_3
    movlw   '%'
    call    LCD_SEND_CHAR
    
    return

; === LCD DISPLAY FUNCTIONS ===
LCD_INIT:
    ; LCD initialization sequence
    movlw   20              ; wait 20ms for LCD power up
    call    DELAY_MS
    movlw   0x38            ; 8-bit mode, 2 lines, 5x8 font
    call    LCD_SEND_CMD
    movlw   0x0C            ; display on, cursor off
    call    LCD_SEND_CMD
    movlw   0x01            ; clear display
    call    LCD_SEND_CMD
    movlw   5
    call    DELAY_MS
    return

LCD_SEND_CMD:
    movwf   PORTD
    bcf     PORTE, 0        ; RS = 0 for command mode
    call    PULSE_E
    movlw   2
    call    DELAY_MS
    return

LCD_SEND_CHAR:
    movwf   PORTD
    bsf     PORTE, 0        ; RS = 1 for data mode
    call    PULSE_E
    movlw   1
    call    DELAY_MS
    return

PULSE_E:
    ; Generate enable pulse for LCD
    bsf     PORTE, 1        ; E = high
    nop
    nop
    bcf     PORTE, 1        ; E = low
    return

SEND_NUMBER_3:
    ; Convert 3-digit number to ASCII for LCD
    clrf    BCD_H
    clrf    BCD_T
n3_100:
    movlw   100
    subwf   TEMP_W, w
    btfss   STATUS, 0
    goto    n3_10
    movwf   TEMP_W
    incf    BCD_H, f
    goto    n3_100
n3_10:
    movlw   10
    subwf   TEMP_W, w
    btfss   STATUS, 0
    goto    n3_print
    movwf   TEMP_W
    incf    BCD_T, f
    goto    n3_10
n3_print:
    movf    BCD_H, w
    addlw   '0'
    call    LCD_SEND_CHAR
    movf    BCD_T, w
    addlw   '0'
    call    LCD_SEND_CHAR
    movf    TEMP_W, w
    addlw   '0'
    call    LCD_SEND_CHAR
    return

SEND_NUMBER_2:
    ; Convert 2-digit number to ASCII for LCD
    clrf    BCD_T
n2_10:
    movlw   10
    subwf   TEMP_W, w
    btfss   STATUS, 0
    goto    n2_print
    movwf   TEMP_W
    incf    BCD_T, f
    goto    n2_10
n2_print:
    movf    BCD_T, w
    addlw   '0'
    call    LCD_SEND_CHAR
    movf    TEMP_W, w
    addlw   '0'
    call    LCD_SEND_CHAR
    return

; === PORT CONFIGURATION AND ADC SETUP ===
INIT_PORTS:
    bsf     STATUS, 5       ; switch to Bank 1
    
    clrf    TRISB           ; PORTB = output for stepper motor
    clrf    TRISD           ; PORTD = output for LCD data pins
    clrf    TRISE           ; PORTE = output for LCD control pins
    
    movlw   0b00000011      ; RA0, RA1 = inputs for analog sensors
    movwf   TRISA
    
    ; UART pins configured in INIT_UART function
    movlw   0b10000000      ; RC7 = input for RX
    movwf   TRISC
    
    movlw   0b00000100      ; AN0, AN1 as analog, rest digital
    movwf   ADCON1
    
    bcf     STATUS, 5       ; back to Bank 0
    
    ; Clear all output ports
    clrf    PORTB
    clrf    PORTD
    clrf    PORTE
    return

INIT_ADC:
    ; ADC configuration: enabled, Fosc/8 clock, channel AN0 selected
    movlw   0b01000001
    movwf   ADCON0
    return

READ_ADC:
    ; Select ADC channel and perform conversion
    andlw   0x07            ; mask channel number
    movwf   TEMP_W
    rlf     TEMP_W, f       ; shift left 3 times
    rlf     TEMP_W, f
    rlf     TEMP_W, f
    movlw   0b11000111      ; clear channel bits
    andwf   ADCON0, f
    movf    TEMP_W, w       ; set new channel
    iorwf   ADCON0, f
    movlw   2               ; settling time delay
    call    DELAY_MS
    bsf     ADCON0, 2       ; start conversion (GO/DONE bit)
wait_adc:
    btfsc   ADCON0, 2       ; wait for conversion complete
    goto    wait_adc
    movf    ADRESH, w       ; read result (8-bit mode)
    return

DELAY_MS:
    ; Simple delay function (aproximately 1ms per count at 4MHz)
    movwf   DELAY_VAR2
delay_outer:
    movlw   250
    movwf   DELAY_VAR1
delay_inner:
    nop
    decfsz  DELAY_VAR1, f
    goto    delay_inner
    decfsz  DELAY_VAR2, f
    goto    delay_outer
    return

END resetVec