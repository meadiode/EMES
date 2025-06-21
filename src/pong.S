#include <avr/io.h>

#define DIR_UP     0x00
#define DIR_DOWN   0x03
#define DIR_LEFT   0x01
#define DIR_RIGHT  0x02

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

    out PORTB, r16

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

    rcall display_clear
    rcall new_game

main_loop:
    rcall poll_kb

    rcall draw_net
    rcall move_ball
    rcall check_score
    rcall move_paddles

    ldi r17, 99
    rcall long_delay

    rjmp main_loop


.global delay
delay:
    ret

.global long_delay
; Long delay routine - from ~100us to ~25ms at 8MHz
; Input r17 - delay value: approx delay_time(us) = (r17 + 1) * 100
; Used registers: r17, r18
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

i2c_start:
    cbi DDRB, SCL
    cbi DDRB, SDA
    rcall delay
    sbi DDRB, SDA
    rcall delay
    sbi DDRB, SCL
    rcall delay
    ret


.global i2c_stop

i2c_stop:
    sbi DDRB, SDA 
    cbi DDRB, SCL
    rcall delay
    cbi DDRB, SDA
    rcall delay
    ret


.global i2c_write
; Inputs: r20 - data byte
; Used registers: r19, r20
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
    rcall delay
    cbi DDRB, SCL
    rcall delay
    sbi DDRB, SCL
    dec r19
    brne i2c_write_loop

    ; ACK cycle
    cbi DDRB, SDA
    rcall delay
    cbi DDRB, SCL
    rcall delay
    sbi DDRB, SCL
    rcall delay

    ret


.global display_write_reg
; Inputs: r21 - register address; r22 - register value
; Used registers: r19, r20, r21, r22
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
; Used registers: r19, r20, r21, r22, r23
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
; Used registers: r19, r20, r21, r22, r23, r24
display_set_pixel:
    mov r21, r24    ; Calculate PWM register id as [y * 18 + x + 1]
    swap r21        ; Multiply y by 18
    add r21, r24
    add r21, r24
    add r21, r23    ; Adding x
    inc r21         ; Adding 1
    rcall display_write_reg

    ret


.global display_clear
display_clear:
    ldi r21, 0
    ldi r22, 0
    
display_clear_write_pwm_val:
    rcall display_write_reg
    inc r21
    cpi r21, (198 + 1)
    brne display_clear_write_pwm_val
    ret



.global poll_kb
; Read keyboard
; Checks if a key is pressed by sampling analog signal from the keyboard resistor ladder
; Output: r26 - key id [1..4], or zero if no key is pressed, MSB indicates a key-down event
; Used registers: r17, r20, r21, r22, r26
poll_kb:
    clr r20 
    clr r21 
    ldi r17, 4

poll_kb_adc_sample_loop:             ; Sample ADC 4 times and store average in r20
    sbi ADCSRA, ADSC

poll_kb_adc_wait_loop:
    sbic ADCSRA, ADSC
    rjmp poll_kb_adc_wait_loop
    in r22, ADCL
    adc r20, r22
    brcc poll_kb_no_hibyte_inc
    inc r21
poll_kb_no_hibyte_inc:
    dec r17
    brne poll_kb_adc_sample_loop

    lsr r21                  ; Divide R21-R20 by 4 to find average
    ror r20
    lsr r21
    ror r20

    cpi r20, 40                ; Check if the resulting value corresponds to one of the keys
    brlo poll_kb_key_none
    cpi r20, 51
    brlo poll_kb_key_1
    cpi r20, 61
    brlo poll_kb_key_2
    cpi r20, 73
    brlo poll_kb_key_3
    cpi r20, 83
    brlo poll_kb_key_4

    rjmp poll_kb_key_none            ; No key is pressed 

; Load key-id into r26 and return
poll_kb_key_1:                       ; UP key
    ldi r17, (DIR_UP + 1)
    rjmp poll_kb_update_r26

poll_kb_key_2:                       ; DOWN key
    ldi r17, (DIR_DOWN + 1)
    rjmp poll_kb_update_r26

poll_kb_key_3:                       ; LEFT key
    ldi r17, (DIR_LEFT + 1)               
    rjmp poll_kb_update_r26

poll_kb_key_4:                       ; RIGHT key
    ldi r17, (DIR_RIGHT + 1)
    rjmp poll_kb_update_r26

poll_kb_key_none:
    ldi r17, 0

poll_kb_update_r26:
    mov r20, r26
    andi r20, 0x7f
    cp r17, r20              ; Check if the currently pressed key is different from the previously pressed one
    brne poll_kb_key_change
    mov r26, r17
    ret
poll_kb_key_change:
    mov r26, r17
    ori r26, 0x80         ; Set MSB to indicate that it's a diffferent key now
    ret


.global beep
beep:
    ldi r17, ((1 << COM0B1) | (1 << WGM01))
    out TCCR0A, r17
    
;    ldi r19, hi8(16000)
;    ldi r18, lo8(16000)
    out ICR0H, r19
    out ICR0L, r18

    ldi r18, hi8(500)
    ldi r17, lo8(500)
    out OCR0BH, r18
    out OCR0BL, r17

    ret


.global no_beep
no_beep:
    ldi r17, 1 << COM0B1
    out TCCR0A, r17
    ret


.global boop
boop:
    ldi r19, hi8(8000000 / 250)
    ldi r18, lo8(8000000 / 250)
    rcall beep
    ldi r17, 1
    rcall looong_delay
    rcall no_beep
    ret


.global happy_beep
happy_beep:
    ldi r19, hi8(8000000 / 800)
    ldi r18, lo8(8000000 / 800)
    rcall beep
    ldi r17, 10
    rcall looong_delay
    ldi r19, hi8(8000000 / 1000)
    ldi r18, lo8(8000000 / 1000)
    rcall beep
    ldi r17, 20
    rcall looong_delay
    rcall no_beep

    ret



.global new_game
new_game:
    ldi r16, 0
    sts ai_timer, r16
    sts score_player1, r16
    sts score_player2, r16
    sts scorer, r16
    rcall new_point
    rcall move_ball
    rcall move_paddles
    rcall draw_net

    ldi r17, 3
    ldi r27, 100
new_game_player_select_loop:
    rcall looong_delay
    rcall poll_kb
    sbrs r26, 7                                  ; Check if any key is pressed
    rjmp new_game_player_select_loop_cont
    andi r26, 0b10
    breq new_game_cpu_vs_human
    ldi r16, 0b01
    rjmp new_game_ret
new_game_cpu_vs_human:
    ldi r16, 0b10
    rjmp new_game_ret

new_game_player_select_loop_cont:
    dec r27
    brne new_game_player_select_loop

    ldi r16, 0b11                        ; Play  CPU vs CPU if no key is pressed for 10sec 

new_game_ret:
    sts players, r16                     ; The players var defines who controls the paddles
                                         ; 0b00 - human/human, 0b01 - human/CPU, 0b10 - CPU/human, 0b11 - CPU/CPU
    ret



.global new_point
new_point:
    lds r17, scorer
    cpi r17, 2
    breq new_point_player2_side
    
    ; Player 1 side - default 
    ldi r16, 1
    sts ball_x, r16
    ldi r16, 37
    sts ball_vel_x, r16
    rjmp new_point_cont

new_point_player2_side:
    ldi r16, 13
    sts ball_x, r16
    ldi r16, -37
    sts ball_vel_x, r16

new_point_cont:
    ldi r16, 4
    sts ball_y, r16
    ldi r16, 0
    sts ball_mov_x, r16
    sts ball_mov_y, r16
    ldi r16, 23
    sts ball_vel_y, r16

    ldi r16, 3
    sts paddle_left, r16                 ; y position of the paddles
    sts paddle_right, r16

    ret


.global move_ball
move_ball:
    lds r23, ball_x
    lds r24, ball_y
    ldi r22, 0
    rcall display_set_pixel              ; Erase ball

; Ball X-movement
    lds r25, ball_mov_x
    lds r16, ball_vel_x
    sbrc r16, 7                          ; r16 = abs(ball_vel_x)
    neg r16
    add r25, r16                         ; Increase movement on x
    brcc move_ball_x_proc                ; If movement on x overflows, then move the ball on x 
    lds r16, ball_vel_x                  ; Load vel_x again and check if negative
    tst r16
    brmi move_ball_go_left               ; If vel_x negative, then move the ball left
    cpi r23, 13                          ; Else, move right and if x == 13, then the ball is bouncing from the right paddle
    breq move_ball_bounce_right
    inc r23
    rjmp move_ball_x_proc

move_ball_go_left:
    cpi r23, 1                           ; Check if x == 1, the ball is bouncing from the left paddle 
    breq move_ball_bounce_left
    dec r23
    rjmp move_ball_x_proc

move_ball_bounce_right:
    lds r27, paddle_right
    inc r27
    sub r27, r24
    sbrc r27, 7
    neg r27
    cpi r27, 2
    brge move_ball_player1_score
    rjmp move_ball_bounce_x

move_ball_player1_score:
    inc r23
    ldi r17, 1
    sts scorer, r17
    lds r17, score_player1
    inc r17
    sts score_player1, r17
    rjmp move_ball_bounce_x

move_ball_bounce_left:
    lds r27, paddle_left
    inc r27
    sub r27, r24
    sbrc r27, 7
    neg r27
    cpi r27, 2
    brge move_ball_player2_score
    rjmp move_ball_bounce_x

move_ball_player2_score:
    dec r23
    ldi r17, 2
    sts scorer, r17
    lds r17, score_player2
    inc r17
    sts score_player2, r17

move_ball_bounce_x:
    neg r16                              ; Negate vel_x in case of bounce
    sts ball_vel_x, r16
    rcall boop

move_ball_x_proc:
    sts ball_mov_x, r25

; Ball Y-movement
    lds r25, ball_mov_y
    lds r16, ball_vel_y
    sbrc r16, 7                          ; r16 = abs(ball_vel_y)
    neg r16
    add r25, r16                         ; Increase movement on y
    brcc move_ball_y_proc                ; If movement on y overflows, then move the ball on y 
    lds r16, ball_vel_y                  ; Load vel_y again and check if negative
    tst r16
    brmi move_ball_go_up                 ; If vel_y negative, then move the ball up
    cpi r24, 9                           ; Else, move down and if y >= 9, then the ball is bouncing from the bottom wall
    breq move_ball_bounce_bottom
    inc r24
    rjmp move_ball_y_proc

move_ball_go_up:
    cpi r24, 0
    breq move_ball_bounce_up
    dec r24
    rjmp move_ball_y_proc

move_ball_bounce_bottom:
    ;dec r24
    rjmp move_ball_bounce_y

move_ball_bounce_up:
    ;inc r24

move_ball_bounce_y:
    neg r16                              ; Negate vel_y in case of bounce
    sts ball_vel_y, r16


move_ball_y_proc:
    sts ball_mov_y, r25
    

    sts ball_x, r23
    sts ball_y, r24

    
    ldi r22, 0x40
    rcall display_set_pixel              ; Draw ball


    ret



.global draw_paddle
draw_paddle:
    ldi r16, 0

draw_paddle_loop:
    rcall display_set_pixel
    inc r24
    inc r16
    cpi r16, 3
    brne draw_paddle_loop
    ret


.global move_paddles
move_paddles:

    lds r16, ai_timer
    inc r16
    cpi r16, 14                                 ; This number determines how slow CPU player is
    breq move_paddles_ai_enabled
    ldi r27, 0
    rjmp move_paddles_start

move_paddles_ai_enabled:
    ldi r27, 1
    lds r16, 0

move_paddles_start:
    sts ai_timer, r16

; Left paddle movement 
    ldi r22, 0
    ldi r23, 0
    lds r24, paddle_left
    rcall draw_paddle
    lds r24, paddle_left

    lds r17, players
    andi r17, 0b10
    breq move_paddles_check_left_controls
    sbrs r27, 0
    rjmp move_paddles_draw_left
    lds r16, ball_vel_x
    tst r16
    brpl move_paddles_draw_left

    lds r16, ball_y
    mov r17, r24
    inc r17
    sub r16, r17
    breq move_paddles_draw_left
    brpl move_paddles_move_left_down
    brmi move_paddles_move_left_up
    rjmp move_paddles_draw_left

move_paddles_check_left_controls:
    cpi r26, 0b10000010
    breq move_paddles_move_left_up
    cpi r26, 0b10000011
    breq move_paddles_move_left_down
    rjmp move_paddles_draw_left

move_paddles_move_left_up:
    cpi r24, 0
    breq move_paddles_draw_left
    dec r24
    rjmp move_paddles_draw_left

move_paddles_move_left_down:
    cpi r24, 7
    brge move_paddles_draw_left
    inc r24

move_paddles_draw_left:
    sts paddle_left, r24
    ldi r22, 0x20
    rcall draw_paddle


; Right paddle movement 
    ldi r22, 0
    ldi r23, 14
    lds r24, paddle_right
    rcall draw_paddle
    lds r24, paddle_right

    lds r17, players
    andi r17, 0b01
    breq move_paddles_check_right_controls
    sbrs r27, 0
    rjmp move_paddles_draw_right
    lds r16, ball_vel_x
    tst r16
    brmi move_paddles_draw_right

    lds r16, ball_y
    mov r17, r24
    inc r17
    sub r16, r17
    breq move_paddles_draw_right
    brpl move_paddles_move_right_down
    brmi move_paddles_move_right_up
    rjmp move_paddles_draw_right

move_paddles_check_right_controls:
    cpi r26, 0b10000100
    breq move_paddles_move_right_up
    cpi r26, 0b10000001
    breq move_paddles_move_right_down
    rjmp move_paddles_draw_right

move_paddles_move_right_up:
    cpi r24, 0
    breq move_paddles_draw_right
    dec r24
    rjmp move_paddles_draw_right

move_paddles_move_right_down:
    cpi r24, 7
    brge move_paddles_draw_right
    inc r24

move_paddles_draw_right:
    sts paddle_right, r24
    ldi r22, 0x20
    rcall draw_paddle

    ret


.global draw_net
draw_net:
    ldi r23, 7
    ldi r24, 0
    ldi r22, 0x05

draw_net_loop:
    rcall display_set_pixel
    inc r24
    cpi r24, 10
    brne draw_net_loop

    ret


.global check_score
check_score:
    lds r16, scorer
    tst r16
    breq check_score_ret

    ldi r30, lo8(img_digit_thin_0 + 0x4000)
    ldi r31, hi8(img_digit_thin_0 + 0x4000)
    lds r17, score_player1
    
    cpi r17, 9
    brne check_score_p1_not_winner
    set

check_score_p1_not_winner:
    ldi r18, 0
check_score_p1_ctr_loop:
    cp r17, r18
    breq check_score_p1_ctr_loop_end
    subi r30, -2
    inc r18
    rjmp check_score_p1_ctr_loop

check_score_p1_ctr_loop_end:
    ldi r27, 3
    ldi r28, 3
    ldi r29, 0x40
    rcall display_draw_img_3x5

    ldi r30, lo8(img_digit_thin_0 + 0x4000)
    ldi r31, hi8(img_digit_thin_0 + 0x4000)
    lds r17, score_player2
    cpi r17, 9
    brne check_score_p2_not_winner
    set
check_score_p2_not_winner:
    ldi r18, 0
check_score_p2_ctr_loop:
    cp r17, r18
    breq check_score_p2_ctr_loop_end
    subi r30, -2
    inc r18
    rjmp check_score_p2_ctr_loop

check_score_p2_ctr_loop_end:
    ldi r27, 9
    ldi r28, 3
    ldi r29, 0x40
    rcall display_draw_img_3x5

    rcall happy_beep

    ldi r17, 100
    rcall looong_delay

    rcall display_clear

    brtc check_score_new_point
    clt
    rcall new_game
    rjmp check_score_ret

check_score_new_point:
    rcall new_point

check_score_ret:
    ldi r16, 0
    sts scorer, r16
    ret


.global display_draw_img_3x5
; Inputs: r27 - x offset; r28 - y offset; r29 - intensity; Z(r31, r30) - bitmap address
; Used registers: r16, r19, r20, r21, r22, r23, r24, r25, r26, r27, r28, r29, r30, r31

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



.section .data;

ball_x:
    .byte 0x00
ball_y:
    .byte 0x00
ball_mov_x:
    .byte 0x00
ball_mov_y:
    .byte 0x00
ball_vel_x:
    .byte 0x00
ball_vel_y:
    .byte 0x00

paddle_left:
    .byte 0x00
paddle_right:
    .byte 0x00

players:
    .byte 0x00

ai_timer:
    .byte 0x00

score_player1:
    .byte 0x00
score_player2:
    .byte 0x00

scorer:
    .byte 0x00

.end