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

#define ABS(x) ((x) < 0 ? -(x) : (x))
#define MAX(a, b) ((a) > (b) ? (a) : (b))
#define MIN(a, b) ((a) > (b) ? (b) : (a))

static uint8_t kb_key = 0;
static uint8_t randn = 13;
static uint8_t dbuffer[9] = {0};

static int8_t bpos_x;
static int8_t bpos_y;
static int8_t bdir_x;
static int8_t bdir_y;
static uint8_t bmov_x;
static uint8_t bmov_y;

static int8_t paddles[2] = {2, 3};
static uint8_t endgame = 1;
static uint8_t snd_timer = 0;

// void rng(void)
// {
//     randn = randn ^ (randn << 3);
//     randn = randn ^ (randn >> 1);
//     randn = randn ^ (randn << 5);
// }


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


void beep(void)
{
    snd_timer = 10;
    ICR0 = 16000;
    OCR0B = 500;
}

void delay(void)
{
    for (uint8_t i = 0; i < 10; i++)
    {
        asm("nop;");
    }
}


void clear_buffer(void)
{
    for (uint8_t i = 0; i < sizeof(dbuffer); i++)
    {
        dbuffer[i] = 0;
    }
}

void put_pixel(int8_t x, int8_t y)
{
    if (x < 0 || y < 0 || (x >= 5 && x <= 7))
    {
        return;
    }

    uint8_t bn;

    if (x < 5)
    {
        bn = (6 - y) * 5 + (4 - x);
    }
    else
    {
        bn = 35 + (6 - y) * 5 + (4 - (x - 8));
    }

    dbuffer[bn >> 3] |= 1 << (bn & 7);
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

void process(void)
{
    bmov_x += ABS(bdir_x);
    bmov_y += ABS(bdir_y);


    if (bmov_x >= 128)
    {
        bmov_x = 0;

        if (bdir_x > 0)
        {
            if (bpos_x >= 12)
            {
                bdir_x = -bdir_x;
                bpos_x--;
                beep();
                if ((bpos_y > paddles[1] + 1) || (bpos_y < paddles[1]))
                {
                    endgame = 1;
                }
            }
            else
            {
                bpos_x++;
            }
        }
        else if (bdir_x < 0)
        {
            if (bpos_x <= 0)
            {
                bdir_x = -bdir_x;
                bpos_x++;
                beep();
            }
            else
            {
                bpos_x--;
            }
        }
    }

    if (bmov_y >= 128)
    {
        bmov_y = 0;

        if (bdir_y > 0)
        {
            if (bpos_y >= 6)
            {
                bdir_y = -bdir_y;
                bpos_y--;
            }
            else
            {
                bpos_y++;
            }
        }
        else if (bdir_y < 0)
        {
            if (bpos_y <= 0)
            {
                bdir_y = -bdir_y;
                bpos_y++;
            }
            else
            {
                bpos_y--;
            }
        }
    }
}


int main()
{
    CCP = 0xd8;   /* Write configuration change protection signature - 0xD8*/
    CLKPSR = 0;   /* Set main clock prescaler to 1, resulting frequency is ~8MHz */
    
    ICR0 = 400;
    
    TCCR0A = (1 << COM0B1) | (1 << WGM01);
    TCCR0B = (1 << WGM03) | (1 << WGM02) | (1 << CS00);

    ADMUX  = 0;               /* Enable ADC input channel 0 - PB0 */
    ADCSRA |= (1 << ADEN);    /* Turn on the ADC */
    DIDR0  |= (1 << ADC0D);   /* Disable digital input on PB0 */

    DDRB = DDRB_ALL; /* Set all pins as outputs */

    PORTB = (1 << PORTB2) | (1 << PORTB3);

    OCR0A = 0;
    OCR0B = 50;

    uint8_t prev_kb_key = 0;

    for (;;)
    {
        poll_kb();

        if (kb_key != 0 && prev_kb_key == 0)
        {
            if (kb_key == 1 && paddles[1] > 0)
            {
                paddles[1]--;
            }

            if (kb_key == 2 && paddles[1] < 5)
            {
                paddles[1]++;
            }
        }

        // uint8_t pid = bdir_x > 0 ? 1 : 0;
        uint8_t pid = 0;
        int8_t dy = bpos_y - paddles[pid];

        if (dy < 0)
        {
            paddles[pid] = MAX(0, paddles[pid] - 1);
        }
        else if (dy > 0)
        {
            paddles[pid] = MIN(5, paddles[pid] + 1);
        }

        prev_kb_key = kb_key;

        clear_buffer();

        process();

        if (endgame)
        {
            endgame = 0;
            bpos_x = 1;
            bpos_y = 3;

            bdir_x = 24;
            bdir_y = 8;
            bmov_x = 0;
            bmov_y = 0;
        }

        put_pixel(bpos_x, bpos_y);
        put_pixel(0, paddles[0]);
        put_pixel(0, paddles[0] + 1);
        put_pixel(12, paddles[1]);
        put_pixel(12, paddles[1] + 1);

        draw_buffer();

        if (snd_timer)
        {
            snd_timer--;
            if (!snd_timer)
            {
                ICR0 = 400;
                OCR0B = 50;
            }
        }


        for (uint16_t i = 0; i < 2000; i++)
        {
            delay();
        }
    }
}