#include <stdlib.h>

int main(int argc, char** argv)
{
    void* pa = 0;
    void* pb = 0;
    for (int i = 30000 ; i != 0 ; --i)
    {
        pa = malloc(20);
        pb = malloc(45);
        free(pa);
        pa = malloc(20);
        free(pa);
        pa = malloc(100);
        pa = malloc(10);
    }
    return 0;
}
