%ifndef malloc_lifo_incl
%define malloc_lifo_incl

SECTION .bss

    ; malloc free chunk lifo stack
    struc _malloc_lifo_entry
        .p_chunk: resq 1 ; pointer to chunk.
        .p_prev: resq 1  ; pointer to previous lifo entry.
        .p_next: resq 1  ; pointer to next lifo entry.
    endstruc

    _malloc_lifo_first_ptr: resq 1 ; pointer to first lifo entry.
    _malloc_lifo_last_ptr: resq 1  ; pointer to last lifo entry.
    _malloc_lifo_count: resq 1     ; number of lifo stack entries.

SECTION .text

; constructor.
;
_malloc_lifo_init:
    mov qword [_malloc_lifo_first_ptr], 0
    mov qword [_malloc_lifo_last_ptr], 0
    mov qword [_malloc_lifo_count], 0
    ret

; add a free chunk to the lifo stack.
;
; arguments:
;     rdi : pointer to chunk to add.
; returns:
;     rax : pointer to lifo entry. 0 if failed.
;
_malloc_lifo_add:
    ; save clobbered registers.
    push rcx
    ; get free heap space.
    push rdi
    mov rdi, _malloc_lifo_entry_size
    call _malloc_heap_grow_if_needed
    pop rdi
    test rax, rax
    jz .failed
.create_lifo_entry:
    ; populate fields.
    mov qword [rax + _malloc_lifo_entry.p_chunk], rdi
    mov rcx, [_malloc_lifo_last_ptr]
    mov qword [rax + _malloc_lifo_entry.p_prev], rcx
    mov qword [rax + _malloc_lifo_entry.p_next], 0
    inc qword [_malloc_lifo_count]
    ; do we need to update previous entry's next ptr?
    mov rcx, [_malloc_lifo_last_ptr]
    test rcx, rcx
    jz .skip_update_prev
    mov qword [rcx + _malloc_lifo_entry.p_next], rax
.skip_update_prev:
    ; update last lifo entry ptr.
    mov [_malloc_chunk_last_ptr], rax
    ; if this is the first lifo entry, update first entry ptr.
    cmp qword [_malloc_lifo_first_ptr], 0
    jne .done
    mov [_malloc_lifo_first_ptr], rax
.failed:
    xor rax, rax
.done:
    ; restore clobbered registers.
    pop rcx
    ret

%endif
