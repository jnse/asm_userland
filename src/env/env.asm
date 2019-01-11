
;
; =============================================================================
;

SECTION .data

;
; =============================================================================
;

SECTION .bss

    argc: resq 1
    p_program_name: resq 1
    envstr_len: resq 1
;
; =============================================================================
;

SECTION .text

    GLOBAL _start

; Included functions ----------------------------------------------------------

jmp _start

%include "strlen.asm"
%include "print.asm"
%include "exit.asm"

%define word_size 8 ; How many bytes in a qword

; Entry point -----------------------------------------------------------------

_start:

    ; get argc and argv[0]
    pop qword [argc]
    pop qword [p_program_name]

    ; discard the rest of argv[] by advancing the stack pointer.
    mov rdx, [argc]
    mov rax, word_size
    mul qword rdx
    add rsp, rax

    ; read environment variables.
begin_dump_env:

    pop qword rdi

    or rdi, rdi
    jz end_dump_env

    call println
    
    jmp begin_dump_env ; and loop.
end_dump_env:
    
    ; exit 0
    xor rdi, rdi
    call exit
    ret

