;******************************************************************************
;   PROJECT: Home Automation (Term Project)
;   MODULE:  7-Segment Display Assembly Code Block (Board #1)
;   FILE:    Display_Module_Final.asm
;
;   AUTHOR:  Yigit Dombayli
;   ID:      151220212123
;
;   DESCRIPTION:
;   This module manages the 7-Segment Display. It reads shared data (Temperatures
;   and Fan Speed) from the common memory block populated by other modules.
;   It cycles through showing Desired Temp, Ambient Temp, and Fan Speed every
;   2 seconds [R2.1.3-1].
;******************************************************************************

    LIST P=16F877A
    #include "P16F877A.INC"

    ; Configuration: HS Oscillator, WDT OFF, LVP OFF
    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _CP_OFF

;------------------------------------------------------------------------------
; MEMORY MAP (SHARED DATA DEFINITIONS)
; These addresses must match with the rest of the group's code!
;------------------------------------------------------------------------------
SHARED_DATA_BLOCK  EQU 0x20
    DESIRED_TEMP_INT   EQU 0x20  ; [R2.1.1-1] Desired Temp Integer Part
    DESIRED_TEMP_FRAC  EQU 0x21  ; [R2.1.1-1] Desired Temp Fractional Part
    AMBIENT_TEMP_INT   EQU 0x22  ; [R2.1.1-4] Ambient Temp Integer Part
    AMBIENT_TEMP_FRAC  EQU 0x23  ; [R2.1.1-4] Ambient Temp Fractional Part
    FAN_SPEED          EQU 0x24  ; [R2.1.1-5] Fan Speed (RPS) - 0-255 Integer

;------------------------------------------------------------------------------
; LOCAL VARIABLES
;------------------------------------------------------------------------------
    CBLOCK 0x30                  ; Local variables start after shared block
        ; Display Buffer (Values currently being shown)
        DIGIT_1_VAL              ; Leftmost Digit
        DIGIT_2_VAL              ; Middle-Left Digit (With Dot for Temp)
        DIGIT_3_VAL              ; Middle-Right Digit
        DIGIT_4_VAL              ; Rightmost Digit

        ; System Variables
        CURRENT_DIGIT            ; For Multiplexing (0-3)
        DISPLAY_STATE            ; 0: Desired, 1: Ambient, 2: Fan
        
        ; Timer Variables (For 2 Second Delay)
        TIMER_COUNT_L            ; Low Byte counter
        TIMER_COUNT_H            ; High Byte counter
        
        ; Math Helpers (For Fan Speed BCD Conversion)
        TEMP_VAL                 ; Temporary value for calculation
        HUNDREDS                 ; Hundreds digit
        TENS                     ; Tens digit
        ONES                     ; Ones digit

        ; Interrupt Context Saving
        W_TEMP
        STATUS_TEMP
    ENDC

;------------------------------------------------------------------------------
; RESET & INTERRUPT VECTORS
;------------------------------------------------------------------------------
    ORG     0x000
    GOTO    INIT

    ORG     0x004
    GOTO    ISR
; -----------------------------------------------------------
    ; TEST BLO?U BA?LANGICI (Sensör yoksa buray? kullan)
    ; -----------------------------------------------------------
    
    ; 1. Senaryo: ?stenen S?cakl?k = 25.5 Derece
    MOVLW   d'25'
    MOVWF   DESIRED_TEMP_INT    ; 0x20 adresine 25 yaz
    MOVLW   d'5'
    MOVWF   DESIRED_TEMP_FRAC   ; 0x21 adresine 5 yaz

    ; 2. Senaryo: Ortam S?cakl??? = 27.4 Derece
    MOVLW   d'27'
    MOVWF   AMBIENT_TEMP_INT    ; 0x22 adresine 27 yaz
    MOVLW   d'4'
    MOVWF   AMBIENT_TEMP_FRAC   ; 0x23 adresine 4 yaz

    ; 3. Senaryo: Fan H?z? = 120 RPS
    MOVLW   d'120'
    MOVWF   FAN_SPEED           ; 0x24 adresine 120 yaz
    
    ; -----------------------------------------------------------
    ; TEST BLO?U B?T???
    ; -----------------------------------------------------------
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
    
    ; Timer0 Setup (Prescaler 1:32 -> ~4ms interrupt)
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

;------------------------------------------------------------------------------
; MAIN LOOP
; Check DISPLAY_STATE and update DIGIT variables accordingly.
; The ISR handles the timing (changing states) and multiplexing.
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
    ; Format: [Int Tens][Int Ones].[Frac][Blank] -> e.g., 25.5 
    
    ; 1. Digit (Tens of Integer) - Simplified: Assuming < 100
    MOVF    DESIRED_TEMP_INT, W
    MOVWF   TEMP_VAL
    CALL    BIN_TO_BCD          ; Split W into Hundreds/Tens/Ones
    MOVF    TENS, W
    MOVWF   DIGIT_1_VAL
    
    ; 2. Digit (Ones of Integer) - Has DOT
    MOVF    ONES, W
    MOVWF   DIGIT_2_VAL
    
    ; 3. Digit (Fractional Part)
    MOVF    DESIRED_TEMP_FRAC, W
    MOVWF   DIGIT_3_VAL
    
    ; 4. Digit (Blank or 'C') - Let's use Blank for Desired
    MOVLW   d'10'               ; 10 = Blank in table
    MOVWF   DIGIT_4_VAL
    
    GOTO    MAIN_LOOP

; --- STATE 1: Show Ambient Temperature ---
LOAD_AMBIENT_TEMP:
    ; Format: [Int Tens][Int Ones].[Frac][C] -> e.g., 27.4C
    
    MOVF    AMBIENT_TEMP_INT, W
    MOVWF   TEMP_VAL
    CALL    BIN_TO_BCD
    MOVF    TENS, W
    MOVWF   DIGIT_1_VAL
    
    MOVF    ONES, W
    MOVWF   DIGIT_2_VAL
    
    MOVF    AMBIENT_TEMP_FRAC, W
    MOVWF   DIGIT_3_VAL
    
    MOVLW   d'11'               ; 11 = 'C' in table
    MOVWF   DIGIT_4_VAL
    
    GOTO    MAIN_LOOP

; --- STATE 2: Show Fan Speed ---
LOAD_FAN_SPEED:
    ; Format: [Hundreds][Tens][Ones][F] -> e.g., 120F
    ; No Decimal Point here.
    
    MOVF    FAN_SPEED, W
    MOVWF   TEMP_VAL
    CALL    BIN_TO_BCD
    
    MOVF    HUNDREDS, W
    MOVWF   DIGIT_1_VAL
    
    MOVF    TENS, W
    MOVWF   DIGIT_2_VAL
    
    MOVF    ONES, W
    MOVWF   DIGIT_3_VAL
    
    MOVLW   d'12'               ; 12 = 'F' in table
    MOVWF   DIGIT_4_VAL
    
    GOTO    MAIN_LOOP

;------------------------------------------------------------------------------
; INTERRUPT SERVICE ROUTINE (Multiplexing & Timing)
;------------------------------------------------------------------------------
ISR:
    ; Context Saving
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP

    BCF     INTCON, T0IF        ; Clear Flag
    CLRF    PORTA               ; Prevent Ghosting

    ; --- 2 Second Timer Logic ---
    ; TMR0 overflow ~4ms (at 4MHz/HS, 1:32 prescaler)
    ; 2000ms / 4ms = 500 interrupts needed.
    
    INCF    TIMER_COUNT_L, F    ; Increment Low Byte
    BTFSC   STATUS, Z           ; Did it roll over?
    INCF    TIMER_COUNT_H, F    ; Yes, increment High Byte
    
    ; Check if count reached 500 (0x01F4)
    MOVF    TIMER_COUNT_H, W
    SUBLW   0x01                ; Check High Byte = 1
    BTFSS   STATUS, Z
    GOTO    CONTINUE_MUX        ; Not yet
    
    MOVF    TIMER_COUNT_L, W
    SUBLW   0xF4                ; Check Low Byte = 0xF4 (244) -> ~500 total
    BTFSS   STATUS, Z
    GOTO    CONTINUE_MUX        ; Not yet

    ; -- 2 Seconds Reached --
    CLRF    TIMER_COUNT_L       ; Reset Counter
    CLRF    TIMER_COUNT_H
    
    INCF    DISPLAY_STATE, F    ; Next State
    MOVF    DISPLAY_STATE, W
    SUBLW   d'3'                ; If State == 3, reset to 0
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

SHOW_D1:
    MOVF    DIGIT_1_VAL, W
    CALL    GET_SEG_CODE
    MOVWF   PORTD
    BSF     PORTA, 0            ; Activate D1 (Left)
    INCF    CURRENT_DIGIT, F
    GOTO    EXIT_ISR

SHOW_D2:
    MOVF    DIGIT_2_VAL, W
    CALL    GET_SEG_CODE
    ; Only Add DOT if Display State is 0 or 1 (Temperatures)
    ; If State is 2 (Fan), do not add dot.
    BTFSS   DISPLAY_STATE, 1    ; Check if Bit 1 is set (State 2 = 10 binary)
    IORLW   b'10000000'         ; Add Dot (Only for State 0 and 1)
    
    MOVWF   PORTD
    BSF     PORTA, 1            ; Activate D2
    INCF    CURRENT_DIGIT, F
    GOTO    EXIT_ISR

SHOW_D3:
    MOVF    DIGIT_3_VAL, W
    CALL    GET_SEG_CODE
    MOVWF   PORTD
    BSF     PORTA, 2            ; Activate D3
    INCF    CURRENT_DIGIT, F
    GOTO    EXIT_ISR

SHOW_D4:
    MOVF    DIGIT_4_VAL, W
    CALL    GET_SEG_CODE
    MOVWF   PORTD
    BSF     PORTA, 3            ; Activate D4
    CLRF    CURRENT_DIGIT       ; Reset Digit Counter
    GOTO    EXIT_ISR

EXIT_ISR:
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE

;------------------------------------------------------------------------------
; HELPER: BINARY TO BCD (0-255)
; Input: TEMP_VAL
; Output: HUNDREDS, TENS, ONES
;------------------------------------------------------------------------------
BIN_TO_BCD:
    CLRF    HUNDREDS
    CLRF    TENS
    CLRF    ONES
    
    MOVF    TEMP_VAL, W
    MOVWF   ONES            ; Move value to ONES to start processing

CHECK_HUNDREDS:
    MOVLW   d'100'
    SUBWF   ONES, W         ; W = ONES - 100
    BTFSS   STATUS, C       ; If ONES < 100, Carry is Clear
    GOTO    CHECK_TENS      ; Done with hundreds
    MOVWF   ONES            ; Update ONES
    INCF    HUNDREDS, F
    GOTO    CHECK_HUNDREDS

CHECK_TENS:
    MOVLW   d'10'
    SUBWF   ONES, W         ; W = ONES - 10
    BTFSS   STATUS, C       ; If ONES < 10, Carry is Clear
    RETURN                  ; Done! Remainder is ONES
    MOVWF   ONES            ; Update ONES
    INCF    TENS, F
    GOTO    CHECK_TENS

;------------------------------------------------------------------------------
; LOOK-UP TABLE
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