
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

#define BITBANG 1

void bitbang_i2c_write(uint8_t addr, const uint8_t *data, uint32_t size);
void bitbang_i2c_read(uint8_t addr, uint8_t *data, uint32_t size);


#ifdef BITBANG
# define is31_write(addr, data, size) bitbang_i2c_write(addr, data, size)
# define is31_read(addr, data, size) bitbang_i2c_read(addr, data, size)
#else
# define is31_write(addr, data, size) i2c_write_blocking(i2c0, addr, data, size, false)
# define is31_read(addr, data, size) i2c_read_blocking(i2c0, addr, data, size, false)
#endif


void is31_set_reg_page(uint8_t page_id)
{
    uint8_t data[2];

    /* Unlock the page-select register */
    data[0] = 0xfe;
    data[1] = 0xc5;
    is31_write(ADDR, data, 2);

    /* select page */
    data[0] = 0xfd;
    data[1] = page_id;
    is31_write(ADDR, data, 2);
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
    is31_write(ADDR, data, 2);

    /* Global Current Control register */
    data[0] = 0x01;
    data[1] = 0x70;
    is31_write(ADDR, data, 2);

    /* Pull up/down register config register */
    data[0] = 0x01;
    data[1] = 0x70;
    is31_write(ADDR, data, 2);


    is31_set_reg_page(1);

    /* Write scalling values */
    for (uint8_t i = 1; i <= 198; i++)
    {
        data[0] = i;
        data[1] = 0xff;

        is31_write(ADDR, data, 2);
    }

    is31_set_reg_page(0);

    /* Write PWMs */
    for (uint8_t i = 1; i <= 198; i++)
    {
        data[0] = i;
        data[1] = 0x00;

        is31_write(ADDR, data, 2);
    }
}

void is31_printout_config_registers(void)
{

    uint8_t data = 0xfc;
    uint8_t rdata = 0;

    is31_write(ADDR, &data, 1);
    is31_read(ADDR, &rdata, 1);

    printf("Device id: 0x%02X\n", rdata);

    is31_set_reg_page(2);

    const char* const regnames[] =
    {
        "Configureation register                 ",
        "Global Current Control register         ",
        "Pull Down/Up resistor selection register",
    };

    for (uint8_t reg_id = 0; reg_id < 3; reg_id++)
    {
        
        if (reg_id == 2)
        {
            gpio_put(18, 1);
        }
        is31_write(ADDR, &reg_id, 1);
        is31_read(ADDR, &rdata, 1);
        
        gpio_put(18, 0);

        printf("%s : 0x%02X\n", regnames[reg_id], rdata);
    }
}

void is31_set_pixel(uint8_t x, uint8_t y, uint8_t val)
{
    uint8_t data[2];

    data[0] = 1 + y * 18 + x; /* PWM reg id */
    data[1] = val;

    is31_write(ADDR, data, 2);
}

void bitbang_i2c_write(uint8_t addr, const uint8_t *data, uint32_t size)
{
    /* start condition */
    gpio_set_dir(PIN_SDA, false);
    gpio_set_dir(PIN_SCL, false);
    sleep_us(1);
    gpio_set_dir(PIN_SDA, true);
    sleep_us(1);

    for (uint32_t i = 0; i <= size; i++)
    {
        uint8_t byte;
        if (i == 0)
        {
            byte = addr << 1;         
        }
        else
        {
            byte = data[i - 1];
        }

        for (uint8_t j = 0; j < 8; j++)
        {
            gpio_set_dir(PIN_SDA, (byte & 0b10000000) == 0);
            gpio_set_dir(PIN_SCL, true);
            sleep_us(1);
            gpio_set_dir(PIN_SCL, false);
            sleep_us(1);
            byte <<= 1;
        }

        /* ACK cycle */
        gpio_set_dir(PIN_SDA, true);
        gpio_set_dir(PIN_SCL, true);
        sleep_us(1);
        gpio_set_dir(PIN_SCL, false);
        sleep_us(1);
        gpio_set_dir(PIN_SDA, false);
    }

    /* stop condition */
    gpio_set_dir(PIN_SDA, true);
    gpio_set_dir(PIN_SCL, true);
    sleep_us(1);
    gpio_set_dir(PIN_SCL, false);
    gpio_set_dir(PIN_SDA, true);
    sleep_us(1);
}


void bitbang_i2c_read(uint8_t addr, uint8_t *data, uint32_t size)
{
    /* start condition */
    gpio_set_dir(PIN_SDA, false);
    gpio_set_dir(PIN_SCL, false);
    sleep_us(1);
    gpio_set_dir(PIN_SDA, true);
    gpio_put(PIN_SDA, 0);
    sleep_us(1);

    uint8_t byte = (addr << 1) | 1;

    for (uint8_t j = 0; j < 8; j++)
    {
        gpio_set_dir(PIN_SDA, (byte & 0b10000000) == 0);
        gpio_set_dir(PIN_SCL, true);
        sleep_us(1);
        gpio_set_dir(PIN_SCL, false);
        sleep_us(1);
        byte <<= 1;
    }

    /* ACK cycle */
    gpio_set_dir(PIN_SCL, true);
    sleep_us(1);
    gpio_set_dir(PIN_SCL, false);
    sleep_us(1);
    gpio_set_dir(PIN_SDA, false);

    for (uint32_t i = 0; i < size; i++)
    {
        uint8_t rbyte = 0;
        for (uint8_t j = 0; j < 8; j++)
        {
            gpio_set_dir(PIN_SCL, true);
            sleep_us(1);
            rbyte |= (gpio_get(PIN_SDA) ? 1 : 0) << (7 - j);
            gpio_set_dir(PIN_SCL, false);
            sleep_us(1);
        }
        data[i] = rbyte;
    }

    /* ACK cycle */
    gpio_set_dir(PIN_SDA, true);
    gpio_put(PIN_SDA, 1);
    gpio_set_dir(PIN_SCL, true);
    sleep_us(1);
    gpio_set_dir(PIN_SCL, false);
    sleep_us(1);
    gpio_set_dir(PIN_SDA, false);

    /* stop condition */
    gpio_set_dir(PIN_SDA, true);
    gpio_put(PIN_SDA, 0);
    gpio_set_dir(PIN_SCL, true);
    sleep_us(1);
    gpio_set_dir(PIN_SCL, false);
    sleep_us(1);
    gpio_set_dir(PIN_SDA, false);
}


int main(void)
{
    stdio_init_all();

    printf("SW: %u\n", 4);
    
    gpio_init(PIN_SDB);
    gpio_init(PIN_SDA);
    gpio_init(PIN_SCL);
    
    gpio_init(18);
    gpio_set_dir(18, true);
    gpio_put(18, 0);

    i2c_init(i2c0, 100 * 1000);

#ifdef BITBANG
    gpio_set_dir(PIN_SDA, false);
    gpio_set_dir(PIN_SCL, false);
#else
    gpio_set_function(PIN_SDA, GPIO_FUNC_I2C);
    gpio_set_function(PIN_SCL, GPIO_FUNC_I2C);
#endif

    gpio_set_dir(PIN_SDB, true);

    is31_init();

    for (uint8_t i = 0; i < 3; i++)
    {
        printf("Read-out attempt #%d:\n", i);
        sleep_ms(1000);
        is31_printout_config_registers();
        printf("\n\n");
    }


    is31_set_reg_page(0); 

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
                    val *= 0x04;
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

            sleep_ms(20);
        }
        sleep_ms(1000);
    }

    
    return 0;
}
