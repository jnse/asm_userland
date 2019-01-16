
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

debug_rsp:
    push rdi
    push rax
    push rsi
    mov rdi, str_rsp
    call print
    mov rdi, mystr
    mov rsi, rsp
    call itoa_hex
    call println
    pop rsi
    pop rax
    pop rdi
    ret

debug:
    push rdi
    push rax
    push rsi
    mov rdi, str_start
    call print
    mov rdi, mystr
    mov rsi, [_malloc_heap_start]
    call itoa_hex
    call println
    mov rdi, str_size
    call print
    mov rdi, mystr
    mov rsi, [_malloc_heap_size]
    call itoa_hex
    call println
    mov rdi, str_cursor
    call print
    mov rdi, mystr
    mov rsi, [_malloc_mem_cursor]
    call itoa_hex
    call println
    mov rdi, str_line
    call println
    pop rsi
    pop rax
    pop rdi
    ret

_start:

%include "main.asm"

    call init_memory
    mov rbx, 30000
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
    dec rbx
    jnz .main_loop
    ; exit 0
    xor rdi, rdi
    call exit
    ret
