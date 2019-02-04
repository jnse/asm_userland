%ifndef PRINT_INCL
%define PRINT_INCL

%include "syscalls.asm"
%include "file_descriptors.asm"
%include "string/strlen.asm"

SECTION .DATA

line_break: db 10, 0

SECTION .text

; printn : prints a string with length n to stdout.
;
; arguments:
;     rdi : pointer to string data.
;     rsi : string length.
;
printn:
    ; preserve registers
    push rax
    push rsi
    push rdi
    ; move arguments to syscall args.
    push rsi
    mov rsi, rdi
    pop rdx
    ; call write syscall.
    mov rax, syscall_write
    mov rdi, fd_stdout
    syscall ; rdx=len rsi=str
    ; restore registers
    pop rdi
    pop rsi
    pop rax
    ret

; print : prints a null-terminated string to stdout.
;
; arguments:
;     rdi : pointer to string data.
;
print:
    ; preserve registers
    push rsi
    ; get string length
    call strlen
    ; print using printn and result of above.
    mov rsi, rax
    call printn
    ; restore registers
    pop rsi
    ret

; println : same as print, but with a newline at the end.
;
; arguments:
;     rdi : pointer to string data.
;
println:
    ; preserve registers.
    push rdi
    push rsi
    ; output linebreak.
    call print
    mov rdi, line_break
    mov rsi, 1
    call printn
    ; restore registers.
    pop rsi
    pop rdi
    ret

%endif
