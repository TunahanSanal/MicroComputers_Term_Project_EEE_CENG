;******************************************************************************
;   PROJECT: Home Automation (Term Project)
;   MODULE:  7-Segment Display Assembly Code Block (Board 1)
;   FILE:    Display_Main.asm
;
;   AUTHOR:  Yigit Dombayli
;   ID:      151220212123
;
;   DESCRIPTION:
;   This module manages the 7-Segment Display. It reads shared data 
;   from the common memory block and displays it.
;******************************************************************************

    LIST P=16F877A
    #include "P16F877A.INC"

    ; Configuration: HS Oscillator, WDT OFF, LVP OFF
    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _CP_OFF

;------------------------------------------------------------------------------
; MEMORY MAP (SHARED DATA DEFINITIONS)
; FIXED: Variables defined with EQU must be at Column 1 (Leftmost)
;------------------------------------------------------------------------------
SHARED_DATA_BLOCK  EQU 0x20
DESIRED_TEMP_INT   EQU 0x20  ; R2.1.1-1 Desired Temp Integer Part
DESIRED_TEMP_FRAC  EQU 0x21  ; R2.1.1-1 Desired Temp Fractional Part
AMBIENT_TEMP_INT   EQU 0x22  ; R2.1.1-4 Ambient Temp Integer Part
AMBIENT_TEMP_FRAC  EQU 0x23  ; R2.1.1-4 Ambient Temp Fractional Part
FAN_SPEED          EQU 0x24  ; R2.1.1-5 Fan Speed RPS

;------------------------------------------------------------------------------
; LOCAL VARIABLES
;------------------------------------------------------------------------------
    CBLOCK 0x30                  
        ; Display Buffer 
        DIGIT_1_VAL              ; Leftmost Digit
        DIGIT_2_VAL              ; Middle-Left Digit
        DIGIT_3_VAL              ; Middle-Right Digit
        DIGIT_4_VAL              ; Rightmost Digit

        ; System Variables
        CURRENT_DIGIT            ; For Multiplexing (0-3)
        DISPLAY_STATE            ; 0: Desired, 1: Ambient, 2: Fan
        
        ; Timer Variables (For 2 Second Delay)
        TIMER_COUNT_L            
        TIMER_COUNT_H            
        
        ; Math Helpers (BCD Conversion)
        TEMP_VAL                 
        HUNDREDS                 
        TENS                     
        ONES                     

        ; Interrupt Context Saving
        W_TEMP
        STATUS_TEMP
    ENDC

;------------------------------------------------------------------------------
; VECTORS
;------------------------------------------------------------------------------
    ORG     0x000
    GOTO    INIT

    ORG     0x004
    GOTO    ISR

;------------------------------------------------------------------------------
; INITIALIZATION
;------------------------------------------------------------------------------
INIT:
    ; --- Bank 1 Setup ---
    BSF     STATUS, RP0
    CLRF    TRISD               ; PORTD Output (Segments)
    CLRF    TRISA               ; PORTA Output (Digit Selectors)
    MOVLW   0x06                
    MOVWF   ADCON1              ; Make PORTA Digital
    
    ; Timer0 Setup (Prescaler 1:32 -> 4ms interrupt)
    MOVLW   b'10000100'
    MOVWF   OPTION_REG
    
    ; --- Bank 0 Setup ---
    BCF     STATUS, RP0
    CLRF    PORTA
    CLRF    PORTD
    
    ; Initialize Variables
    CLRF    CURRENT_DIGIT
    CLRF    DISPLAY_STATE
    CLRF    TIMER_COUNT_L
    CLRF    TIMER_COUNT_H
    
    ; Enable Interrupts
    BSF     INTCON, T0IE
    BSF     INTCON, GIE

    ; ===========================================================
    ; >>> TEST DATA BLOCK <<<
    ; ===========================================================
    
    ; 1. Desired Temp = 25.5
    MOVLW   d'25'
    MOVWF   DESIRED_TEMP_INT
    MOVLW   d'5'
    MOVWF   DESIRED_TEMP_FRAC

    ; 2. Ambient Temp = 27.4
    MOVLW   d'27'
    MOVWF   AMBIENT_TEMP_INT
    MOVLW   d'4'
    MOVWF   AMBIENT_TEMP_FRAC

    ; 3. Fan Speed = 120 RPS
    MOVLW   d'120'
    MOVWF   FAN_SPEED
    ; ===========================================================

;------------------------------------------------------------------------------
; MAIN LOOP
;------------------------------------------------------------------------------
MAIN_LOOP:
    MOVF    DISPLAY_STATE, W
    SUBLW   d'0'
    BTFSC   STATUS, Z
    GOTO    LOAD_DESIRED_TEMP   ; If State = 0

    MOVF    DISPLAY_STATE, W
    SUBLW   d'1'
    BTFSC   STATUS, Z
    GOTO    LOAD_AMBIENT_TEMP   ; If State = 1

    MOVF    DISPLAY_STATE, W
    SUBLW   d'2'
    BTFSC   STATUS, Z
    GOTO    LOAD_FAN_SPEED      ; If State = 2

    GOTO    MAIN_LOOP

; --- STATE 0: Show Desired Temperature ---
LOAD_DESIRED_TEMP:
    MOVF    DESIRED_TEMP_INT, W
    MOVWF   TEMP_VAL
    CALL    BIN_TO_BCD          
    MOVF    TENS, W
    MOVWF   DIGIT_1_VAL         ; Tens
    MOVF    ONES, W
    MOVWF   DIGIT_2_VAL         ; Ones (Dot added in ISR)
    MOVF    DESIRED_TEMP_FRAC, W
    MOVWF   DIGIT_3_VAL         ; Fractional
    MOVLW   d'10'               ; Blank
    MOVWF   DIGIT_4_VAL
    GOTO    MAIN_LOOP

; --- STATE 1: Show Ambient Temperature ---
LOAD_AMBIENT_TEMP:
    MOVF    AMBIENT_TEMP_INT, W
    MOVWF   TEMP_VAL
    CALL    BIN_TO_BCD
    MOVF    TENS, W
    MOVWF   DIGIT_1_VAL
    MOVF    ONES, W
    MOVWF   DIGIT_2_VAL         ; Ones (Dot added in ISR)
    MOVF    AMBIENT_TEMP_FRAC, W
    MOVWF   DIGIT_3_VAL
    MOVLW   d'11'               ; C Char
    MOVWF   DIGIT_4_VAL
    GOTO    MAIN_LOOP

; --- STATE 2: Show Fan Speed ---
LOAD_FAN_SPEED:
    MOVF    FAN_SPEED, W
    MOVWF   TEMP_VAL
    CALL    BIN_TO_BCD
    MOVF    HUNDREDS, W
    MOVWF   DIGIT_1_VAL
    MOVF    TENS, W
    MOVWF   DIGIT_2_VAL         ; No Dot here
    MOVF    ONES, W
    MOVWF   DIGIT_3_VAL
    MOVLW   d'12'               ; F Char
    MOVWF   DIGIT_4_VAL
    GOTO    MAIN_LOOP

;------------------------------------------------------------------------------
; INTERRUPT SERVICE ROUTINE
;------------------------------------------------------------------------------
ISR:
    ; Context Save
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP

    BCF     INTCON, T0IF        ; Clear Flag
    CLRF    PORTA               ; Prevent Ghosting

    ; --- 2 Second Timer Logic ---
    INCF    TIMER_COUNT_L, F    
    BTFSC   STATUS, Z           
    INCF    TIMER_COUNT_H, F    
    
    ; Check for approx 500 counts
    MOVF    TIMER_COUNT_H, W
    SUBLW   0x01                
    BTFSS   STATUS, Z
    GOTO    CONTINUE_MUX        
    
    MOVF    TIMER_COUNT_L, W
    SUBLW   0xF4                ; Low byte check 244
    BTFSS   STATUS, Z
    GOTO    CONTINUE_MUX        

    ; -- 2 Seconds Reached --
    CLRF    TIMER_COUNT_L       
    CLRF    TIMER_COUNT_H
    INCF    DISPLAY_STATE, F    ; Next State
    MOVF    DISPLAY_STATE, W
    SUBLW   d'3'                ; Cycle 0-1-2-0
    BTFSC   STATUS, Z
    CLRF    DISPLAY_STATE

CONTINUE_MUX:
    ; --- Multiplexing Logic ---
    MOVF    CURRENT_DIGIT, W
    ADDWF   PCL, F
    GOTO    SHOW_D1
    GOTO    SHOW_D2
    GOTO    SHOW_D3
    GOTO    SHOW_D4

SHOW_D1: ; Leftmost (RA0)
    MOVF    DIGIT_1_VAL, W
    CALL    GET_SEG_CODE
    MOVWF   PORTD
    BSF     PORTA, 0            
    INCF    CURRENT_DIGIT, F
    GOTO    EXIT_ISR

SHOW_D2: ; Middle-Left (RA1) - Check for DOT
    MOVF    DIGIT_2_VAL, W
    CALL    GET_SEG_CODE
    ; Only Add DOT if State is 0 or 1 (Temperatures)
    BTFSS   DISPLAY_STATE, 1    ; If State=2 (Bit 1 set), Skip Dot
    IORLW   b'10000000'         ; Add Dot (Bit 7)
    MOVWF   PORTD
    BSF     PORTA, 1            
    INCF    CURRENT_DIGIT, F
    GOTO    EXIT_ISR

SHOW_D3: ; Middle-Right (RA2)
    MOVF    DIGIT_3_VAL, W
    CALL    GET_SEG_CODE
    MOVWF   PORTD
    BSF     PORTA, 2            
    INCF    CURRENT_DIGIT, F
    GOTO    EXIT_ISR

SHOW_D4: ; Rightmost (RA3)
    MOVF    DIGIT_4_VAL, W
    CALL    GET_SEG_CODE
    MOVWF   PORTD
    BSF     PORTA, 3            
    CLRF    CURRENT_DIGIT       
    GOTO    EXIT_ISR

EXIT_ISR:
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE

;------------------------------------------------------------------------------
; HELPER: BINARY TO BCD (0-255)
;------------------------------------------------------------------------------
BIN_TO_BCD:
    CLRF    HUNDREDS
    CLRF    TENS
    CLRF    ONES
    MOVF    TEMP_VAL, W
    MOVWF   ONES            
CHECK_HUNDREDS:
    MOVLW   d'100'
    SUBWF   ONES, W         
    BTFSS   STATUS, C       
    GOTO    CHECK_TENS      
    MOVWF   ONES            
    INCF    HUNDREDS, F
    GOTO    CHECK_HUNDREDS
CHECK_TENS:
    MOVLW   d'10'
    SUBWF   ONES, W         
    BTFSS   STATUS, C       
    RETURN                  
    MOVWF   ONES            
    INCF    TENS, F
    GOTO    CHECK_TENS

;------------------------------------------------------------------------------
; LOOK-UP TABLE (Common Cathode)
;------------------------------------------------------------------------------
GET_SEG_CODE:
    ADDWF   PCL, F
    RETLW   b'00111111'     ; 0
    RETLW   b'00000110'     ; 1
    RETLW   b'01011011'     ; 2
    RETLW   b'01001111'     ; 3
    RETLW   b'01100110'     ; 4
    RETLW   b'01101101'     ; 5
    RETLW   b'01111101'     ; 6
    RETLW   b'00000111'     ; 7
    RETLW   b'01111111'     ; 8
    RETLW   b'01101111'     ; 9
    RETLW   b'00000000'     ; 10 (Blank)
    RETLW   b'00111001'     ; 11 (C)
    RETLW   b'01110001'     ; 12 (F)
    RETURN

    END