#include <avr/io.h>

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


    ldi r16, 0
    sts kb_stat, r16

    ldi r30, lo8(pipes)
    ldi r31, hi8(pipes)
    ldi r16, 1
    st Z+, r16
    ldi r16, 6
    st Z+, r16
    ldi r16, 1
    st Z+, r16
    ldi r16, 2
    sts x_offset, r16
    ldi r16, 0
    sts scroll_t, r16

main_loop:
    lds r16, scroll_t
    inc r16
    sts scroll_t, r16
    cpi r16, 40
    breq main_update_scroll
    rjmp main_loop_cont

main_update_scroll:
    clr r16
    sts scroll_t, r16
    lds r16, x_offset
    inc r16
    sts x_offset, r16
    cpi r16, 8
    breq main_update_pipes
    rjmp main_loop_cont

main_update_pipes:
    clr r16
    sts x_offset, r16
    rcall spawn_pipe

main_loop_cont:
    rcall display_clear
    rcall draw_pipes

    rjmp main_loop


.global draw_pipes
; Used registers: r16, r17, r19, r20, r21, r22, r23, r24, r25, r26, r27, r30, r31
draw_pipes:
    ldi r30, lo8(pipes)
    ldi r31, hi8(pipes)
    ldi r22, 40

    clr r16  ; r16 - pipe index
    lds r25, x_offset
    clr r23
    sub r23, r25

draw_pipes_x_loop:
    ld r26, Z+
    clr r24

draw_pipes_y_loop:
    cp r24, r26
    brge draw_pipes_y_loop_check2
    rjmp draw_pipes_y_loop_draw
draw_pipes_y_loop_check2:
    mov r27, r26
    subi r27, -3
    cp r24, r27
    brge draw_pipes_y_loop_draw
    rjmp draw_pipes_y_loop_cont

draw_pipes_y_loop_draw:
    rcall display_set_pixel
    inc r23
    rcall display_set_pixel
    dec r23

draw_pipes_y_loop_cont:
    inc r24
    cpi r24, 10
    brge draw_pipes_y_loop_end

    rjmp draw_pipes_y_loop

draw_pipes_y_loop_end:
    inc r16
    cpi r16, 3
    brge draw_pipes_ret
    subi r23, -8

    rjmp draw_pipes_x_loop

draw_pipes_ret:
    ret


.global spawn_pipe
spawn_pipe:
    ldi r30, lo8(pipes)
    ldi r31, hi8(pipes)

    ld r20, Z+
    ld r20, Z+
    ld r21, Z
    ldi r30, lo8(pipes)
    ldi r31, hi8(pipes)
    st Z+, r20
    st Z+, r21

    rcall rand
    andi r17, 0b111
    breq spawn_pipe_c1
    cpi r17, 7
    brlo spawn_pipe_store_vpos
    ldi r17, 6
    rjmp spawn_pipe_store_vpos
spawn_pipe_c1:
    ldi r17, 1

spawn_pipe_store_vpos:
    st Z, r17
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
    tst r23                     ; x,y screen bound checks
    brmi display_set_pixel_ret
    cpi r23, 15
    brge display_set_pixel_ret
    tst r24
    brmi display_set_pixel_ret
    cpi r24, 10
    brge display_set_pixel_ret

    mov r21, r24    ; Calculate PWM register id as [y * 18 + x + 1]
    swap r21        ; Multiply y by 18
    add r21, r24
    add r21, r24
    add r21, r23    ; Adding x
    inc r21         ; Adding 1
    rcall display_write_reg

display_set_pixel_ret:
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


.global poll_kb
; Read keyboard
; Checks if a key is pressed by sampling analog signal from the keyboard resistor ladder
; Output: r26 - 1 if a key is pressed
; Used registers: r16, r17, r20, r26
poll_kb:

    ldi r16, 4
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
    ldi r17, 2
    rcall long_delay

poll_kb_sample_loop_cont:
    dec r16
    brne poll_kb_sample_loop

    cpi r19, 222
    brlo poll_kb_key

poll_kb_key_none:
    ldi r17, 0                       ; No key is pressed 
    rjmp poll_kb_update_r26

poll_kb_key:
    ldi r17, 1
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


tune_game_over:
    .byte 3
    .byte 14
    .short SPEAKER_PWM(B4)
    .byte 14
    .short SPEAKER_PWM(F4)
    .byte 40
    .short SPEAKER_PWM(C4)


.section .data
    

seed:
    .byte 0x00

kb_stat:
    .byte 0x00

x_offset:
    .byte 0x00

scroll_t:
    .byte 0x00

birb_y:
    .byte 0x00

birb_flap_t:
    .byte 0x00

birb_a:
    .byte 0x00

pipes:
    .zero 3


.end