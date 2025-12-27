;==============================================================================
; Temperature Control Module Test Code
; Written by YUSUF ?NAN  (151220192079)-----26/12/2025
; engr.inanyusuf@gmail.com	
; PIC16F877A
; MPLAB X IDE v6.25-- XC8 / pic-as  is Used

; -----NOTE-------
; You can Change desired temperature at line 93
; FOR TEST Goto  MAIN_LOOP: and test all the properties with function calls that are turned into comments
;==============================================================================

        PROCESSOR 16F877A
        #include <xc.inc>

;==============================================================================
; CONFIGURATION BITS
;==============================================================================
        CONFIG  FOSC = HS
        CONFIG  WDTE = OFF
        CONFIG  PWRTE = ON
        CONFIG  BOREN = OFF
        CONFIG  LVP = OFF
        CONFIG  CPD = OFF
        CONFIG  WRT = OFF
        CONFIG  CP = OFF

;==============================================================================
; RAM VARIABLES (BANK0)
;==============================================================================
        PSECT   udata_bank0

DESIRED_TEMP:   DS 1	;desired temperature 8BIT 0-255
AMBIENT_TEMP:   DS 1	;ambient temperature (ADC) 0-255
LOOP_DELAY:     DS 1	;for ADC Acquisition Delay
FAN_RPS:	DS 1	;Keeps Calculated Fan RPS Value

D1:	DS 1		;for 1_second delay
D2:	DS 1		;for 1_second delay
D3:	DS 1		;for 1_second delay
    

;===========================================================================
; RESET VECTOR
;==============================================================================
        PSECT   resetVec, class=CODE, delta=2
        ORG     0x0000
        GOTO    INIT

;==============================================================================
; INITIALIZATION
;==============================================================================
INIT:
        CLRF    INTCON		;Blocks all Interrupts During Process
	
	; --- PORT CONFIG ---
        BANKSEL TRISA		;
        MOVLW   0010001B	;RA0 and RA4 Configured as Input
        MOVWF   TRISA	    

        BANKSEL TRISC		; RC2,RC5 OUTPUT
        MOVLW   11011011B	; RC2 =>COOLER FAN
	MOVWF   TRISC		; RC5 =>HEATER
	
	BANKSEL OPTION_REG	;PSA ASSIGNED TO WDT,Counter mode selected
	MOVLW	00101000B	;RA4 SET AS CLOCK SOURCE(COUNTER FOR TACHOMETER)
	MOVWF	OPTION_REG	;T0SE RESET to RA4's Low to High Transition
				
	
	BANKSEL TMR0	    ;TMR0 SET TO ZERO FOR INITIAL COUNTER VALUE
	CLRF TMR0
;------------------------------------------
        BANKSEL TRISB	    ;To watch ADC OR RPS value on PORTB 
        CLRF    TRISB
        BANKSEL PORTB	    ;
        CLRF    PORTB
;--------------------------------------------------	
	;--- OUTPUT INITIAL STATE ---
        BANKSEL PORTC	    
        BCF     PORTC, 5    ;HEATER OFF
        BCF     PORTC, 2    ;COOLER FAN OFF

        
	
	;--- ADC CONFIG ---
	BANKSEL ADCON1	    ; ADC Result is Left Justified
	MOVLW   00001110B   ; +Vref=Vdd, -Vref=Vss
	MOVWF   ADCON1	    ;RA0 configured as ANALOG IN, for Temp. Sensor LM35 

        BANKSEL ADCON0	    ; ADC ON, and CH0 (RA0) selected for ADC Channel
        MOVLW   01000001B   ;01 000 0 0 1 --fosc/8--AN0--GO=0--ADON=1
        MOVWF   ADCON0
	
	; --- Desired temperature default ---
        MOVLW   25	    
        BANKSEL DESIRED_TEMP
        MOVWF   DESIRED_TEMP

;==============================================================================
; MAIN LOOP
;==============================================================================
MAIN_LOOP:
        ;CALL    READ_TEMP
        ;CALL    CONTROL_TEMP
	CALL	 FAN_ON
	CALL MEASURE_RPS
	;CALL	 HEATER_ON
	;CALL DELAY_1S
	
	
        GOTO    MAIN_LOOP

;==============================================================================
; READ AMBIENT TEMPERATURE (ADC)
;==============================================================================
READ_TEMP:
        MOVLW   25		;it is for ADC Acquisition delay
        BANKSEL LOOP_DELAY
        MOVWF   LOOP_DELAY

ADC_ACQ:
        NOP			; Acquisition delay (~25 us)
        DECFSZ  LOOP_DELAY, F
        GOTO    ADC_ACQ

        BANKSEL ADCON0
        BSF     ADCON0, 2	; GO/DONE = 1 ,ADC Started

WAIT_ADC:
        BTFSC   ADCON0, 2
        GOTO    WAIT_ADC	;WAIT UNTIL CONVERSION IS FINISHED
	
	
	BANKSEL ADRESH	;Bir bit sola kayd?rarak s?cakl??? tam say? olarak gösterir
	
	RLF   ADRESH,W	;(2C hassasiyet düzeltilecek)
        		;ADRESH==HIGH BYTE OF THE CONVERSION RESULT
			;IS TRANSFERRED TO AMBIENT_TEMP REGISTER 
        BANKSEL AMBIENT_TEMP	
        MOVWF   AMBIENT_TEMP	
	BANKSEL PORTB		;to watch ADC value on PORTB
        MOVWF   PORTB		;Smilar one is on MEASURE_RPS
				;make one of theese  --MOVWF   PORTB--
				;Lines comment line

        

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

        BTFSC   STATUS, 0   ; IF DESIRED > AMBIENT; GOTO HEATER_ON 
        GOTO    HEATER_ON	    ;ELSE; GOTO FAN_ON
	;STATUS(C)=0 DESIRED-AMBIENT =POSITIVE RESULT
	;STATUS(C)=1 DESIRED-AMBIENT =NEGATIVE RESULT
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

;==============================
; Measure Fan Speed (RPS)
;==============================
MEASURE_RPS:

    BANKSEL TMR0
    CLRF    TMR0          ; RESET Timer0
    NOP			  ;for 2Tcy TMR0 do not count
    NOP			  ;for 2Tcy TMR0 do not count

			  ;To calculate RPS(rotation per second)
    CALL    DELAY_1S      ;For 1_second, Count Pulses from RA4(TOCKI)
			  ;This counter value recorded to TMR0 register
    
			  
    BANKSEL TMR0	  ;RPS Value on  TMR0 register, 
    MOVF    TMR0, W       ;Recorded to FAN_RPS register 
   
    BANKSEL FAN_RPS
    MOVWF   FAN_RPS
    
    BANKSEL PORTB
    MOVWF   PORTB
    

    RETURN
	
    
;==============================
; 1 SECOND DELAY used for RPS Calculation( ? 1.075 SECOND)
;==============================	
DELAY_1S:
    MOVLW   250       ; D1 = 250
    MOVWF   D1
D1_LOOP:
    MOVLW   200       ; D2 = 200
    MOVWF   D2
D2_LOOP:
    MOVLW   10        ; D3 = 10
    MOVWF   D3
D3_LOOP:
    NOP
    DECFSZ  D3, F
    GOTO    D3_LOOP
    DECFSZ  D2, F
    GOTO    D2_LOOP
    DECFSZ  D1, F
    GOTO    D1_LOOP
    RETURN
        END
