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

    _malloc_first: resb 1           ; first chunk flag
    _malloc_last_free_cache: resq 1 ; Pointer to the last freed chunk.
    _malloc_last_free_size: resq 1  ; Pointer tot he last freed chunk's size.    
    ; malloc chunk header fields
    struc _malloc_chunk_header
        .bytes: resq 1              ; size of chunk in bytes.
        .p_data: resq 1             ; pointer to chunk data.
        .free: resb 1               ; chunk free flag.
        .p_next: resq 1             ; pointer to next chunk.
        .p_prev: resq 1             ; pointer to previous chunk.
    endstruc

    ; free chunk stack
    struc _malloc_free_chunk_stack
        .p_next: resq 1             ; pointer to next bin.
        .p_prev: resq 1             ; pointer to prev bin
        .p_chunk: resq 1            ; pointer to first child chunk
    endstruc
    ; pointer to first free chunk bin (if any).
    _malloc_free_chunk_stack: resq 1 
    ; pointer to the last entry in the free chunk stack.
    _malloc_free_chunk_stack_last: resq 1 


SECTION .data
   
    ; allocate at least this many bytes (one page seems reasonable).
    _malloc_page_size equ 4096
    ; error strings.
    _malloc_msg_failed db "Malloc failed.", 0
    _free_msg_no_chunk db "Free: could not find chunk to release.", 0

SECTION .text

%include "syscalls.asm"
%include "print.asm"

; constructor -----------------------------------------------------------------

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
    mov qword [_malloc_heap_free], 0
    mov qword [_malloc_free_chunk_stack], 0
    mov qword [_malloc_free_chunk_stack_last], 0
    ; restore registers.
    pop rdi
    pop rax
    ret

; heap management -------------------------------------------------------------

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
    ; if space required is less than the page size, alloc page size.
    cmp rdi, _malloc_page_size
    jg .call_brk
    mov rdi, _malloc_page_size
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
    xor rax, rax
    jmp .done
.not_full:
    mov rax, 1
.done:
    ret

; checks if we can fit a new chunk cache entry in the heap without growing it.
;
; returns:
;     rax : set to 0 if heap full.
;           set to 1 if fits.
malloc_can_fit_cache_entry:
    mov rax, [_malloc_heap_free]
    sub rax, _malloc_free_chunk_stack_size
    jc .full
    mov rax,1
    jmp .done
.full
    xor rax, rax
.done
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

; grows heap if needed to fit a free chunk cache entry.
;
; returns:
;     rax : 0 on failure, 1 on success.
;
malloc_grow_if_needed_for_cache:
    ; save clobbered registers.
    push rdi
    ; check if there's room on the heap.
    mov rdi, _malloc_free_chunk_stack_size
    call malloc_can_fit_cache_entry
    test rax, rax
    jnz .success
    ; not enough room, make some.
    call malloc_grow_heap
    test rax, rax
    jz .failed
.success:    
    mov rax, 1
    jmp .done
.failed:
    xor rax,rax
.done
    ; restore clobbered registers.
    pop rdi
    ret

; chunk management ------------------------------------------------------------

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
    push rbx
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
    ; make rbx point to the old chunk.
    mov rbx, [_malloc_mem_cursor]
    ; write new chunk fields. 
    mov qword [rdx + _malloc_chunk_header.bytes], rdi
    mov qword [rdx + _malloc_chunk_header.p_data], rcx
    mov byte [rdx + _malloc_chunk_header.free], 0
    mov qword [rdx + _malloc_chunk_header.p_prev], rbx
    mov qword [rbx + _malloc_chunk_header.p_next], rcx
    mov qword [rdx + _malloc_chunk_header.p_next], 0
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
    pop rbx
    pop rcx
    pop rdx
    ret

; free chunk management -------------------------------------------------------

; creates a free chunk in the free chunk stack.
;
; arguments:
;     rdi : pointer to chunk
; returns:
;     rax : pointer to free chunk.
;           or 0 if failed.
;
malloc_create_free_chunk:
    ; save clobbered registers.
    push rdx
    ; make sure there is room on the heap.
    call malloc_grow_if_needed_for_cache
    test rax, rax
    jz .failed
    ; find start of free memory.
    mov rax, [_malloc_heap_end]
    sub rax, [_malloc_heap_free]
    ; save pointer to the last free chunk on the stack.
    mov rdx, [_malloc_free_chunk_stack_last]
    ; populate fields.
    mov [rax + _malloc_free_chunk_stack.p_next], 0
    mov [rax + _malloc_free_chunk_stack.p_prev], rdx
    mov [rax + _malloc_free_chunk_stack.p_chunk], rdi
    ; update last free chunk's next pointer.
    mov [rdx + _malloc_free_chunk_stack.p_next], rax
    ; update pointer to last free chunk.
    mov [_malloc_free_chunk_stack_last], rax
    ; increment free chunks.
    inc [_malloc_free_chunk_stack_size]
    jmp .done 
.failed:
    xor rax, rax
.done:
    ; restore clobbered registers.
    pop rdx
    ret

; finds a free chunk to fit given size.
;
; arguments:
;     rdi : pointer to chunk.
; returns:
;     rax : pointer to free chunk.
;           0 if none found.
;
malloc_find_free_chunk:
    ; save clobbered registers.
    push rcx
    ; rcx = iterator - start searching from most recently freed.
    mov rcx, [_malloc_free_chunk_stack_last]
    test rcx, rcx
    jz .failed
    ; skip if there's no free blocks.
    cmp [_malloc_free_chunk_stack_size], 0
    jmp .failed
.loop:
    ; rax keeps a pointer to the chunk.
    mov rax, [rcx + _malloc_free_chunk_stack.p_chunk]
    test rax, rax
    jz .next_free_bin
    ; free chunk big enough?
    cmp rdi, [rax + _malloc_chunk_header.bytes]
    jle .done
.next_free_bin:
    mov rcx, [rcx + _malloc_free_chunk_stack.p_prev]
    test rcx, rcx
    jnz .loop
.failed:
    xor rax, rax
.done:
    ; restore clobbered registers.
    pop rcx
    ret

; consumes a free chunk.
;
; arguments:
;    rdi : pointer to free chunk.
; returns:
;    rax : pointer to chunk.
;
malloc_consume_free_chunk:
    ; for now just remove pointers to this chunk.
    ; rcx = prev chunk.
    mov rcx, [rdi + _malloc_free_chunk_stack.p_prev]
    test rcx, rcx
    jz .update_next
    ; rdx = next chunk.
    mov rdx, [rdi + _malloc_free_chunk_stack.p_next]
    test rdx, rdx
    jz .update_prev
    ; stitch prev+next togeather.
    mov [rcx + _malloc_free_chunk_stack.p_next], rdx
    mov [rdx + _malloc_free_chunk_stack.p_prev], rcx
    jmp .done
.update_prev:    
    mov rcx, [rdi + _malloc_free_chunk_stack.p_prev]
    test rcx, rcx
    jz .update_next
    mov [rcx + _malloc_free_chunk_stack.p_next], 0
.update_next:
    mov rcx, [rdi + 

; end-user functions. ---------------------------------------------------------

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
    je .check_heap
    cmp qword [_malloc_last_free_size], rdi
    jne .check_heap
.use_cache:
    ; mark cached block as used, and return it.
    mov qword [_malloc_last_free_cache + _malloc_chunk_header.free], 0
    mov qword rcx, [_malloc_last_free_cache]
    mov qword rax, [rcx + _malloc_chunk_header.p_data]
    ; consume cache
    ; TODO TODO TODO 
    mov qword [_malloc_last_free_cache], 0
    mov qword [_malloc_last_free_size], 0
    dec qword [_malloc_free_counter]
    jmp .done
.check_heap:
    ; if the chunk will fit in the heap, just create it.
    ; otherwise, see if we can re-use a free block.
    call malloc_can_fit_chunk
    test rax, rax
    jnz .create_chunk
.try_reuse_free:
    call malloc_find_free_chunk
    test rax,rax
    jz .create_chunk
    ; rax now points to a usable chunk.
    ; if it's too big, we might have to split it.
    mov rsi, rax
    call malloc_split_chunk
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
    push rdx
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
    mov qword rdx, [rcx + _malloc_chunk_header.bytes]
    mov qword [_malloc_last_free_size], rdx
.check_prev:
    ; if there's a previous chunk, zero it's next chunk ptr.
    cmp qword [rcx + _malloc_chunk_header.p_prev], 0
    je .check_next
    mov qword rdx, [rcx + _malloc_chunk_header.p_prev]
    mov qword [rdx + _malloc_chunk_header.p_next], 0
.check_next
    ; if there's a next chunk, zero it's prev chunk ptr.
    cmp qword [rcx + _malloc_chunk_header.p_next], 0
    je .done_free
    mov qword rdx, [rcx + _malloc_chunk_header.p_next]
    mov qword [rdx + _malloc_chunk_header.p_prev], 0
.done_free:
    ; increment free chunk counter.
    inc qword [_malloc_free_counter]
    ; place free chunk in a free chunk bin.
    push rdi
    mov rdi, rcx
    call place_free_chunk_in_bin
    pop rdi
    jmp .done
.chunk_not_found_error:
    mov rdi, _free_msg_no_chunk
    call println
.done:
    ; restore clobbered registers and return.
    pop rax
    pop rcx
    pop rdx
    ret

%endif
