%ifndef MALLOC_DEBUG_INCL
%define MALLOC_DEBUG_INCL

%include "malloc/malloc.asm" 
%include "malloc/malloc_heap.asm"

section .bss

    ; itoa buffer for debugging.
    _malloc_debug_buffer: resq 1

section .data

    ; debug strings.
    _malloc_msg_debug_next_chunk db "Chunk at        : ", 0
    _malloc_msg_debug_bytes db "    bytes       : ", 0
    _malloc_msg_debug_p_data db "    pdata       : ", 0
    _malloc_msg_debug_free db "    free        : ", 0
    _malloc_msg_debug_p_next db "    p_next      : ", 0
    _malloc_msg_debug_p_prev db "    p_prev      : ", 0
    _malloc_msg_debug_p_prev_free db "    p_prev_free : ", 0
    _malloc_msg_debug_p_next_free db "    p_next_free : ", 0
    _malloc_msg_debug_chunks_allocated db "ALLOCATED CHUNKS:", 0
    _malloc_msg_debug_chunks_free db "FREE CHUNKS:", 0
section .text

; dump all fields of a malloc chunk.
;
; arguments:
;     rdi : pointer to chunk
;
malloc_debug_chunk:
    ; save clobbered registers.
    push rcx
    push rdi
    push rax
    ; save chunk pointer.
    mov rcx, rdi
    ; print chunk address
    push rcx
    mov qword rdi, _malloc_msg_debug_next_chunk
    call print
    mov rdi, _malloc_debug_buffer
    pop rsi
    push rsi
    call itoa_hex
    call println
    ; print chunk bytes
    mov qword rdi, _malloc_msg_debug_bytes
    call print
    mov rdi, _malloc_debug_buffer
    pop rcx
    mov qword rsi, [rcx + _malloc_chunk_header.bytes]
    push rcx
    call itoa
    call println
    ; print chunk data ptr
    mov qword rdi, _malloc_msg_debug_p_data
    call print
    mov rdi, _malloc_debug_buffer
    pop rcx
    push rcx
    mov qword rsi, [rcx + _malloc_chunk_header.p_data]
    call itoa_hex
    call println
    ; print free
    mov qword rdi, _malloc_msg_debug_free
    call print
    mov rdi, _malloc_debug_buffer
    pop rcx
    push rcx
    mov qword rsi, [rcx + _malloc_chunk_header.free]
    call itoa_hex
    call println
    ; print p_prev
    mov qword rdi, _malloc_msg_debug_p_prev
    call print
    mov rdi, _malloc_debug_buffer
    pop rcx
    push rcx
    mov qword rsi, [rcx + _malloc_chunk_header.p_prev]
    call itoa_hex
    call println
    ; print p_next
    mov qword rdi, _malloc_msg_debug_p_next
    call print
    mov rdi, _malloc_debug_buffer
    pop rcx
    push rcx
    mov qword rsi, [rcx + _malloc_chunk_header.p_next]
    call itoa_hex
    call println
    ; print p_prev_free
    mov qword rdi, _malloc_msg_debug_p_prev_free
    call print
    mov rdi, _malloc_debug_buffer
    pop rcx
    push rcx
    mov qword rsi, [rcx + _malloc_chunk_header.p_prev_free]
    call itoa_hex
    call println
    ; print p_next_free
    mov qword rdi, _malloc_msg_debug_p_next_free
    call print
    mov rdi, _malloc_debug_buffer
    pop rcx
    mov qword rsi, [rcx + _malloc_chunk_header.p_next_free]
    call itoa_hex
    call println
    ; restore clobbered registers. 
    pop rax
    pop rdi
    pop rcx
    ret

; dumps all allocated chunks.
malloc_debug_chunks:
    push rcx
    push rsi
    push rdi
    push rax
    mov rdi, _malloc_msg_debug_chunks_allocated
    call println
    mov qword rcx, [_malloc_chunk_count]
    test rcx, rcx
    jz .done 
    mov qword rcx, [_malloc_chunk_first_ptr]
.debug_loop:
    mov rdi, rcx
    push rcx
    call malloc_debug_chunk
    pop rcx
    ; move to next chunk
    mov rcx, [rcx + _malloc_chunk_header.p_next]
    test rcx, rcx
    jnz .debug_loop
.done:
    pop rax
    pop rdi
    pop rsi
    pop rcx
    ret

; dumps the stack of freed chunks.
malloc_debug_free_stack:
    push rcx
    push rdi
    mov rdi, _malloc_msg_debug_chunks_free
    call println    
    mov qword rcx, [_malloc_lifo_first_ptr]
.debug_loop:
    test rcx, rcx
    jz .done
    mov rdi, rcx
    push rcx
    call malloc_debug_chunk
    pop rcx
    mov rcx, [rcx + _malloc_chunk_header.p_next_free]
    jmp .debug_loop
.done:
    pop rdi
    pop rcx
    ret

%endif
