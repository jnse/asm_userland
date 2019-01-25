%ifndef malloc_chunk_incl
%define malloc_chunk_incl

SECTION .bss

    ; malloc chunk header fields
    struc _malloc_chunk_header
      .bytes: resq 1  ; size of chunk in bytes.
      .p_data: resq 1 ; pointer to chunk data.
      .free: resb 1   ; chunk free flag.
      .p_prev: resq 1 ; pointer to previous chunk.
      .p_next: resq 1 ; pointer to next chunk.
      .p_prev_free: resq 1 ; pointer to next free chunk.
      .p_next_free: resq 1 ; pointer to previous free chunk.
    endstruc

    _malloc_chunk_first_ptr: resq 1 ; pointer to first allocated chunk.
    _malloc_chunk_last_ptr: resq 1  ; pointer to last allocated chunk.
    _malloc_chunk_count: resq 1     ; number of chunks.

SECTION .text

; initializes malloc chunk management.
;
_malloc_chunk_init:
    mov qword [_malloc_chunk_first_ptr], 0
    mov qword [_malloc_chunk_last_ptr], 0
    mov qword [_malloc_chunk_count], 0
    ret

; creates a new memory chunk.
;
; arguments: 
;     rdi : chunk size in bytes.
; returns:
;     rax : pointer to chunk. 0 if failed.
;
_malloc_chunk_create:
    ; save clobbered registers.
    push rcx
    ; get free heap space.
    push rdi
    add rdi, _malloc_chunk_header_size
    call _malloc_heap_grow_if_needed
    pop rdi
    test rax, rax
    jz .failed
.create_chunk:
    ; calculate pointer to data (right behind header).
    mov rcx, rax
    add rcx, _malloc_chunk_header_size
    ; increment chunk count.
    inc qword [_malloc_chunk_count]
    ; populate fields.
    mov qword [rax + _malloc_chunk_header.bytes], rdi
    mov qword [rax + _malloc_chunk_header.p_data], rcx
    mov byte [rax + _malloc_chunk_header.free], 0
    mov qword [rax + _malloc_chunk_header.p_next], 0
    mov qword [rax + _malloc_chunk_header.p_prev], 0
    mov qword [rax + _malloc_chunk_header.p_next_free], 0
    mov qword [rax + _malloc_chunk_header.p_prev_free], 0
    push rcx
    mov rcx, [_malloc_chunk_last_ptr]
    mov qword [rax + _malloc_chunk_header.p_prev], rcx
    ; do we need to update previous chunk's next ptr?
    test rcx, rcx
    jz .skip_update_prev
    mov qword [rcx + _malloc_chunk_header.p_next], rax
.skip_update_prev:
    pop rcx
    mov qword [rax + _malloc_chunk_header.p_next], 0
    ; update last chunk ptr.
    mov [_malloc_chunk_last_ptr], rax
    ; if this is the first chunk, update first chunk ptr.
    cmp qword [_malloc_chunk_first_ptr], 0
    jne .done
    mov [_malloc_chunk_first_ptr], rax
    ; result = ptr to data.
    mov qword rax, [rax + _malloc_chunk_header.p_data]
    jmp .done
.failed:
    xor rax, rax
.done:
    ; restore clobbered registers.
    pop rcx
    ret

; find a chunk with given data ptr.
;
; arguments:
;     rdi : pointer to chunk's data.
; returns:
;     rax : pointer to found chunk, or 0 if not found.
;
_malloc_chunk_find:
    ; save clobbered registers.
    push rcx
    ; iterate on rcx, start from most recent.
    mov rcx, [_malloc_chunk_last_ptr]
    ; if there are no chunks, skip.
    test rcx, rcx
    jz .not_found
.loop:
    cmp qword rdi, [rcx + _malloc_chunk_header.p_data]
    je .found
    mov rcx, [rcx + _malloc_chunk_header.p_prev]
    test rcx, rcx
    jnz .loop
.not_found:
    xor rax, rax
    jmp .done
.found:
    mov rax, rcx
.done:
    ; restore clobbered registers
    pop rcx
    ret

%endif
