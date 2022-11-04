;-----------------------------------------------------
; Project:	DANREX LED LAMP CONTROL
; MCU:		PIC16F506
; File:		sysconfig.inc
; Author:	kai@hinoeng.co.jp
; Created on August 15, 2017, 9:20 AM   				
;-----------------------------------------------------
#define RESMASK		0xf8
#define PORSTAT		0x18				
;-------------------------------
; PWM STEP CONFIGURATIONs
;-------------------------------   
				
#if 0				; #if 0: Use 4 steps per second 
#define PWM_STEP_8  8		; #if 1: Use 5 steps per second
#else
#define PWM_STEP_5  5
#endif    
    
    
#ifdef PWM_STEP_8
#define PWM_STEP PWM_STEP_8	; @1500ms / 8 = 187 ms
;#define PWM_IVAL    0xb6	; PWM interval 182 x 256 x 4us = 187 ms
#define PWM_IVAL    0xf3	; PWM interval 244 x 256 x 4us = 250 ms				
#else
#ifdef PWM_STEP_5
#define PWM_STEP PWM_STEP_5
#define PWM_IVAL    0xc3	; PWM interval 244 x 256 x 4us = 200ms
#endif
#endif 
    
#define PWM_TSIZE PWM_STEP    
#define PWM_DOFF  PWM_TSIZE    
    
    
;----------------------------
; OTHER CONFIGURATIONs
;----------------------------    
#define CONFIG_USE_8CYCLES	; Use 8 checking cycles, comment out 
				; if unused
#ifdef CONFIG_USE_8CYCLES
#define PANEL_CHECK_INTERVAL	2 ; 8s
				  ; 1 - 2s   1 x PWM_IVAL x 8
				  ; 2 - 4s   2 x PWM_IVAL x 8
				  ; 3 - 6s   3 x PWM_IVAL x 8
				  ; 4 - 8s   4 x PWM_IVAL x 8
#endif				



#define CONFIG_DELAY_PAD
#ifdef  CONFIG_DELAY_PAD
#define PWM_TOFF    0xc3	; T_OFF: 200ms				  
#define PWM_TPAD_IVAL	    0xa	    ;	10x1024us
#define PWM_TPAD	    0x22    ; 34 x PWM_TPAD_IVAL = 350ms
				    ; 1500 - 200 x PWM_STEP = 350ms
#endif				  