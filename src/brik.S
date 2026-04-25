#include <avr/io.h>

#define KEY_NONE   0x00
#define KEY_LEFT   0x02
#define KEY_RIGHT  0x04
#define KEY_DOWN   0x08
#define KEY_ROTATE 0x10

#define SPEAKER_PWM_DUTY 500
#define SPEAKER_PWM(Hz)  (8000000 / (Hz))  ; Min Hz value: 122

#define ADDR_W 0x40
#define ADDR_R 0x41

#define SCL PORTB2
#define SDA PORTB3

#define START_SPEED          42
#define DROP_SPEED           2
#define LEVELUP_N            10
#define LEVELUP_SPEED_CHANGE 3

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

    andi r17, 0x80
    brne main_loop_move_shape
    lds r17, fall_t
    cpi r17, 0
    brne main_loop_cont

main_loop_move_shape:
    rcall move_shape
    lds r16, shape_tx_flags
    andi r16, 0b10
    breq main_loop_cont
; Shape landing 
    rcall beep
    rcall collapse_full_rows
    rcall spawn_shape

; Check if game over
    rcall load_shape
    lds r27, shape_x
    lds r18, shape_y
    ldi r30, lo8(gs(pixel_check))
    ldi r31, hi8(gs(pixel_check))
    rcall process_shape
    brts main_loop_game_over

; Increase speed after LEVELUP_N landed shapes
    lds r16, shape_ctr
    inc r16
    cpi r16, LEVELUP_N
    brlo main_loop_land_cont
    ldi r16, 1
    lds r17, fall_speed_val
    subi r17, LEVELUP_SPEED_CHANGE
    sts fall_speed_val, r17
    sts fall_speed, r17

main_loop_land_cont:
    sts shape_ctr, r16

main_loop_cont:

    lds r16, fall_t
    inc r16
    lds r17, fall_speed
    cp r16, r17
    brlo main_loop_no_fall
    ldi r16, 0

main_loop_no_fall:
    sts fall_t, r16

    ldi r17, 0
    rcall looong_delay

    rjmp main_loop

main_loop_game_over:
    ldi r30, lo8(tune_game_over + 0x4000)
    ldi r31, hi8(tune_game_over + 0x4000)
    rcall play_tune

main_loop_game_over_idle:
    rjmp main_loop_game_over_idle


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
    lds r16, fall_speed_val
    sts fall_speed, r16
    rjmp poll_kb_update

poll_kb_key_1:
    ldi r17, KEY_LEFT
    rjmp poll_kb_update

poll_kb_key_2:
    ldi r17, KEY_DOWN
    rjmp poll_kb_update

poll_kb_key_3:
    ldi r17, KEY_ROTATE
    rjmp poll_kb_update

poll_kb_key_4:
    ldi r17, KEY_RIGHT               
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


.global process_shape
; Inputs:
;   r27 - x position
;   r18 - y position
;   Y(r29, r28) - shape bitmap address
;   Z(r31, r30) - shape processing sub-function address
; Output:
;   T(flag) - T is set if the shape collides/goes off-screen
; Used registers: r16, r17, r18, r19, r20, r21, r22, r23, r24, r25, r26, r27, r28, r29, r30, r31
; Call depth: 5

process_shape:
    mov r24, r18 ; r24 - y
    ldi r25, 8 ; r25 - bit counter

process_shape_y_loop:
    mov r23, r27 ; r23 - x
process_shape_x_loop:
    cpi r25, 8  ; Check if all bits in the current byte are read
    brne process_shape_do_stuff
    ldi r25, 0
    ld r26, Y+  ; Fetch the next byte if the current one ended

process_shape_do_stuff:
    sbrc r26, 7
    icall
    inc r25
    lsl r26
    inc r23
    mov r16, r23
    sub r16, r27
    cpi r16, 4
    brlo process_shape_x_loop

    inc r24
    mov r16, r24
    sub r16, r18
    cpi r16, 4
    brlo process_shape_y_loop

    ret


.global pixel_check
; Checks if a pixel is off-screen or if it's overlapping with a lit pixel on the screen 
; Inputs:
;   r23 - pixel x
;   r24 - pixel y
; Output:
;   T(flag) - T is set if the pixel is off-screen or is overlapping
; Used registers: r16, r17, r19, r20, r21, r22, r23, r24, 25, 26
; Call depth: 4
pixel_check:
    cpi r23, 0
    brmi pixel_check_fail
    cpi r23, 17
    brge pixel_check_fail
    cpi r24, 0
    brmi pixel_check_fail
    cpi r24, 10
    brge pixel_check_fail
    rcall display_get_pixel
    cpi r22, 0
    brne pixel_check_fail
    rjmp pixel_check_ret

pixel_check_fail:
    set
pixel_check_ret:
    ret


.global spawn_shape
spawn_shape:
    ldi r16, 13
    sts shape_x, r16
    ldi r16, 3
    sts shape_y, r16
    
    rcall rand
    andi r17, 0b111
    cpi r17, 7
    brlo spawn_shape_calc_ptr
    dec r17

spawn_shape_calc_ptr:
    mov r16, r17
    lsl r17
    add r17, r16
    sts shape_ptr, r17

    ret


.global load_shape
load_shape:
    ldi r28, lo8(shapes + 0x4000)
    ldi r29, hi8(shapes + 0x4000)
    lds r16, shape_ptr
    add r28, r16
    ldi r16, 0
    adc r29, r16
    ret

.global check_and_restore_shape
check_and_restore_shape:
; Check if the shape is colliding
    rcall load_shape
    ldi r30, lo8(gs(pixel_check))
    ldi r31, hi8(gs(pixel_check))
    rcall process_shape
    ldi r22, 0x15
    brts check_and_restore_shape_restore
    sts shape_x, r27
    sts shape_y, r18    
    ret

check_and_restore_shape_restore:
    clt
    lds r27, shape_x
    lds r18, shape_y
    lds r16, shape_tx_flags
    lds r17, shape_ptr_next
    sbrc r16, 2
    sts shape_ptr, r17
    sbrs r16, 0
    ret
    ldi r16, 0b10
    sts shape_tx_flags, r16
    ldi r22, 0x05
    ret


.global collapse_row
; Input: r25 - row index
; Used register: r16, r17, r19, r20, r21, r22, r23, r24, 25, 26
collapse_row:
    ldi r16, 0  ; Column index 
collapse_row_column_loop:
    
    mov r26, r25  ; r26 - row index    
collapse_row_row_loop:
    mov r23, r26
    inc r23
    mov r24, r16
    rcall display_get_pixel
    mov r23, r26
    rcall display_set_pixel

    inc r26
    cpi r26, 15
    brne collapse_row_row_loop

    inc r16
    cpi r16, 10
    brne collapse_row_column_loop

    ret


.global collapse_full_rows
collapse_full_rows:
    ldi r23, 14                 ; Row index
    
collapse_full_rows_x_loop:
    ldi r24, 0                  ; Column index
collapse_full_rows_y_loop:
    rcall display_get_pixel
    cpi r22, 0
    breq collapse_full_rows_x_loop_cont
    inc r24
    cpi r24, 10
    brne collapse_full_rows_y_loop

    mov r25, r23
    push r23

    ldi r30, lo8(tune_row_collapse + 0x4000)
    ldi r31, hi8(tune_row_collapse + 0x4000)
    rcall play_tune

    rcall collapse_row
    pop r23

collapse_full_rows_x_loop_cont:
    subi r23, 1
    brcc collapse_full_rows_x_loop

    ret


.global move_shape
move_shape:
    lds r27, shape_x
    lds r18, shape_y

; Erase shape
    rcall load_shape
    ldi r30, lo8(gs(display_set_pixel))
    ldi r31, hi8(gs(display_set_pixel))
    ldi r22, 0x00
    sts shape_tx_flags, r22
    rcall process_shape
    ld r16, Y
    sts shape_ptr_next, r16

; Update position from player's input
    lds r17, kb_stat
    cpi r17, (KEY_LEFT | 0x80)
    breq move_shape_key_left
    cpi r17, (KEY_RIGHT | 0x80)
    breq move_shape_key_right
    cpi r17, (KEY_ROTATE | 0x80)
    breq move_shape_key_rotate
    cpi r17, (KEY_DOWN | 0x80)
    breq move_shape_key_down
    lds r17, fall_t
    cpi r17, 0
    breq move_shape_fall

    rjmp move_shape_cont

move_shape_key_left:
    dec r18
    rjmp move_shape_cont

move_shape_key_right:
    inc r18
    rjmp move_shape_cont

move_shape_key_rotate:
    lds r16, shape_tx_flags
    ori r16, 0b100
    sts shape_tx_flags, r16
    lds r16, shape_ptr
    lds r17, shape_ptr_next
    sts shape_ptr, r17
    sts shape_ptr_next, r16
    rjmp move_shape_cont

move_shape_key_down:
    ldi r16, DROP_SPEED
    sts fall_speed, r16
    rjmp move_shape_cont

move_shape_fall:
    dec r27
    ldi r16, 1
    sts shape_tx_flags, r16

move_shape_cont:
    rcall check_and_restore_shape

move_shape_draw_shape:
    rcall load_shape
    ldi r30, lo8(gs(display_set_pixel))
    ldi r31, hi8(gs(display_set_pixel))
    rcall process_shape

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


.global new_game
; Call depth: 1
new_game:
    ldi r16, START_SPEED
    sts fall_speed_val, r16
    sts fall_speed, r16
    ldi r16, 1
    sts shape_ctr, r16
    sts fall_t, r16

    rcall spawn_shape
    ret



.section .text

; Shapes format: 
;   2 bytes bitmap 4x4
;   1 byte offset from 'shapes' to the next rotated variant

shapes:
shape_o:                ; 0
    .byte 0b11001100
    .byte 0b00000000
    .byte 0

shape_t:                ; 3
    .byte 0b11100100
    .byte 0b00000000
    .byte 21

shape_j:                ; 6
    .byte 0b01000100
    .byte 0b11000000
    .byte 30

shape_l:                ; 9
    .byte 0b10001000
    .byte 0b11000000
    .byte 39

shape_z:                ; 12
    .byte 0b11000110
    .byte 0b00000000
    .byte 48

shape_s:                ; 15
    .byte 0b01101100
    .byte 0b00000000
    .byte 51

shape_i:                ; 18
    .byte 0b10001000
    .byte 0b10001000
    .byte 54

shape_t_90:             ; 21
    .byte 0b10001100
    .byte 0b10000000
    .byte 24

shape_t_180:            ; 24
    .byte 0b01001110
    .byte 0b00000000
    .byte 27

shape_t_270:            ; 27
    .byte 0b01001100
    .byte 0b01000000
    .byte 3

shape_j_90:             ; 30
    .byte 0b11100010
    .byte 0b00000000
    .byte 33

shape_j_180:            ; 33
    .byte 0b11001000
    .byte 0b10000000
    .byte 36

shape_j_270:            ; 36
    .byte 0b10001110
    .byte 0b00000000
    .byte 6

shape_l_90:             ; 39
    .byte 0b00101110
    .byte 0b00000000
    .byte 42

shape_l_180:            ; 42
    .byte 0b11000100
    .byte 0b01000000
    .byte 45

shape_l_270:            ; 45
    .byte 0b11101000
    .byte 0b00000000
    .byte 9

shape_z_90:             ; 48
    .byte 0b01001100
    .byte 0b10000000
    .byte 12

shape_s_90:             ; 51
    .byte 0b10001100
    .byte 0b01000000
    .byte 15

shape_i_90:             ; 54
    .byte 0b00001111
    .byte 0b00000000
    .byte 18


tune_beep:
    .byte 1                   ; Number of notes
    
    .byte 4                   ; Duration
    .short SPEAKER_PWM(1200)  ; Frequency


tune_row_collapse:
    .byte 2                   ; Number of notes
    
    .byte 5                   ; Duration
    .short SPEAKER_PWM(900)   ; Frequency

    .byte 5                   ; Duration
    .short SPEAKER_PWM(1500)  ; Frequency


tune_game_over:
    .byte 20                  ; Number of notes
    
    .byte 12
    .short SPEAKER_PWM(E5)
    .byte 6
    .short SPEAKER_PWM(B4)
    .byte 6
    .short SPEAKER_PWM(C5)
    .byte 12
    .short SPEAKER_PWM(D5)
    .byte 6
    .short SPEAKER_PWM(C5)
    .byte 6
    .short SPEAKER_PWM(B4)

    .byte 12
    .short SPEAKER_PWM(A4)
    .byte 6
    .short SPEAKER_PWM(A4)
    .byte 6
    .short SPEAKER_PWM(C5)
    .byte 12
    .short SPEAKER_PWM(E5)
    .byte 6
    .short SPEAKER_PWM(D5)
    .byte 6
    .short SPEAKER_PWM(C5)

    .byte 16
    .short SPEAKER_PWM(B4)
    .byte 6
    .short SPEAKER_PWM(C5)
    .byte 12
    .short SPEAKER_PWM(D5)
    .byte 12
    .short SPEAKER_PWM(E5)

    .byte 12
    .short SPEAKER_PWM(C5)
    .byte 12
    .short SPEAKER_PWM(A4)
    .byte 2
    .short 0x0000
    .byte 12
    .short SPEAKER_PWM(A4)


.section .data

shape_x:
    .byte 0x00

shape_y:
    .byte 0x00

shape_ptr:
    .byte 0x00

shape_ptr_next:
    .byte 0x00

kb_stat:
    .byte 0x00

shape_tx_flags:
    .byte 0x00

fall_t:
    .byte 0x00

fall_speed:
    .byte 0x00

seed:
    .byte 0x00

shape_ctr:
    .byte 0x00

fall_speed_val:
    .byte 0x00
