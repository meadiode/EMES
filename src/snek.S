#include <avr/io.h>

#define KB_REG            r26

#define DIR_UP     0x00
#define DIR_DOWN   0x03
#define DIR_LEFT   0x01
#define DIR_RIGHT  0x02

#define SNEK_MOVE_TIME 128


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
    ;rcall display_clear
    rcall poll_kb
    rcall process_input
    rcall move_snek
    rcall draw_food

    ldi r17, 20
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


.global i2c_read
; Outputs: r22 - read data byte
; Used registers: r17, r19, r21, r22
i2c_read:
    cbi DDRB, SDA
    ldi r22, 0
    ldi r19, 8
i2c_read_loop:
    lsl r22
    cbi DDRB, SCL
    rcall delay
    in r21, PINB
    sbrc r21, 3
    inc r22
    sbi DDRB, SCL
    rcall delay
    dec r19
    brne i2c_read_loop

    ; ACK cycle
    cbi DDRB, SDA
    sbi PORTB, SDA
    rcall delay
    cbi DDRB, SCL
    rcall delay
    sbi DDRB, SCL
    rcall delay
    cbi PORTB, SDA
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


.global display_get_pixel
; inputs: r23 - x; r24 - y
; Outputs: r22 - pixel value
; Used registers: r17, r19, r20, r21, r22, r23, r24
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
display_clear:
    ldi r21, 0
    ldi r22, 0
    
display_clear_write_pwm_val:
    rcall display_write_reg
    inc r21
    cpi r21, (198 + 1)
    brne display_clear_write_pwm_val
    
    ret


.global display_draw_img_15x10
display_draw_img_15x10:
    ldi r24, 0 ; r24 - y
    ldi r25, 8 ; r25 - bit counter

display_draw_img_15x10_y_loop:
    ldi r23, 0 ; r23 - x
display_draw_img_15x10_x_loop:
    cpi r25, 8  ; Check if all bits in the current byte are read
    brne display_draw_img_15x10_put_pixel
    ldi r25, 0
    ld r26, Z+  ; Fetch the next byte if the current one ended

display_draw_img_15x10_put_pixel:
    sbrs r26, 7
    ldi r22, 0
    sbrc r26, 7
    ldi r22, 0x20
    inc r25
    lsl r26
    rcall display_set_pixel
    inc r23
    cpi r23, 15
    brlo display_draw_img_15x10_x_loop

    inc r24
    cpi r24, 10
    brlo display_draw_img_15x10_y_loop

    ret


.global display_read_reg
; Inputs: r21 - register address
; Outputs r22 - register value
; Used registers: r17, r19, r20, r21, r22

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

; Load key-id into KB_REG and return
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


.global beep
beep:
    ldi r17, ((1 << COM0B1) | (1 << WGM01))
    out TCCR0A, r17
    
;    ldi r18, hi8(32000)
;    ldi r17, lo8(32000)
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


.global short_beep
short_beep:
    ldi r19, hi8(8000000 / 1000)
    ldi r18, lo8(8000000 / 1000)
    rcall beep
    ldi r17, 3
    rcall looong_delay
    rcall no_beep
    ret



.global move_snek
move_snek:
    lds r18, move_t
    inc r18
    cpi r18, SNEK_MOVE_TIME
    breq move_snek_cont
    sts move_t, r18
    rjmp move_snek_ret

move_snek_cont:
    ldi r18, 0
    sts move_t, r18

    lds r23, head_x
    lds r24, head_y
    lds r25, hdir

    ldi r22, 0x0
    rcall display_set_pixel
    rcall move_snek_cursor

    sts prev_hdir, r25
    sts head_x, r23
    sts head_y, r24

    ldi r22, 0x20
    rcall display_set_pixel

move_snek_check_food:
    swap r24
    andi r24, 0b11110000
    or r24, r23
    lds r18, food_pos
    cp r18, r24
    brne move_snek_ret

    lds r18, size
    inc r18
    sts size, r18
    
    rcall short_beep
    rcall spawn_food


move_snek_ret:
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
 ; Touched registers: r23, r24
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
process_input:
    sbrs KB_REG, 7
    rjmp process_input_done
    mov r17, KB_REG
    andi r17, 0b111
    cpi r17, 0
    breq process_input_done
    dec r17

    ; check if the new direction is oposite to the current one
    lds r24, prev_hdir
    ldi r19, 3
    sub r19, r24
    cp r17, r19
    breq process_input_done

    sts hdir, r17            ; update direction
process_input_done:
    ret


.global spawn_food
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
draw_food:
    lds r23, food_pos
    mov r24, r23
    swap r24
    andi r23, 0b1111
    andi r24, 0b1111

    ldi r22, 0x40
    rcall display_set_pixel
    ret


.global rand
; Get a very pseudo random value
; Outputs: r17 - random value [0..255]
; Used registers: r17, r18
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
new_game:
    ldi r16, (SNEK_MOVE_TIME - 1)
    sts move_t, r16

    ldi r16, 4
    sts head_x, r16
    sts head_y, r16

    ldi r16, DIR_RIGHT
    sts hdir, r16
    sts prev_hdir, r16

    rcall move_snek
    rcall spawn_food

    ret



.section .text

; 15x10
img_star:
    .byte 0b00000001
    .byte 0b00000000
    .byte 0b00000111
    .byte 0b00000000
    .byte 0b00001010
    .byte 0b00000000
    .byte 0b00110110
    .byte 0b00000111
    .byte 0b11000111
    .byte 0b11000110
    .byte 0b00000011
    .byte 0b00000010
    .byte 0b00001000
    .byte 0b00000101
    .byte 0b11010000
    .byte 0b00011110
    .byte 0b11110000
    .byte 0b00110000
    .byte 0b01100000


; 15x10
img_club:
    .byte 0b11111100
    .byte 0b01111111
    .byte 0b11110000
    .byte 0b01111111
    .byte 0b11110001
    .byte 0b11111111
    .byte 0b10110110
    .byte 0b11111110
    .byte 0b00101000
    .byte 0b11111000
    .byte 0b00000000
    .byte 0b11111000
    .byte 0b10100011
    .byte 0b11111011
    .byte 0b01101111
    .byte 0b11111110
    .byte 0b11111111
    .byte 0b11111000
    .byte 0b11111100


; 15x10
img_diamond:
    .byte 0b00000001
    .byte 0b00000000
    .byte 0b00000111
    .byte 0b00000000
    .byte 0b00011101
    .byte 0b00000000
    .byte 0b01111101
    .byte 0b00000001
    .byte 0b11111111
    .byte 0b00000001
    .byte 0b11111100
    .byte 0b00000001
    .byte 0b11110000
    .byte 0b00000001
    .byte 0b11000000
    .byte 0b00000001
    .byte 0b00000000
    .byte 0b00000000
    .byte 0b00000000

; 15x10
img_heart:
    .byte 0b00001100
    .byte 0b01100000
    .byte 0b00111101
    .byte 0b11100000
    .byte 0b11111111
    .byte 0b00100001
    .byte 0b11111111
    .byte 0b01000011
    .byte 0b11111111
    .byte 0b10000011
    .byte 0b11111110
    .byte 0b00000011
    .byte 0b11111000
    .byte 0b00000011
    .byte 0b11100000
    .byte 0b00000011
    .byte 0b10000000
    .byte 0b00000010
    .byte 0b00000000


; 15x10
img_spade:
    .byte 0b11111110
    .byte 0b11111111
    .byte 0b11111000
    .byte 0b11111111
    .byte 0b11100000
    .byte 0b11111111
    .byte 0b10000000
    .byte 0b11111110
    .byte 0b00000000
    .byte 0b11111100
    .byte 0b00000001
    .byte 0b11111100
    .byte 0b10100111
    .byte 0b11111111
    .byte 0b01111111
    .byte 0b11111100
    .byte 0b01111111
    .byte 0b11110000
    .byte 0b01111100


; 15x10
img_emes:
    .byte 0b11000000
    .byte 0b01100111
    .byte 0b00010100
    .byte 0b10010011
    .byte 0b01010101
    .byte 0b10111100
    .byte 0b10101010
    .byte 0b00011101
    .byte 0b00010110
    .byte 0b11000000
    .byte 0b00000000
    .byte 0b00000110
    .byte 0b00001100
    .byte 0b00000100
    .byte 0b00101000
    .byte 0b00001000
    .byte 0b01010000
    .byte 0b00111010
    .byte 0b11000000


.section .data

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
    .zero 12

; Bytes used: 20
; Max stack depth: 6 

.end