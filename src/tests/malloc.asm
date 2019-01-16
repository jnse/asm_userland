; Tests malloc and free functionality.

;
; =============================================================================
;

SECTION .data

line db "------------------------------------------------------", 0

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
    mov rdi, mystr
    mov rsi, [_malloc_heap_size]
    call itoa_hex
    call println

    ; allocate a bunch of memory
    mov rdi, 20
    call malloc

    push rax
    
    mov rsi, [_malloc_mem_cursor]
    mov rdi, mystr
    call itoa_hex
    call println

    mov rdi, 45
    call malloc

    mov rsi, [_malloc_mem_cursor]
    mov rdi, mystr
    call itoa_hex
    call println

    call malloc_debug
    mov rdi, line
    call println

    ; now free last chunk of memory
    pop rax
    mov rdi, rax
    call free

    call malloc_debug
    mov rdi, line
    call println

    ; see if it will be re-used
    mov rdi, 100
    call malloc

    call malloc_debug
    mov rdi, line
    call println

    ; print out the final heap size
    mov rdi, mystr
    mov rsi, [_malloc_heap_size]
    call itoa_hex
    call println

    ; exit 0
    xor rdi, rdi
    call exit
    ret
