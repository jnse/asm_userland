
;
; =============================================================================
;

SECTION .data

str_line   db "------------------------------------------------------", 0
str_start  db "Heap start: ", 0
str_size   db "Heap size : ", 0
str_cursor db "Cursor    : ", 0
str_iter   db 10, "=========================================================================", 10, 0
str_rsp    db "RSP = ", 0

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

    mov rcx, 30000
.main_loop:

    ; allocate a bunch of memory
    mov rdi, 20
    call malloc
    push rax
    ; alloc some more.
    mov rdi, 45
    call malloc
    ; now free first chunk of memory
    pop rax
    mov rdi, rax
    call free
    ; allocate it again
    mov rdi, 20
    call malloc
    ; free it again
    mov rdi, rax
    call free
    ; allocate something too big to be reused
    mov rdi, 100
    call malloc
    ; allocate something that could be reused
    mov rdi, 10
    call malloc

.next:
    ; iterate
    dec rcx
    test rcx, rcx
    jnz .main_loop

.done:
    ; exit 0
    xor rdi, rdi
    call exit
    ret
