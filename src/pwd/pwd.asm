
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

    mov rdi, mystr
    mov rsi, [_malloc_heap_start]
    call itoa_hex
    call println

    mov rdi, 5
    call malloc

    ; exit 0
    xor rdi, rdi
    call exit
    ret

