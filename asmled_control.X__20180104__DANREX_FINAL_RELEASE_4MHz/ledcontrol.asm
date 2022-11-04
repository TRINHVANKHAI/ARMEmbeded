
;-----------------------------------------------------
; Project:	DANREX LED LAMP CONTROL
; MCU:		PIC16F506
; File:		ledcontrol.asm
; Author:	kai@hinoeng.co.jp    
; Created on March 17, 2017, 8:07 AM      
;-----------------------------------------------------
; MAX DUTY 50%@50kHz
; DUTY SETTING USE DUTY_TABLE
;=====================================================  
    
LIST P=16F506
#include <p16f506.inc>
#include <sysconfig.inc>    
    
;----------------------------------------
; CONFIGURATIONS
;----------------------------------------    
; SYSCLK:	  4MHz - internal OSC
; WATCHDOG:	  OFF
; MASTER RESET:   Unused
; CODE PROTECTED: OFF 
;----------------------------------------
__CONFIG (_IntRC_OSC_RB4EN & _WDT_OFF & _MCLRE_OFF & _IOSCFS_OFF & _CP_OFF)
   
      
;------------------------
; PWM control registers
;------------------------  
CBLOCK	0x12
    pwmDuty
    pwmPeriod
    pwmIndex
    pwmInterval
    pwmTon		    ;;;ADDED 20170901
    pwmPad
    ;;pwmDi
    pwmPi
    pwmTR
    pwmFR
    inpCheck
    cmpFR
    resSR
    ENDC    
;------------------
; INITIALIZATION
;------------------
RES_VECT  CODE    0x0000            ; processor reset vector 
    BCF	    FSR,5		    ; Select BANK0
    BCF	    FSR,6		    ; Select BANK0 
    MOVF    STATUS,W		    ; Get status register
    ANDLW   RESMASK    
    MOVWF   resSR
    BCF	    STATUS,7		    ; Clear reset cause's flag
    BCF	    STATUS,6
    BCF	    STATUS,5
    CLRWDT			    ; TMR0 init
    CLRF    TMR0		    ; Timer interval 2ms
    MOVLW   0xc2		    ; TMR0 0x02=4us 0x03=8us
    OPTION  
    CLRF    PORTB
    CLRF    PORTC
    MOVLW   0xcf
    TRIS    PORTB		    ; Set RB4, RB5 as output
    MOVLW   0xf7
    TRIS    PORTC		    ; Set RC3 as output
    MOVLW   0x30
    MOVWF   ADCON0		    ; Disable ADC
    MOVLW   0xeb		    ; CM1 Disable output
    MOVWF   CM1CON0		    ; CM1 Disable wakeup    
    MOVLW   0xea		    ; CM2 disable output
    MOVWF   CM2CON0		    ; CM2 Enable wakeup
    MOVLW   0xa8		    ; Use low range
    MOVWF   VRCON		    ; VRCON = 0.8V @2.4VDC  			    
    CALL    DELAY_10us		    ; NEED delay for stable
    CALL    DELAY_10us
    CLRF    inpCheck		    
    CLRF    pwmIndex
    CLRF    pwmTR
    CLRF    pwmInterval    
    BCF	    PORTC,3		    ; Turn off PWMBOOST
    BCF	    PORTB,4		    ; Turn off LED1
    BCF	    PORTB,5		    ; Turn off LED2    
    MOVF    resSR,W
    XORLW   PORSTAT
    BTFSS   STATUS,Z		    ; Detect POR
    GOTO    RESTART		    ; Check solar panel input
    GOTO    START		    ; Enter running mode
;-------------------
; MAIN PROCESS
;------------------- 
MAIN_PROG CODE                      ; Let linker place main program
 
RESTART 

    MOVF    CM1CON0,W		    ; 
    ANDLW   0x80
    BTFSS   STATUS,Z		    ; if C1OUT=0
    GOTO    SYS_SLEEP

#ifdef CONFIG_USE_8CYCLES	    ; Enable 8 checking cycles   
    MOVF    TMR0,W
    XORWF   pwmFR,W
    ANDLW   0x80
    BTFSC   STATUS,Z
    GOTO    RESTART
    COMF    pwmFR,F
    INCF    pwmTR,F		    ; Increse timer counter
    MOVLW   PWM_IVAL		    ; 200ms
    XORWF   pwmTR,W
    BTFSS   STATUS,Z		    ;
    GOTO    RESTART
    CLRF    pwmTR		    ; Exceed timer interval, reset  
    INCF    pwmInterval,F
    MOVLW   PANEL_CHECK_INTERVAL    ; Reach solar pannel's check    
    XORWF   pwmInterval,W	    ; interval value
    BTFSS   STATUS,Z		    ; 
    GOTO    RESTART
    CLRF    pwmInterval
    RLF	    inpCheck,F		    ; Goto sleep if C2OUT=1
    BTFSC   CM2CON0,C2OUT	    ; Get C2OUT
    BSF     inpCheck,0
    BTFSS   CM2CON0,C2OUT
    CLRF    inpCheck 
    MOVF    pwmIndex,W		    ; Get checking cycle count
    INCF    pwmIndex,F		    ; Increase checking cycle 
    XORLW   8			    ; Make sure solar panel input
    BTFSS   STATUS,Z		    ; is low in 8 checking cycles
    GOTO    RESTART		    ; 8 x 1s = 8s
    MOVF    inpCheck,W
    ANDLW   0xFF		    
    BTFSS   STATUS,Z		    ; is low for 8 times    
    GOTO    SYS_SLEEP		    ; goto sleep
    CLRF    inpCheck		    
    CLRF    pwmIndex
    CLRF    pwmTR
    CLRF    pwmInterval
    GOTO    START		    ; else enter normal running mode
#else				    ; Check solar panel once only     
    MOVF    CM2CON0,W
    ANDLW   0x80
    BTFSS   STATUS,Z
    GOTO    SYS_SLEEP 
    GOTO    START		    ; Enter running mode          
#endif    

;-----------------------
; START RUNNING MODE
;-----------------------    
START
    BSF	    CM1CON0,C1ON	    ; Enable C1
    MOVLW   PWM_TSIZE               ; Duty table size
    SUBWF   pwmIndex,W
    BTFSC   STATUS,Z		    ;
    CLRF    pwmIndex		    ; If index == 5; clear it
    
;;;----20170901 Jail 50kHz @50%duty-------   
;;; For unlock, set to #if 1    
;;;---------------------------------------    
#if 0 
    MOVF    pwmIndex,W		    ; Get index  
    CALL    GET_DUTY
    MOVWF   pwmDuty		    ; Duty index      
    MOVLW   PWM_DOFF                ; Period offset
    ADDWF   pwmIndex,W		    ;
    CALL    GET_DUTY		    ; Get period
    MOVWF   pwmPeriod
#else
    MOVLW   0x01
    MOVWF   pwmDuty
    MOVLW   0x01
    MOVWF   pwmPeriod
#endif 
;;;----20170901 Jail 50kHz @50%duty-------       
    
;;;-------20170901------------    
    MOVF    pwmIndex,W		    
    CALL    GET_TON_P3
    MOVWF   pwmTon
;;;-------20170901------------    
#ifndef CONFIG_DELAY_PAD	    ; Default turned on
    MOVLW   3			    ; Turn off 1st of PWM per one sec 
    SUBWF   pwmIndex,W		    ; #if 0: normal mode
    BTFSS   STATUS,0		    ; #if 1: 2 first PWM will be turned off
    GOTO    PWM_OFF		    ; to keep led clearly off and reduce
				    ; consumption
#endif    
    BSF	    PORTB,RB5
    ;;;BSF	    PORTB,RB4    
PWM_PUT				    ; PWMBOOST control
    BCF	    PORTC,RC3		    ; POS     
    MOVF    pwmPeriod,W
    MOVWF   pwmPi
    DECFSZ  pwmPi,F
    GOTO    $-1
    NOP
    BTFSC   CM1CON0,C1OUT	    ; If overcurrent occured
    ;;GOTO    SYS_SLEEP		    ; Goto sleep immediately
    RRF     pwmIndex,F		    ; Or reduce pwm duty 
    MOVF    TMR0,W
    XORWF   pwmFR,W		
    BSF	    PORTC,RC3		    ; NEG     
    ANDLW   0x80		    ;
    BTFSC   STATUS,Z		    ; Test if TMR0 is overflow
    GOTO    $+3		            ; No overflow is occured
    COMF    pwmFR,F
    INCF    pwmTR,F		    ; Increase PWM count
    ;;;MOVLW   0x14		    ; Set major duty here 20ms
    MOVF    pwmTon,W		    ; 20170901 free pwm Ton
    SUBWF   pwmTR,W		    ; Increase timer counter
    BTFSS   STATUS,Z		    ; If 20ms then stop PWM
    GOTO    PWM_PUT
    
    BCF	    PORTC,RC3
    BCF	    PORTB,RB5
    CLRF    pwmTR
    CALL    DELAY_10us
    CALL    DELAY_10us
    BSF	    PORTB,RB4
    ;RLF	    pwmTon,F
    ;-------------------------------
PHASE_MOVE
    BCF	    PORTC,RC3		    ; POS     
    MOVF    pwmPeriod,W
    MOVWF   pwmPi
    DECFSZ  pwmPi,F
    GOTO    $-1
    NOP
    BTFSC   CM1CON0,C1OUT	    ; If overcurrent occured
    ;;GOTO    SYS_SLEEP		    ; Goto sleep immediately
    RRF     pwmIndex,F		    ; Or reduce pwm duty	    
    MOVF    TMR0,W
    XORWF   pwmFR,W	
    BSF	    PORTC,RC3		    ; NEG    
    ANDLW   0x80		    ;
    BTFSC   STATUS,Z		    ; Test if TMR0 is overflow
    GOTO    $+3		            ; No overflow is occured
    COMF    pwmFR,F
    INCF    pwmTR,F		    ; Increase PWM count
    ;;;MOVLW   0x14		    ; Set major duty here 20ms
    MOVF    pwmTon,W		    ; 20170901 free pwm Ton
    SUBWF   pwmTR,W		    ; Increase timer counter
    BTFSS   STATUS,Z		    ; If 20ms then stop PWM
    GOTO    PHASE_MOVE
    BCF	    PORTB,RB4
    ;-------------------------------
    
PWM_OFF
    BCF	    PORTC,RC3
    BCF	    PORTB,RB4
    BCF	    PORTB,RB5
    BCF	    CM1CON0,C1ON	    ; Disable C1
;---------------------   
; MAIN LOOP
;---------------------    
LOOP  
    ;------------
    
    ;------------
    MOVF    TMR0,W
    XORWF   pwmFR,W
    ANDLW   0x80
    BTFSC   STATUS,Z
    GOTO    LOOP
    COMF    pwmFR,F
    INCF    pwmTR,F		    ; Increse timer counter
    MOVLW   PWM_TOFF		    ; 200ms
    XORWF   pwmTR,W
    BTFSS   STATUS,Z		    ;
    GOTO    LOOP
    CLRF    pwmTR		    ; Exceed timer interval, reset
    INCF    pwmIndex,F		    ; Increase PWM index   
#ifdef CONFIG_DELAY_PAD
    MOVLW   PWM_STEP
    XORWF   pwmIndex,W
    BTFSC   STATUS,Z
    CALL    DELAY_PADDING
#endif  ; CONFIG_DELAY_PAD
    INCF    pwmInterval,F
    MOVLW   PANEL_CHECK_INTERVAL    ; Reach solar pannel's check 		    
    XORWF   pwmInterval,W	    ; interval value
    BTFSS   STATUS,Z		    ; 
    GOTO    START
    CLRF    pwmInterval   
    
#ifdef CONFIG_USE_8CYCLES    
    ;;BSF	    VRCON,VREN	    ; For reducing power consumption
    BSF	    CM2CON0,C2ON	    ; only turn on C2 once every second
    CALL    DELAY_10us		    ; Make sure C2 stablized

    RLF	    inpCheck,F		    ; Check solar panel input for 8 cycles
    BTFSC   CM2CON0,C2OUT	    ; and make sure if it is high for all
    BSF     inpCheck,0		    ; cycles
    BTFSS   CM2CON0,C2OUT
    CLRF    inpCheck
    BCF     CM2CON0,C2ON	    ; Turn off C2
    ;;BCF	    VRCON,VREN
    MOVF    inpCheck,W
    XORLW   0xFF
    BTFSS   STATUS,Z
    GOTO    START		    ;
    CLRF    inpCheck  
    ;;BSF	    VRCON,VREN
    BSF	    CM2CON0,C2ON	    ; Keep C2 running before entering sleep
    CALL    DELAY_10us		    ; for monitering solar panel input
    GOTO    SYS_SLEEP 
    
#else
    ;;BSF   VRCON,VREN	            ; For reducing power consumption
    BSF	    CM2CON0,C2ON	    ; only turn on C2 once every second
    CALL    DELAY_10us		    ; Make sure C2 stablized
    MOVF    CM2CON0,W
    ANDLW   0x80
    BTFSS   STATUS,Z
    GOTO    SYS_SLEEP
    BCF	    CM2CON0,C2ON	    ; Turn off C2
    ;;BCF   VRCON,VREN
    GOTO    START		    ; Goto start
#endif    

    GOTO    $			    ; End of main

;-------------------    
; DUTY TABLE
;-------------------    
GET_DUTY			    
    ADDWF   PCL,F
#ifdef PWM_STEP_5    
    RETLW   0x1			    ; 0
    RETLW   0x2			    ; 1
    RETLW   0x4			    ; 2
    RETLW   0x5			    ; 3
    RETLW   0x6		            ; 4
    RETLW   0x6			    ; 0
    RETLW   0x5			    ; 1
    RETLW   0x3			    ; 2
    RETLW   0x2                     ; 3 
    RETLW   0x1			    ; 4 
#else
#ifdef PWM_STEP_4	    ;
    RETLW   0x1		    ;0 POS 
    RETLW   0x2		    ;1 POS
    RETLW   0x4		    ;2 POS
    RETLW   0x6		    ;3 POS
    RETLW   0x6		    ;0 NEG
    RETLW   0x5		    ;1 NEG
    RETLW   0x3		    ;2 NEG
    RETLW   0x1		    ;3 NEG
#endif
#endif    
    
GET_TON_P1
    ADDWF   PCL,F   
    RETLW   0x0a	; 2
    RETLW   0x13	; 3
    RETLW   0x1d	; 4
    RETLW   0x27	; 5
    RETLW   0x31	; 6
    
GET_TON_P2
    ADDWF   PCL,F 
    RETLW   0x05	; 2 5
    RETLW   0x05	; 3 5
    RETLW   0x09	; 4 10
    RETLW   0x1d	; 5 30
    RETLW   0x31	; 6 50
    
GET_TON_P3
    ADDWF   PCL,F  
    RETLW   0x05	; 2 5
    RETLW   0x05	; 3 5
    RETLW   0x09	; 4 10
    RETLW   0x1d	; 5 30
    RETLW   0x61	; 6 100
    
GET_TON_P4
    ADDWF   PCL,F  
    RETLW   0x09	; 2 10
    RETLW   0x09	; 3 10
    RETLW   0x09	; 4 10
    RETLW   0x1d	; 5 30
    RETLW   0x1d	; 6 30

GET_TON_P5
    ADDWF   PCL,F 
    RETLW   0x09	; 2 10
    RETLW   0x09	; 3 10
    RETLW   0x1d	; 4 30
    RETLW   0x1d	; 5 30
    RETLW   0x61	; 6 100
    
;-------------------
; SUBROUTINES
;-------------------    
SYS_SLEEP
    CLRF    PORTB
    CLRF    PORTC
    MOVLW   0xff
    TRIS    PORTB		    ; Disable PWM
    MOVLW   0xff
    TRIS    PORTC		    ; Disable PWM
    MOVLW   0x30 
    MOVWF   ADCON0		    ; Disable ADC
    MOVLW   0xe3
    MOVWF   CM1CON0		    ; Disable C1 
    MOVF    CM2CON0,W
    MOVWF   0xF
    SLEEP
    
DELAY_10us    
    GOTO    $+1		
    GOTO    $+1	
    GOTO    $+1	
    GOTO    $+1	
    GOTO    $+1	
    GOTO    $+1	
    GOTO    $+1	
    GOTO    $+1	
    GOTO    $+1	
    GOTO    $+1
    RETURN
    
DELAY_PADDING
#ifdef  CONFIG_DELAY_PAD  
    MOVF    TMR0,W
    XORWF   pwmFR,W
    ANDLW   0x80
    BTFSC   STATUS,Z
    GOTO    DELAY_PADDING
    COMF    pwmFR,F
    INCF    pwmTR,F		    ; Increse timer counter
    MOVLW   PWM_TPAD_IVAL	    ; 10ms
    XORWF   pwmTR,W
    BTFSS   STATUS,Z		    ;
    GOTO    DELAY_PADDING
    CLRF    pwmTR		    ; Exceed timer interval, reset  
    INCF    pwmPad,F
    MOVLW   PWM_TPAD		    ; Exceed padding delay   
    XORWF   pwmPad,W		    ; interval value
    BTFSS   STATUS,Z		    ; 
    GOTO    DELAY_PADDING
    CLRF    pwmPad 
#endif    
    RETLW   0
    
;-------------------
; FOR DEBUG
;-------------------    
TMR0_TEST_FREQ  
    BTFSC   TMR0,7
    BSF	    PORTC,3
    BTFSS   TMR0,7
    BCF	    PORTC,3
    GOTO    TMR0_TEST_FREQ
  
CM2_TEST_FUNC
    BTFSC   CM2CON0,C2OUT
    BSF     PORTC,3
    BTFSS   CM2CON0,C2OUT
    BCF	    PORTC,3
    GOTO    CM2_TEST_FUNC
    END
    
    
