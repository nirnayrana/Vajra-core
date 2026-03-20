volatile int x = 5;
volatile int y = 10;

int main() {
    volatile int *uart = (int*)0x80000000;

    *uart = x;   // must load from memory
    *uart = y;

    while (1);
}