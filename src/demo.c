#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdlib.h>
#include <stdbool.h>


/* B0: DISP_DATA, KEYBOARD */
/* B1: DISP_BR, BUZZER */
/* B2: DISP_CLK0 */
/* B3: DISP_CLK1 */


#define DDRB_ALL  0b00001111
#define DDRB_ADC  0b00001110

typedef union
{
    struct
    {
        uint8_t c0r6:5;
        uint8_t c0r5:5;
        uint8_t c0r4:5;
        uint8_t c0r3:5;
        uint8_t c0r2:5;
        uint8_t c0r1:5;
        uint8_t c0r0:5;

        uint8_t c1r6:5;
        uint8_t c1r5:5;
        uint8_t c1r4:5;
        uint8_t c1r3:5;
        uint8_t c1r2:5;
        uint8_t c1r1:5;
        uint8_t c1r0:5;

        uint8_t pad:2;

    } pixels;

    uint8_t bytes[9];  

} dbuf_t;

static const dbuf_t disp_up __attribute__((progmem)) = {
    .pixels.c0r0 = 0b10001,
    .pixels.c0r1 = 0b10001,
    .pixels.c0r2 = 0b10001,
    .pixels.c0r3 = 0b10001,
    .pixels.c0r4 = 0b10001,
    .pixels.c0r5 = 0b10001,
    .pixels.c0r6 = 0b01110,

    .pixels.c1r0 = 0b11110,
    .pixels.c1r1 = 0b10001,
    .pixels.c1r2 = 0b10001,
    .pixels.c1r3 = 0b11110,
    .pixels.c1r4 = 0b10000,
    .pixels.c1r5 = 0b10000,
    .pixels.c1r6 = 0b10000,

    .pixels.pad = 0b00,
};

static const dbuf_t disp_dn __attribute__((progmem)) = {
    .pixels.c0r0 = 0b11110,
    .pixels.c0r1 = 0b10001,
    .pixels.c0r2 = 0b10001,
    .pixels.c0r3 = 0b10001,
    .pixels.c0r4 = 0b10001,
    .pixels.c0r5 = 0b10001,
    .pixels.c0r6 = 0b11110,

    .pixels.c1r0 = 0b10001,
    .pixels.c1r1 = 0b10001,
    .pixels.c1r2 = 0b11001,
    .pixels.c1r3 = 0b10101,
    .pixels.c1r4 = 0b10011,
    .pixels.c1r5 = 0b10001,
    .pixels.c1r6 = 0b10001,

    .pixels.pad = 0b00,
};


static const dbuf_t disp_lf __attribute__((progmem)) = {
    .pixels.c0r0 = 0b10000,
    .pixels.c0r1 = 0b10000,
    .pixels.c0r2 = 0b10000,
    .pixels.c0r3 = 0b10000,
    .pixels.c0r4 = 0b10000,
    .pixels.c0r5 = 0b10000,
    .pixels.c0r6 = 0b11111,

    .pixels.c1r0 = 0b11111,
    .pixels.c1r1 = 0b10000,
    .pixels.c1r2 = 0b10000,
    .pixels.c1r3 = 0b11100,
    .pixels.c1r4 = 0b10000,
    .pixels.c1r5 = 0b10000,
    .pixels.c1r6 = 0b10000,

    .pixels.pad = 0b00,
};

static const dbuf_t disp_rt __attribute__((progmem)) = {
    .pixels.c0r0 = 0b11110,
    .pixels.c0r1 = 0b10001,
    .pixels.c0r2 = 0b10001,
    .pixels.c0r3 = 0b11110,
    .pixels.c0r4 = 0b10010,
    .pixels.c0r5 = 0b10001,
    .pixels.c0r6 = 0b10001,

    .pixels.c1r0 = 0b11111,
    .pixels.c1r1 = 0b00100,
    .pixels.c1r2 = 0b00100,
    .pixels.c1r3 = 0b00100,
    .pixels.c1r4 = 0b00100,
    .pixels.c1r5 = 0b00100,
    .pixels.c1r6 = 0b00100,

    .pixels.pad = 0b00,
};

static const dbuf_t disp_no __attribute__((progmem)) = {
    .pixels.c0r0 = 0b00000,
    .pixels.c0r1 = 0b00000,
    .pixels.c0r2 = 0b01010,
    .pixels.c0r3 = 0b00100,
    .pixels.c0r4 = 0b01010,
    .pixels.c0r5 = 0b00000,
    .pixels.c0r6 = 0b00000,

    .pixels.c1r0 = 0b00000,
    .pixels.c1r1 = 0b00000,
    .pixels.c1r2 = 0b00100,
    .pixels.c1r3 = 0b01110,
    .pixels.c1r4 = 0b00100,
    .pixels.c1r5 = 0b00000,
    .pixels.c1r6 = 0b00000,

    .pixels.pad = 0b00,
};


static uint8_t kb_key = 0;
static uint8_t dbuffer[9] = {0x3f, 0xc6, 0x18, 0xe3, 0x8f, 0x51, 0x11, 0x15, 0x23};


void poll_kb(void)
{
    uint16_t samples = 0u;

    DDRB = DDRB_ADC;
    
    for (uint8_t i = 0; i < 4; i++)
    {
        ADCSRA |= (1 << ADSC); /* Start ADC conversion */

        while (ADCSRA & (1 << ADSC)) /* Wait till the conversion is ready */
        {
            asm("nop;");
        }

        samples += ADCL;
    }

    samples = samples / 4;


    if (40 <= samples && samples <= 44)
    {
        kb_key = 1;
    }
    else
    if (53 <= samples && samples <= 60)
    {
        kb_key = 2;
    }
    else
    if (61 <= samples && samples <= 69)
    {
        kb_key = 3;
    }
    else
    if (74 <= samples && samples <= 82)
    {
        kb_key = 4;
    }
    else
    {
        kb_key = 0;
    }

    DDRB = DDRB_ALL;
}

static inline void delay(void)
{
    for (uint8_t i = 0; i < 10; i++)
    {
        asm("nop;");
    }
}

void draw_buffer(void)
{
    PORTB |= (1 << PORTB0);
    PORTB &= ~(1 << PORTB3) & 0x0f;
    delay();
    PORTB |= (1 << PORTB3);
    delay();

    for (uint8_t i = 0; i < 35; i++)
    {
        uint8_t bit = (dbuffer[i >> 3] >> (i & 0b111)) & 0x01;
        
        if (bit)
        {
            PORTB |= (1 << PORTB0);
        }
        else
        {
            PORTB &= ~(1 << PORTB0) & 0x0f;
        }

        PORTB &= ~(1 << PORTB3) & 0x0f;
        delay();
        PORTB |= (1 << PORTB3);
        delay();
    }

    PORTB |= (1 << PORTB0);
    PORTB &= ~(1 << PORTB2) & 0x0f;
    delay();
    PORTB |= (1 << PORTB2);
    delay();

    for (uint8_t i = 35; i < 70; i++)
    {
        uint8_t bit = (dbuffer[i >> 3] >> (i & 0b111)) & 0x01;
        
        if (bit)
        {
            PORTB |= (1 << PORTB0);
        }
        else
        {
            PORTB &= ~(1 << PORTB0) & 0x0f;
        }

        PORTB &= ~(1 << PORTB2) & 0x0f;
        delay();
        PORTB |= (1 << PORTB2);
        delay();
    }

}


void display_key(void)
{
    static uint8_t prev_key = 0xff;

    if (kb_key != prev_key)
    {
        prev_key = kb_key;
        const dbuf_t *syms = NULL;

        switch (kb_key)
        {
        case 1:
            ICR0 = 40000;
            OCR0B = 1250;
            syms = &disp_up;
            break;
        case 2:
            ICR0 = 16000;
            OCR0B = 500;
            syms = &disp_dn;
            break;
        case 3:
            ICR0 = 8000;
            OCR0B = 250;
            syms = &disp_lf;
            break;
        case 4:
            ICR0 = 5333;
            OCR0B = 166;
            syms = &disp_rt;
            break;
        default:
            ICR0 = 400;
            OCR0B = 50;
            syms = &disp_no;
            break;
        }

        for (uint8_t i = 0; i < sizeof(dbuffer); i++)
        {
            dbuffer[i] = syms->bytes[i];
        }
    }
}


int main()
{
    CCP = 0xd8;   /* Write configuration change protection signature - 0xD8*/
    CLKPSR = 0;   /* Set main clock prescaler to 1, resulting frequency is ~8MHz */
    
    ICR0 = 160;
    
    TCCR0A = (1 << COM0B1) | (1 << WGM01);
    TCCR0B = (1 << WGM03) | (1 << WGM02) | (1 << CS00);

    ADMUX  = 0;               /* Enable ADC input channel 0 - PB0 */
    ADCSRA |= (1 << ADEN);    /* Turn on the ADC */
    DIDR0  |= (1 << ADC0D);   /* Disable digital input on PB0 */

    DDRB = DDRB_ALL; /* Set all pins as outputs */

    PORTB = (1 << PORTB2) | (1 << PORTB3);

    OCR0A = 0;
    OCR0B = 16;

    for (;;)
    {
        poll_kb();

        display_key();

        draw_buffer();

        for (uint16_t i = 0; i < 1000; i++)
        {
            asm("nop;");
        }
    }
}
