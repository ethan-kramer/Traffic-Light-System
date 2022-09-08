; TrafficLight.asm
;
; Created: 11/20/2021 10:18:29 AM
; Authors : Patrick McCormick, Ethan Kramer, Daniel Joseph
; Purpose: Traffic Light File

;----------------------Circutry Notes-------------------------------
;1k Ohm Resistors for buttons
;220 Ohm Resistors for LED's
;Positive = Annode (connect wire here)
;Negative = Cathode (connect resistor here)


;------------------------Global Defines and Macros-------------------------------------
.MACRO    _INIT_STACK               ; macro for stack initialization
     LDI  R16, HIGH(RAMEND)
     OUT  SPH, R16
     LDI  R16, LOW(RAMEND)
     OUT  SPL, R16
.ENDMACRO

.DEF ACTIVATED_LED = R18           ; used for array pointer1
.DEF STACK_END = R19               ; used for array pointer1
.DEF TEMP_REGISTER = R20           ; register for temporary storage
;.DEF ACTIVATED_LED2 = R21    

.EQU TL1_RED = (1<<PB5)            ; traffic light 1: RED
.EQU TL1_YELLOW = (1<<PB4)         ; traffic light 1: YELLOW
.EQU TL1_GREEN = (1<<PB3)          ; traffic light 1: Green

.EQU TL2_RED = (1<<PD7)            ; traffic light 2: RED
.EQU TL2_YELLOW = (1<<PD6)         ; traffic light 2: YELLOW
.EQU TL2_GREEN = (1<<PD5)          ; traffic light 2: Green

.EQU CROSS1_WHITE = (1<<PB5)|(1<<PB2)       ; crosswalk signal 1 for traffic light 1: WHITE
.EQU CROSS2_WHITE = (1<<PD7)|(1<<PD4)       ; crosswalk signal 2 for traffic light 2: WHITE

.EQU CYCLE_NORMAL = 3              ; used for pointer
.EQU CYCLE_CROSSWALK = 4           ; used for pointer
 
 ;--------------------Vector Table----------------------------------------
.ORG 0x0000                        ; start address
          RJMP MAIN

.ORG INT0addr                      ; external interrupt 0 request
          RJMP EXTERNAL0 
          
.ORG INT1addr
          RJMP EXTERNAL0           ; external interrupt 1 request. may need to edit once 2nd light set works

.ORG OC1Aaddr                   ; 
          RJMP START_OCR1_ROUTINE

.ORG INT_VECTORS_SIZE                   ;
;--------------------------------------------------------------------


MAIN:
     _INIT_STACK

     ;--------------------Set Array Pointer Z----------------------------
     LDI  ZH, HIGH(ALL_LIGHTS1<<1)
     LDI  ZL, LOW(ALL_LIGHTS1<<1)

     LDI  ACTIVATED_LED, 0       ; tracks which light is activated
     LDI  STACK_END, CYCLE_NORMAL  

     ;--------------Traffic Light 1 Output Pins-------------------------
     SBI  DDRB, PB5                  ; set PB5 to output (TL1: red LED)
     SBI  DDRB, PB4                  ; set PB4 to output (TL1: yellow LED)
     SBI  DDRB, PB3                  ; set PB3 to output (TL1: green LED)
     SBI  DDRB, PB2                  ; set PB2 to output (TL1 crosswalk: white)

     ;--------------Traffic Light 2 Output Pins-------------------------
     SBI  DDRD, PD7                  ; set PD7 to output (TL2: red LED)
     SBI  DDRD, PD6                  ; set PD6 to output (TL2: yellow LED)
     SBI  DDRD, PD5                  ; set PD5 to output (TL2: green LED)
     SBI  DDRD, PD4                  ; set PD4 to output (TL2 crosswalk: white)
     
     ;--------------TESTING--------------------------------
  
     ;-----------------Set Crosswalk Button 1 To Pull-Up------------------
     CBI  DDRD,DDD2           ; set PORTD PIN2 to input (must be PD2 for External Intrruput 0 to function)
     SBI  PORTD,PD2           ; set PORTD PIN2 to pull-up

     ;-----------------Set Crosswalk Button 2 To Pull-Up------------------
     CBI  DDRD,DDD3           ; set PORTD PIN3 to input (must be PD3 for External Intrruput 0 to function)
     SBI  PORTD,PD3           ; set PORTD PIN3 to pull-up

     ;-----------------Interrupt For Button 1 and Button 2-----------------------------
     LDI  TEMP_REGISTER, (1<<INT0) | (1<<INT1)
     OUT  EIMSK, TEMP_REGISTER     ; enables exernal interrupt 0 in external interrupt mask register
     LDI  TEMP_REGISTER, (1<<ISC01) |(1<<ISC11)
     STS  EICRA, TEMP_REGISTER     ; enables falling edge bits of external interrupt control register A

     ;------------------Timer 1 Setup: 3 Second Delay---------------------
     CLR  TEMP_REGISTER
     STS  TCNT1H, TEMP_REGISTER
     STS  TCNT1L, TEMP_REGISTER
     LDI  TEMP_REGISTER, 0xB7
     STS  OCR1AH, TEMP_REGISTER              ; OCR1AH  = 0xB7 HIGH byte
     LDI  TEMP_REGISTER, 0x1A
     STS  OCR1AL, TEMP_REGISTER              ; OCR1AL = 0x1A LOW byte

     CLR  TEMP_REGISTER
     STS  TCCR1A, TEMP_REGISTER              ; clear Timer Counter Control Register A
     LDI  TEMP_REGISTER, (1<<WGM12)|(1<<CS12)|(1<<CS10)
     STS  TCCR1B, TEMP_REGISTER              ; CTC mode 1024 prescaler

     LDI  TEMP_REGISTER, (1<<OCIE1A)
     STS  TIMSK1, TEMP_REGISTER              ; CTC A interrupt in mask register


;---------------------Start Program---------------------------------------
SEI                                     ; global interrupts enabled
END:     
     RJMP END

;---------------------External Interrupt 0--------------------------------
EXTERNAL0:
     LDI  STACK_END, CYCLE_CROSSWALK
     RETI

;---------------------Timer 1 Interrupt-------------------------------------
START_OCR1_ROUTINE:
     LPM  R0, Z+                             ; gets current light and increments pointer
     OUT  PORTB, R0                          ; toggle light

     INC  ACTIVATED_LED
     CP   ACTIVATED_LED, STACK_END
     BRNE STOP_OCR1_ROUTINE
     LDI  ZH, HIGH(ALL_LIGHTS1<<1)
     LDI  ZL, LOW(ALL_LIGHTS1<<1)

     LDI  ACTIVATED_LED, 0
     LDI  STACK_END, CYCLE_NORMAL

STOP_OCR1_ROUTINE:
     RETI                                    ; exit OCR1 routine

ALL_LIGHTS1:
     .DB  TL1_GREEN, TL1_YELLOW, TL1_RED, CROSS1_WHITE