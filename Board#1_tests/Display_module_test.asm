;******************************************************************************
; PROJECT: 7-Segment Display Test (Board #1)
; DESCRIPTION: Basic hardware test.
; Author : Yi?it Dombayl? ---- 151220212123
;******************************************************************************
    LIST P=16F877A
    #include "P16F877A.INC"
    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _CP_OFF
    
    ERRORLEVEL -302 ; Ignore warnings

;------------------------------------------------------------------------------
; VARIABLES
;------------------------------------------------------------------------------
    CBLOCK 0x20
        DIGIT_1_VAL      ; Number for Digit 1
        DIGIT_2_VAL      ; Number for Digit 2
        DIGIT_3_VAL      ; Number for Digit 3
        DIGIT_4_VAL      ; Number for Digit 4
        CURRENT_DIGIT    ; Active digit
        
        W_TEMP           ; Save CPU state
        STATUS_TEMP      ; Save Status
        PCLATH_TEMP      ; Save PCLATH
        DELAY_1          ; Timer var 1
        DELAY_2          ; Timer var 2
        COUNTER_VAR      ; Counter for 0-9
    ENDC

    ORG 0x000
    GOTO INIT            ; Start here
    
    ORG 0x004
    GOTO ISR             ; Go to interrupt (Timer)

;------------------------------------------------------------------------------
; NUMBER PATTERNS (0-9)
;------------------------------------------------------------------------------
    ORG 0x100
GET_SEG_CODE:
    ADDWF PCL, F
    RETLW b'00111111' ; 0
    RETLW b'00000110' ; 1
    RETLW b'01011011' ; 2
    RETLW b'01001111' ; 3
    RETLW b'01100110' ; 4
    RETLW b'01101101' ; 5
    RETLW b'01111101' ; 6
    RETLW b'00000111' ; 7
    RETLW b'01111111' ; 8
    RETLW b'01101111' ; 9
    RETLW b'00000000' ; Off

;------------------------------------------------------------------------------
; SETUP
;------------------------------------------------------------------------------
INIT:
    BSF     STATUS, RP0     ; Go to settings
    CLRF    TRISD           ; Set Port D as Output (Segments)
    CLRF    TRISA           ; Set Port A as Output (Controls)
    
    ; Timer Config
    BCF     OPTION_REG, 5   ; Internal clock
    BCF     OPTION_REG, 3   ; Prescaler to Timer
    BSF     OPTION_REG, 2   ; Slow down timer
    BSF     OPTION_REG, 1   ; (Values to stop flickering)
    BCF     OPTION_REG, 0   
    
    BCF     STATUS, RP0     ; Exit settings
    
    CLRF    PORTA           ; Clear ports
    CLRF    PORTD
    CLRF    CURRENT_DIGIT
    
    BSF     INTCON, T0IE    ; Turn on Timer interrupt
    BSF     INTCON, GIE     ; Turn on Global interrupt
    
    ; Clear screen variables
    MOVLW   d'10'
    MOVWF   DIGIT_1_VAL
    MOVWF   DIGIT_2_VAL
    MOVWF   DIGIT_3_VAL
    MOVWF   DIGIT_4_VAL

;------------------------------------------------------------------------------
; MAIN LOOP
;------------------------------------------------------------------------------
MAIN_LOOP:
    ; --- TEST 1: ALL ON (8888) ---
    MOVLW   d'8'
    MOVWF   DIGIT_1_VAL
    MOVWF   DIGIT_2_VAL
    MOVWF   DIGIT_3_VAL
    MOVWF   DIGIT_4_VAL
    CALL    WAIT_1SEC       ; Wait to see

    ; --- TEST 2: ORDER (1234) ---
    MOVLW   d'1'
    MOVWF   DIGIT_1_VAL
    MOVLW   d'2'
    MOVWF   DIGIT_2_VAL
    MOVLW   d'3'
    MOVWF   DIGIT_3_VAL
    MOVLW   d'4'
    MOVWF   DIGIT_4_VAL
    CALL    WAIT_1SEC
    CALL    WAIT_1SEC

    ; --- TEST 3: COUNT UP (0-9) ---
    CLRF    COUNTER_VAR
COUNT_LOOP:
    MOVF    COUNTER_VAR, W
    MOVWF   DIGIT_1_VAL     ; Put number on all digits
    MOVWF   DIGIT_2_VAL
    MOVWF   DIGIT_3_VAL
    MOVWF   DIGIT_4_VAL
    
    CALL    WAIT_1SEC       ; Wait
    
    INCF    COUNTER_VAR, F  ; Add +1
    MOVLW   d'10'
    SUBWF   COUNTER_VAR, W
    BTFSS   STATUS, Z       ; Is it 10?
    GOTO    COUNT_LOOP      ; No, keep counting
    
    GOTO    MAIN_LOOP       ; Yes, restart all

;------------------------------------------------------------------------------
; DELAY
;------------------------------------------------------------------------------
WAIT_1SEC:
    MOVLW   d'10'
    MOVWF   DELAY_1
L1: MOVLW   d'200'
    MOVWF   DELAY_2
L2: NOP                     
    NOP
    DECFSZ  DELAY_2, F      ; Count down inner
    GOTO    L2
    DECFSZ  DELAY_1, F      ; Count down outer
    GOTO    L1
    RETURN

;------------------------------------------------------------------------------
; INTERRUPT (Screen Refresh)
;------------------------------------------------------------------------------
ISR:
    ; Save everything
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP
    MOVF    PCLATH, W
    MOVWF   PCLATH_TEMP

    BTFSS   INTCON, T0IF    ; Timer Check
    GOTO    EXIT_ISR
    BCF     INTCON, T0IF    ; Reset Timer Flag

    ; Clear Screen
    CLRF    PORTA   
    CLRF    PORTD

    ; Select Next Digit
    MOVLW   HIGH GET_SEG_CODE
    MOVWF   PCLATH
    MOVF    CURRENT_DIGIT, W
    ADDWF   PCL, F

    GOTO    DISP_D1
    GOTO    DISP_D2
    GOTO    DISP_D3
    GOTO    DISP_D4

DISP_D1:
    MOVF    DIGIT_1_VAL, W
    CALL    GET_SEG_CODE    ; Get pattern
    MOVWF   PORTD           ; Send to LEDs
    BSF     PORTA, 0        ; Turn on Digit 1
    INCF    CURRENT_DIGIT, F
    GOTO    EXIT_ISR

DISP_D2:
    MOVF    DIGIT_2_VAL, W
    CALL    GET_SEG_CODE
    MOVWF   PORTD
    BSF     PORTA, 1        ; Turn on Digit 2
    INCF    CURRENT_DIGIT, F
    GOTO    EXIT_ISR

DISP_D3:
    MOVF    DIGIT_3_VAL, W
    CALL    GET_SEG_CODE
    MOVWF   PORTD
    BSF     PORTA, 2        ; Turn on Digit 3
    INCF    CURRENT_DIGIT, F
    GOTO    EXIT_ISR

DISP_D4:
    MOVF    DIGIT_4_VAL, W
    CALL    GET_SEG_CODE
    MOVWF   PORTD
    BSF     PORTA, 3        ; Turn on Digit 4
    CLRF    CURRENT_DIGIT   ; Reset digit counter
    GOTO    EXIT_ISR

EXIT_ISR:
    ; Restore everything
    MOVF    PCLATH_TEMP, W
    MOVWF   PCLATH
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE

    END