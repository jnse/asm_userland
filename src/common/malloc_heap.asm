%ifndef MALLOC_HEAP_INCL
%define MALLOC_HEAP_INCL

; page size determines minimum amount of memory we allocate when growing
; the heap.
%define _malloc_heap_page_size 4096

; heap management functions used by malloc.

SECTION .bss

    _malloc_heap_size: resq 1  ; stores heap size.
    _malloc_heap_start: resq 1 ; stores heap start address.
    _malloc_heap_end: resq 1   ; stores the heap end address.
    _malloc_heap_free: resq 1  ; stores the number of bytes free.

SECTION .text

; constructor.
_malloc_heap_init:
    ; get heap start address.
    mov rax, syscall_brk
    xor rdi, rdi
    syscall
    mov qword [_malloc_heap_start], rax
    mov qword [_malloc_heap_end], rax
    ; init everything else.
    mov qword [_malloc_heap_size], 0
    mov qword [_malloc_heap_free], 0
    ret

; _malloc_heap_grow : grows program heap.
;
; arguments:
;     rdi : number of bytes to grow by.
; returns:
;     rax : number of bytes allocated.
;
_malloc_heap_grow:
    ; save clobbered registers.
    push rdi
    push rdx
    ; if space required is less than the page size, alloc page size.
    cmp rdi, _malloc_heap_page_size
    jg .call_brk
    mov rdi, _malloc_heap_size
.call_brk:
    ; use BRK to allocate more heap space.
    add rdi, [_malloc_heap_start]
    add rdi, [_malloc_heap_size]
    mov rax, syscall_brk
    syscall
    ; check for failure.
    cmp rax, [_malloc_heap_start]
    je .failed
    ; free space += (new heap end - old heap end)
    mov qword rdx, rax
    sub qword rdx, [_malloc_heap_end]
    add [_malloc_heap_free], rdx
    ; save the new heap end.
    mov [_malloc_heap_end], rax
    ; save new heap size.
    sub rax, [_malloc_heap_start]
    mov qword [_malloc_heap_size], rax
    jmp .done
.failed:
    xor rax, rax
.done:
    ; restore clobbered registers.
    pop rdx
    pop rdi
    ret

; grows heap if needed for requested size.
;
; arguments:
;     rdi : number of bytes required.
; returns:
;     rax : ptr to memory for requested space
;           0 on failure.
;
_malloc_heap_grow_if_needed:
    mov rax, [_malloc_heap_free]
    sub rax, rdi
    jc .need_space
.consume_space:
    sub qword [_malloc_heap_free], rdi
    jnz .calc_ptr
    mov qword [_malloc_heap_free], 0
    jmp .calc_ptr
.need_space:
    call _malloc_heap_grow
    test rax, rax
    jz .failed
.calc_ptr:
    mov rax, [_malloc_heap_end]
    sub rax, [_malloc_heap_free]
    jmp .done
.failed:
    xor rax, rax
.done:
    ret

%endif
