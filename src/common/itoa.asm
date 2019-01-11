%ifndef ITOA_INCL
%define ITOA_INCL

SECTION .text

; itoa : Convert an interger into an string
;
; maximum possible returned string length is 21 
; chars (incl null terminator)
; 
; arguments:
;     rdi : pointer to string to hold result.
;     rsi : integer to convert.
;
; returns:
;     rdi : points to end of string
;
itoa:
   ; save registers.
   push rdx
   push rcx
   push rbx
   push rax
   ; set up initial state.
   mov rax, rsi      ; copy arg
   mov rbx, 10       ; base-10 (decimal)
   xor ecx, ecx      ; digit#
._next_divide:
   xor edx, edx
   div rbx           ; divide by the number-base
   push rdx          ; save remainder on the stack
   inc rcx           ; and count this remainder
   cmp rax, 0        ; loop until quotient=0
   jne ._next_divide
._next_digit:
   pop rax           ; else pop recent remainder
   add al, '0'       ; and convert to a numeral
   stosb             ; store to ptr (rdi)
   loop ._next_digit ; next digit.
   ; null-terminate result.
   xor al, al
   stosb
   ; restore registers
   pop rax
   pop rbx
   pop rcx
   pop rdx
   ret

; itoa_hex : Convert an interger into an string
;
; maximum possible returned string length is 21 
; chars (incl null terminator)
; 
; arguments:
;     rdi : pointer to string to hold result.
;     rsi : integer to convert.
;
; returns:
;     rdi : points to end of string
;
itoa_hex:
   ; save registers.
   push rdx
   push rcx
   push rbx
   push rax
   push rdi
   ; set up initial state.
   mov rax, rsi      ; copy arg
   mov rbx, 16       ; base-16 (hexadecimal)
   xor ecx, ecx      ; digit#
._next_divide:
   xor edx, edx
   div rbx           ; divide by the number-base
   push rdx          ; save remainder on the stack
   inc rcx           ; and count this remainder
   cmp rax, 0        ; loop until quotient=0
   jne ._next_divide
._next_digit:
   pop rax           ; else pop recent remainder
   cmp al, 10
   jl ._digit_is_number
   add al, 55        ; 87=chr$('a')-10
   jmp ._store_digit
._digit_is_number:
   add al, '0'       ; and convert to a numeral
._store_digit:
   stosb             ; store to ptr (rdi)
   loop ._next_digit ; next digit.
   ; null-terminate result.
   xor al, al
   stosb
   ; restore registers
   pop rdi
   pop rax
   pop rbx
   pop rcx
   pop rdx
   ret

%endif
