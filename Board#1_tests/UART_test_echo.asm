;******************************************************************************
; PROJECT: UART Test (Board #1)
; SYSTEM:  20 MHz / 9600 Baud
; NOTE:    Simple echo test. Fixes weird text on screen.
; Author: Yi?it Dombayl? --- 151220212123
;******************************************************************************
    LIST P=16F877A
    #include "P16F877A.INC"
    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _CP_OFF
    
    ERRORLEVEL -302 ; Hide warnings

;------------------------------------------------------------------------------
; VARIABLES
;------------------------------------------------------------------------------
    CBLOCK 0x20
        RX_TEMP          ; Store the letter we received
        W_TEMP           ; Save CPU work
        STATUS_TEMP      ; Save Status
        PCLATH_TEMP      ; Save Location
    ENDC

    ORG 0x000
    GOTO INIT            ; Start setup
    
    ORG 0x004
    GOTO ISR             ; Go to Interrupt (When data comes)

;------------------------------------------------------------------------------
; SETUP 
;------------------------------------------------------------------------------
INIT:
    ; --- UART CONFIG ---
    BSF     STATUS, RP0    
    
    MOVLW   b'10000000'     ; RC7 (RX) Input
    MOVWF   TRISC           ; RC6 (TX) Output
    
    MOVLW   d'129'          
    MOVWF   SPBRG
    
    BSF     TXSTA, TXEN    
    BCF     TXSTA, SYNC     
    BSF     TXSTA, BRGH   
    BSF     PIE1, RCIE      
    ; --------------------------------
    
    BCF     STATUS, RP0    
    
    BSF     RCSTA, SPEN     
    BSF     RCSTA, CREN    
    
    BSF     INTCON, PEIE    
    BSF     INTCON, GIE     

    CALL    SEND_WELCOME
;------------------------------------------------------------------------------
; MAIN LOOP
;------------------------------------------------------------------------------
MAIN_LOOP:
    NOP                     ; Do nothing
    GOTO    MAIN_LOOP       ; Just wait here forever

;------------------------------------------------------------------------------
; HELPER FUNCTIONS
;------------------------------------------------------------------------------
SEND_WELCOME:
    MOVLW   'U'
    CALL    SEND_CHAR
    MOVLW   'A'
    CALL    SEND_CHAR
    MOVLW   'R'
    CALL    SEND_CHAR
    MOVLW   'T'
    CALL    SEND_CHAR
    MOVLW   ' '
    CALL    SEND_CHAR
    MOVLW   'O'
    CALL    SEND_CHAR
    MOVLW   'K'
    CALL    SEND_CHAR
    MOVLW   d'13'           ; New Line (Enter key)
    CALL    SEND_CHAR
    RETURN

SEND_CHAR:
    BSF     STATUS, RP0     ; Go to Settings
WAIT_TX:
    BTFSS   TXSTA, TRMT     ; Is the line busy?
    GOTO    WAIT_TX         ; Yes, wait...
    BCF     STATUS, RP0     ; Exit Settings
    
    MOVWF   TXREG           ; Send the character now
    RETURN

;------------------------------------------------------------------------------
; INTERRUPT (When PC sends a letter)
;------------------------------------------------------------------------------
ISR:
    ; Save current work (Safety)
    MOVWF   W_TEMP
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP
    MOVF    PCLATH, W
    MOVWF   PCLATH_TEMP

    ; Check: Did a letter arrive?
    BTFSS   PIR1, RCIF
    GOTO    EXIT_ISR
    
    ; --- ECHO PROCESS ---
    MOVF    RCREG, W        ; Get the letter
    MOVWF   RX_TEMP         ; Save it
    
    CALL    SEND_CHAR       ; Send it back to PC (Echo)

EXIT_ISR:
    ; Restore saved work
    MOVF    PCLATH_TEMP, W
    MOVWF   PCLATH
    SWAPF   STATUS_TEMP, W
    MOVWF   STATUS
    SWAPF   W_TEMP, F
    SWAPF   W_TEMP, W
    RETFIE

    END