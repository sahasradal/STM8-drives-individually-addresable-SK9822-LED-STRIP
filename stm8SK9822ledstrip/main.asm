stm8/

	#include "mapping.inc"
	#include "STM8S103F.inc"
	
  
;MACRO's HERE
pointerX MACRO first		; mactro for calling pointerX
	ldw X,first
	MEND
pointerY MACRO first		; macro for calling pointer Y
	ldw Y,first
	MEND  
millis MACRO first			; macro for milli seconds , eg call  millis 100 for 100ms
	pushw Y
	ldw Y,first
	call delayYx1mS
	popw Y
	MEND
	
micros MACRO first			; macro for micro seconds , eg micros 100  for 100us
	pushw Y
	ldw Y,first
	call usdelay
	popw Y
	MEND  
  
	  segment byte at 100 'ram1' 
	  
;ALL RAM variables here	  
buffer1  ds.b		; reserve 1 byte for temp storage
buffer2  ds.b		; reserve 1 byte for temp storage
buffer3  ds.b		; reserve 1 byte for temp storage
buffer4  ds.b		; reserve 1 byte for temp storage	  
data     ds.b		; reserve 1 byte for SPI data storage	  
red      ds.b		; reserve 1 byte for red led PWM value
green    ds.b		; reserve 1 byte for green led PWM value
blue     ds.b		; reserve 1 byte for blue led PWM value
colourstep ds.b		; 1 byte reserved for number of PWM value , each 10 bytes is 1 colour fade	  



;COMPILER/STUDIO GENERATED STACK SET UP CODE
	segment 'rom'
main.l
	; initialize SP
	ldw X,#stack_end
	ldw SP,X

	#ifdef RAM0	
	; clear RAM0
ram0_start.b EQU $ram0_segment_start
ram0_end.b EQU $ram0_segment_end
	ldw X,#ram0_start
clear_ram0.l
	clr (X)
	incw X
	cpw X,#ram0_end	
	jrule clear_ram0
	#endif

	#ifdef RAM1
	; clear RAM1
ram1_start.w EQU $ram1_segment_start
ram1_end.w EQU $ram1_segment_end	
	ldw X,#ram1_start
clear_ram1.l
	clr (X)
	incw X
	cpw X,#ram1_end	
	jrule clear_ram1
	#endif

	; clear stack
stack_start.w EQU $stack_segment_start
stack_end.w EQU $stack_segment_end
	ldw X,#stack_start
clear_stack.l
	clr (X)
	incw X
	cpw X,#stack_end	
	jrule clear_stack
	
	
	
;MAIN LOOP OR MAIN PROGRAM STARTS HERE
infinite_loop.l

fclk.l 		equ 16000000	; processor speed for delay calculation
LEDnum		equ 30			; number of LEDs in the SK9822strip
	
	mov CLK_CKDIVR,#$00	; cpu clock no divisor = 16mhz
	
	bset PD_DDR,#2		;PD2 as output DATA
	bset PD_DDR,#3		;PD3 as output CLOCK
	bset PD_CR1,#2		;set as fast output pushpull
	bset PD_CR2,#2		;set as fast output pushpull
	bset PD_CR1,#3		;set as fast output pushpull
	bset PD_CR2,#3		;set as fast output pushpull
	bset PD_ODR,#2		;set data high and clock low  spi mode 0,data PD2, clock PD3
	
mainloop:
	call start_frame	; call start_frame routine,SK9822 requires 32 0's to start
	call audiframe		; call audiframe which sends LED sequence like audi car indicator
	call ms100			; the LEDs stay lit after all are lit up 1 by 1 ,100ms
	call start_frame	; call start_frame routine,SK9822 requires 32 0's to start
	call frame0			; transmits 0x00 to all colours , led strip has no light
	call ms100			; LEDCsrip stays dark for 100ms
	call start_frame	; call start frame again to begine new sequence
	call redframe		; call redframe which lights up the red LEDs in the strip
	call ms250			; delay 250ms
	call start_frame	; call start frame again to begine new sequence
	call greenframe		; caall greenframe which lights up the green LEDs in the strip
	call ms250			; delay 250ms
	call start_frame	; call start frame again to begine new sequence
	call blueframe		; call blueframe which lights up the blue LEDs in the strip
	call ms250			; delay 250ms
	call start_frame	; call start frame again to begine new sequence
	call mixframe1		; blue and green si mixed
	call ms250			; delay 250ms
	call start_frame	; call start frame again to begine new sequence
	call mixframe2		; green and red is mixed
	call ms250			; delay 250ms
	call start_frame	; call start frame again to begine new sequence
	call mixframe3		; blue and red is mixed
	call ms250			; delay 250ms
	call start_frame	; call start frame again to begine new sequence
	call frame0			; transmits 0x00 to all colours , led strip has no light
	call ms250			; delay 250ms
	call start_frame	; call start frame again to begine new sequence
	call bullet			; sends a fram animating a single led shoots across the strip
	mov colourstep,#100	; load coloursteps with 100, means 100 different colour / fade combinations 
	pointerX #colour1	; set pointer X to colour1 array by calling macro pointerX
	call fade			; call subroutine fade to mix and fade colours one by one
	
	jra mainloop		;repeat sequence by branching to mainloop label
	
	
SPI:
	mov buffer1,#8  	; move counter value 8 for 8 bits
TX:
	sll data			; shift left data
	jrc hi				; branch to label hi if carry set
	bres PD_ODR,#2 		; set data low
	call us1			; 1us delay
	bset PD_ODR,#3		; clock high
	call us1			; 1us delay
	bres PD_ODR,#3		; clock low
	dec buffer1			; decrease counter
	jrne TX				; if counter not 0 loop back to label TX
	ret
hi:
	bset PD_ODR,#2 		; set data high
	call us1			; 1us delay
	bset PD_ODR,#3		; clock high
	call us1			; 1us delay
	bres PD_ODR,#3		; clock low
	dec buffer1			; decrease counter
	jrne TX				; if counter not 0 loop back to label TX
	ret
	
start_frame:
	mov buffer2,#4 		; counter value 4 to transmit 0 x 4
st_tx:
	mov data,#0			; load data with 0 , start frame has four 0 bytes to be transmitted to LEDstip
	call SPI			; transmit  byte loaded in data
	dec buffer2			; decrease count
	jrne st_tx			; if counter not 0 loop back till 4 bytes rae transmitted
	ret					; return to caller
	
greenframe:
	mov buffer2,#30		; the LED strips I have has 30 leds ,so counter is 30
gloop:
	mov data,#$e0		; constant value of 0xe0 + PWM value of 0b00000 (0) to 0b11111 (31)
	ld a,#2				; load a with PWM value 2. arbitarirly chosen value 2 of 31
	or a,data			; OR A with contents in data
	ld data,a			; mov the contents of A (0xe0 ORed with 2 = 0xe2)
	call SPI			; transmit data
	mov data,#$00		; BLUE = 0
	call SPI			; transmit data
	mov data,#$ff		; GREEN = 256
	call SPI			; transmit data
	mov data,#$00		; BLUE = 0
	call SPI			; transmit data
	dec buffer2			; decrease counter
	jrne gloop			; call end frame to indicate end of data stream
	call end_frame		; call end frame to indicate end of data stream
	call ms250			; delay 250ms
	ret					; return to caller
	
blueframe:
	mov buffer2,#30		; the LED strips I have has 30 leds ,so counter is 30
bloop:
	mov data,#$e0		; constant value of 0xe0 + PWM value of 0b00000 (0) to 0b11111 (31)(decides brightness)
	ld a,#2				; load a with PWM value 2. arbitarirly chosen value 2 of 31
	or a,data			; OR A with contents in data
	ld data,a			; mov the contents of A (0xe0 ORed with 2 = 0xe2)
	call SPI			; transmit data
	mov data,#$ff		; BLUE = 0
	call SPI			; transmit data
	mov data,#$00		; GREEN = 256
	call SPI			; transmit data
	mov data,#$00		; BLUE = 0
	call SPI			; transmit data
	dec buffer2			; decreace counter
	jrne bloop			; loop till vlue reaches 0
	call end_frame		; call end frame to indicate end of data stream
	call ms250			; delay 250ms
	ret					; return to caller
	
redframe:
	mov buffer2,#30		; the LED strips I have has 30 leds ,so counter is 30
rloop:
	mov data,#$e0		; constant value of 0xe0 + PWM value of 0b00000 (0) to 0b11111 (31)(decides brightness)
	ld a,#2				; load a with PWM value 2. arbitarirly chosen value 2 of 31
	or a,data			; OR A with contents in data
	ld data,a			; mov the contents of A (0xe0 ORed with 2 = 0xe2)
	call SPI			; transmit data
	mov data,#$00		; BLUE = 0
	call SPI			; transmit data
	mov data,#$00		; GREEN = 256
	call SPI			; transmit data
	mov data,#$ff		; BLUE = 0
	call SPI			; transmit data
	dec buffer2			; decreace counter
	jrne rloop			; loop till vlue reaches 0
	call end_frame		; call end frame to indicate end of data stream
	call ms250			; delay 250ms
	ret					; return to caller
	
frame0:
	mov buffer2,#30		; the LED strips I have has 30 leds ,so counter is 30
loop0:
	mov data,#$e0		; constant value of 0xe0 + PWM value of 0b00000 (0) to 0b11111 (31)(decides brightness)
	ld a,#2				; load a with PWM value 2. arbitarirly chosen value 2 of 31
	or a,data			; OR A with contents in data
	ld data,a			; mov the contents of A (0xe0 ORed with 2 = 0xe2)
	call SPI			; transmit data
	mov data,#$00		; BLUE = 0
	call SPI			; transmit data
	mov data,#$00		; GREEN = 256
	call SPI			; transmit data
	mov data,#$00		; BLUE = 0
	call SPI			; transmit data
	dec buffer2			; decreace counter
	jrne loop0			; loop till vlue reaches 0
	call end_frame		; call end frame to indicate end of data stream
	call ms100			; delay 250ms
	ret					; return to caller
	
end_frame:
	mov data,#0			; The LED strip data stream ends with end frame with 0's half the number of LED's , we have 30 leds
	call SPI			; transmit data 
	mov data,#0			; load data with 0, 
	call SPI			; transmit data
	ret					; return to caller
	
bullet:
	mov buffer2,#LEDnum 	;LEDnum is number of LED (my strip has 30)
	mov buffer3,#0		;first position of LED is 0 grows to 30
L1:
	tnz buffer3			;test buffer3 for negative or zero, is this sequence start or not
	jreq fframe			;if buffer3 is 0,branch to fframe which sets the 1st LED
	call ms30			;delay ms250
	call start_frame	;send start frame for SK
	mov buffer2,#LEDnum ;LEDnum is number of LED (my strip has 30)
	call subloop0
	ld a,#LEDnum		;load A with number of LEDs
	cp a,buffer3		;check buffer3 has addressed all LEDs
	jrne L1
	ret
fframe:
	call bulletframe
	mov buffer4,#1
	call subloop0
	ld a,#LEDnum		;load A with number of LEDs
	cp a,buffer3		;check buffer3 has addressed all LEDs
	jrne L1
bulletframe:
	mov data,#$e0		;constant value of 0xe0 + PWM value of 0b00000 (0) to 0b11111 (31)(decides brightness)
	ld a,#2				;load a with PWM value 2. arbitarirly chosen value 2 of 31
	or a,data			;OR A with contents in data
	ld data,a			;mov the contents of A (0xe0 ORed with 2 = 0xe2)
	call SPI			;transmit data
	mov data,#$00		;blue
	call SPI
	mov data,#$FF		;green
	call SPI
	mov data,#$7C		;red
	call SPI
	dec buffer2			; decrease LED counter
	inc buffer3			; increase step counter
	clr buffer4
	ret
subloop0:				;this loop writes blank frames to remaining LEDs
	mov data,#$e0		;constant value of 0xe0 + PWM value of 0b00000 (0) to 0b11111 (31)(decides brightness)
	ld a,#2				;load a with PWM value 2. arbitarirly chosen value 2 of 31
	or a,data			;OR A with contents in data
	ld data,a			;mov the contents of A (0xe0 ORed with 2 = 0xe2)
	call SPI			;transmit data
	mov data,#$00		;blue
	call SPI
	mov data,#$00		;green
	call SPI
	mov data,#$00		;red
	call SPI
	inc buffer4			; increase LED counter
	ld a,buffer4
	cp a,buffer3		;compare step counter to A copied from buffer4 , if buffer4 equals buffer3 its time to call bullet frame
	jreq bulletframe	;if comparison is equal call bullet frame to light up the correct LED
	dec buffer2			; decrease 1 LED
	jrne subloop0		; if buffer2/LEDnum not rech 0 loop to write 29 blank frames
	call end_frame
	clr buffer4
	ret
	
audiframe:
	mov buffer3,#LEDnum		;first position of LED is 0 grows to 30
L2:
	call ms10			;delay ms250
	call start_frame	;send start frame for SK
	mov buffer2,#LEDnum 	;LEDnum is number of LED (my strip has 30)
	call movframe1
	call subloop1
	ld a,buffer3		;load A with number of LEDs
	cp a,#0		 		;check buffer3 has addressed all LEDs
	jrne L2
	ret
movframe1:
	mov buffer4,#LEDnum	;load buffer4 with number of LED
	ld a,buffer4		;copy to A buffer4 for subtraction (mem-mem not allowed)
	sub a,buffer3		;subtract buffer3 from A
	ld buffer4,a		;copy result of subtraction from A to buffer4
audiloop:
	mov data,#$e0		;constant value of 0xe0 + PWM value of 0b00000 (0) to 0b11111 (31)(decides brightness)
	ld a,#2				;load a with PWM value 2. arbitarirly chosen value 2 of 31
	or a,data			;OR A with contents in data
	ld data,a			;mov the contents of A (0xe0 ORed with 2 = 0xe2)
	call SPI			;transmit data
	mov data,#$00		;blue
	call SPI
	mov data,#$64		;green
	call SPI
	mov data,#$ff		;red
	call SPI
	dec buffer4			; decrease LED counter
	jrpl audiloop
	dec buffer3			; increase step counter
	dec buffer2
	ret
subloop1:				;this loop writes blank frames to remaining LEDs
	mov data,#$e0		;constant value of 0xe0 + PWM value of 0b00000 (0) to 0b11111 (31)(decides brightness)
	ld a,#2				;load a with PWM value 2. arbitarirly chosen value 2 of 31
	or a,data			;OR A with contents in data
	ld data,a			;mov the contents of A (0xe0 ORed with 2 = 0xe2)
	call SPI			;transmit data
	mov data,#$00		;blue
	call SPI
	mov data,#$00		;green
	call SPI
	mov data,#$00		;red
	call SPI
	dec buffer2			; decrease 1 LED
	jrne subloop1		; if buffer2/LEDnum not rech 0 loop to write 29 blank frames
	call end_frame
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;DELAY routines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
delayYx1mS:
	call delay1mS
	decw Y
	jrne delayYx1mS
	ret
delay1mS:
	pushw Y
	ldw Y,#{{fclk/1000}/3}
delay1mS_01:
	decw Y
	jrne delay1mS_01
	popw Y
	ret


usdelay:
	decw Y
	pushw Y
	popw Y
	pushw Y
	popw Y
	jrne usdelay
	ret

ms2000:
	millis #2000
	ret
	
ms500:
	millis #500
	ret
ms250:
	millis #250
	ret
ms100:
	millis #250
	ret
ms50:
	millis #50
ms30:
	millis #30
	ret
ms10:
	millis #10
	ret	
us1:
	micros #1
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


mixframe1:
	mov buffer2,#30	; the LED strips I have has 30 leds ,so counter is 30
m1loop:
	mov data,#$e0	; constant value of 0xe0 + PWM value of 0b00000 (0) to 0b11111 (31)(decides brightness)
	ld a,#2			; load a with PWM value 2. arbitarirly chosen value 2 of 31
	or a,data		; OR A with contents in data
	ld data,a		; mov the contents of A (0xe0 ORed with 2 = 0xe2)
	call SPI		; transmit data
	mov data,#$ff	; BLUE = 0
	call SPI		; transmit data
	mov data,#$ff	; GREEN = 256
	call SPI		; transmit data
	mov data,#$00	; BLUE = 0
	call SPI		; transmit data
	dec buffer2		; decreace counter
	jrne m1loop		; loop till vlue reaches 0
	call end_frame	; call end frame to indicate end of data stream
	call ms250		; delay 250ms
	ret				; return to caller
	
mixframe2:
	mov buffer2,#30	; the LED strips I have has 30 leds ,so counter is 30
m2loop:
	mov data,#$e0	; constant value of 0xe0 + PWM value of 0b00000 (0) to 0b11111 (31)(decides brightness)
	ld a,#2			; load a with PWM value 2. arbitarirly chosen value 2 of 31
	or a,data		; OR A with contents in data
	ld data,a		; mov the contents of A (0xe0 ORed with 2 = 0xe2)
	call SPI		; transmit data
	mov data,#$00	; BLUE = 0
	call SPI		; transmit data
	mov data,#$ff	; GREEN = 256
	call SPI		; transmit data
	mov data,#$ff	; BLUE = 0
	call SPI		; transmit data
	dec buffer2		; decreace counter
	jrne m2loop		; loop till vlue reaches 0
	call end_frame	; call end frame to indicate end of data stream
	call ms250		; delay 250ms
	ret				; return to caller
mixframe3:
	mov buffer2,#30	; the LED strips I have has 30 leds ,so counter is 30
m3loop:
	mov data,#$e0	; constant value of 0xe0 + PWM value of 0b00000 (0) to 0b11111 (31)(decides brightness)
	ld a,#2			; load a with PWM value 2. arbitarirly chosen value 2 of 31
	or a,data		; OR A with contents in data
	ld data,a		; mov the contents of A (0xe0 ORed with 2 = 0xe2)
	call SPI		; transmit data
	mov data,#$ff	; BLUE = 0
	call SPI		; transmit data
	mov data,#$00	; GREEN = 256
	call SPI		; transmit data
	mov data,#$ff	; BLUE = 0
	call SPI		; transmit data
	dec buffer2		; decreace counter
	jrne m3loop		; loop till vlue reaches 0
	call end_frame	; call end frame to indicate end of data stream
	call ms250		; delay 250ms
	ret				; return to caller	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


fade:					; this routine loads different values into LED frame to create fade effect
	call start_frame	;atart frame to initialize LED data acceptance
	mov buffer2,#30		; the LED strips I have has 30 leds ,so counter is 30
	ld a,(X)			; pointer X set in main loop , load to A from address pointed by Xpointer
	ld blue,a			; first value in the array is blue PWM/brightness value
	incw X				; increase pointer X
	ld a,(X)			; pointer X set in main loop , load to A from address pointed by Xpointer			
	ld green,a			; 2nd value in the array is green PWM/brightness value
	incw X				; increase pointer X
	ld a,(X)			; pointer X set in main loop , load to A from address pointed by Xpointer
	ld red,a			; 3rd value in the array is blue PWM/brightness value
	incw X				; increase pointer X for the next iteration through routine,total 100
floop:
	mov data,#$e0		; constant value of 0xe0 + PWM value of 0b00000 (0) to 0b11111 (31)
	ld a,#2				; load a with PWM value 2. arbitarirly chosen value 2 of 31(decides brightness)
	or a,data			; OR A with contents in data
	ld data,a			; mov the contents of A (0xe0 ORed with 2 = 0xe2)
	call SPI			; transmit data
	mov data,blue		; BLUE = array value0
	call SPI			; transmit data
	mov data,green		; GREEN = array value
	call SPI			; transmit data
	mov data,red		; BLUE = array value
	call SPI			; transmit data
	dec buffer2			; decreace counter
	jrne floop			; loop till vlue reaches 0
	call end_frame		; call end frame to indicate end of data stream
	call ms50			; delay 50ms for LED to display current colour combination
	dec colourstep		; decrease colour step , each step is 3 values in the colour array below from colour1 to colour20
	jrne fade			; loop through fade routine till all array elements are loaded to LED
	ret					; return to caller
	
	
	
	
	
	
	
	
	
	
colour1	dc.B 25,0,0,50,0,0,75,0,0,100,0,0,125,0,0,
colour2 dc.B 150,0,0,175,0,0,200,0,0,230,0,0,255,0,0

colour3 dc.B 255,25,0,255,50,0,255,75,0,255,100,0,255,125,0
colour4 dc.B 255,150,0,255,175,0,255,200,0,255,230,0,255,255,0

colour5 dc.B 230,255,0,200,255,0,175,255,0,150,255,0,125,255,0
colour6 dc.B 100,255,0,75,255,0,50,255,0,25,255,0,0,255,0

colour7 dc.B 0,255,25,0,255,50,0,255,75,0,255,100,0,255,125
colour8 dc.B 0,255,150,0,255,175,0,255,200,0,255,230,0,255,255

colour9 dc.B 0,230,255,0,200,50,0,175,255,0,150,255,0,125,255
colour10 dc.B 0,100,255,0,75,255,0,50,255,0,25,255,0,0,255

colour11 dc.B 25,0,255,50,0,255,75,0,255,100,0,255,125,0,255
colour12 dc.B 150,0,255,175,0,255,200,0,255,230,0,255,255,0,255

colour13 dc.B 255,25,225,255,50,225,255,75,225,255,100,225,255,125,225
colour14 dc.B 255,150,225,255,175,225,255,200,225,255,230,225,255,255,225

colour15 dc.B 255,255,230,255,255,200,255,255,175,255,255,150,255,255,125
colour16 dc.B 255,255,100,255,255,75,255,255,50,255,255,25,255,255,0

colour17 dc.B 255,230,0,255,200,0,255,175,0,255,150,0,255,125,0,
colour18 dc.B 255,100,0,255,75,0,255,50,0,255,25,0,255,0,0

colour19 dc.B 230,0,0,200,0,0,175,0,0,150,0,0,125,0,0
colour20 dc.B 100,0,0,75,0,0,50,0,0,25,0,0,0,0,0


pwmup   dc.B 25,50,75,100,125,150,175,200,230,255
pwmdown dc.B 255,230,200,175,150,125,100,75,50,25
	
	
	
	
	
	
	
	
	
	
	
	
;INTERRUPT VECTOR TABLE
	interrupt NonHandledInterrupt
NonHandledInterrupt.l
	iret

	segment 'vectit'
	dc.l {$82000000+main}									; reset
	dc.l {$82000000+NonHandledInterrupt}	; trap
	dc.l {$82000000+NonHandledInterrupt}	; irq0
	dc.l {$82000000+NonHandledInterrupt}	; irq1
	dc.l {$82000000+NonHandledInterrupt}	; irq2
	dc.l {$82000000+NonHandledInterrupt}	; irq3
	dc.l {$82000000+NonHandledInterrupt}	; irq4
	dc.l {$82000000+NonHandledInterrupt}	; irq5
	dc.l {$82000000+NonHandledInterrupt}	; irq6
	dc.l {$82000000+NonHandledInterrupt}	; irq7
	dc.l {$82000000+NonHandledInterrupt}	; irq8
	dc.l {$82000000+NonHandledInterrupt}	; irq9
	dc.l {$82000000+NonHandledInterrupt}	; irq10
	dc.l {$82000000+NonHandledInterrupt}	; irq11
	dc.l {$82000000+NonHandledInterrupt}	; irq12
	dc.l {$82000000+NonHandledInterrupt}	; irq13
	dc.l {$82000000+NonHandledInterrupt}	; irq14
	dc.l {$82000000+NonHandledInterrupt}	; irq15
	dc.l {$82000000+NonHandledInterrupt}	; irq16
	dc.l {$82000000+NonHandledInterrupt}	; irq17
	dc.l {$82000000+NonHandledInterrupt}	; irq18
	dc.l {$82000000+NonHandledInterrupt}	; irq19
	dc.l {$82000000+NonHandledInterrupt}	; irq20
	dc.l {$82000000+NonHandledInterrupt}	; irq21
	dc.l {$82000000+NonHandledInterrupt}	; irq22
	dc.l {$82000000+NonHandledInterrupt}	; irq23
	dc.l {$82000000+NonHandledInterrupt}	; irq24
	dc.l {$82000000+NonHandledInterrupt}	; irq25
	dc.l {$82000000+NonHandledInterrupt}	; irq26
	dc.l {$82000000+NonHandledInterrupt}	; irq27
	dc.l {$82000000+NonHandledInterrupt}	; irq28
	dc.l {$82000000+NonHandledInterrupt}	; irq29

	end
