#include <avr/io.h>

#define KEY_NONE  0x00
#define KEY_LUP   0x02
#define KEY_LDOWN 0x04
#define KEY_RUP   0x08
#define KEY_RDOWN 0x10

#define WOLF_LEFT_UP     (19 * 0)
#define WOLF_LEFT_DOWN   (19 * 1)
#define WOLF_RIGHT_UP    (19 * 2)
#define WOLF_RIGHT_DOWN  (19 * 3)


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
    rcall poll_kb
    rcall update_wolf
    rcall update_chutes
    rcall draw_chutes

    ldi r17, 39
    rcall long_delay

    rjmp main_loop


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


.global poll_kb
; Read keyboard
; Checks if a key is pressed by sampling analog signal from the keyboard resistor ladder
; Output: r17/kb_stat - key id [1..4], or zero if no key is pressed
; Touched registers: r17, r20, r21, r22
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

; Load key-id into r17
poll_kb_key_none:
    ldi r17, KEY_NONE
    ldi r16, 40
    rjmp poll_kb_update

poll_kb_key_1:
    ldi r17, KEY_LDOWN
    rjmp poll_kb_update

poll_kb_key_2:
    ldi r17, KEY_LUP
    rjmp poll_kb_update

poll_kb_key_3:
    ldi r17, KEY_RDOWN
    rjmp poll_kb_update

poll_kb_key_4:
    ldi r17, KEY_RUP               
    rjmp poll_kb_update


poll_kb_update:
    lds r20, kb_stat
    andi r20, 0x7f
    cp r17, r20              ; Check if the currently pressed key is different from the previously pressed one
    brne poll_kb_key_change
    sts kb_stat, r17
    ret
poll_kb_key_change:
    ori r17, 0x80         ; Set MSB to indicate that it's a different key now
    sts kb_stat, r17
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


.global beep
beep:
    ldi r30, lo8(tune_beep + 0x4000)
    ldi r31, hi8(tune_beep + 0x4000)
    rcall play_tune

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


.global update_wolf
update_wolf:
    ;lds r17, kb_stat
    sbrs r17, 7                ; Check if key-down
    rjmp update_wolf_ret

    cpi r17, (KEY_LUP | 0x80)
    breq update_wolf_left_up
    cpi r17, (KEY_LDOWN | 0x80)
    breq update_wolf_left_down
    cpi r17, (KEY_RUP | 0x80)
    breq update_wolf_right_up
    cpi r17, (KEY_RDOWN | 0x80)
    breq update_wolf_right_down
    rjmp update_wolf_ret

update_wolf_left_up:
    ldi r27, WOLF_LEFT_UP
    rjmp update_wolf_draw

update_wolf_left_down:
    ldi r27, WOLF_LEFT_DOWN
    rjmp update_wolf_draw

update_wolf_right_up:
    ldi r27, WOLF_RIGHT_UP
    rjmp update_wolf_draw

update_wolf_right_down:
    ldi r27, WOLF_RIGHT_DOWN

update_wolf_draw:
    ldi r30, lo8(img_wolf_ld + 0x4000)
    ldi r31, hi8(img_wolf_ld + 0x4000)
    lds r16, wolf_pos
    add r30, r16
    ldi r16, 0
    adc r31, r16
    ldi r22, 0
    rcall display_blit_img_15x10  ; Erase previous wolf sprite

    ldi r30, lo8(img_wolf_ld + 0x4000)
    ldi r31, hi8(img_wolf_ld + 0x4000)
    add r30, r27
    ldi r16, 0
    adc r31, r16
    ldi r22, 0x20
    rcall display_blit_img_15x10 ; Draw wolf sprite

    sts wolf_pos, r27

update_wolf_ret:
    ret


.global update_chutes
update_chutes:

    ldi r28, lo8(chutes)     ; Y - chute state address
    ldi r29, hi8(chutes)

    ldi r30, lo8(chutes_t)   ; Z - chute timer address
    ldi r31, hi8(chutes_t)

    ldi r16, 4               ; r16 - chute index
update_chutes_loop:
    ld r19, Y
    ld r20, Z
    inc r20
    st Z+, r20
    brne update_chutes_loop_cont  ; If a chute's timer didn't roll over, go to the next chute
                                  ; Else, move the eggs and spawn a new one (or not)
    lsr r19

; check if the egg is catched or dropped here 
    
    sbrc r19, 6
    rjmp update_chutes_loop_cont  ; Skip if an egg was spawned previously
    
    lds r21, prob
    rcall rand
    cp r21, r17
    brlo update_chutes_loop_cont
    ori r19, 0b10000000           ; Egg spawned

update_chutes_loop_cont:
    st Y+, r19
    dec r16
    brne update_chutes_loop
    ret


.global draw_chutes
; Used registers: r17, r19, r20, r21, r22, r23, r24
draw_chutes:
    ldi r28, lo8(chutes)
    ldi r29, hi8(chutes)
    ldi r30, lo8(chute_paths + 0x4000)
    ldi r31, hi8(chute_paths + 0x4000)

    ldi r16, 4
draw_chutes_loop:
    ld r25, Y+
    ldi r18, 5
draw_chutes_chute_loop:
    ld r23, Z+
    mov r24, r23
    swap r24
    andi r23, 0b1111
    andi r24, 0b1111
    ldi r22, 0x00
    lsr r25
    brcc draw_chutes_chute_loop_draw_egg
    ldi r22, 0x10

draw_chutes_chute_loop_draw_egg:
    rcall display_set_pixel

    dec r18
    brne draw_chutes_chute_loop
    
    dec r16
    brne draw_chutes_loop

    ret



.global new_game
; Call depth: 1
new_game:
    ldi r28, lo8(chutes)     ; Y - chute state address
    ldi r29, hi8(chutes)
    ldi r30, lo8(chutes_t)   ; Z - chute timer address
    ldi r31, hi8(chutes_t)
    ldi r19, 0

    ldi r16, 4
new_game_init_loop:
    st Y+, r19
    rcall rand
    st Z+, r17
    dec r16
    brne new_game_init_loop

    sts score, r19
    ldi r16, 24
    sts prob, r16
    ldi r16, 3
    sts lives, r16

    ret



.section .text

tune_beep:
    .byte 1                   ; Number of notes
    
    .byte 4                   ; Duration
    .short SPEAKER_PWM(1200)  ; Frequency


; 15x10
img_wolf_ld:
    .byte 0b00000011
    .byte 0b00000000
    .byte 0b00001110
    .byte 0b10000000
    .byte 0b00001101
    .byte 0b00000000
    .byte 0b00001010
    .byte 0b00000000
    .byte 0b00111000
    .byte 0b00000000
    .byte 0b10100000
    .byte 0b00000110
    .byte 0b01000000
    .byte 0b00000001
    .byte 0b10000000
    .byte 0b00000101
    .byte 0b00000000
    .byte 0b00011011
    .byte 0b00000000


; 15x10
img_wolf_lu:
    .byte 0b00000011
    .byte 0b00000000
    .byte 0b00001110
    .byte 0b00000000
    .byte 0b00001100
    .byte 0b00000000
    .byte 0b01001000
    .byte 0b00000000
    .byte 0b01111000
    .byte 0b00000000
    .byte 0b00101000
    .byte 0b00000000
    .byte 0b01010000
    .byte 0b00000001
    .byte 0b10000000
    .byte 0b00000010
    .byte 0b10000000
    .byte 0b00001101
    .byte 0b10000000


; 15x10
img_wolf_rd:
    .byte 0b00000001
    .byte 0b10000000
    .byte 0b00001011
    .byte 0b10000000
    .byte 0b00010110
    .byte 0b00000000
    .byte 0b00101000
    .byte 0b00000000
    .byte 0b00111000
    .byte 0b00000000
    .byte 0b00101000
    .byte 0b00000000
    .byte 0b01001100
    .byte 0b00000000
    .byte 0b11000000
    .byte 0b00000010
    .byte 0b10000000
    .byte 0b00000111
    .byte 0b10000000


; 15x10
img_wolf_ru:
    .byte 0b00000001
    .byte 0b10000000
    .byte 0b00000011
    .byte 0b10000000
    .byte 0b00000110
    .byte 0b00000000
    .byte 0b00001001
    .byte 0b00000000
    .byte 0b00111100
    .byte 0b00000000
    .byte 0b10100000
    .byte 0b00000001
    .byte 0b01000000
    .byte 0b00000000
    .byte 0b11000000
    .byte 0b00000010
    .byte 0b10000000
    .byte 0b00001101
    .byte 0b10000000


; Egg chutes path points - packed as [(y << 4) | x]
chute_paths:
chute_path_lu:
    .byte ((2 << 4) | 3)
    .byte ((2 << 4) | 2)
    .byte ((1 << 4) | 2)
    .byte ((1 << 4) | 1)
    .byte ((0 << 4) | 0)

chute_path_ld:
    .byte ((6 << 4) | 3)
    .byte ((6 << 4) | 2)
    .byte ((5 << 4) | 2)
    .byte ((5 << 4) | 1)
    .byte ((4 << 4) | 0)

chute_path_ru:
    .byte ((2 << 4) | 11)
    .byte ((2 << 4) | 12)
    .byte ((1 << 4) | 12)
    .byte ((1 << 4) | 13)
    .byte ((0 << 4) | 14)

chute_path_rd:
    .byte ((6 << 4) | 11)
    .byte ((6 << 4) | 12)
    .byte ((5 << 4) | 12)
    .byte ((5 << 4) | 13)
    .byte ((4 << 4) | 14)


.section .data

kb_stat:
    .byte 0x00

wolf_pos:
    .byte 0x00

prob:
    .byte 0x00

speed:
    .byte 0x00

score:
    .byte 0x00

lives:
    .byte 0x00

chutes:

chute_lu:
    .byte 0x00
chute_ld:
    .byte 0x00
chute_ru:
    .byte 0x00
chute_rd:
    .byte 0x00


chutes_t:

chute_lu_t:
    .byte 0x00
chute_ld_t:
    .byte 0x00
chute_ru_t:
    .byte 0x00
chute_rd_t:
    .byte 0x00


seed:
    .byte 0x00
