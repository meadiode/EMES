
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

int main(void)
{
    stdio_init_all();

    gpio_init(PIN_SDB);
    gpio_init(PIN_SDA);
    gpio_init(PIN_SCL);

    i2c_init(i2c0, 100 * 1000);
    gpio_set_function(PIN_SDA, GPIO_FUNC_I2C);
    gpio_set_function(PIN_SCL, GPIO_FUNC_I2C);
    gpio_pull_up(PIN_SDA);
    gpio_pull_up(PIN_SCL);

    gpio_set_dir(PIN_SDB, true);

    gpio_put(PIN_SDB, false);
    sleep_ms(100);
    gpio_put(PIN_SDB, true);

    for (;;)
    {
        sleep_ms(5000);

        uint8_t data[2] = {0xfc, 0x00};
        uint8_t rdata = 0;

        i2c_write_blocking(i2c0, ADDR, data, 1, false);
        i2c_read_blocking(i2c0, ADDR, &rdata, 1, false);

        printf("Device id: 0x%02X\n", rdata);

        /* Unlock the page-select register */
        data[0] = 0xfe;
        data[1] = 0xc5;
        i2c_write_blocking(i2c0, ADDR, data, 2, false);

        /* Select page 2 */
        data[0] = 0xfd;
        data[1] = 0x02;
        i2c_write_blocking(i2c0, ADDR, data, 2, false);


        /* Pull up/down register config register */
        data[0] = 0x01;
        data[1] = 0x70;
        i2c_write_blocking(i2c0, ADDR, data, 2, false);

        /* Global Current Control register */
        data[0] = 0x01;
        data[1] = 0x10;
        i2c_write_blocking(i2c0, ADDR, data, 2, false);

        /* Configuration register */
        data[0] = 0x00;
        data[1] = 0x01;
        i2c_write_blocking(i2c0, ADDR, data, 2, false);

        
        for (uint8_t i = 0; i < 2; i++)
        {
            data[0] = i;
            i2c_write_blocking(i2c0, ADDR, data, 1, false);
            i2c_read_blocking(i2c0, ADDR, &rdata, 1, false);

            printf("Register %u val: 0x%02X\n", i, rdata);
        }


        /* Unlock the page-select register */
        data[0] = 0xfe;
        data[1] = 0xc5;
        i2c_write_blocking(i2c0, ADDR, data, 2, false);

        /* Select page 0 */
        data[0] = 0xfd;
        data[1] = 0x00;
        i2c_write_blocking(i2c0, ADDR, data, 2, false);

        /* Write PWMs */
        for (uint8_t i = 0; i < 180; i++)
        {
            data[0] = i;
            if ((i % 18) < 16)
            {
                data[1] = 0xa0;
            }
            else
            {
                data[1] = 0x00;
            }

            i2c_write_blocking(i2c0, ADDR, data, 2, false);
        }

        
        /* Unlock the page-select register */
        data[0] = 0xfe;
        data[1] = 0xc5;
        i2c_write_blocking(i2c0, ADDR, data, 2, false);

        /* Select page 1 */
        data[0] = 0xfd;
        data[1] = 0x01;
        i2c_write_blocking(i2c0, ADDR, data, 2, false);

        /* Write scalling values */
        for (uint8_t i = 0; i < 199; i++)
        {
            data[0] = i;
            data[0] = i;

            if ((i % 18) < 16)
            {
                data[1] = 0xff;
            }
            else
            {
                data[1] = 0x00;
            }

            i2c_write_blocking(i2c0, ADDR, data, 2, false);
        }

    }

    
    return 0;
}
