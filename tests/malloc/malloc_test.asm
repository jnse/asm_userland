
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

%include "string/strlen.asm"
%include "string/print.asm"
%include "main/exit.asm"
%include "string/itoa.asm"
%include "malloc/malloc.asm"
%include "malloc/malloc_debug.asm"

%define word_size 8 ; How many bytes in a qword

; Entry point -----------------------------------------------------------------

_start:

%include "main/main.asm"

    call init_memory

    ; print out the initial heap size
    ;mov rdi, mystr
    ;mov rsi, [_malloc_heap_size]
    ;call itoa_hex
    ;call println

    ; allocate a bunch of memory
    mov rdi, 10
    call malloc

    mov rdi, 20
    call malloc
    push rax

    mov rdi, 30
    call malloc
    push rax

    mov rdi, 40
    call malloc

    ; print the list of chunks before free'ing.
    call malloc_debug_chunks
    mov rdi, line
    call println

    ; now free the middle 2 chunks
    pop rax
    mov rdi, rax
    call free

    pop rax
    mov rdi, rax
    call free

    call malloc_debug_free_stack
    mov rdi, line
    call println

    call malloc_debug_chunks
    mov rdi, line
    call println
    mov rdi, line
    call println

    ; try to re-use a chunk.
    mov rdi, 5
    call malloc

    call malloc_debug_free_stack
    mov rdi, line
    call println

    call malloc_debug_chunks
    mov rdi, line
    call println

    ; exit 0
    xor rdi, rdi
    call exit
    ret

