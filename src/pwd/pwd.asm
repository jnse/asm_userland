
;
; =============================================================================
;

SECTION .data

;
; =============================================================================
;

SECTION .bss

mystr: resb 22

;
; =============================================================================
;

SECTION .text

    GLOBAL _start

; Included functions ----------------------------------------------------------

%include "strlen.asm"
%include "print.asm"
%include "exit.asm"
%include "itoa.asm"
%include "malloc.asm"

%define word_size 8 ; How many bytes in a qword

; Entry point -----------------------------------------------------------------

_start:

%include "main.asm"

    call init_memory

    ; print out the initial heap size
    ;mov rdi, mystr
    ;mov rsi, [_malloc_heap_size]
    ;call itoa_hex
    ;call println

    ; allocate a bunch of memory
    mov rdi, 0xffff
    call malloc

    ; write something to it.
    mov byte [rax], 'H'
    mov byte [rax+1], 'e'
    mov byte [rax+2], 'l'
    mov byte [rax+3], 'l'
    mov byte [rax+4], 'o'

    ; now free the memory
    mov rdi, rax
    call free

    ; now when we allocate some more memory, 
    ; the previously freed block should get re-used,
    ; so long the requested size <= the chunk size.
    mov rdi, 0x0f00
    call malloc

    ; write something to the recycled chunk.
    mov byte [rax], 'W'
    mov byte [rax+1], 'o'
    mov byte [rax+2], 'r'
    mov byte [rax+3], 'l'
    mov byte [rax+4], 'd'

    ; fuck around a bit to make sure nothing blows up.
    mov rdi, 0x100
    call malloc
    mov rdi, 0x0f00
    call malloc
    mov rdi, rax
    call free
    mov rdi, 0xfa0
    call malloc

    ; alright, print out final heap size.
    mov rdi, mystr
    mov rsi, [_malloc_heap_size]
    call itoa_hex
    call println

    ; exit 0
    xor rdi, rdi
    call exit
    ret

