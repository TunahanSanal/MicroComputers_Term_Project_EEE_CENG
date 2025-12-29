;==================================================
; TEMPERATURE MODULE TEST CODE
; Fan + Temperature + Tachometer (RPS)
; PIC16F877A  for Fosc= 10 MHz
	
; Author: Yusuf inan ---- 151220192079
; engr.inanyusuf@gmail.com

;====== NOTES =====================================
; DESIRED_TEMP =25 at line 108 you can change
; Turn MOVWF PORTB comment either at line 170 or at line 235
; Be aware of CLRF TRISB at line 79(just for debug purpose)
; All these codes work stably with a 10 MHz oscillator frequency.
; Because of delay functions in these codes
; To test goto line 125 MAIN_LOOP and remove ';' symbol before the function call you want to test
;==================================================
;=====NEW VERSION==================================
;Timer0 interrupt is used for 1 second timer to calculate RPS
;Timer1(RC0) counter is used for RPS count 
;HYSTERESIS added to control the FAN more stable
	
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
	    FAN_OFF_TEMP      ;(HEATER_ON_TEMP) Give us FAN hysteresis. it equals to(DESIRED_TEMP-2)
	    FAN_ON_TEMP	      ;(HEATER_OFF_TEMP)Give us FAN hysteresis. it equals to(DESIRED_TEMP+2)
            FAN_RPS           ; Tach result (RPS)
	    
	    ACQ_DELAY
	    T0_CNT		; Timer0 overflow counter(When this hit to 38, 1 sec is passed )
            ONE_SEC_FLAG	; 1 second elapsed flag
	    DLY1	        ;FOR 1 SECOND DELAY SUBROUTINE
	    DLY2		;FOR 1 SECOND DELAY SUBROUTINE
	    DLY3		;FOR 1 SECOND DELAY SUBROUTINE
        ENDC

        ORG 0x000
        GOTO INIT
	ORG 0x004
	GOTO ISR

;--------------------------------------------------
; INIT
;--------------------------------------------------
INIT:
	;============================
	; TIMER0 CONFIG (10 MHz)
	;============================
	BANKSEL OPTION_REG
	MOVLW b'00000111'
	; RBPU=0
	; T0CS=0   (Internal clock)
	; T0SE=0
	; PSA=0    (Prescaler -> TMR0)
	; PS=111   (1:256)
	MOVWF OPTION_REG

	BANKSEL TMR0
	CLRF TMR0

	BANKSEL INTCON
	BSF INTCON, T0IE     ; Timer0 interrupt enable
	BSF INTCON, GIE      ; Global interrupt enable

	CLRF T0_CNT
	CLRF ONE_SEC_FLAG
	;==================================================
    
        BANKSEL TRISA
	
        ; RA0 = Analog input
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

        BANKSEL ADCON0	    ;RAM Bank0 is selected
	
	
        MOVLW b'10000001'   ;Fosc/32, RA0 is seleted as ADC Channel
        MOVWF ADCON0	    ;GO=0, ADON=1 (ADC IS ACTIVE)

        ; Fixed set temperature = 25
        MOVLW d'25'
        MOVWF DESIRED_TEMP	    ;DESIRED TEMPERATURE	    
	DECF DESIRED_TEMP,W
	DECF DESIRED_TEMP,W
	MOVWF FAN_OFF_TEMP
	INCF DESIRED_TEMP,W
	INCF DESIRED_TEMP,W
	MOVWF FAN_ON_TEMP
	
	;HEATER AND COOLER INITIAL STATES
	
        BCF PORTC,5	;HEATER IS OFF
	BCF PORTC,2	;COOLER IS OFF

;=============================================================================
;		MAIN LOOP
;=============================================================================
MAIN_LOOP:

    BTFSS ONE_SEC_FLAG, 0   ; is 1 second passed
    GOTO MAIN_LOOP          ; NO, GOTO MAIN_LOOP

    ; --- YES, 1 Second passed. Do below block----
    BCF ONE_SEC_FLAG, 0     ; flag’i temizle

    	;CALL READ_TEMPERATURE
	;CALL CONTROL_TEMP
	CALL FAN_ON
	;CALL HEATER_ON
	CALL MEASURE_FAN_RPS
	CLRF TMR1L
	CLRF TMR1H
	
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
	
	;By adding Hysteresis, make more stable FAN control around DESIRED_TEMP 
	
        ;--- FAN ON CONTROL ---
        BANKSEL AMBIENT_TEMP
        MOVF    AMBIENT_TEMP, W
        BANKSEL FAN_ON_TEMP
        SUBWF   FAN_ON_TEMP, W       ; FAN_ON_TEMP(DESIRED_TEMP+2) - AMBIENT

        BTFSS   STATUS,0             ; C=0 → AMBIENT >= FAN_ON
        GOTO    FAN_ON

        ;--- FAN OFF CONTROL ---
        BANKSEL AMBIENT_TEMP
        MOVF    AMBIENT_TEMP, W
        BANKSEL FAN_OFF_TEMP
        SUBWF   FAN_OFF_TEMP, W      ; FAN_OFF_TEMP(DESIRED_TEMP-2) - AMBIENT

        BTFSC   STATUS,0             ; C=1 → FAN_OFF =>AMBIENT 
        GOTO    HEATER_ON

        
        GOTO    ALL_OFF
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

        MOVF    TMR1L, W
        MOVWF   FAN_RPS           ; PULSE COUNT IN 1 SECOND

        BANKSEL PORTB
        MOVF    FAN_RPS, W
        MOVWF   PORTB             ; DEBUG

        RETURN

;----------------------------------
; ~1 SECOND DELAY @ 10 MHz
;----------------------------------

DELAY_1SEC:
        MOVLW   d'25'
        MOVWF   DLY1

D1_L1:
        MOVLW   d'200'
        MOVWF   DLY2

D1_L2:
        MOVLW   d'200'
        MOVWF   DLY3

D1_L3:
        DECFSZ  DLY3, F
        GOTO    D1_L3

        DECFSZ  DLY2, F
        GOTO    D1_L2

        DECFSZ  DLY1, F
        GOTO    D1_L1

        RETURN

	
ISR:	
	BTFSS INTCON,T0IF
	GOTO ISR_EXIT
	BCF INTCON, T0IF
	INCF T0_CNT, F
	MOVLW d'38'          ; ~1 second @10MHz
	SUBWF T0_CNT, W
	BTFSS STATUS, Z	     ; in equality Z=1 SKIP ISR_EXIT
	GOTO ISR_EXIT

	;--- 1 second elapsed ---
	CLRF T0_CNT
	BSF ONE_SEC_FLAG, 0
	
ISR_EXIT:
	RETFIE

        END
