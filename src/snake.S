#include <avr/io.h>

#define ZERO_REG   r16
#define BEEP_REG   r25
#define KB_REG     r26

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
    rcall init


main_loop:
    rcall clear_buffer
    rcall poll_kb
    rcall process_input
    rcall move_head
    rcall render_game

continue:
    cpi BEEP_REG, 0
    brne do_beep
    rjmp main_loop_continue
do_beep:
    dec BEEP_REG
    brne main_loop_continue
    rcall no_beep

main_loop_continue:    
    ldi r17, 15
yooge_delay_1:
    ldi r19, 200
yooge_delay_2:
    rcall delay
    dec r19
    brne yooge_delay_2
    dec r17
    brne yooge_delay_1

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
; Output: r26 - key id [1..4], or zero if no key is pressed
; Used registers: r17, r20, r21, r22, r26
.global poll_kb
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


; Inputs: 
;   r21 - start pixel index,
;   Z(r31:r30) - clock pin pulse function
;   Y(r29:r28) - pixel buffer pointer
; Used registers:
;   r17, r18, r19, r20, r21, r22, r28, r29, r30, r31
.global draw_pixels
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


.global draw_buffer_c1
draw_buffer_c1:
    ldi r30, lo8(gs(pulse_b3))
    ldi r31, hi8(gs(pulse_b3))
    ldi r21, 0

    rcall draw_pixels

    ret



.global draw_buffer_c2
draw_buffer_c2:

    ldi r30, lo8(gs(pulse_b2))
    ldi r31, hi8(gs(pulse_b2))
    ldi r21, 35
    
    rcall draw_pixels

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
    ldi r22, 6       ; calculate (6 - y) * 5
    sub r22, r21
    mov r23, r22
    lsl r22
    lsl r22
    add r22, r23

    cpi r20, 5
    brlo put_pixel_c1

    mov r23, r20
    subi r23, 5
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


.global beep
beep:
    ldi BEEP_REG, 10

    ldi r18, hi8(16000)
    ldi r17, lo8(16000)
    out ICR0H, r18
    out ICR0L, r17

    ldi r18, hi8(500)
    ldi r17, lo8(500)
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


.global move_head
move_head:
    lds r18, move_t
    inc r18

    cpi r18, 60
    breq do_move
    rjmp move_head_done

do_move:
    ldi r18, 0
    lds r19, hdir
    lds r20, head_x
    lds r21, head_y

    cpi r19, DIR_UP
    breq do_move_up
    cpi r19, DIR_DOWN
    breq do_move_down
    
    cpi r19, DIR_LEFT
    breq do_move_left
    
    inc r20            ; else move right
    rjmp do_move_done

do_move_up:
    dec r21
    rjmp do_move_done
do_move_down:
    inc r21
    rjmp do_move_done
do_move_left:
    dec r20
do_move_done:
    sts hdir, r19
    sts head_x, r20
    sts head_y, r21

move_head_done:
    sts move_t, r18
    ret


.global process_input
process_input:
    sbrs KB_REG, 7
    rjmp process_input_done
    mov r17, KB_REG
    andi r17, 0b111
    cpi r17, 0
    breq process_input_done
    dec r17
    sts hdir, r17
process_input_done:
    ret


.global render_game
render_game:
    lds r20, head_x
    lds r21, head_y
    rcall put_pixel

    ldi r28, lo8(dbuffer)
    ldi r29, hi8(dbuffer)
    rcall draw_buffer_c1
    rcall draw_buffer_c2

    ret



.global init
init:
    sts move_t, ZERO_REG
    sts head_x, ZERO_REG
    sts head_y, ZERO_REG

    ldi r17, DIR_RIGHT
    sts hdir, r17

    ret


.section .data;


move_t:
    .byte 0x00
head_x:
    .byte 0x00
head_y:
    .byte 0x00
hdir:
    .byte 0x00
size:
    .byte 0x00
grow_size:
    .byte 0x00

dbuffer:
    .zero 9


.end