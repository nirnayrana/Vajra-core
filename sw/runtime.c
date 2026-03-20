#define UART_ADDR 0x80000000

void uart_putchar(char c) {
    *(volatile int*)UART_ADDR = c;
}

void print(const char *s) {
    while (*s) {
        uart_putchar(*s++);
    }
}
