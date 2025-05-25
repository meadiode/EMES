
#include <pico/stdlib.h>
#include <hardware/gpio.h>
#include <hardware/pwm.h>
#include <hardware/i2c.h>
#include <stdio.h>
#include <string.h>

#define PIN_SDB 15
#define PIN_SDA 16
#define PIN_SCL 17

#define ADDR (0b01000000 >> 1)

#include "badapple.h"

void is31_set_reg_page(uint8_t page_id)
{
    uint8_t data[2];

    /* Unlock the page-select register */
    data[0] = 0xfe;
    data[1] = 0xc5;
    i2c_write_blocking(i2c0, ADDR, data, 2, false);

    /* select page */
    data[0] = 0xfd;
    data[1] = page_id;
    i2c_write_blocking(i2c0, ADDR, data, 2, false);
}

void is31_init(void)
{
    uint8_t data[2];

    /* HW reset */
    gpio_put(PIN_SDB, false);
    sleep_ms(100);
    gpio_put(PIN_SDB, true);

    is31_set_reg_page(2);

    /* Configuration register */
    data[0] = 0x00;
    data[1] = 0x01;
    i2c_write_blocking(i2c0, ADDR, data, 2, false);

    /* Global Current Control register */
    data[0] = 0x01;
    data[1] = 0x10;
    i2c_write_blocking(i2c0, ADDR, data, 2, false);

    /* Pull up/down register config register */
    data[0] = 0x01;
    data[1] = 0x70;
    i2c_write_blocking(i2c0, ADDR, data, 2, false);


    is31_set_reg_page(1);

    /* Write scalling values */
    for (uint8_t i = 1; i <= 198; i++)
    {
        data[0] = i;
        data[1] = 0xff;

        i2c_write_blocking(i2c0, ADDR, data, 2, false);
    }

    is31_set_reg_page(0);

    /* Write PWMs */
    for (uint8_t i = 1; i <= 198; i++)
    {
        data[0] = i;
        data[1] = 0x00;

        i2c_write_blocking(i2c0, ADDR, data, 2, false);
    }
}


void is31_set_pixel(uint8_t x, uint8_t y, uint8_t val)
{
    uint8_t data[2];

    data[0] = 1 + y * 18 + x; /* PWM reg id */
    data[1] = val;

    i2c_write_blocking(i2c0, ADDR, data, 2, false);
}


int main(void)
{
    stdio_init_all();

    gpio_init(PIN_SDB);
    gpio_init(PIN_SDA);
    gpio_init(PIN_SCL);

    i2c_init(i2c0, 400 * 1000);
    gpio_set_function(PIN_SDA, GPIO_FUNC_I2C);
    gpio_set_function(PIN_SCL, GPIO_FUNC_I2C);
    gpio_pull_up(PIN_SDA);
    gpio_pull_up(PIN_SCL);

    gpio_set_dir(PIN_SDB, true);

    is31_init();

    sleep_ms(3000);

    for (;;)
    {

    for (uint32_t fid = 0; fid < 6560; fid++)
    {
        const uint8_t *frame = &badapple[38 * fid];

        uint8_t x = 0;
        uint8_t y = 0;

        for (uint32_t i = 0; i < 38; i++)
        {
            for (uint8_t j = 0; j < 4; j++)
            {
                uint8_t val = (frame[i] >> (j * 2)) & 0b11;
                val *= 2;
                is31_set_pixel(x, y, val);
                x++;

                if (x >= 15)
                {
                    y++;
                    x = 0;
                }

                if (y  >= 10)
                {
                    break;
                }
            }
        }

        sleep_ms(15);
    }

        sleep_ms(1000);
    }

    
    return 0;
}
