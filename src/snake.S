#include <avr/io.h>

#define ZERO_REG          r16
#define BEEP_REG          r25
#define KB_REG            r26

#define DIR_UP     0x00
#define DIR_DOWN   0x03
#define DIR_LEFT   0x01
#define DIR_RIGHT  0x02

#define GSTATE_GAME  0x00
#define GSTATE_SCORE 0x01


#define SNEK_MOVE_TIME 128

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
    rcall new_game

main_loop:
    brtc game_loop
; Game over/score count loop    
    
    rcall poll_kb
    andi KB_REG, 0b10000000
    breq game_over_loop_cont
    clt
    rcall new_game

game_over_loop_cont:
    lds r17, move_t
    cpi r17, 250
    brlo game_over_loop_cont2
    sts move_t, ZERO_REG
    ldi r23, 0
    ldi r24, 0
    lds r27, size
    ldi r28, lo8(digit_0 + 0x4000)
    ldi r29, hi8(digit_0 + 0x4000)


game_over_loop_cont2:
    rcall clear_display
    cpi r27, 0
    breq game_over_loop_disp
    dec r27
    ldi r17, 5
    add r23, r17
    cpi r23, 50
    brne game_over_loop_disp
    ldi r23, 0
    add r24, r17

game_over_loop_disp:
    ldi r28, lo8(digit_0 + 0x4000)
    ldi r30, lo8(gs(pulse_b3))
    ldi r31, hi8(gs(pulse_b3))
    add r28, r24
    ldi r21, 0
    rcall draw_pixels 
    ldi r28, lo8(digit_0 + 0x4000)
    ldi r30, lo8(gs(pulse_b2))
    ldi r31, hi8(gs(pulse_b2))
    add r28, r23
    ldi r21, 0
    rcall draw_pixels

    rjmp continue

game_loop:
    rcall clear_buffer
    rcall poll_kb
    rcall process_input
    rcall move_snek
    rcall trace_snek
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


.global clear_buffer
clear_buffer:
    ldi r30, lo8(dbuffer)
    ldi r31, hi8(dbuffer)

clear_loop:
    st Z+, ZERO_REG
    cpi r30, lo8(dbuffer + 9)
    brne clear_loop

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


.global put_pixel
; Draws a pixel in the frame buffer
; Inputs:
;  r20 - pixel x
;  r21 - pixel y
; Outputs:
;  r23 - nonzero if there's a pixel already at (x, y)
; Touched registers: r17, r23, r24, r30, r31
put_pixel:
    ldi r17, 6       ; calculate (6 - y) * 5
    sub r17, r21
    mov r23, r17
    lsl r17
    lsl r17
    add r17, r23

    cpi r20, 5
    brlo put_pixel_c1

    mov r23, r20
    subi r23, 5
    ldi r24, 4
    sub r24, r23
    ldi r23, 35
    add r23, r24
    add r17, r23
    rjmp calc_byte_n

put_pixel_c1:
    ldi r23, 4
    sub r23, r20
    add r17, r23 ; r17 contains bit number

calc_byte_n:
    mov r23, r17
    lsr r23
    lsr r23
    lsr r23      ; r23 contains byte number

    ldi r24, 1
    andi r17, 0b111

calc_mask:
    cpi r17, 0
    breq apply_mask
    lsl r24
    dec r17
    rjmp calc_mask

apply_mask:
    ldi r30, lo8(dbuffer)
    ldi r31, hi8(dbuffer)
    add r30, r23
    ld r17, Z
    mov r23, r17
    and r23, r24
    or r17, r24
    st Z, r17

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


.global move_snek
move_snek:
    lds r18, move_t
    inc r18

    cpi r18, SNEK_MOVE_TIME
    breq do_move_snek
    sts move_t, r18
    rjmp move_snek_done

do_move_snek:
    ldi r18, 0
    sts move_t, r18

    lds r20, head_x
    lds r21, head_y
    lds r22, hdir

    rcall move_snek_cursor

    sts head_x, r20
    sts head_y, r21

    rcall shift_snek_buffer
    lds r19, prev_hdir
    sts prev_hdir, r22
    cp r19, r22              ; Check if the snake turned
    breq move_snek_check_food

    ; Recording a turn in snek_buffer
    rcall shift_snek_buffer
    lds r17, snek_buffer
    ori r17, 0b01000000
    
    cpi r19, DIR_UP
    breq do_move_snek_turn_updown
    cpi r19, DIR_DOWN
    breq do_move_snek_turn_updown
    eor r19, r22
    sbrs r19, 0
    ori r17, 0b00100000
    rjmp do_move_snek_write_turn
 
do_move_snek_turn_updown:
    eor r19, r22
    sbrc r19, 0
    ori r17, 0b00100000

do_move_snek_write_turn:
    sts snek_buffer, r17

move_snek_check_food:
    ; Check if the food was eaten
    lds r18, food_pos
    mov r19, r20
    swap r19
    or r19, r21
    cp r18, r19
    brne move_snek_done
    rcall trace_snek
    rcall spawn_food
    rcall clear_buffer
    rcall beep

    lds r18, size
    inc r18
    sts size, r18

move_snek_done:
    ret


.global shift_snek_buffer
; Shifts right every byte in snek_buffer
; Touched registers: r17, r18, r28, r29
shift_snek_buffer:

    ldi r28, lo8(snek_buffer)
    ldi r29, hi8(snek_buffer)
    ldi r17, 6
    clc

shift_snek_buffer_nb:
    ld r18, Y
    ror r18
    st Y+, r18
    dec r17
    brne shift_snek_buffer_nb

    ret


.global move_snek_cursor
 ; Advances a 2d cursor according to the heading direction
 ; Inputs:
 ;  r20 - cursor x
 ;  r21 - cursor y
 ;  r22 - heading direction
 ; Outputs:
 ;  r20 - updated cursor x
 ;  r21 - updated cursor y
 ; Touched registers: r20, r21
move_snek_cursor:
    cpi r22, DIR_UP
    breq move_snek_cursor_up
    cpi r22, DIR_DOWN
    breq move_snek_cursor_down
    cpi r22, DIR_LEFT
    breq move_snek_cursor_left
    inc r20            ; else move right
    cpi r20, 10
    brlo move_snek_cursor_done
    ldi r20, 0

    rjmp move_snek_cursor_done

move_snek_cursor_up:
    dec r21
    brpl move_snek_cursor_done
    ldi r21, 6
    rjmp move_snek_cursor_done
move_snek_cursor_down:
    inc r21
    cpi r21, 7
    brlo move_snek_cursor_done
    ldi r21, 0
    rjmp move_snek_cursor_done
move_snek_cursor_left:
    dec r20
    brpl move_snek_cursor_done
    ldi r20, 9

move_snek_cursor_done:
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

    ; check if the new direction is oposite to the current one
    lds r24, hdir
    ldi r19, 3
    sub r19, r24
    cp r17, r19
    breq process_input_done

    sts hdir, r17            ; update direction
process_input_done:
    ret


.global trace_snek
trace_snek:
    ldi r28, lo8(snek_buffer)
    ldi r29, hi8(snek_buffer)

    lds r20, head_x
    lds r21, head_y

    rcall put_pixel          ; Draw the snake's head

    lds r17, move_t
    andi r17, 0b111
    cpi r17, 0
    brne trace_snek_done     ; Draw rest of the snake only once every 8 frames.
                             ; so it would appear dimmer than the head

    lds r17, prev_hdir
    ldi r22, 3
    sub r22, r17             ; reverse heading direction

    ldi r27, 1               ; r27 stores current snake segment index
    ldi r18, 0               ; r18 stores current bit index in snek_buffer

snek_buffer_bit_iter:

    mov r17, r18
    andi r17, 0b111
    brne next_snek_segment
    ld r19, Y+               ; r19 sores current byte from snek_buffer 

next_snek_segment:
    lsl r19
    ; if next bit is zero, then it's a straight segment
    brcc next_snek_segment_continue 
    ; else, it's a turn so read the next bit to see where it turns
    inc r18
    mov r17, r18
    andi r17, 0b111
    ; fetch the next byte if the current one ended
    brne next_snek_segment_turn
    ld r19, Y+

next_snek_segment_turn:
    lsl r19
    brcs next_snek_segment_turn_right
    cpi r22, DIR_UP
    breq next_snek_segment_tl
    cpi r22, DIR_DOWN
    breq next_snek_segment_tr
    cpi r22, DIR_LEFT
    breq next_snek_segment_td
    rjmp next_snek_segment_tu

next_snek_segment_turn_right:
    cpi r22, DIR_UP
    breq next_snek_segment_tr
    cpi r22, DIR_DOWN
    breq next_snek_segment_tl
    cpi r22, DIR_LEFT
    breq next_snek_segment_tu
    rjmp next_snek_segment_td    

next_snek_segment_tl:
    ldi r22, DIR_LEFT
    rjmp next_snek_segment_continue
next_snek_segment_tr:
    ldi r22, DIR_RIGHT
    rjmp next_snek_segment_continue
next_snek_segment_tu:
    ldi r22, DIR_UP
    rjmp next_snek_segment_continue
next_snek_segment_td:
    ldi r22, DIR_DOWN
next_snek_segment_continue:

    rcall move_snek_cursor
    rcall put_pixel
    
    cpi r23, 0               ; Check if the snake bites itself
    breq next_snek_segment_continue2
    set                      ; If yes, set T to indicate endgame
    ldi r17, 250
    sts move_t, r17
    rjmp trace_snek_done

next_snek_segment_continue2:
    inc r27
    inc r18
    lds r17, size
    cp r27, r17
    brlo snek_buffer_bit_iter

trace_snek_done:
    ret



.global render_game
render_game:
    
    lds r17, move_t
    andi r17, 0b11111
    cpi r17, 16
    brlo render_game_cont    ; Skip drawing food half of the time, to make it appear blinking
    
    lds r20, food_pos
    mov r21, r20
    swap r20
    andi r20, 0b1111
    andi r21, 0b1111
    rcall put_pixel

render_game_cont:
    ldi r28, lo8(dbuffer)
    ldi r29, hi8(dbuffer)

    ldi r30, lo8(gs(pulse_b3))
    ldi r31, hi8(gs(pulse_b3))
    ldi r21, 0
    rcall draw_pixels

    ldi r30, lo8(gs(pulse_b2))
    ldi r31, hi8(gs(pulse_b2))
    ldi r21, 35
    rcall draw_pixels
    
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
;    mov r18, r17
;    lsl r18
;    lsl r18
;    lsl r18
;    lsl r18
;    lsl r18

    ldi r19, 5
lshift_seed_x5:
    lsl r18
    subi r19, 1
    brne lshift_seed_x5

    eor r17, r18

    sts seed, r17
    ret


.global spawn_food
spawn_food:
    rcall rand
    lds r20, seed
    mov r21, r20
    swap r21
    andi r20, 0b1111
    andi r21, 0b1111

spawn_food_clamp_x:
    cpi r20, 10
    brlo spawn_food_clamp_y
    lsr r20
    rjmp spawn_food_clamp_x

spawn_food_clamp_y:
    cpi r21, 7
    brlo do_spawn_food
    lsr r21
    rjmp spawn_food_clamp_y

do_spawn_food:
    rcall put_pixel
    cpi r23, 0
    brne spawn_food

    swap r20
    or r20, r21
    sts food_pos, r20

    ret


.global new_game
new_game:
    rcall init
    rcall clear_buffer
    rcall trace_snek
    rcall spawn_food
    ret

.global init
init:
    sts move_t, ZERO_REG

    ldi r17, 2
    sts head_x, r17
    sts head_y, r17
    sts hdir, r17
    sts prev_hdir, r17

;    ldi r17, 42
;    sts seed, r17

    ldi r17, 2
    sts size, r17

    sts snek_buffer, ZERO_REG

    ret


.section .text

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


move_t:
    .byte 0x00
head_x:
    .byte 0x00
head_y:
    .byte 0x00
hdir:
    .byte 0x00
prev_hdir:
    .byte 0x00
size:
    .byte 0x00
food_pos:
    .byte 0x00
seed:
    .byte 0x00
snek_buffer:
    .zero 7
dbuffer:
    .zero 9

.end