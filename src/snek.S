#include <avr/io.h>

#define KB_REG            r26

#define DIR_RIGHT  0
#define DIR_UP     1
#define DIR_LEFT   2
#define DIR_DOWN   3

#define KEY_LU     1
#define KEY_LB     0
#define KEY_RU     3
#define KEY_RB     2

#define SNEK_MOVE_TIME   128
#define SNEK_BUFFER_SIZE 13

#define SNEK_HEAD_VALUE  40
#define SNEK_BODY_VALUE1 20
#define SNEK_BODY_VALUE2 2

#define SPEAKER_PWM_DUTY 500
#define SPEAKER_PWM(Hz)  (8000000 / (Hz))  ; Min Hz value: 122

#define ADDR_W 0x40
#define ADDR_R 0x41

#define SCL PORTB2
#define SDA PORTB3

.section .data
.section .text

.global main
main:
    ldi r17, 0xd8                                            ; Write configuration change protection signature - 0xD8
    out CCP, r17                         
    out CLKPSR, r16                                          ; Set main clock prescaler to 1, resulting frequency is ~8MHz

    out ADMUX, r16                                           ; Enable ADC input channel 0 - PB0
    sbi ADCSRA, ADEN                                         ; Turn on the ADC
    sbi DIDR0, ADC0D                                         ; Disable digital input on PB0

    ldi r17, 0b0010
    out DDRB, r17                                            ; Set B1 as output

    out PORTB, r16                                           ; All pins low

    ldi r17, ((1 << WGM03) | (1 << WGM02) | (1 << CS00))     ; Set up timer's fast PWM mode
    out TCCR0B, r17

    ldi r23, 2
    rcall display_set_reg_page

    ldi r21, 0x00
    ldi r22, 0x01
    rcall display_write_reg

    ldi r21, 0x01
    ldi r22, 0x70
    rcall display_write_reg

    ldi r23, 1
    rcall display_set_reg_page

    ldi r21, 0
    ldi r22, 0xff

write_scalling_val:
    rcall display_write_reg
    inc r21
    cpi r21, (198 + 1)
    brne write_scalling_val

    ldi r23, 0
    rcall display_set_reg_page

    ldi r21, 0
    ldi r22, 0

write_pwm_val:
    rcall display_write_reg
    inc r21
    cpi r21, (198 + 1)
    brne write_pwm_val

    rcall new_game

main_loop:
    brts game_over_loop
    
    rcall poll_kb
    rcall process_input
    rcall move_snek
    rcall draw_food

    ldi r17, 15
    rcall long_delay

    rjmp main_loop

game_over_loop:
    rcall show_score

game_over_loop_cont:
    rcall poll_kb
    andi KB_REG, 0b10000011
    breq game_over_loop_cont
    clt
    rcall new_game
    rjmp main_loop

    rjmp game_over_loop_cont


.global long_delay
; Long delay routine - from ~100us to ~25ms at 8MHz
; Input r17 - delay value: approx delay_time(us) = (r17 + 1) * 100
; Used registers: r17, r18
; Call depth: 1
long_delay:
    subi r18, 1
    brcc long_delay
    subi r17, 1
    brcs long_delay_ret
    rjmp long_delay
long_delay_ret:
    ret


.global looong_delay
; Very long delay routine - from ~25ms to ~6.5s at 8MHz
; Input r17 - delay value: approx delay_time(ms) = (r17 + 1) * 25
; Used registers: r17, r18, r19
; Call depth: 1
looong_delay:
    subi r19, 1
    brcc looong_delay
    subi r18, 1
    brcc looong_delay
    subi r17, 1
    brcs looong_delay_ret
    rjmp looong_delay
looong_delay_ret:
    ret



.global i2c_start
; Call depth: 1
i2c_start:
    cbi DDRB, SCL
    cbi DDRB, SDA
    nop
    sbi DDRB, SDA
    nop
    sbi DDRB, SCL
    nop
    ret


.global i2c_stop
; Call depth: 1
i2c_stop:
    sbi DDRB, SDA 
    cbi DDRB, SCL
    nop
    cbi DDRB, SDA
    nop
    ret


.global i2c_write
; Inputs: r20 - data byte
; Used registers: r17, r19, r20
; Call depth: 1
i2c_write:
    ldi r19, 8
i2c_write_loop:
    lsl r20
    brcc i2c_write_sda_0
    cbi DDRB, SDA
    rjmp i2c_write_loop_cont
i2c_write_sda_0:
    sbi DDRB, SDA
i2c_write_loop_cont:
    nop
    cbi DDRB, SCL
    nop
    sbi DDRB, SCL
    dec r19
    brne i2c_write_loop

    ; ACK cycle
    cbi DDRB, SDA
    nop
    cbi DDRB, SCL
    nop
    sbi DDRB, SCL
    nop

    ret


.global i2c_read
; Outputs: r22 - read data byte
; Used registers: r17, r19, r21, r22
; Call depth: 1
i2c_read:
    cbi DDRB, SDA
    ldi r22, 0
    ldi r19, 8
i2c_read_loop:
    lsl r22
    cbi DDRB, SCL
    nop
    in r21, PINB
    sbrc r21, 3
    inc r22
    sbi DDRB, SCL
    nop
    dec r19
    brne i2c_read_loop

    ; ACK cycle
    cbi DDRB, SDA
    sbi PORTB, SDA
    nop
    cbi DDRB, SCL
    nop
    sbi DDRB, SCL
    nop
    cbi PORTB, SDA
    ret


.global display_write_reg
; Inputs: r21 - register address; r22 - register value
; Used registers: r17, r19, r20, r21, r22
; Call depth: 2
display_write_reg:
    rcall i2c_start
    ldi r20, ADDR_W
    rcall i2c_write
    mov r20, r21
    rcall i2c_write
    mov r20, r22
    rcall i2c_write
    rcall i2c_stop
    ret


.global display_set_reg_page
; Inputs: r23 - page id
; Used registers: r17, r19, r20, r21, r22, r23
; Call depth: 3
display_set_reg_page:
    ldi r21, 0xfe
    ldi r22, 0xc5
    rcall display_write_reg

    ldi r21, 0xfd
    mov r22, r23
    rcall display_write_reg
    ret


.global display_set_pixel
; inputs: r23 - x; r24 - y, r22 - value
; Used registers: r17, r19, r20, r21, r22, r23, r24
; Call depth: 3
display_set_pixel:
    mov r21, r24    ; Calculate PWM register id as [y * 18 + x + 1]
    swap r21        ; Multiply y by 18
    add r21, r24
    add r21, r24
    add r21, r23    ; Adding x
    inc r21         ; Adding 1
    rcall display_write_reg

    ret


.global display_get_pixel
; inputs: r23 - x; r24 - y
; Outputs: r22 - pixel value
; Used registers: r17, r19, r20, r21, r22, r23, r24
; Call depth: 3
display_get_pixel:
    mov r21, r24    ; Calculate PWM register id as [y * 18 + x + 1]
    swap r21        ; Multiply y by 18
    add r21, r24
    add r21, r24
    add r21, r23    ; Adding x
    inc r21         ; Adding 1
    rcall display_read_reg

    ret


.global display_clear
; Clear entire screen
; Used registers: r17, r19, r20, r21, r22
; Call depth: 3
display_clear:
    ldi r21, 0
    ldi r22, 0
    
display_clear_write_pwm_val:
    rcall display_write_reg
    inc r21
    cpi r21, (198 + 1)
    brne display_clear_write_pwm_val
    
    ret


.global display_draw_img_3x5
; Inputs: r27 - x offset; r28 - y offset; r29 - intensity; Z(r31, r30) - bitmap address
; Used registers: r16, r19, r20, r21, r22, r23, r24, r25, r26, r27, r28, r29, r30, r31
; Call depth: 4
display_draw_img_3x5:
    mov r24, r28 ; r24 - y
    ldi r25, 8 ; r25 - bit counter

display_draw_img_3x5_y_loop:
    mov r23, r27 ; r23 - x
display_draw_img_3x5_x_loop:
    cpi r25, 8  ; Check if all bits in the current byte are read
    brne display_draw_img_3x5_put_pixel
    ldi r25, 0
    ld r26, Z+  ; Fetch the next byte if the current one ended

display_draw_img_3x5_put_pixel:
    sbrs r26, 7
    ldi r22, 0
    sbrc r26, 7
    mov r22, r29
    inc r25
    lsl r26
    rcall display_set_pixel
    inc r23
    mov r16, r23
    sub r16, r27
    cpi r16, 3
    brlo display_draw_img_3x5_x_loop

    inc r24
    mov r16, r24
    sub r16, r28
    cpi r16, 5
    brlo display_draw_img_3x5_y_loop

    ret


.global display_read_reg
; Inputs: r21 - register address
; Outputs r22 - register value
; Used registers: r17, r19, r20, r21, r22
; Call depth: 2
display_read_reg:
    rcall i2c_start
    ldi r20, ADDR_W
    rcall i2c_write    
    mov r20, r21
    rcall i2c_write
    rcall i2c_stop

    rcall i2c_start
    ldi r20, ADDR_R
    rcall i2c_write
    rcall i2c_read
    rcall i2c_stop

    ret



.global poll_kb
; Read keyboard
; Checks if a key is pressed by sampling analog signal from the keyboard resistor ladder
; Output: r26 - key id [1..4], or zero if no key is pressed
; Touched registers: r17, r20, r21, r22, r26
; Call depth: 1
poll_kb:
    sbi ADCSRA, ADSC       ; Sample ADC

poll_kb_adc_wait_loop:
    sbic ADCSRA, ADSC
    rjmp poll_kb_adc_wait_loop
    
    in r20, ADCL
    cpi r20, 25            ; Check if the resulting value corresponds to one of the keys
    brlo poll_kb_key_1
    cpi r20, 96
    brlo poll_kb_key_2
    cpi r20, 154
    brlo poll_kb_key_3
    cpi r20, 222
    brlo poll_kb_key_4

; Load key-id into KB_REG and return
poll_kb_key_none:
    ldi r17, 0                       ; No key is pressed 
    rjmp poll_kb_update_r26

poll_kb_key_1:
    ldi r17, (KEY_LU + 1)
    rjmp poll_kb_update_r26

poll_kb_key_2:
    ldi r17, (KEY_RU + 1)
    rjmp poll_kb_update_r26

poll_kb_key_3:
    ldi r17, (KEY_RB + 1)               
    rjmp poll_kb_update_r26

poll_kb_key_4:
    ldi r17, (KEY_LB + 1)
    rjmp poll_kb_update_r26

poll_kb_update_r26:
    mov r20, KB_REG
    andi r20, 0x7f
    cp r17, r20              ; Check if the currently pressed key is different from the previously pressed one
    brne poll_kb_key_change
    mov KB_REG, r17
    ret
poll_kb_key_change:
    mov KB_REG, r17
    ori KB_REG, 0x80         ; Set MSB to indicate that it's a diffferent key now
    ret


.global play_tune
; Call depth: 2
play_tune:
    ldi r17, ((1 << COM0B1) | (1 << WGM01))   ; Enable PWM output
    out TCCR0A, r17

    ldi r18, hi8(500)     ; Speaker's PWM duty cycle 
    ldi r19, lo8(500)
    out OCR0BH, r18
    out OCR0BL, r19

    ld r16, Z+            ; Number of notes
play_tune_loop:
    ld r17, Z+            ; Duration (in multiple of 25ms)
    ld r18, Z+            ; Frequncy hi byte
    ld r19, Z+            ; Frequncy low byte
    out ICR0H, r19
    out ICR0L, r18
    rcall looong_delay

    dec r16
    brne play_tune_loop

    ldi r17, 1 << COM0B1  ; Disable PWM output
    out TCCR0A, r17

    ret


.global move_snek
; Call depth: 5
move_snek:
    lds r18, move_t
    inc r18
    cpi r18, SNEK_MOVE_TIME
    breq move_snek_cont
    sts move_t, r18
    rjmp move_snek_ret

move_snek_cont:
    rcall display_clear

    ldi r18, 0
    sts move_t, r18

    lds r23, head_pos
    lds r24, head_pos
    swap r24
    andi r23, 0b1111
    andi r24, 0b1111
    lds r25, hdir
    lds r31, prev_hdir

    rcall move_snek_cursor

    mov r22, r24
    swap r22
    or r22, r23
    sts head_pos, r22

    ldi r22, SNEK_HEAD_VALUE        ; Draw head
    rcall display_set_pixel

    rcall shift_snek_buffer         ; Push a bit to snek_buffer

    sts prev_hdir, r25
    cp r25, r31                     ; Check if the snake has turned
    breq move_snek_draw_snek
                                    ; If yes, record a turn in snek_buffer
    rcall shift_snek_buffer         ; Push another bit to encode turn direction 
    lds r17, snek_buffer
    ori r17, 0b10000000             ; Encode a turn as '1'
    
    mov r16, r25                    ; Determine if the snake turned right as [(hdir + 4 - prev_hdir) % 4 != 3]
    subi r16, -4
    sub r16, r31
    sbrs r16, 1                     ; Encode left turn as '0'
    ori r17, 0b01000000             ; Encode right turn as '1'
    sts snek_buffer, r17

move_snek_draw_snek:                ; Draw the rest of the snake

    ldi r30, lo8(snek_buffer)
    ldi r31, hi8(snek_buffer)

    lds r16, size                ; r16 - snake segment index
    ldi r28, 0                   ; r28 - bit index in snek_buffer
    subi r25, -2                 ; Reverse heading direction as [hdir = (hdir + 2) % 4]
    andi r25, 0b11

move_snek_iter_buffer:
    cpi r16, 0
    breq move_snek_check_food
    rcall move_snek_cursor

    mov r18, r28                 ; if bit_index % 8 == 0 then fetch the next byte from snek_buffer
    andi r18, 0b111
    brne move_snek_next_segment
    ld r27, Z+                   ; r27 - current byte contents in snek_buffer

move_snek_next_segment:
    lsl r27                      ; Check the next bit, if it's a zero - it's a straight segment
    brcc move_snek_next_segment_cont
                                 ; Else, increment bit_index and fetch the next byte if needed
    inc r28                       
    mov r18, r28
    andi r18, 0b111
    brne move_snek_next_segment_turn
    ld r27, Z+
                                ; Turn either left or right, depending on the next bit in snek_buffer
move_snek_next_segment_turn:
    lsl r27
    brcs move_snek_next_segment_turn_right
    subi r25, -1
    rjmp move_snek_next_segment_turn_cont

move_snek_next_segment_turn_right:
    subi r25, -3

move_snek_next_segment_turn_cont:
    andi r25, 0b11

move_snek_next_segment_cont:

    rcall display_get_pixel              ; Check self-bite
    cpi r22, 0
    breq move_snek_next_segment_draw
    set                                  ; If yes, finish the game
    
    ldi r30, lo8(tune_game_over + 0x4000)
    ldi r31, hi8(tune_game_over + 0x4000)
    rcall play_tune
    
    ret

move_snek_next_segment_draw:    

    ldi r22, SNEK_BODY_VALUE1            ; Draw the snake body with alternating shades
    mov r17, r16
    andi r17, 1
    breq move_snek_next_segment_draw_cont
    ldi r22, SNEK_BODY_VALUE2
    
move_snek_next_segment_draw_cont:
    
    rcall display_set_pixel

    dec r16
    inc r28
    rjmp move_snek_iter_buffer
; The snake is fully drawn here

move_snek_check_food:               ; Check if the food was eaten
    lds r24, head_pos
    lds r18, food_pos
    cp r18, r24
    brne move_snek_ret

    lds r18, size                  ; Increment the snake size if the food was eaten
    inc r18
    sts size, r18
    
    ldi r30, lo8(tune_food_eaten + 0x4000)
    ldi r31, hi8(tune_food_eaten + 0x4000)
    rcall play_tune

    rcall spawn_food


move_snek_ret:
    ret


.global shift_snek_buffer
; Shifts right every bit in snek_buffer
; Used registers: r17, r18, r28, r29
; Call depth: 1
shift_snek_buffer:

    ldi r28, lo8(snek_buffer)
    ldi r29, hi8(snek_buffer)
    ldi r17, SNEK_BUFFER_SIZE
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
;  r23 - cursor x
;  r24 - cursor y
;  r25 - heading direction
; Outputs:
;  r23 - updated cursor x
;  r24 - updated cursor y
; Used registers: r23, r24, r25
; Call depth: 1
move_snek_cursor:
    cpi r25, DIR_UP
    breq move_snek_cursor_up
    cpi r25, DIR_DOWN
    breq move_snek_cursor_down
    cpi r25, DIR_LEFT
    breq move_snek_cursor_left
    inc r23            ; else move right
    cpi r23, 15
    brlo move_snek_cursor_done
    ldi r23, 0

    rjmp move_snek_cursor_done

move_snek_cursor_up:
    dec r24
    brpl move_snek_cursor_done
    ldi r24, 9
    rjmp move_snek_cursor_done
move_snek_cursor_down:
    inc r24
    cpi r24, 10
    brlo move_snek_cursor_done
    ldi r24, 0
    rjmp move_snek_cursor_done
move_snek_cursor_left:
    dec r23
    brpl move_snek_cursor_done
    ldi r23, 14

move_snek_cursor_done:
    ret


.global process_input
; Update snake heading direction according to pressed keys
; Used registers: r17, r24
; Call depth: 1
process_input:
    sbrs KB_REG, 7             ; Exit if no key-down event present (LSB isn't set)    
    rjmp process_input_done
    mov r17, KB_REG
    andi r17, 0b111
    cpi r17, 0                 ; Exit if no key is pressed
    breq process_input_done
    
    dec r17                    ; r17 - key id
    
    lds r24, prev_hdir
    andi r24, 0x01
    breq process_input_left_right

    ldi r24, DIR_LEFT
    sbrc r17, 1
    ldi r24, DIR_RIGHT
    rjmp process_input_update_hdir

process_input_left_right:
    ldi r24, DIR_DOWN
    sbrc r17, 0
    ldi r24, DIR_UP

process_input_update_hdir:
    sts hdir, r24              ; Update direction
process_input_done:
    ret


.global spawn_food
; Call depth: 4
spawn_food:
    rcall rand
    lds r23, seed
    mov r24, r23
    swap r24
    andi r23, 0b1111
    andi r24, 0b1111

spawn_food_clamp_x:
    cpi r23, 15
    brlo spawn_food_clamp_y
    subi r23, 15

spawn_food_clamp_y:
    cpi r24, 10
    brlo spawn_food_cont
    subi r24, 10

spawn_food_cont:
    rcall display_get_pixel
    cpi r22, 0
    brne spawn_food

    swap r24
    or r24, r23
    sts food_pos, r24

    ret


.global draw_food
; Call depth: 4
draw_food:
    lds r23, food_pos
    mov r24, r23
    swap r24
    andi r23, 0b1111
    andi r24, 0b1111

    lds r22, move_t         ; Make the food blink
    lsr r22
draw_food_cont:
    rcall display_set_pixel
    ret


.global show_score
; Call depth: 5
show_score:
    rcall display_clear

    lds r17, size
    ldi r18, 0

show_score_calc_loop:
    cpi r17, 10
    brlo show_score_draw
    subi r17, 10
    inc r18
    rjmp show_score_calc_loop

show_score_draw:
    lsl r17
    lsl r18
    ldi r30, lo8(img_digit_thin_0 + 0x4000)
    ldi r31, hi8(img_digit_thin_0 + 0x4000)
    ldi r27, 4
    ldi r28, 2
    ldi r29, 0x20
    add r30, r18
    
    rcall display_draw_img_3x5
    ldi r30, lo8(img_digit_thin_0 + 0x4000)
    ldi r27, 8
    add r30, r17
    rcall display_draw_img_3x5

    ret



.global rand
; Get a very pseudo random value
; Outputs: r17 - random value [0..255]
; Used registers: r17, r18
; Call depth: 1
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
    mov r18, r17
    swap r18
    lsl r18
    andi r18, 0b11100000
    eor r17, r18

    sts seed, r17
    ret


.global new_game
; Call depth: 6
new_game:
    ldi r16, (SNEK_MOVE_TIME - 1)
    sts move_t, r16

    ldi r16, (4 << 4) | 4
    sts head_pos, r16

    ldi r16, 0
    sts hdir, r16
    sts prev_hdir, r16
    sts size, r16

    rcall move_snek
    rcall spawn_food

    ret

.section .text

; 3x5
img_digit_thin_0:
    .byte 0b11010110
    .byte 0b11010110


; 3x5
img_digit_thin_1:
    .byte 0b01011001
    .byte 0b00101110


; 3x5
img_digit_thin_2:
    .byte 0b11100111
    .byte 0b11001110


; 3x5
img_digit_thin_3:
    .byte 0b11100111
    .byte 0b10011110


; 3x5
img_digit_thin_4:
    .byte 0b10110111
    .byte 0b10010010


; 3x5
img_digit_thin_5:
    .byte 0b11110011
    .byte 0b10011110


; 3x5
img_digit_thin_6:
    .byte 0b11110011
    .byte 0b11011110


; 3x5
img_digit_thin_7:
    .byte 0b11100101
    .byte 0b00100100


; 3x5
img_digit_thin_8:
    .byte 0b11110111
    .byte 0b11011110


; 3x5
img_digit_thin_9:
    .byte 0b11110111
    .byte 0b10011110


tune_game_over:
    .byte 3                  ; Number of notes
    
    .byte 14                 ; Duration
    .short SPEAKER_PWM(300)  ; Frequency

    .byte 14                 ; Duration
    .short SPEAKER_PWM(200)  ; Frequency

    .byte 40                 ; Duration
    .short SPEAKER_PWM(125)  ; Frequency


tune_food_eaten:
    .byte 2                  ; Number of notes
    
    .byte 3                  ; Duration
    .short SPEAKER_PWM(800)  ; Frequency

    .byte 4                  ; Duration
    .short SPEAKER_PWM(1000) ; Frequency


.section .data

move_t:
    .byte 0x00
head_pos:
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
    .zero SNEK_BUFFER_SIZE

; Bytes used: 20
; Max call depth: 6 

.end