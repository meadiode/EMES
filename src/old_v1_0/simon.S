#include <avr/io.h>

#define ZERO_REG          r16
#define BEEP_REG          r25
#define KB_REG            r26

#define DIR_UP     0x00
#define DIR_DOWN   0x03
#define DIR_LEFT   0x01
#define DIR_RIGHT  0x02

.section .data
.section .text

.global main
main:
    ldi r17, 0xd8                                            ; Write configuration change protection signature - 0xD8
    out CCP, r17                         
    out CLKPSR, ZERO_REG                                     ; Set main clock prescaler to 1, resulting frequency is ~8MHz

    out ADMUX, ZERO_REG                                      ; Enable ADC input channel 0 - PB0
    sbi ADCSRA, ADEN                                         ; Turn on the ADC
    sbi DIDR0, ADC0D                                         ; Disable digital input on PB0

    ldi r17, 0b1111
    out DDRB, r17                                            ; Set all pins as outputs

    sbi PORTB, PORTB2                                        ; Set B2 and B3 high
    sbi PORTB, PORTB3


    ldi r17, ((1 << COM0B1) | (1 << WGM01))                  ; Set up timer's fast PWM mode, OC0B(B1) is the output
    out TCCR0A, r17
    ldi r17, ((1 << WGM03) | (1 << WGM02) | (1 << CS00))
    out TCCR0B, r17

    rcall no_beep

main_loop:





continue:
    cpi BEEP_REG, 0
    brne do_beep
    rjmp main_loop_continue
do_beep:
    dec BEEP_REG
    brne main_loop_continue
    rcall no_beep

main_loop_continue:

    ldi r17, 250
yooge_delay:
    rcall delay
    dec r17
    brne yooge_delay

    rjmp main_loop



.global delay
; Simple delay routine - about 7us at 8MHz main clock
; Touched registers: r18
delay:
    ldi r18, 10
delay_loop:
    nop;
    dec r18
    brne delay_loop
    ret


.global poll_kb
; Read keyboard
; Checks if a key is pressed by sampling analog signal from the keyboard resistor ladder
; Output: r26 - key id [1..4], or zero if no key is pressed
; Touched registers: r17, r20, r21, r22, r26
poll_kb:
    clr r20 
    clr r21
    ldi r17, 4

    cbi DDRB, 0              ; Set B0 as input to poll the keyboard

adc_sample_loop:             ; Sample ADC 4 times and store the sum of samples in R21-R20
    sbi ADCSRA, ADSC

adc_wait_loop:
    sbic ADCSRA, ADSC
    rjmp adc_wait_loop
    
    in r22, ADCL
    adc r20, r22
    brcc no_hibyte_inc
    inc r21
no_hibyte_inc:
    dec r17
    brne adc_sample_loop
    sbi DDRB, 0              ; Set B0 back as output

    lsr r21                  ; Divide R21-R20 by 4 to find average
    ror r20
    lsr r21
    ror r20

    mov r17, r20             ; Check if the resulting value corresponds to one of the keys
    subi r17, 20
    cpi r17, (30 + 1)
    brlo key_1

    mov r17, r20
    subi r17, 52
    cpi r17, (8 + 1)
    brlo key_2

    mov r17, r20
    subi r17, 61
    cpi r17, (11 + 1)
    brlo key_3

    mov r17, r20
    subi r17, 74
    cpi r17, (8 + 1)
    brlo key_4

    rjmp key_none            ; No key is pressed 

; Load key-id into KB_REG and return
key_1:                       ; UP key
    ldi r17, (DIR_UP + 1)
    rjmp poll_kb_update_r26

key_2:                       ; DOWN key
    ldi r17, (DIR_DOWN + 1)
    rjmp poll_kb_update_r26

key_3:                       ; LEFT key
    ldi r17, (DIR_LEFT + 1)               
    rjmp poll_kb_update_r26

key_4:                       ; RIGHT key
    ldi r17, (DIR_RIGHT + 1)
    rjmp poll_kb_update_r26

key_none:
    ldi r17, 0
    rjmp poll_kb_update_r26

poll_kb_update_r26:
    mov r20, KB_REG
    andi r20, 0x7f
    cp r17, r20
    brne poll_kb_key_change
    mov KB_REG, r17
    ret
poll_kb_key_change:
    mov KB_REG, r17
    ori KB_REG, 0x80
    ret


.global pulse_b3
pulse_b3:
    cbi PORTB, PORTB3
    rcall delay
    sbi PORTB, PORTB3
    rcall delay
    ret


.global pulse_b2
pulse_b2:
    cbi PORTB, PORTB2
    rcall delay
    sbi PORTB, PORTB2
    rcall delay
    ret


.global draw_pixels
; Inputs: 
;   r21 - start pixel index,
;   Z(r31:r30) - clock pin pulse function
;   Y(r29:r28) - pixel buffer pointer
; Touched registers:
;   r17, r18, r19, r20, r21, r22, r28, r29, r30, r31
draw_pixels:

    sbi PORTB, PORTB0
    icall

    mov r17, r21
    ldi r22, 35
    add r21, r22
    mov r22, r28
draw_pixels_for_each_pixel:
    mov r18, r17
    lsr r18
    lsr r18
    lsr r18
    mov r19, r17
    andi r19, 0b111

    mov r28, r22
    add r28, r18
    ld r20, Y

draw_pixels_extract_pixel_bit:
    cpi r19, 0
    breq draw_pixels_read_bit
    dec r19
    lsr r20
    rjmp draw_pixels_extract_pixel_bit


draw_pixels_read_bit:
    cbi PORTB, PORTB0
    sbrc r20, 0
    sbi PORTB, PORTB0

    icall

    inc r17
    cp r17, r21
    brne draw_pixels_for_each_pixel
    mov r28, r22
    
    cbi PORTB, PORTB0

    ret


.global clear_display
clear_display:
    sbi PORTB, PORTB0
    rcall pulse_b3
    rcall pulse_b2
    cbi PORTB, PORTB0
    ldi r17, 35
clear_display_each_pixel:
    rcall pulse_b3
    rcall pulse_b2
    dec r17
    brne clear_display_each_pixel    
    
    ret


.global beep
beep:
    ldi BEEP_REG, 20

    ldi r18, hi8(8000)
    ldi r17, lo8(8000)
    out ICR0H, r18
    out ICR0L, r17

    ldi r18, hi8(250)
    ldi r17, lo8(250)
    out OCR0BH, r18
    out OCR0BL, r17

    ret


.global no_beep
no_beep:
    ldi r18, hi8(400)                                        ; Set ICR0 to 400, resulting frequency is ~20KHz
    ldi r17, lo8(400)
    out ICR0H, r18
    out ICR0L, r17

    ldi r17, 50                                              ; Set OCR0B to 50, resulting duty cycle is ~12.5%
    out OCR0BH, ZERO_REG
    out OCR0BL, r17

    ret


.global process_input
process_input:
    sbrs KB_REG, 7
    rjmp process_input_done
    nop
    nop
    nop
process_input_done:
    ret


.global rand
rand:
    lds r17, seed
    
    ; seed = seed ^ (seed << 3)
    mov r18, r17
    lsl r18
    lsl r18
    lsl r18
    eor r17, r18

    ; seed = seed ^ (seed >> 1)
    mov r18, r17
    lsr r18
    eor r17, r18

    ; seed = seed ^ (seed << 5)
    ldi r19, 5
lshift_seed_x5:
    lsl r18
    subi r19, 1
    brne lshift_seed_x5

    eor r17, r18

    sts seed, r17
    ret


.global init
init:

;    ldi r17, 42
;    sts seed, r17
    ret


.section .text

symbol_1:
    .byte 0b00000000
    .byte 0b00010000
    .byte 0b00010101
    .byte 0b00010101
    .byte 0b00000001

symbol_2:
    .byte 0b00111111
    .byte 0b11000110
    .byte 0b00011000
    .byte 0b00111111
    .byte 0b00000000

symbol_3:
    .byte 0b00000000
    .byte 0b00010000
    .byte 0b11110010
    .byte 0b00001001
    .byte 0b00000001

symbol_4:
    .byte 0b00101110
    .byte 0b11010110
    .byte 0b11101000
    .byte 0b00000000
    .byte 0b00000000

digit_0:
    .byte 0b00101110
    .byte 0b11001110
    .byte 0b10011010
    .byte 0b10100011
    .byte 0b00000011

digit_1:
    .byte 0b10001110
    .byte 0b00010000
    .byte 0b01000010
    .byte 0b00011000
    .byte 0b00000001

digit_2:
    .byte 0b00011111
    .byte 0b00010001
    .byte 0b00010001
    .byte 0b10100010
    .byte 0b00000011

digit_3:
    .byte 0b00111110
    .byte 0b00000100
    .byte 0b00010111
    .byte 0b10000010
    .byte 0b00000111

digit_4:
    .byte 0b00100001
    .byte 0b10000100
    .byte 0b00011111
    .byte 0b01100011
    .byte 0b00000100


digit_5:
    .byte 0b00111111
    .byte 0b00000100
    .byte 0b00001111
    .byte 0b11100001
    .byte 0b00000111

digit_6:
    .byte 0b00101110
    .byte 0b01000110
    .byte 0b00001111
    .byte 0b10100001
    .byte 0b00000011

digit_7:
    .byte 0b10000100
    .byte 0b00010000
    .byte 0b00010001
    .byte 0b11000010
    .byte 0b00000111

digit_8:
    .byte 0b00101110
    .byte 0b01000110
    .byte 0b00010111
    .byte 0b10100011
    .byte 0b00000011

digit_9:
    .byte 0b00101110
    .byte 0b00000100
    .byte 0b00010111
    .byte 0b10100011
    .byte 0b00000011

.section .data;


gstate:
    .byte 0x00
seed:
    .byte 0x00
start_seed:
    .byte 0x00
seq_length:
    .byte 0x00


.end