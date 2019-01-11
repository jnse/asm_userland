;
; This is a fairly simple, but probably not very efficient malloc.
;
;   * uses the BRK syscall to expand the heap if needed.
;   * memory is allocated in chunks with a header and the actual data.
;   * chunks are laid out back-to-back on the heap
;
; | CHUNK HEADER | CHUNK DATA || CHUNK HEADER | CHUNK DATA || etc...
;
; init_memory needs to be called on program start to initialize some pointers 
; and  counters.
;
; A malloc starts with a search for an unused chunk of any size that will
; accomodate the requested size. If found, it will be used.
; (obvously this is a costly search, and could be very wasteful).
; 
; If the search comes up dry, we check to see if there's enough free space on
; the heap to accomodate a new chunk. 
; 
; If needed, BRK is called to grow heap space to accomodate the 
; new chunk header + data (which effectively means that once the initial heap
; space is used up, you'll always be calling BRK until you free chunks).
;

%ifndef MALLOC_INCL
%define MALLOC_INCL

extern _end

SECTION .bss

    _malloc_heap_size: resq 1  ; stores heap size.
    _malloc_heap_start: resq 1 ; stores heap start address.
    _malloc_mem_cursor: resq 1 ; always points to the chunk at heap edge.

    ; malloc chunk header fields
    struc _malloc_chunk_header
      .bytes: resq 1
      .p_data: resq 1
      .free: resb 1
    endstruc

    debugstr: resb 22

SECTION .data
    
    _malloc_chunk_size equ 4096
    _malloc_msg_failed db "Malloc failed.", 10, 0

SECTION .text

%include "syscalls.asm"
%include "print.asm"

init_memory:
    ; save registers
    push rax
    push rdi
    ; get heap start, set cursor
    mov rax, syscall_brk
    xor rdi, rdi
    syscall
    mov qword [_malloc_heap_start], rax
    mov qword [_malloc_mem_cursor], rax
    ; Init heap size.
    mov qword [_malloc_heap_size], 0
    ; restore registers.
    pop rdi
    pop rax
    ret

; print value in rdi
debug:
    push rdi
    push rsi
    mov rsi, rdi
    mov rdi, debugstr
    call itoa_hex
    call println
    pop rsi
    pop rdi
    ret

; malloc : allocates memory.
;
; arguments: rdi : Number of bytes to allocate.
; returns : rax = pointer to allocated memory.
;
malloc:
.handle_null:
    ; save clobbered registers.
    push rcx
    push rdx
    ; allocating 0 bytes means don't do anything.
    test rdi, rdi
    jz .return_null
.find_free_chunk:
    mov qword rcx, [_malloc_heap_start] ; use rcx as our iterator.
.find_free_chunk_loop:
    ; is our iterator is past the cursor?
    cmp rcx, _malloc_mem_cursor
    jg .check_free_heap_space ; then move on to create a new chunk.
    ; is current chunk free?
    mov rax, [rcx + _malloc_chunk_header.free]
    test rax,rax
    jnz .found_free_chunk
    ; no?, move rcx ptr to the start of the next chunk.
    mov rax, [rcx + _malloc_chunk_header.bytes]
    add qword rcx, _malloc_chunk_header_size
    add qword rcx, rax
    jmp .find_free_chunk_loop ; keep looking.
.found_free_chunk:
    ; now that we found a free chunk, we should check if it's big enough.
    cmp rax, rdi
    jl .find_free_chunk_loop ; too small, keep looking.
.found_good_chunk:
    ; we found a usable chunk, mark it as used.
    mov byte [rcx + _malloc_chunk_header.free], 0
    mov qword rax, [rcx + _malloc_chunk_header.p_data]
    jmp .done
.check_free_heap_space:
    ; heap_size - (memory requested + chunk_header_size) < 0 ?
    mov qword rax, [_malloc_heap_size]
    push rdi ; save requested space because we'll be adding chunk header size.
    add qword rdi, _malloc_chunk_header_size
    sub rax, rdi ; should set overflow flag when going below zero.
    pop rdi ; restore original requested memory size to rdi.
    jc .alloc_heap_space ; if CF set by sub (shouldn't be cleared by pop)
    jmp .create_chunk
.alloc_heap_space:
    push rdi ; save requested space because we'll be adding chunk header size.
    ; space required = space requested + chunk_header_size.
    add qword rdi, _malloc_chunk_header_size
    add qword rdi, [_malloc_heap_start]
    ; use BRK to allocate more heap space.
    mov rax, syscall_brk
    syscall 
    pop rdi ; restore original requested memory size to rdi.
    ; check for failure.
    cmp rax, [_malloc_heap_start]
    je .return_null
    ; our heap size is now bigger by requested space.
    add qword [_malloc_heap_size], rdi
.create_chunk:
    ; rax points to the previous chunk
    mov rax, [_malloc_mem_cursor]  
    ; but wait, are we the first chunk?
    cmp rax, [_malloc_heap_start]
    jle .first_chunk
    ; rdx points to our to-be-created chunk.
    mov rdx, rax
    add qword rdx, [rax+_malloc_chunk_header.bytes]
    add qword rdx, _malloc_chunk_header_size
    jmp .populate_chunk_fields
.first_chunk:
    mov rdx, [_malloc_heap_start]
.populate_chunk_fields:
    ; rcx points to the new chunk data.
    mov rcx, rdx
    add rcx, _malloc_chunk_header_size
    ; write new chunk fields. 
    mov qword [rdx + _malloc_chunk_header.bytes], rdi
    mov qword [rdx + _malloc_chunk_header.p_data], rcx
    mov byte [rdx + _malloc_chunk_header.free], 0
    ; move memory cursor to start of new chunk data.
    mov qword [_malloc_mem_cursor], rdx
    ; save result (ptr to data) in rax.
    mov rax, rcx
    jmp .done
.return_null:
    mov rdi, _malloc_msg_failed
    call println
    xor rax, rax
.done:
    ; restore clobbered registers and return.
    pop rdx
    pop rcx
    ret

%endif
