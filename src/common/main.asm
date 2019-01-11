%ifndef MAIN_INCL
%define MAIN_INCL

; This basically implements a c-style main()
; function which consumes the stack to set
; up ARGC, ARGV[], and ENV[]

SECTION .bss

    argc: resq 1           ; argument count.
    envc: resq 1           ; env var count.
    p_argv: resq 1         ; pointer to arguments array.
    p_env: resq 1          ; pointer to env vars array.
    p_program_name: resq 1 ; pointer to program name string.

SECTION .text

%include "malloc.asm"

; This should typically be the first thing you call after _start.
; %include this after your _start
;
; CLOBBERS: rdx, rax, rsp
;
main:
    ; get argc and argv[0]
    pop qword [argc]
    ; ARGV[0] is program name.
    pop qword [p_program_name]
    ; which also marks the start of ARGV.
    mov rdx, [p_program_name]
    mov qword [p_argv], rdx
    ; move stack past argv[argc]
    mov rdx, [argc]
    mov rax, 8
    mul qword rdx
    add rsp, rax
    ; save ptr to env var array.
    mov [p_env], rsp

%endif
