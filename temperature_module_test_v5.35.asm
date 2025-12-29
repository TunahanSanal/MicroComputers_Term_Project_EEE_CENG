;==================================================
; TEMPERATURE MODULE TEST CODE
; Fan + Temperature + Tachometer (RPS)
; PIC16F877A  for Fosc= 10 MHz
; MPLAB IDE v5.35
	
; Author: Yusuf inan ---- 151220192079
; engr.inanyusuf@gmail.com

;----- NOTES --------
; DESIRED_TEMP =25 at line 75 you can change
; Turn MOVWF PORTB comment either at line 120 or at line 181
; Be aware of CLRF TRISB at line 50(just for debug purpose)
; All these codes work stably with a 10 MHz oscillator frequency.
; Because of delay functions in these codes
; To test goto line 84 MAIN_LOOP and remove ';' symbol before the function call you want to test 
;==================================================

        LIST    P=16F877A
        #include <P16F877A.INC>

        __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CP_OFF

        ERRORLEVEL -302

;--------------------------------------------------
; VARIABLES
;--------------------------------------------------
        CBLOCK  0x70
            AMBIENT_TEMP      ; ADC based temperature
            DESIRED_TEMP      ; Fixed to 25C at line 62
            FAN_RPS           ; Tach result (RPS)
	    ACQ_DELAY
	    DLY1	        ;FOR 1 SECOND DELAY SUBROUTINE
	    DLY2		;FOR 1 SECOND DELAY SUBROUTINE
	    DLY3		;FOR 1 SECOND DELAY SUBROUTINE
        ENDC

        ORG 0x000
        GOTO INIT

;--------------------------------------------------
; INIT
;--------------------------------------------------
INIT:
	;CLRF    INTCON	
        BSF STATUS, RP0
	
        ;m5 RA0 = Analog input
        BSF TRISA, 0 
	
	CLRF TRISB ;JUST FOR DEBUG TEMPERATURE AND FAN SPEED WITH PORTB
	
        
        BSF TRISC, 0	;TACHOMETER INPUT (T1CKI)Timer1 clock in
	BCF TRISC,5     ;HEATER (OUTPUT)
        BCF TRISC, 2    ;COOLER (OUTPUT)
	
        ; ADC config (AN0 analog)
        MOVLW b'00001110'   ;left justified
        MOVWF ADCON1	    ;only RA0 Analog INPUT, others are DIGITAL
			    ;+Vref=VDD -Vref=VSS
	BANKSEL T1CON
        ; Timer1 external clock (RC0)
        MOVLW b'00000011'   ; Timer1 is ON, External Clock from RC0 is selected,
        MOVWF T1CON	    ;Do not synchronize external clock input
			    ;T1OSCEN=0, 1:1 Presacaler value

        BCF STATUS, RP0	    ;RAM Bank0 is selected

        MOVLW b'10000001'   ;Fosc/32, RA0 is seleted as ADC Channel
        MOVWF ADCON0	    ;GO=0, ADON=1 (ADC IS ACTIVE)

        ; Fixed set temperature = 25
        MOVLW d'25'
        MOVWF DESIRED_TEMP	    ;DESIRED TEMPERATURE	    

	
	;HEATER AND COOLER INITIAL STATES
	
        BCF PORTC,5	;HEATER IS OFF
	BCF PORTC,2	;COOLER IS OFF

MAIN_LOOP:
    
        ;CALL READ_TEMPERATURE
        ;CALL CONTROL_TEMP
		;CALL MEASURE_FAN_RPS
		;CALL FAN_ON
		;CALL HEATER_ON
        
        GOTO MAIN_LOOP

;--------------------------------------------------
; READ TEMPERATURE (ADC)
;--------------------------------------------------
READ_TEMPERATURE:
    
    ;---- ADC ACQUISITION DELAY ---
    MOVLW .100
    MOVWF ACQ_DELAY
LABEL:
    NOP
    DECFSZ ACQ_DELAY,F
    GOTO LABEL
    ;---- ADC ACQUISITION DELAY ---
    
    BSF ADCON0, GO	 ;ADC CONVERSION IS STARTED

WAIT_ADC:
        BTFSC ADCON0, GO ; WAIT FOR ADC CONVERSION IS FINISHED
        GOTO WAIT_ADC

        ; ADC CONVERSION RESULT IS ON ADRESH and ADRESL registers
	; ADC RESULT WAS LEFT JUSTIFIED MOST SIGNIFICANT BYTE IS ON ADRESH
        MOVF ADRESH, W	
        ADDWF ADRESH, W      ; x2 (TURNS ADC VALUE INTO CELCIOUS) 
        MOVWF AMBIENT_TEMP   ; LOADS THE VALUE TO AMBIENT_TEMP 
	
	MOVWF PORTB ; JUST FOR DEBUG PURPOSE
	
        RETURN
	
;==============================================================================
; TEMPERATURE CONTROL LOGIC
;==============================================================================
CONTROL_TEMP:
    
        BANKSEL AMBIENT_TEMP
        MOVF    AMBIENT_TEMP, W	    ; W = AMBIENT_TEMP
        BANKSEL DESIRED_TEMP
        SUBWF   DESIRED_TEMP, W	    ; W = DESIRED - AMBIENT

        BANKSEL STATUS
        BTFSC   STATUS, 2   ; IF STATUS(Z)=1, EQUAL 
        GOTO    ALL_OFF

        BTFSC   STATUS, 0    ; IF DESIRED > AMBIENT; GOTO HEATER_ON 
        GOTO    HEATER_ON    ;ELSE; GOTO FAN_ON
	;STATUS(C)=1 DESIRED-AMBIENT =POSITIVE RESULT
	;STATUS(C)=0 DESIRED-AMBIENT =NEGATIVE RESULT
        GOTO    FAN_ON
	
; --- FAN ON, AMBIENT IS TOO HOT ---
FAN_ON:
        BANKSEL PORTC
        BCF     PORTC, 5    ;HEATER OFF
        BSF     PORTC, 2    ;FAN ON
        RETURN

	
; --- HEATER ON, AMBIENT IS TOO COLD ---	
HEATER_ON:
        BANKSEL PORTC
        BSF     PORTC, 5    ;HEATER ON
        BCF     PORTC, 2    ;FAN OFF
        RETURN
	
; --- AMBIENT TEMPERATURE IS GOOD ---
ALL_OFF:
        BANKSEL PORTC
        BCF     PORTC, 5    ;HEATER OFF
        BCF     PORTC, 2    ;FAN OFF
        RETURN

;--------------------------------------------------
; FAN TACH MEASUREMENT (RPS)
; 1 pulse = 1 revolution
; 1 second window
;--------------------------------------------------
MEASURE_FAN_RPS:
        CLRF TMR1L
        CLRF TMR1H

        CALL DELAY_1SEC

        MOVF TMR1L, W
        MOVWF FAN_RPS        ; RPS value
	BANKSEL PORTB
	MOVF FAN_RPS,W
	MOVWF PORTB	    ; JUST FOR DEBUG PURPOSE
        RETURN
	
;----------------------------------
; ~1 SECOND DELAY @ 10 MHz
;----------------------------------

DELAY_1SEC
        MOVLW   d'25'
        MOVWF   DLY1

D1_L1
        MOVLW   d'200'
        MOVWF   DLY2

D1_L2
        MOVLW   d'200'
        MOVWF   DLY3

D1_L3
        DECFSZ  DLY3, F
        GOTO    D1_L3

        DECFSZ  DLY2, F
        GOTO    D1_L2

        DECFSZ  DLY1, F
        GOTO    D1_L1

        RETURN


        END


