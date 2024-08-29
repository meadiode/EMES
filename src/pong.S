#include <avr/io.h>

#define ZERO_REG r17

.section .data


.section .text

.global main
main:
    ldi r16, 0xd8                                            ; Write configuration change protection signature - 0xD8
    out CCP, r16                         
    out CLKPSR, ZERO_REG                                     ; Set main clock prescaler to 1, resulting frequency is ~8MHz

    out ADMUX, ZERO_REG                                      ; Enable ADC input channel 0 - PB0
    sbi ADCSRA, ADEN                                         ; Turn on the ADC
    sbi DIDR0, ADC0D                                         ; Disable digital input on PB0

    ldi r16, 0b1111
    out DDRB, r16                                            ; Set all pins as outputs

    sbi PORTB, PORTB2                                        ; Set B2 and B3 high
    sbi PORTB, PORTB3


    ldi r16, ((1 << COM0B1) | (1 << WGM01))                  ; Set up timer's fast PWM mode, OC0B(B1) is the output
    out TCCR0A, r16
    ldi r16, ((1 << WGM03) | (1 << WGM02) | (1 << CS00))
    out TCCR0B, r16

    ldi r18, hi8(400)                                        ; Set ICR0 to 400, resulting frequency is ~20KHz
    ldi r16, lo8(400)
    out ICR0H, r18
    out ICR0L, r16

    ldi r16, 50                                              ; Set OCR0B to 50, resulting duty cycle is ~12.5%
    out OCR0BH, ZERO_REG
    out OCR0BL, r16

    rcall init

main_loop:

    cbi DDRB, 0                                              ; Set B0 as input to poll the keyboard
    rcall poll_kb
    sbi DDRB, 0                                              ; Set B0 back as output

    rcall clear_buffer

    rcall process_ball_x
    rcall process_ball_y
    lds r20, bpos_x
    lds r21, bpos_y
    rcall put_pixel    
    rcall draw_buffer_c1
    rcall draw_buffer_c2

;    ldi r20, 0
;    ldi r21, 3
;    rcall put_pixel
;    ldi r20, 1
;    rcall put_pixel
;    ldi r20, 2
;    rcall put_pixel
;    ldi r20, 3
;    rcall put_pixel
;    ldi r20, 4
;    rcall put_pixel
;    ldi r20, 5
;    rcall put_pixel
;    ldi r20, 6
;    rcall put_pixel
;    ldi r20, 7
;    rcall put_pixel
;    ldi r20, 8
;    rcall put_pixel
;    ldi r20, 9
;    rcall put_pixel
;    ldi r20, 10
;    rcall put_pixel
;    ldi r20, 11
;    rcall put_pixel
;    ldi r20, 12
;    rcall put_pixel
;    rcall draw_buffer_c1
;    rcall draw_buffer_c2
    
    ldi r16, 10
yooge_delay_1:
    ldi r19, 200
yooge_delay_2:
    rcall delay
    dec r19
    brne yooge_delay_2
    dec r16
    brne yooge_delay_1

;    cbi PORTB, PORTB3
;    rcall delay
;    sbi PORTB, PORTB3
    rjmp main_loop



; Simple delay routine - about 7us at 8MHz main clock
; Used registers: r18
.global delay
delay:
    ldi r18, 10
    ;mov r18, r20
delay_loop:
    nop;
    dec r18
    brne delay_loop
    ret


; Read keyboard
; Checks if a key is pressed by sampling analog signal from the keyboard resistor ladder
; Output: r20 - key id [1..4], or zero if no key is pressed
; Used registers: r16, r20, r21, r22
.global poll_kb
poll_kb:
    clr r20 
    clr r21
    ldi r16, 4

adc_sample_loop:                                             ; Sample ADC 4 times and store the sum of samples in R21-R20
    sbi ADCSRA, ADSC

adc_wait_loop:
    sbic ADCSRA, ADSC
    rjmp adc_wait_loop
    
    in r22, ADCL
    adc r20, r22
    brcc no_hibyte_inc
    inc r21
no_hibyte_inc:
    dec r16
    brne adc_sample_loop

    lsr r21                                                  ; Divide R21-R20 by 4 to find average
    ror r20
    lsr r21
    ror r20

    mov r16, r20                                             ; Check if the resulting value corresponds to one of the keys
    subi r16, 40
    cpi r16, (4 + 1)
    brlo key_1

    mov r16, r20
    subi r16, 53
    cpi r16, (7 + 1)
    brlo key_2

    mov r16, r20
    subi r16, 61
    cpi r16, (8 + 1)
    brlo key_3

    mov r16, r20
    subi r16, 74
    cpi r16, (8 + 1)
    brlo key_4

    rjmp key_none                                            ; No key is pressed 

key_1:                                                       ; Load key-id into r20 and return
    ldi r20, 1
    ret

key_2:
    ldi r20, 2
    ret

key_3:
    ldi r20, 3
    ret

key_4:
    ldi r20, 4
    ret

key_none:
    ldi r20, 0
    ret



.global draw_buffer_c1
draw_buffer_c1:
    sbi PORTB, PORTB0

    cbi PORTB, PORTB3
    rcall delay
    sbi PORTB, PORTB3
    rcall delay

    clr r16
for_each_pixel_c1:
    mov r18, r16
    lsr r18
    lsr r18
    lsr r18
    mov r19, r16
    andi r19, 0b111

    ldi r30, lo8(dbuffer)
    ldi r31, hi8(dbuffer)
    add r30, r18
    ld r20, Z

extract_pixel_bit_c1:
    cpi r19, 0
    breq read_bit_c1
    dec r19
    lsr r20
    rjmp extract_pixel_bit_c1


read_bit_c1:
    cbi PORTB, PORTB0
    sbrc r20, 0
    sbi PORTB, PORTB0

    cbi PORTB, PORTB3
    rcall delay
    sbi PORTB, PORTB3
    rcall delay

    inc r16
    cpi r16, 35
    brne for_each_pixel_c1

    ret



.global draw_buffer_c2
draw_buffer_c2:
    sbi PORTB, PORTB0

    cbi PORTB, PORTB2
    rcall delay
    sbi PORTB, PORTB2
    rcall delay

    ldi r16, 35
for_each_pixel_c2:
    mov r18, r16
    lsr r18
    lsr r18
    lsr r18
    mov r19, r16
    andi r19, 0b111

    ldi r30, lo8(dbuffer)
    ldi r31, hi8(dbuffer)
    add r30, r18
    ld r20, Z

extract_pixel_bit_c2:
    cpi r19, 0
    breq read_bit_c2
    dec r19
    lsr r20
    rjmp extract_pixel_bit_c2


read_bit_c2:
    cbi PORTB, PORTB0
    sbrc r20, 0
    sbi PORTB, PORTB0

    cbi PORTB, PORTB2
    rcall delay
    sbi PORTB, PORTB2
    rcall delay

    inc r16
    cpi r16, 70
    brne for_each_pixel_c2

    ret



.global clear_buffer
clear_buffer:
    ldi r30, lo8(dbuffer)
    ldi r31, hi8(dbuffer)

clear_loop:
    st Z+, ZERO_REG
    cpi r30, lo8(dbuffer + 9)
    brne clear_loop

    ret



; input: r20 = x, r21 = y 
.global put_pixel
put_pixel:
    cpi r20, 5
    brlo put_pixel_calc
    cpi r20, (7 + 1)
    brsh put_pixel_calc
    ret

put_pixel_calc:
    ldi r22, 6       ; calculate (6 - y) * 5
    sub r22, r21
    mov r23, r22
    lsl r22
    lsl r22
    add r22, r23

    cpi r20, 5
    brlo put_pixel_c1

    mov r23, r20
    subi r23, 8
    ldi r24, 4
    sub r24, r23
    ldi r23, 35
    add r23, r24
    add r22, r23
    rjmp calc_byte_n

put_pixel_c1:
    ldi r23, 4
    sub r23, r20
    add r22, r23 ; r22 contains bit number

calc_byte_n:
    mov r23, r22
    lsr r23
    lsr r23
    lsr r23      ; r23 contains byte number

    ldi r24, 1
    andi r22, 0b111

calc_mask:
    cpi r22, 0
    breq apply_mask
    lsl r24
    dec r22
    rjmp calc_mask

apply_mask:
    ldi r30, lo8(dbuffer)
    ldi r31, hi8(dbuffer)
    add r30, r23
    ld r22, Z
    or r22, r24
    st Z, r22

    ret


.global process_ball_x
process_ball_x:
    lds r19, bpos_x
    lds r20, bmov_x
    lds r21, bvel_x
    lds r22, bdir_x

    add r20, r21

    cpi r20, 128
    brsh move_ball_x
    rjmp move_ball_x_update

move_ball_x:
    ldi r20, 0

    cpi r22, 1
    breq move_ball_x_right

    cpi r19, 0
    breq move_ball_x_bounce_l    
    dec r19
    rjmp move_ball_x_update

move_ball_x_bounce_l:
    ldi r22, 1
    inc r19
    ; check paddle collision here
    rjmp move_ball_x_update


move_ball_x_right:
    cpi r19, 12
    brge move_ball_x_bounce_r
    inc r19
    rjmp move_ball_x_update

move_ball_x_bounce_r:
    ldi r22, -1
    dec r19
    ; check paddle collision here

move_ball_x_update:
    sts bpos_x, r19
    sts bmov_x, r20
    sts bvel_x, r21
    sts bdir_x, r22
    ret


.global process_ball_y
process_ball_y:
    lds r19, bpos_y
    lds r20, bmov_y
    lds r21, bvel_y
    lds r22, bdir_y

    add r20, r21

    cpi r20, 128
    brsh move_ball_y
    rjmp move_ball_y_update

move_ball_y:
    ldi r20, 0

    cpi r22, 1
    breq move_ball_y_down

    cpi r19, 0
    breq move_ball_y_bounce_u    
    dec r19
    rjmp move_ball_y_update

move_ball_y_bounce_u:
    ldi r22, 1
    inc r19
    rjmp move_ball_y_update


move_ball_y_down:
    cpi r19, 6
    brge move_ball_y_bounce_d
    inc r19
    rjmp move_ball_y_update

move_ball_y_bounce_d:
    ldi r22, -1
    dec r19

move_ball_y_update:
    sts bpos_y, r19
    sts bmov_y, r20
    sts bvel_y, r21
    sts bdir_y, r22
    ret



.global init
init:
    ldi r16, 1
    sts bpos_x, r16

    sts bdir_x, r16
    sts bdir_y, r16

    ldi r16, 3
    sts bpos_y, r16

    ldi r16, 24
    sts bvel_x, r16

    ldi r16, 8
    sts bvel_y, r16

    sts bmov_x, ZERO_REG
    sts bmov_y, ZERO_REG

    ret


.data;

bpos_x:
    .byte 0x00
bpos_y:
    .byte 0x00
bmov_x:
    .byte 0x00
bmov_y:
    .byte 0x00
bvel_x:
    .byte 0x00
bvel_y:
    .byte 0x00
bdir_x:
    .byte 0x00
bdir_y:
    .byte 0x00

dbuffer:
    .zero 9

.end
