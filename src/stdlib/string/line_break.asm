%ifndef LINE_BREAK_INCL
%define LINE_BREAK_INCL

SECTION .data

    str_line_break db 0x0A

SECTION .text

line_break:
    ; preserve registers.
    push rdi
    push rsi
    ; call write syscall.
    mov rdi, str_line_break
    mov rsi, 1
    call echo
    ; restore registers.
    pop rsi
    pop rdi
    ret

%endif
