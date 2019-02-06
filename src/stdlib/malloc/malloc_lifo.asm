%ifndef malloc_lifo_incl
%define malloc_lifo_incl

SECTION .bss

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

; stitches two (sequential) lifo entries into one large entry.
;
; arguments:
;     rdi : pointer to first chunk.
;     rsi : pointer to second chunk.
;
_malloc_lifo_stitch:
    ; save clobbered registers.
    push rax
    ; recalculate size of first chunk.
    mov qword rax, [rsi + _malloc_chunk_header.bytes]
    add qword [rdi + _malloc_chunk_header.bytes], rax
    add qword [rdi + _malloc_chunk_header.bytes], _malloc_chunk_header_size
    ; second chunk's next chunk becomes first chunk's next chunk.
    mov rax, [rsi + _malloc_chunk_header.p_next_free]
    mov [rdi + _malloc_chunk_header.p_next_free], rax
    ; make sure nothing points to the second chunk.
    cmp rsi, [_malloc_lifo_last_ptr]
    jne .skip_update_last
    mov [_malloc_lifo_last_ptr], rdi
.skip_update_last:
    cmp rsi, [_malloc_lifo_first_ptr]
    jne .skip_update_first
    mov [_malloc_lifo_first_ptr], rdi
.skip_update_first:
    ; restore clobbered registers.
    pop rax
    ret

; deletes a lifo entry and shrinks the heap, if the lifo entry is
; located at the edge of heap memory.
;
; arguments:
;     rdi : pointer to lifo entry.
; 
_malloc_lifo_delete_if_we_can:
    ; save clobbered registers.
    push rax;
    ; check if we can actually go through with this.
    mov rax, rdi
    add rax, _malloc_chunk_header_size
    add qword rax, [rdi + _malloc_chunk_header.bytes]
    cmp rax, _malloc_heap_end
    jne .done
.delete_chunk
    call _malloc_lifo_remove_entry
    call _malloc_heap_set_end
.done:
    ; restore clobbered registers.
    pop rax
    ret

; merges free chunks if they are adjacent.
_malloc_lifo_defrag:
    ; save clobbered registers.
    push rcx
    push rax
    ; iterate on rcx
    mov rcx, [_malloc_lifo_first_ptr]
.check_entry:
    ; done?
    test rcx, rcx
    jz .done
    ; calculate current chunk's end in rax.
    mov rax, [rcx + _malloc_chunk_header.bytes]
    add rax, rcx
    add rax, _malloc_chunk_header_size
    ; if chunk end = pointer to next chunk, stitch.
    cmp rax, [rcx + _malloc_chunk_header.p_next_free]
    je .stitch
    mov rcx, [rcx + _malloc_chunk_header.p_next_free]
    jmp .check_entry
.stitch:
    mov rdi, rcx
    mov rsi, rax
    call _malloc_lifo_stitch
.done:
    ; restore clobbered registers.
    pop rax
    pop rcx
    ret

; add a free chunk to the lifo stack.
;
; arguments:
;     rdi : pointer to chunk to add.
; returns:
;     rax : 1 on success, 0 if failed.
;
_malloc_lifo_add_chunk:
    ; save clobbered registers.
    push rcx
    mov rax, 1
.create_lifo_entry:
    ; populate fields.
    mov rcx, [_malloc_lifo_last_ptr]
    mov qword [rdi + _malloc_chunk_header.p_prev_free], rcx
    mov qword [rdi + _malloc_chunk_header.p_next_free], 0
    inc qword [_malloc_lifo_count]
    ; update last ptr
    mov qword [_malloc_lifo_last_ptr], rdi
    ; do we need to update previous entry's next ptr?
    test rcx, rcx
    jz .skip_update_prev
    mov qword [rcx + _malloc_chunk_header.p_next_free], rdi
.skip_update_prev:
    ; if this is the first lifo entry, update first entry ptr.
    cmp qword [_malloc_lifo_first_ptr], 0
    jne .done
    mov [_malloc_lifo_first_ptr], rdi
    jmp .done
.failed:
    xor rax, rax
.done:
    call _malloc_lifo_defrag
    ; restore clobbered registers.
    pop rcx
    ret

; remove a free chunk from the lifo stack.
;
; arguments:
;     rdi : pointer to chunk to remove.
;
_malloc_lifo_remove_entry:
    ; save clobbered registers.
    push rax
    push rdx
    ; if there's only one entry left, we're it.
    cmp qword [_malloc_lifo_count], 1
    jne .not_only_entry
.is_only_entry:
    mov qword [_malloc_lifo_first_ptr], 0
    mov qword [_malloc_lifo_last_ptr], 0
    jmp .skip_zero_next
.not_only_entry:
    ; if there's both a previous entry and a next entry
    ; stitch them togeather.
    mov qword rdx, [rdi + _malloc_chunk_header.p_prev_free]
    mov qword rax, [rdi + _malloc_chunk_header.p_next_free]
    test rdx, rdx
    jz .skip_stitch
    test rax, rax
    jz .skip_stitch 
    mov qword [rax + _malloc_chunk_header.p_prev_free], rdx
    mov qword [rdx + _malloc_chunk_header.p_next_free], rax
.skip_stitch:
    ; if there's a previous entry, null it's next ptr.
    test rdx, rdx
    jz .skip_zero_prev
    mov qword [rdx + _malloc_chunk_header.p_next_free], 0
.skip_zero_prev:
    ; if there's a next entry, null it's prev ptr.
    test rax, rax
    jz .skip_zero_next
    mov qword [rax + _malloc_chunk_header.p_prev_free], 0
.skip_zero_next:
    ; TODO add this entry to the trash pile.
    ; call _malloc_trash_add
    ; decrement entry count.
    dec qword [_malloc_lifo_count]
.done:
    ; restore clobbered registers.
    pop rdx
    pop rax
    ret

; find a chunk in the lifo stack.
;
; arguments:
;     rdi : pointer to chunk's data.
; returns:
;     rax : pointer to found chunk, or 0 if not found.
;
_malloc_lifo_find:
    ; save clobbered registers.
    push rcx
    ; if there are no chunks, skip.
    cmp qword [_malloc_lifo_count], 0
    je .not_found
    ; iterate on rcx, start from most recent.
    mov rcx, [_malloc_lifo_last_ptr]
.loop:
    cmp qword rdi, [rcx + _malloc_chunk_header.p_data]
    je .found
    mov rcx, [rcx + _malloc_chunk_header.p_prev_free]
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

; find a chunk to fit requested data size.
;
; arguments:
;     rdi : number of bytes requested.
; returns:
;     rax : pointer to found chunk, or 0 if not found.
;
_malloc_lifo_find_fit:
    ; save clobbered registers.
    push rcx
    ; skip if there are no lifo entries.
    cmp qword [_malloc_lifo_count], 0
    je .return_null
    ; iterate on rcx, start from most recent.
    mov rcx, [_malloc_lifo_last_ptr]
.loop:
    ; fits?
    cmp qword rdi, [rcx + _malloc_chunk_header.bytes]
    jle .found
    mov rcx, [rcx + _malloc_chunk_header.p_prev_free]
    test rcx, rcx
    jnz .loop
.not_found:
    xor rax, rax
    jmp .done
.found:
    mov rax, rcx
    jmp .done
.return_null:
    xor rax, rax
.done:
    ; restore clobbered registers.
    pop rcx
    ret

; remove a chunk from the lifo stack.
; 
; arguments:
;     rdi : pointer to chunk's data.
;
_malloc_lifo_remove:
    call _malloc_lifo_find
    test rax, rax
    jz .done
    push rdi
    mov rdi, rax
    call _malloc_lifo_remove_entry
    pop rdi
.done:
    ret

%endif
