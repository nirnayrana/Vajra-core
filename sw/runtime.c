#define UART_ADDR 0x80000000

void uart_putchar(char c) {
    *(volatile int*)UART_ADDR = c;
}

void print(const char *s) {
    while (*s) {
        uart_putchar(*s++);
    }
}
void *memcpy(void *dst, const void *src, unsigned long n) {
    unsigned char *d = dst;
    const unsigned char *s = src;
    while (n--) *d++ = *s++;
    return dst;
}