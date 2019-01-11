%ifndef STRLEN_INCL
%define STRLEN_INCL

%define pcmpistri_equal_each 8

; strlen : Get length of a string.
; 
; arguments : 
;     rdi : pointer to string to get length of.
;
; returns :
;     rax : contains result.
;
strlen:
    ; rax will be our character index/counter
    mov rax, -8      ; start from -1 characters.
    pxor xmm0, xmm0  ; pcmpistri 1st arg = 0 becase we
                     ; just care about getting the length.
strlen_loop:
    add rax, 8       ; move ahead by 1 character.
    pcmpistri xmm0, [rdi+rax], pcmpistri_equal_each
    jnz strlen_loop  ; if zf set we're done.
    add rax, rcx     ; add end position to index.
    ret

%endif
