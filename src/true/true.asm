SECTION .data

SECTION .text
    GLOBAL _start

_start:
    mov eax,1    ; 'exit' syscall
    xor ebx, ebx ; exit with 0
    int 80h      ; call kernel.

