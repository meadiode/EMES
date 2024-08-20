#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdlib.h>
#include <stdbool.h>

void main_loop(void);


#define BLINK_PIN 2

int main()
{
    CCP = 0xd8;   /* Write configuration change protection signature - 0xD8*/
    CLKPSR = 0;   /* Set main clock prescaler to 1, resulting frequency is ~8MHz */

    DDRB |= (1 << DDB0) | (1 << DDB1);
    
    ICR0 = 40000;
    
    TCCR0A = (1 << COM0B1) | (1 << WGM01);
    TCCR0A |= (1 << COM0A1);

    TCCR0B = (1 << WGM03) | (1 << WGM02) | (1 << CS00);

    ADMUX  |= (1 << MUX1);
    ADCSRA |= (1 << ADEN);
    DIDR0  |= (1 << ADC2D);

    OCR0A = 0;
    OCR0B = 1;

    for (;;)
    {

        ADCSRA |= (1 << ADSC);

        while (ADCSRA & (1 << ADSC))
        {
            asm("nop;");
        }

        uint8_t val = ADCL;

        if (40 <= val && val <= 44)
        {
            OCR0B = 64u;

            ICR0 = 40000;
            OCR0A = 512;
        }
        else
        if (53 <= val && val <= 60)
        {
            OCR0B = 128u;
        
            ICR0 = 20000;
            OCR0A = 512;
        }
        else
        if (61 <= val && val <= 69)
        {
            OCR0B = 192u;
        
            ICR0 = 10000;
            OCR0A = 512;
        }
        else
        if (74 <= val && val <= 82)
        {
            ICR0 = 5000;
            OCR0A = 512;

            OCR0B = 255u;
        }
        else
        {
            ICR0 = 200;
            OCR0B = 0u;
            OCR0A = 100u;
        }

        // asm("nop;");


        // PORTB = 4;

        // for (uint16_t i = 0; i < 2000; i++)
        // {
            // asm("nop;");
        // }

        // PORTB = 0;
        
        // for (uint16_t i = 0; i < 8000; i++)
        // {
            // asm("nop;");
        // }
    }
}


void main_loop(void)
{

}
