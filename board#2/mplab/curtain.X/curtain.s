; --------------------------------------------------
; Board#2 main code written in Assembly and wroted by Tunahan Sanal
; OTOMAT?K MOD EKLEND? - 'A' KOMUTU DESTE??
; --------------------------------------------------

#include <xc.inc>

; --- Configuration ---
CONFIG FOSC = XT, WDTE = OFF, PWRTE = ON, BOREN = OFF, LVP = OFF, CPD = OFF, WRT = OFF, CP = OFF

; --- Variables ---
PSECT udata_bank0
    DELAY_VAR1:      DS 1
    DELAY_VAR2:      DS 1
    TEMP_W:          DS 1
    BCD_H:           DS 1
    BCD_T:           DS 1
    BCD_O:           DS 1
    CURTAIN_DESIRED: DS 1
    CURTAIN_CURRENT: DS 1
    LIGHT_VAL:       DS 1
    TEMP_OUT:        DS 1
    PRESS_OUT:       DS 1
    MOTOR_PHASE:     DS 1
    UART_TICK:       DS 1
    RX_DATA:         DS 1
    CONTROL_MODE:    DS 1    ; 0:Otomatik (POT+LDR), 1:PC Kontrol
    SCALE_VAR:       DS 1
    STEP_COUNTER:    DS 1

PSECT resetVec,class=CODE,delta=2
resetVec:
    goto    main

PSECT code,delta=2
main:
    call    INIT_PORTS
    call    INIT_UART
    call    LCD_INIT
    call    INIT_ADC
    
    ; Setup
    movlw   0b00000001
    movwf   MOTOR_PHASE
    clrf    CURTAIN_CURRENT
    clrf    UART_TICK
    clrf    CONTROL_MODE     ; ? Ba?lang?çta OTOMAT?K MOD
    
    ; Dummy Values
    movlw   40
    movwf   TEMP_OUT
    movlw   37
    movwf   PRESS_OUT
    
    ; Ready Message
    movlw   'O'
    call    UART_TX
    movlw   'K'
    call    UART_TX
    movlw   0x0D
    call    UART_TX
    movlw   0x0A
    call    UART_TX
    
loop:
    ; --- 1. SENSOR FUSION ---
    movlw   0           ; LDR
    call    READ_ADC
    movwf   LIGHT_VAL
    
    movlw   1           ; POT
    call    READ_ADC
    call    SCALE_CONVERT 
    movwf   TEMP_W      
    
    ; --- 2. Control Logic ---
    ; I??k < 100 ise gece modu
    movlw   100
    subwf   LIGHT_VAL, w
    btfss   STATUS, 0   
    goto    force_night_mode
    
    ; PC Kontrol Modunda m??
    btfsc   CONTROL_MODE, 0
    goto    do_motor_update     ; PC modunda -> Potansiyometre/LDR dinleme!
    
    ; ? OTOMAT?K MOD: Potansiyometreyi dinle!
    movf    TEMP_W, w
    movwf   CURTAIN_DESIRED
    goto    do_motor_update

force_night_mode:
    movlw   100         
    movwf   CURTAIN_DESIRED

do_motor_update:
    call    UPDATE_MOTOR
    call    UPDATE_LCD
    
    ; --- 3. Burst ---
    incf    UART_TICK, f
    movlw   30
    subwf   UART_TICK, w
    btfss   STATUS, 2
    goto    skip_tx
    clrf    UART_TICK
    
    ; T:xxx B:xxxx L:xxx P:xxx
    movlw   'T'
    call    UART_TX
    movlw   ':'
    call    UART_TX
    movf    TEMP_OUT, w
    movwf   TEMP_W
    call    UART_SEND_NUMBER_3
    
    movlw   'B'
    call    UART_TX
    movlw   ':'
    call    UART_TX
    movlw   '1'
    call    UART_TX
    movlw   '0'
    call    UART_TX
    movf    PRESS_OUT, w
    movwf   TEMP_W
    call    UART_SEND_NUMBER_2_NOLINE
    movlw   ' '
    call    UART_TX
    
    movlw   'L'
    call    UART_TX
    movlw   ':'
    call    UART_TX
    movf    LIGHT_VAL, w
    movwf   TEMP_W
    call    UART_SEND_NUMBER_3_NOLINE
    movlw   ' '
    call    UART_TX
    
    movlw   'P'
    call    UART_TX
    movlw   ':'
    call    UART_TX
    movf    CURTAIN_CURRENT, w
    movwf   TEMP_W
    call    UART_SEND_NUMBER_3
    
skip_tx:
    ; --- 4. PC CONTROL CHECK ---
    call    CHECK_UART
    
    movlw   5
    call    DELAY_MS
    goto    loop

; === STEP MOTOR ===
UPDATE_MOTOR:
    movf    CURTAIN_DESIRED, w
    subwf   CURTAIN_CURRENT, w
    btfsc   STATUS, 2      
    return
    
    btfss   STATUS, 0      
    goto    move_ccw
    
move_cw:    
    movlw   10
    movwf   STEP_COUNTER
cw_loop:
    rlf     MOTOR_PHASE, f
    btfsc   MOTOR_PHASE, 4
    movlw   1
    btfsc   MOTOR_PHASE, 4
    movwf   MOTOR_PHASE
    movf    MOTOR_PHASE, w
    andlw   0x0F
    movwf   PORTB
    movlw   3
    call    DELAY_MS
    decfsz  STEP_COUNTER, f
    goto    cw_loop
    decf    CURTAIN_CURRENT, f 
    return

move_ccw:   
    movlw   10
    movwf   STEP_COUNTER
ccw_loop:
    bcf     STATUS, 0
    rrf     MOTOR_PHASE, f
    btfsc   STATUS, 0
    movlw   8
    btfsc   STATUS, 0
    movwf   MOTOR_PHASE
    movf    MOTOR_PHASE, w
    andlw   0x0F
    movwf   PORTB
    movlw   3
    call    DELAY_MS
    decfsz  STEP_COUNTER, f
    goto    ccw_loop
    incf    CURTAIN_CURRENT, f 
    return


; SCALE_CONVERT
SCALE_CONVERT:
    movwf   SCALE_VAR
    clrf    TEMP_W      ; TEMPORARY WORKING REG
    
s_loop: 
    ; ASSUME THAT ITS AN EQUATION
    ; 255/100=2.55
    movlw   5           ; APPROXIMATION
    subwf   SCALE_VAR, f
    btfss   STATUS, 0   ; IF ITS NEGATIVE
    goto    s_done
    
    movlw   2           ; PROPORTION OF 2.5
    addwf   TEMP_W, f
    goto    s_loop

s_done:
    ; OVERFLOW PROTECTION
    movlw   100
    subwf   TEMP_W, w
    btfsc   STATUS, 0
    retlw   100
    movf    TEMP_W, w
    return

INIT_UART:
    bsf     STATUS, 5
    bcf     TRISC, 6
    bsf     TRISC, 7
    movlw   25          
    movwf   SPBRG
    movlw   0b00100100  
    movwf   TXSTA
    bcf     STATUS, 5
    movlw   0b10010000  
    movwf   RCSTA
    return

; ============================================
; ? KR?T?K DE????KL?K: 'A' VE 'C' KOMUTU DESTE??
; ============================================
CHECK_UART:
    btfsc   RCSTA, 1
    goto    fix_err
    btfss   PIR1, 5
    return
    movf    RCREG, w
    movwf   RX_DATA
    
    ; --- 'A' COMMAND (OTOMAT?K MOD) ---
    movf    RX_DATA, w
    sublw   'A'
    btfsc   STATUS, 2
    goto    set_auto_mode
    
    ; --- 'C' COMMAND (PC KONTROL) ---
    movf    RX_DATA, w
    sublw   'C'
    btfsc   STATUS, 2
    goto    get_pc_val
    
    return

; ? YEN?: Otomatik Moda Geç
set_auto_mode:
    clrf    CONTROL_MODE    ; 0 = Otomatik (POT + LDR aktif)
    ; Onay mesaj? gönder (opsiyonel)
    movlw   'A'
    call    UART_TX
    movlw   'U'
    call    UART_TX
    movlw   'T'
    call    UART_TX
    movlw   'O'
    call    UART_TX
    movlw   0x0D
    call    UART_TX
    movlw   0x0A
    call    UART_TX
    return

; ? GÜNCELLEME: PC Kontrol Modu
get_pc_val:
    call    UART_RX_WAIT
    ; PC'den gelen de?er 0-100 aras?
    movwf   CURTAIN_DESIRED
    movlw   1
    movwf   CONTROL_MODE    ; 1 = PC Kontrol (POT/LDR pasif)
    return

fix_err:
    bcf     RCSTA, 4
    nop
    bsf     RCSTA, 4
    return

UART_RX_WAIT:
    btfss   PIR1, 5
    goto    UART_RX_WAIT
    movf    RCREG, w
    return

UART_TX:
    movwf   RX_DATA
wait_tx:
    btfss   PIR1, 4
    goto    wait_tx
    movf    RX_DATA, w
    movwf   TXREG
    return

; --- DISPLAY FUNCTIONS---
UART_SEND_NUMBER_3:
    clrf BCD_H
    clrf BCD_T
u3_100:
    movlw 100
    subwf TEMP_W, w
    btfss STATUS, 0
    goto u3_10
    movwf TEMP_W
    incf BCD_H, f
    goto u3_100
u3_10:
    movlw 10
    subwf TEMP_W, w
    btfss STATUS, 0
    goto u3_send
    movwf TEMP_W
    incf BCD_T, f
    goto u3_10
u3_send:
    movf BCD_H, w
    addlw '0'
    call UART_TX
    movf BCD_T, w
    addlw '0'
    call UART_TX
    movf TEMP_W, w
    addlw '0'
    call UART_TX
    movlw 0x0D      
    call UART_TX
    movlw 0x0A
    call UART_TX
    return

UART_SEND_NUMBER_3_NOLINE:
    clrf BCD_H
    clrf BCD_T
u3n_100:
    movlw 100
    subwf TEMP_W, w
    btfss STATUS, 0
    goto u3n_10
    movwf TEMP_W
    incf BCD_H, f
    goto u3n_100
u3n_10:
    movlw 10
    subwf TEMP_W, w
    btfss STATUS, 0
    goto u3n_send
    movwf TEMP_W
    incf BCD_T, f
    goto u3n_10
u3n_send:
    movf BCD_H, w
    addlw '0'
    call UART_TX
    movf BCD_T, w
    addlw '0'
    call UART_TX
    movf TEMP_W, w
    addlw '0'
    call UART_TX
    return

UART_SEND_NUMBER_2_NOLINE:
    clrf BCD_T
u2n_10:
    movlw 10
    subwf TEMP_W, w
    btfss STATUS, 0
    goto u2n_send
    movwf TEMP_W
    incf BCD_T, f
    goto u2n_10
u2n_send:
    movf BCD_T, w
    addlw '0'
    call UART_TX
    movf TEMP_W, w
    addlw '0'
    call UART_TX
    return

UPDATE_LCD:
    movlw   0x80
    call    LCD_SEND_CMD
    movlw   '+'
    call    LCD_SEND_CHAR
    movf    TEMP_OUT, w
    movwf   TEMP_W
    call    SEND_NUMBER_3
    movlw   0xDF
    call    LCD_SEND_CHAR
    movlw   'C'
    call    LCD_SEND_CHAR
    movlw   ' '
    call    LCD_SEND_CHAR
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
    movlw   0xC0
    call    LCD_SEND_CMD
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
    movf    CURTAIN_CURRENT, w
    movwf   TEMP_W
    call    SEND_NUMBER_3
    movlw   '%'
    call    LCD_SEND_CHAR
    return

LCD_INIT:
    movlw   20
    call    DELAY_MS
    movlw   0x38
    call    LCD_SEND_CMD
    movlw   0x0C
    call    LCD_SEND_CMD
    movlw   0x01
    call    LCD_SEND_CMD
    movlw   5
    call    DELAY_MS
    return

LCD_SEND_CMD:
    movwf   PORTD
    bcf     PORTE, 0
    call    PULSE_E
    movlw   2
    call    DELAY_MS
    return

LCD_SEND_CHAR:
    movwf   PORTD
    bsf     PORTE, 0
    call    PULSE_E
    movlw   1
    call    DELAY_MS
    return

PULSE_E:
    bsf     PORTE, 1
    nop
    nop
    bcf     PORTE, 1
    return

SEND_NUMBER_3:
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

INIT_PORTS:
    bsf     STATUS, 5
    clrf    TRISB
    clrf    TRISD
    clrf    TRISE
    movlw   0b00000011
    movwf   TRISA
    movlw   0b10000000
    movwf   TRISC
    movlw   0b00000100
    movwf   ADCON1
    bcf     STATUS, 5
    clrf    PORTB
    clrf    PORTD
    clrf    PORTE
    return

INIT_ADC:
    movlw   0b01000001
    movwf   ADCON0
    return

READ_ADC:
    andlw   0x07
    movwf   TEMP_W
    rlf     TEMP_W, f
    rlf     TEMP_W, f
    rlf     TEMP_W, f
    movlw   0b11000111
    andwf   ADCON0, f
    movf    TEMP_W, w
    iorwf   ADCON0, f
    movlw   2
    call    DELAY_MS
    bsf     ADCON0, 2
wait_adc:
    btfsc   ADCON0, 2
    goto    wait_adc
    movf    ADRESH, w
    return

DELAY_MS:
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