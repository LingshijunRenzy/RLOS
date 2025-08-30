static void clear_screen()
{
    char *video_memory = (char *)0xB8000;
    int cells = 80 * 25;
    for (int i = 0; i < cells; i++)
    {
        video_memory[i * 2] = ' ';
        video_memory[i * 2 + 1] = 0x07; // white on black
    }
}

void kernel_main()
{
    // Clear the VGA text buffer before printing
    clear_screen();

    // Simple VGA text buffer printing
    // VGA text buffer starts at 0xB8000
    char *video_memory = (char *)0xB8000;

    char *hello = "Welcome to RLOS! Successfully loaded kernel";
    int i = 0;
    while (hello[i] != '\0')
    {
        video_memory[i * 2] = hello[i]; // Character
        video_memory[i * 2 + 1] = 0x07; // Attribute (white on black)
        i++;
    }

    // Infinite loop to halt the CPU
    while (1)
    {
        // Do nothing
    }
}