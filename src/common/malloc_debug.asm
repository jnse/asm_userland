%ifndef MALLOC_DEBUG_INCL
%define MALLOC_DEBUG_INCL

%include "malloc.asm" 
%include "malloc_heap.asm"

section .bss

    ; itoa buffer for debugging.
    _malloc_debug_buffer: resq 1

section .data

    ; debug strings.
    _malloc_msg_debug_next_chunk db "Chunk at : ", 0
    _malloc_msg_debug_bytes db  "    bytes  : ", 0
    _malloc_msg_debug_p_data db "    pdata  : ", 0
    _malloc_msg_debug_free db   "    free   : ", 0
    _malloc_msg_debug_pnext db  "    pnext  : ", 0
    _malloc_msg_debug_pprev db  "    pprev  : ", 0

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
    mov qword rsi, [rcx + _malloc_chunk_header.free]
    call itoa_hex
    call println
    ; restore clobbered registers. 
    pop rax
    pop rdi
    pop rcx
    ret

; dump all chunks.
malloc_debug_chunks:
    push rcx
    push rsi
    push rdi
    push rax
    mov qword rcx, [_malloc_heap_size]
    test rcx, rcx
    jz .done 
    mov qword rcx, [_malloc_heap_start]
.debug_loop:
    mov rdi, rcx
    push rcx
    call malloc_debug_chunk
    pop rcx
    ; move to next chunk
    add rcx, [rcx + _malloc_chunk_header.bytes]
    add rcx, _malloc_chunk_header_size
.next:
    ; loop
    cmp rcx, [_malloc_mem_cursor]
    jg .done
    jmp .debug_loop
.done:
    pop rax
    pop rdi
    pop rsi
    pop rcx
    ret

%endif
