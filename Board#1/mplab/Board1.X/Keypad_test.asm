;******************************************************************************
; PROJECT: Keypad Test (Board #1)
; AUTHOR: Efe Duhan Alpay --- 152120211089
;
; DESCRIPTION: Simple test code for 4x4 Keypad.
;              It reads the key and shows it on the first 7-segment display.
;******************************************************************************

    LIST P=16F877A
    #include "P16F877A.INC"
    
    ; Configuration: High Speed Osc, Watchdog Off, Power Up Timer On
    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _CP_OFF

    ERRORLEVEL -302 ; Hide bank warnings

;------------------------------------------------------------------------------
; VARIABLES
;------------------------------------------------------------------------------
    CBLOCK 0x20
        ; Display Variables
        DIGIT_1_VAL      ; Value to show on screen
        CURRENT_DIGIT    ; Active digit counter
        
        ; Keypad Variables
        KEY_CODE         ; Stored key value
        KEY_DELAY_1      ; Timer for delay
        KEY_DELAY_2      ; Timer for delay
        
        ; Interrupt Variables
        W_TEMP
        STATUS_TEMP
    ENDC

    ORG 0x000
    GOTO INIT

    ORG 0x004
    GOTO ISR ; Interrupt Service Routine

;------------------------------------------------------------------------------
; 7-SEGMENT TABLE (Common Cathode)
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
    RETLW b'00000000' ; 10 (Empty)
    RETLW b'00111001' ; 11 (C)
    RETLW b'01110001' ; 12 (F)
    RETLW b'01110111' ; 13 (A)
    RETLW b'01111001' ; 14 (E)
    RETLW b'01101101' ; 15 (S)

;------------------------------------------------------------------------------
; INITIALIZATION
;------------------------------------------------------------------------------
INIT:
    BSF STATUS, RP0   ; Go to Bank 1
    
    CLRF TRISD        ; PORTD is Output (Display)
    CLRF TRISA        ; PORTA is Output (Control)
    
    ; Keypad Config: 
    ; RB0-RB3 = Output (Columns)
    ; RB4-RB7 = Input (Rows)
    MOVLW b'11110000' 
    MOVWF TRISB       
    
    ; Timer0 Config (for display refresh)
    BCF OPTION_REG, 7 
    MOVLW b'10000100' ; Prescaler 1:32
    MOVWF OPTION_REG
    
    BCF STATUS, RP0   ; Go back to Bank 0
    
    ; Clear ports and variables
    CLRF PORTD
    CLRF PORTA
    CLRF DIGIT_1_VAL
    
    ; Enable Interrupts
    BSF INTCON, T0IE  
    BSF INTCON, GIE   

;------------------------------------------------------------------------------
; MAIN LOOP
;------------------------------------------------------------------------------
MAIN_LOOP:
    ; Wait for a valid key press
    CALL GET_VALID_KEY
    
    ; Show the key value on the display
    MOVWF DIGIT_1_VAL
    
    GOTO MAIN_LOOP

;------------------------------------------------------------------------------
; KEYPAD FUNCTIONS
;------------------------------------------------------------------------------

; GET_VALID_KEY: Waits for a key press and returns the value in W
GET_VALID_KEY:
    ; 1. Wait if a key is already pressed (release check)
GK_WAIT_NO_KEY:
    CALL SCAN_KEYPAD_RAW
    XORLW 0xFF          ; Check if result is 0xFF (No key)
    BTFSS STATUS, Z     ; If Z=0, a key is pressed. Wait.
    GOTO GK_WAIT_NO_KEY 

    ; 2. Wait for new key press
GK_LOOP:
    CALL SCAN_KEYPAD_RAW
    MOVWF KEY_CODE      
    XORLW 0xFF          
    BTFSC STATUS, Z     ; If Z=1 (No key), keep scanning
    GOTO GK_LOOP
    
    ; 3. Debounce (Simple delay to fix mechanical noise)
    CALL DELAY_DEBOUNCE 
    
    ; 4. Double check the key
    CALL SCAN_KEYPAD_RAW
    MOVWF KEY_CODE
    XORLW 0xFF
    BTFSC STATUS, Z     ; If key is gone, it was noise. Go back.
    GOTO GK_LOOP

    ; Return the valid key in W
    MOVF KEY_CODE, W
    RETURN

; SCAN_KEYPAD_RAW: Scans rows and columns
; Returns: Key value (0-15) or 0xFF (No key)
SCAN_KEYPAD_RAW:
    CLRF PORTB
    
    ; --- SCAN COLUMN 1 (RB0 Low) ---
    MOVLW b'11111110'   
    MOVWF PORTB
    CALL DELAY_SMALL    ; Small delay for stability
    
    ; Check Rows (RB4 - RB7)
    BTFSS PORTB, 4      
    RETLW d'1'          ; Row 1 -> Key '1'
    BTFSS PORTB, 5      
    RETLW d'2'          ; Row 2 -> Key '2'
    BTFSS PORTB, 6      
    RETLW d'3'          ; Row 3 -> Key '3'
    BTFSS PORTB, 7      
    RETLW d'13'         ; Row 4 -> Key 'A'

    ; --- SCAN COLUMN 2 (RB1 Low) ---
    MOVLW b'11111101'
    MOVWF PORTB
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'4'
    BTFSS PORTB, 5
    RETLW d'5'
    BTFSS PORTB, 6
    RETLW d'6'
    BTFSS PORTB, 7
    RETLW d'11'         ; Key 'C'

    ; --- SCAN COLUMN 3 (RB2 Low) ---
    MOVLW b'11111011'
    MOVWF PORTB
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'7'
    BTFSS PORTB, 5
    RETLW d'8'
    BTFSS PORTB, 6
    RETLW d'9'
    BTFSS PORTB, 7
    RETLW d'12'         ; Key 'F'

    ; --- SCAN COLUMN 4 (RB3 Low) ---
    MOVLW b'11110111'
    MOVWF PORTB
    CALL DELAY_SMALL
    BTFSS PORTB, 4
    RETLW d'14'         ; Key '*' or 'E'
    BTFSS PORTB, 5
    RETLW d'0'          ; Key '0'
    BTFSS PORTB, 6
    RETLW d'15'         ; Key '#' or 'S'
    BTFSS PORTB, 7
    RETLW d'13'         ; Key 'A'

    RETLW 0xFF          ; No key pressed

;------------------------------------------------------------------------------
; DELAYS
;------------------------------------------------------------------------------
DELAY_DEBOUNCE:
    MOVLW d'200'
    MOVWF KEY_DELAY_1
DD_L1:
    MOVLW d'250'
    MOVWF KEY_DELAY_2
DD_L2:
    DECFSZ KEY_DELAY_2, F
    GOTO DD_L2
    DECFSZ KEY_DELAY_1, F
    GOTO DD_L1
    RETURN

DELAY_SMALL: 
    MOVLW d'50'
    MOVWF KEY_DELAY_2
DS_LOOP:
    DECFSZ KEY_DELAY_2, F
    GOTO DS_LOOP
    RETURN

;------------------------------------------------------------------------------
; INTERRUPT SERVICE ROUTINE (Display Refresh)
;------------------------------------------------------------------------------
ISR:
    MOVWF W_TEMP        ; Save Context
    SWAPF STATUS, W
    MOVWF STATUS_TEMP

    BCF INTCON, T0IF    ; Clear Timer Flag
    
    ; Enable only Digit 1 for testing
    CLRF PORTA
    
    MOVLW HIGH GET_SEG_CODE
    MOVWF PCLATH
    MOVF DIGIT_1_VAL, W
    CALL GET_SEG_CODE
    MOVWF PORTD         ; Send data to segments
    BSF PORTA, 0        ; Turn on Digit 1

    SWAPF STATUS_TEMP, W ; Restore Context
    MOVWF STATUS
    SWAPF W_TEMP, F
    SWAPF W_TEMP, W
    RETFIE

    END




