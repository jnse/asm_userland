%ifndef EXIT_INCL
%define EXIT_INCL

%include "syscalls.asm"

; exit : exits program.
;
; arguments: rdi : exit code.
;
exit:
    mov rax, syscall_exit
    syscall
    ret

%endif
