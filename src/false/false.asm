SECTION .data

SECTION .text
    GLOBAL _start

_start:
    mov eax,1    ; 'exit' syscall
    mov ebx, 1   ; exit with 1
    int 80h      ; call kernel.

