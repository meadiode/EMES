#include <avr/io.h>

#define KEY_LU     0
#define KEY_RU     1
#define KEY_RB     2
#define KEY_LB     3

#define SPEAKER_PWM_DUTY 500
#define SPEAKER_PWM(Hz)  (8000000 / (Hz))  ; Min Hz value: 122

#define C4 260
#define D4 290
#define E4 330
#define F4 355
#define G4 390
#define A4 440
#define B4 495

#define C5 (C4 * 2)
#define D5 (D4 * 2)
#define E5 (E4 * 2)
#define F5 (F4 * 2)
#define G5 (G4 * 2)
#define A5 (A4 * 2)
#define B5 (B4 * 2)

#define ADDR_W 0x40
#define ADDR_R 0x41

#define SCL PORTB2
#define SDA PORTB3

#define PIXEL_VALUE 28

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

main_write_scalling_val:
    rcall display_write_reg
    inc r21
    cpi r21, (198 + 1)
    brne main_write_scalling_val

    ldi r23, 0
    rcall display_set_reg_page

    ldi r21, 0
    ldi r22, 0

main_write_pwm_val:
    rcall display_write_reg
    inc r21
    cpi r21, (198 + 1)
    brne main_write_pwm_val

    ldi r16, 42
    sts seq_seed, r16
    ldi r16, 0
    sts kb_stat, r16

main_start:
    rcall display_clear
    ldi r16, 0
    sts seq_len, r16
main_intro_loop:
    push r16
    ldi r27, 3
main_intro_loop2:
    rcall activate_button
    ldi r17, 1
    rcall looong_delay
    dec r27
    brpl main_intro_loop2
    ldi r27, 0
    pop r16
    inc r16
    cpi r16, 3
    brlo main_intro_loop

main_play_round:

    ldi r17, 39
    rcall looong_delay

    lds r16, seq_len
    lds r17, seq_seed
    sts seed, r17

main_play_seq_loop:
    push r16
    lds r27, seed
    andi r27, 0b11
    rcall activate_button
    ldi r17, 20
    rcall looong_delay
    rcall rand
    pop r16
    dec r16
    brpl main_play_seq_loop


    lds r16, seq_len
    lds r17, seq_seed
    sts seed, r17

main_players_seq_loop:
    push r16

main_players_input:
    rcall poll_kb
    sbrs r26, 7
    rjmp main_players_input
    mov r27, r26
    andi r27, 0b111
    dec r27    
    brmi main_players_input
    rcall activate_button
    lds r17, seed
    andi r17, 0b11

    cp r17, r27
    brne main_game_over
    rcall rand
    pop r16
    dec r16
    brpl main_players_seq_loop

    lds r17, seq_len
    inc r17
    sts seq_len, r17
    rjmp main_play_round


main_game_over:
    ldi r30, lo8(tune_game_over + 0x4000)
    ldi r31, hi8(tune_game_over + 0x4000)
    rcall play_tune
    rcall show_score
    lds r17, seed
    inc r17
    sts seq_seed, r17

main_game_over_idle:
    rcall poll_kb
    sbrs r26, 7
    rjmp main_game_over_idle
    andi r26, 0b111
    breq main_game_over_idle
    rjmp main_start



.global activate_button
; Inputs: r27 - button id [0..3]
; Used registers: r16, r17, r18, r19, r20, r21, r22, r23, r24, r25, r26, r27, r28, r30, r31
; Call depth: 5
activate_button:
    ldi r22, 4
    ldi r30, lo8(img_simon + 0x4000)
    ldi r31, hi8(img_simon + 0x4000)
    rcall display_blit_img_15x10

    ldi r30, lo8(img_simon_lu + 0x4000)
    ldi r31, hi8(img_simon_lu + 0x4000)
    mov r28, r27  ; Multiply button id by 19 to get bitmap offset
    swap r28
    add r28, r27
    add r28, r27
    add r28, r27

    add r30, r28 ; Add bitmap offset to Z
    ldi r16, 0
    adc r31, r16

    ldi r22, 50
    rcall display_blit_img_15x10

    ldi r30, lo8(tune_lu + 0x4000)
    ldi r31, hi8(tune_lu + 0x4000)
    mov r17, r27 ; Multiply button id by 4 to get tune offset
    lsl r17
    lsl r17
    add r30, r17
    ldi r17, 0
    adc r31, r17
    rcall play_tune

    ldi r30, lo8(img_simon_lu + 0x4000)
    ldi r31, hi8(img_simon_lu + 0x4000)
    add r30, r28 ; Add bitmap offset to Z
    ldi r16, 0
    adc r31, r16

    ldi r22, 0
    rcall display_blit_img_15x10

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
    nop
    sbi DDRB, SDA
    nop
    sbi DDRB, SCL
    nop
    ret


.global i2c_stop

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
i2c_read:
    cbi DDRB, SDA
    ldi r22, 0
    ldi r19, 8
i2c_read_loop:
    lsr r22
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
    nop
    cbi DDRB, SCL
    nop
    sbi DDRB, SCL
    nop
    sbi DDRB, SDA

    ret


.global display_write_reg
; Inputs: r21 - register address; r22 - register value
; Used registers: r17, r19, r20, r21, r22
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


.global display_blit_img_15x10
; Inputs: r22 - pixel value, Z(r31, r30) - bitmap address
; Used registers: r17, r19, r20, r21, r22, r23, r24, r25, r26, r30, r31
; Call depth: 4
display_blit_img_15x10:
    ldi r24, 0 ; r24 - y
    ldi r25, 8 ; r25 - bit counter

display_blit_img_15x10_y_loop:
    ldi r23, 0 ; r23 - x
display_blit_img_15x10_x_loop:
    cpi r25, 8  ; Check if all bits in the current byte are read
    brne display_blit_img_15x10_put_pixel
    ldi r25, 0
    ld r26, Z+  ; Fetch the next byte if the current one ended

display_blit_img_15x10_put_pixel:
    sbrs r26, 7
    rjmp display_blit_img_15x10_x_loop_cont
    rcall display_set_pixel

display_blit_img_15x10_x_loop_cont:
    inc r25
    lsl r26
    inc r23
    cpi r23, 15
    brlo display_blit_img_15x10_x_loop

    inc r24
    cpi r24, 10
    brlo display_blit_img_15x10_y_loop

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


.global show_score
; Call depth: 5
show_score:
    rcall display_clear

    lds r17, seq_len
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



.global poll_kb
; Read keyboard
; Checks if a key is pressed by sampling analog signal from the keyboard resistor ladder
; Output: r26 - key id [1..4], or zero if no key is pressed
; Used registers: r16, r17, r20, r26
poll_kb:

    ldi r16, 16
    ldi r19, 0xff
poll_kb_sample_loop:
    sbi ADCSRA, ADSC       ; Sample ADC

poll_kb_adc_wait_loop:
    sbic ADCSRA, ADSC
    rjmp poll_kb_adc_wait_loop
    in r17, ADCL
    cp r19, r17
    brlo poll_kb_sample_loop_cont
    mov r19, r17
    ldi r17, 49
    rcall long_delay


poll_kb_sample_loop_cont:
    dec r16
    brne poll_kb_sample_loop

    cpi r19, 25            ; Check if the resulting value corresponds to one of the keys
    brlo poll_kb_key_1
    cpi r19, 96
    brlo poll_kb_key_2
    cpi r19, 154
    brlo poll_kb_key_3
    cpi r19, 222
    brlo poll_kb_key_4

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
    lds r26, kb_stat
    mov r20, r26
    andi r20, 0x7f
    cp r17, r20              ; Check if the currently pressed key is different from the previously pressed one
    brne poll_kb_key_change
    mov r26, r17
    ret
poll_kb_key_change:
    mov r26, r17
    ori r26, 0x80         ; Set MSB to indicate that it's a diffferent key now
    sts kb_stat, r26
    ret


.global play_tune
; Used registers: r16, r17, r18, r19, r20, r26
; Call depth: 2
play_tune:
    ldi r17, ((1 << COM0B1) | (1 << WGM01))   ; Enable PWM output
    out TCCR0A, r17

    ldi r18, hi8(SPEAKER_PWM_DUTY) 
    ldi r19, lo8(SPEAKER_PWM_DUTY)
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


.global beep
beep:
    ldi r17, ((1 << COM0B1) | (1 << WGM01))
    out TCCR0A, r17
    
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

    inc r17

    sts seed, r17
    ret



.section .text


; 15x10
img_simon:
    .byte 0b00111111
    .byte 0b11111000
    .byte 0b10000010
    .byte 0b00001010
    .byte 0b00000100
    .byte 0b00001100
    .byte 0b00011100
    .byte 0b00011000
    .byte 0b01110100
    .byte 0b00111111
    .byte 0b11111111
    .byte 0b11100000
    .byte 0b11100000
    .byte 0b11000000
    .byte 0b10000001
    .byte 0b01000001
    .byte 0b00000100
    .byte 0b01111111
    .byte 0b11110000


; 15x10
img_simon_lu:
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b01111100
    .byte 0b00000001
    .byte 0b11111000
    .byte 0b00000011
    .byte 0b11100000
    .byte 0b00000111
    .byte 0b10000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000


; 15x10
img_simon_ru:
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000001
    .byte 0b11110000
    .byte 0b00000011
    .byte 0b11110000
    .byte 0b00000011
    .byte 0b11100000
    .byte 0b00000011
    .byte 0b11000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000


; 15x10
img_simon_rb:
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00011111
    .byte 0b00000000
    .byte 0b01111110
    .byte 0b00000000
    .byte 0b11111000
    .byte 0b00000000
    .byte 0b00000000


; 15x10
img_simon_lb:
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00011111
    .byte 0b00000000
    .byte 0b00111111
    .byte 0b00000000
    .byte 0b00111110
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000


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


tune_lu:
    .byte 1
    .byte 6
    .short SPEAKER_PWM(G5)

tune_ru:
    .byte 1
    .byte 6
    .short SPEAKER_PWM(E4)

tune_rb:
    .byte 1
    .byte 6
    .short SPEAKER_PWM(G4)

tune_lb:
    .byte 1
    .byte 6
    .short SPEAKER_PWM(C4)


tune_game_over:
    .byte 3
    .byte 14
    .short SPEAKER_PWM(B4)
    .byte 14
    .short SPEAKER_PWM(F4)
    .byte 40
    .short SPEAKER_PWM(C4)


.section .data
    
seq_len:
    .byte 0x00

seq_seed:
    .byte 0x00

seed:
    .byte 0x00

kb_stat:
    .byte 0x00


.end