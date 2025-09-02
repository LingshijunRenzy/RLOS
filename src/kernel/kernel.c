#include <stdint.h>

static volatile uint16_t *const VGA_BUFFER = (uint16_t *)0xB8000;
static const int VGA_COLS = 80;
static const int VGA_ROWS = 25;

static uint16_t vga_entry(char c, uint8_t color)
{
    return (uint16_t)c | ((uint16_t)color << 8);
}

void kernel_main(void)
{
    const char *msg = "Hello, Kernel!";
    uint8_t color = 0x07; /* light grey on black */

    /* Clear first line then write */
    for (int i = 0; i < VGA_COLS; ++i)
    {
        VGA_BUFFER[i] = vga_entry(' ', color);
    }

    int x = 0;
    while (msg[x] != '\0')
    {
        VGA_BUFFER[x] = vga_entry(msg[x], color);
        x++;
    }

    for (;;)
    {
        __asm__ __volatile__("hlt");
    }
}
