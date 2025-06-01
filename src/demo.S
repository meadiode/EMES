#include <avr/io.h>

#define ZERO_REG          r16
#define BEEP_REG          r25
#define KB_REG            r26

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

    ldi r17, 0b0011
    out DDRB, r17                                            ; Set B0 & B1 as outputs

    ldi r17, ((1 << WGM03) | (1 << WGM02) | (1 << CS00))     ; Set up timer's fast PWM mode
    out TCCR0B, r17


main_loop:
    sbi DDRB, PORTB2
    rcall no_beep
    ldi r17, 40
    rcall looong_delay

    cbi DDRB, PORTB2
    rcall beep
    ldi r17, 16
    rcall looong_delay    

    rjmp main_loop


.global delay
delay:
    ldi r17, 4
    subi r17, 1
    brcs delay_ret
    rjmp delay
delay_ret:
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


.global display_write
; Inputs: r17, r18

display_write:
    cbi DDRB, PORTB2
    cbi DDRB, PORTB3
    rcall delay
    sbi DDRB, PORTB3
    rcall delay

    ldi r19, 8
display_write_loop:
    lsl r17
    brcc display_write_sda_0
    sbi DDRB, PORTB3
    rjmp display_write_loop_cont
display_write_sda_0:
    cbi DDRB, PORTB3




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


.global beep
beep:
    ldi r17, ((1 << COM0B1) | (1 << WGM01))
    out TCCR0A, r17
    
    ldi r18, hi8(32000)
    ldi r17, lo8(32000)
    out ICR0H, r18
    out ICR0L, r17

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


.global process_input
process_input:
    sbrs KB_REG, 7
    rjmp process_input_done
    nop
    nop
    nop
process_input_done:
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
    ldi r19, 5
lshift_seed_x5:
    lsl r18
    subi r19, 1
    brne lshift_seed_x5

    eor r17, r18

    sts seed, r17
    ret


.global init
init:

;    ldi r17, 42
;    sts seed, r17
    ret


.section .text

symbol_1:
    .byte 0b00000000
    .byte 0b00010000
    .byte 0b00010101
    .byte 0b00010101
    .byte 0b00000001

symbol_2:
    .byte 0b00111111
    .byte 0b11000110
    .byte 0b00011000
    .byte 0b00111111
    .byte 0b00000000

symbol_3:
    .byte 0b00000000
    .byte 0b00010000
    .byte 0b11110010
    .byte 0b00001001
    .byte 0b00000001

symbol_4:
    .byte 0b00101110
    .byte 0b11010110
    .byte 0b11101000
    .byte 0b00000000
    .byte 0b00000000

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


gstate:
    .byte 0x00
seed:
    .byte 0x00
start_seed:
    .byte 0x00
seq_length:
    .byte 0x00


.end