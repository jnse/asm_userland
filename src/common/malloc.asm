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

    _malloc_heap_size: resq 1       ; stores heap size.
    _malloc_heap_start: resq 1      ; stores heap start address.
    _malloc_heap_end: resq 1        ; stores heap end address.
    _malloc_heap_free: resq 1       ; stores how many bytes of heap space is free.
    _malloc_mem_cursor: resq 1      ; always points to the chunk at heap edge.

    _malloc_debug_buffer: resq 1    ; itoa buffer for debugging.
    _malloc_first: resb 1           ; first chunk flag
    _malloc_last_free_cache: resq 1 ; Pointer to the last freed chunk.
    _malloc_last_free_size: resq 1  ; Pointer tot he last freed chunk's size.
    _malloc_free_counter: resq 1    ; Counts number of available free chunks.
    ; malloc chunk header fields
    struc _malloc_chunk_header
        .bytes: resq 1              ; size of chunk in bytes.
        .p_data: resq 1             ; pointer to chunk data.
        .free: resb 1               ; chunk free flag.
    endstruc
    ; free chunk bin (double linked-list)
    struc _malloc_free_chunk_bin
        .min: resq 1                ; no free chunks < min in this bin.
        .max: resq 1                ; no free chunks > max in this bin.
        .p_next: resq 1             ; pointer to next bin.
        .p_prev: resq 1             ; pointer to prev bin
        .p_chunk: resq 1            ; pointer to first child chunk
        .num_chunk: resq 1          ; number of child chunks.
    endstruc
    _malloc_free_chunk_tree: resq 1 ; pointer to first free chunk bin (if any).

SECTION .data
   
    ; allocate at least this many bytes (one page seems reasonable).
    _malloc_minimum_chunk_size equ 4096
    ; error strings.
    _malloc_msg_failed db "Malloc failed.", 0
    _free_msg_no_chunk db "Free: could not find chunk to release.", 0
    ; debug strings.
    _malloc_msg_debug_next_chunk db "Chunk at : ", 0
    _malloc_msg_debug_bytes db  "    bytes  : ", 0
    _malloc_msg_debug_p_data db "    pdata  : ", 0
    _malloc_msg_debug_free db   "    free   : ", 0

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
    mov qword [_malloc_heap_end], rax
    ; Init heap size.
    mov qword [_malloc_heap_size], 0
    ; Init first chunk flag.
    mov qword [_malloc_first], 1
    ; Init freed chunk cache.
    mov qword [_malloc_last_free_cache], 0
    mov qword [_malloc_last_free_size], 0
    mov qword [_malloc_free_counter], 0
    mov qword [_malloc_heap_free], 0
    mov qword [_malloc_free_chunk_tree], 0
    ; restore registers.
    pop rdi
    pop rax
    ret

; arguments:
;     rdi : size of requested chunk.
; WORK IN PROGRESS
malloc_find_free_chunk:
    ; skip if there isn't any.
    cmp qword [_malloc_free_counter], 0
    je .done
    ; rcx = iterator.
    mov qword rcx, [_malloc_free_chunk_tree]
.loop:
    ; check size boundaries.
    cmp qword rdi, [rcx + _malloc_free_chunk_bin.min]
    jl .prev
    cmp qword rdi, [rcx + _malloc_free_chunk_bin.max]
    jg .next
.found_bin:
    ; find fitting chunk in bin.
    jmp .done
.prev
    ; move to prev bin (if any).
    cmp qword [rcx + _malloc_free_chunk_bin.p_prev], 0
    je .done
    mov qword rcx, [rcx + _malloc_free_chunk_bin.p_prev]
    jmp .loop
.next:
    ; move to next bin (if any).
    cmp qword [rcx + _malloc_free_chunk_bin.p_next], 0
    je .done
    mov qword rcx, [rcx + _malloc_free_chunk_bin.p_next]
    jmp .loop
.done:
    ret

; dump all fields of a malloc chunk.
;
; arguments:
;     rdi : pointer to chunk
;
malloc_debug_fields:
    push rcx
    push rdi
    push rax
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
    pop rax
    pop rdi
    pop rcx
    ret

; dump all chunks.
malloc_debug:
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
    call malloc_debug_fields
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

; malloc_grow_heap : grows program heap.
;
; arguments: 
;     rdi : number of bytes to grow by.
; returns: 
;     rax : number of bytes allocated.
;
malloc_grow_heap:
    ; save clobbered registers.
    push rdi
    push rdx
    ; if space required is less than minimum chunk size, alloc chunk size.
    cmp rdi, _malloc_minimum_chunk_size
    jg .call_brk
    mov rdi, _malloc_minimum_chunk_size
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

; checks if we can fit a new chunk in the heap without growing it.
;
; arguments:
;     rdi : requested chunk size.
;
; returns:
;     rax : set to 0 if heap full.
;           set to 1 if fits.
malloc_can_fit_chunk:
    ; take our free memory and subtract requested blocks.
    mov rax, [_malloc_heap_free]
    sub rax, rdi
    jc .full
    ; if we're still good, subtract chunk header size.
    sub rax, _malloc_chunk_header_size
    jc .full
    ; if we're still good at this point, we're done.
    jmp .not_full
.full:
    mov rax, 0
    jmp .done
.not_full:
    mov rax, 1
.done:
    ret

; malloc_grow_if_needed_for_chunk : grows heap if needed to fit a chunk.
;
; arguments:
;     rdi : requested chunk size.
; returns:
;     rax : 0 on failure, allocated bytes on success.
malloc_grow_if_needed_for_chunk:
    ; check space
    call malloc_can_fit_chunk
    test rax, rax
    jnz .done
.alloc_heap_space:
    ; if we got here, we need more space.
    call malloc_grow_heap
.done:
    ret

; malloc_create_chunk : creates a chunk of memory.
; 
; A chunk of memory is basically an allocation the user
; requested with a malloc call, plus headers for malloc
; accounting.
;
; arguments:
;     rdi: amount of bytes to allocate.
; returns:
;     rax : address of requested memory.
;
malloc_create_chunk:
    ; save clobbered registers.
    push rdx
    push rcx
    ; allocate more heap space if needed.
    mov qword rdx, [_malloc_heap_end]
    call malloc_grow_if_needed_for_chunk
    ; check for failure.
    test rax, rax
    jz .failed
    ; if this is the first chunk, we don't
    ; allocate behind the previous chunk (there is none).
    cmp byte [_malloc_first], 1
    je .first_chunk
    ; rdx points to our to-be-created chunk.
    mov qword rdx, [_malloc_mem_cursor]
    add qword rdx, [rdx+_malloc_chunk_header.bytes]
    add qword rdx, _malloc_chunk_header_size
    jmp .populate_chunk_fields
.first_chunk:
    ; if first chunk, alloc at heap start and reset
    ; first chunk flag.
    mov rdx, [_malloc_heap_start]
    mov byte [_malloc_first], 0
.populate_chunk_fields:
    ; make rcx point to the new chunk data.
    mov rcx, rdx
    add rcx, _malloc_chunk_header_size
    ; write new chunk fields. 
    mov qword [rdx + _malloc_chunk_header.bytes], rdi
    mov qword [rdx + _malloc_chunk_header.p_data], rcx
    mov byte [rdx + _malloc_chunk_header.free], 0
    ; move memory cursor to start of new chunk.
    mov qword [_malloc_mem_cursor], rdx
    ; consume free heap space.
    sub qword [_malloc_heap_free], _malloc_chunk_header_size
    sub qword [_malloc_heap_free], rdi
    ; save result (ptr to data) in rax.
    mov rax, rcx
    jmp .done
.failed:
    xor rax, rax
.done:
    pop rcx
    pop rdx
    ret

; malloc : allocates memory.
;
; arguments: 
;     rdi : number of bytes to allocate.
; returns : 
;     rax = pointer to allocated memory.
;
malloc:
.handle_null:
    ; save clobbered registers.
    push rcx
    push rdx
    ; allocating 0 bytes means don't do anything.
    test rdi, rdi
    jz .return_null
.is_cache_usable:
    ; if cache size is an exact match in size, use it!
    cmp qword [_malloc_last_free_cache], 0
    je .create_chunk
    cmp qword [_malloc_last_free_size], rdi
    jne .create_chunk
.use_cache:
    ; mark cached block as used, and return it.
    mov qword [_malloc_last_free_cache + _malloc_chunk_header.free], 0
    mov qword rcx, [_malloc_last_free_cache]
    mov qword rax, [rcx + _malloc_chunk_header.p_data]
    ; consume cache
    mov qword [_malloc_last_free_cache], 0
    mov qword [_malloc_last_free_size], 0
    dec qword [_malloc_free_counter]
    jmp .done
.create_chunk:
    call malloc_create_chunk
    test rax, rax
    jnz .done
.return_null:
    mov rdi, _malloc_msg_failed
    call println
    xor rax, rax
.done:
    ; restore clobbered registers and return.
    pop rdx
    pop rcx
    ret

; free: releases memory allocated with malloc.
;
; arguments:
;     rdi : pointer to address of memory to be freed.
;
free:
    ; save clobbered registers.
    push rcx
    push rax
.find_chunk_to_free:
    ; skip if heap size is 0
    mov qword rcx, [_malloc_heap_size]
    test rcx, rcx
    jz .chunk_not_found_error
    mov qword rcx, [_malloc_heap_start] ; use rcx as our iterator.
.find_chunk_to_free_loop:
    ; is our iterator is past the cursor?
    cmp rcx, [_malloc_mem_cursor]
    jg .chunk_not_found_error
    ; Is this our chunk?
    mov rax, [rcx + _malloc_chunk_header.p_data]
    cmp rax, rdi
    je .mark_chunk_as_free
    ; no? move rcx ptr to the start of the next chunk.
    mov rax, [rcx + _malloc_chunk_header.bytes]
    add qword rcx, _malloc_chunk_header_size
    add qword rcx, rax
    jmp .find_chunk_to_free_loop ; keep looking.    
.mark_chunk_as_free:
    ; when we get here, rcx points to the chunk we're looking to free.
    mov byte [rcx + _malloc_chunk_header.free], 1 ; do the deed.
    ; save a pointer to this chunk and it's size in case we can re-use it.
    mov qword [_malloc_last_free_cache], rcx
    push rdx
    mov qword rdx, [rcx + _malloc_chunk_header.bytes]
    mov qword [_malloc_last_free_size], rdx
    pop rdx
    ; increment free chunk counter.
    inc qword [_malloc_free_counter]
    jmp .done
.chunk_not_found_error:
    mov rdi, _free_msg_no_chunk
    call println
.done:
    ; restore clobbered registers and return.
    pop rax
    pop rcx
    ret

%endif
