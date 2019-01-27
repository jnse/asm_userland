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

%include "malloc_heap.asm"
%include "malloc_chunk.asm"
%include "malloc_lifo.asm"

SECTION .bss

    _malloc_mem_cursor: resq 1      ; always points to the chunk at heap edge.
    _malloc_first: resb 1           ; first chunk flag
    _malloc_last_free_cache: resq 1 ; Pointer to the last freed chunk.
    _malloc_last_free_size: resq 1  ; Pointer tot he last freed chunk's size.
    _malloc_free_counter: resq 1    ; Counts number of available free chunks.

SECTION .data
   
   ; error strings.
    _malloc_msg_failed db "Malloc failed.", 0
    _free_msg_no_chunk db "Free: could not find chunk to release.", 0
    _free_msg_add_fail db "Free: could not add free chunk to stack.", 0

SECTION .text

%include "syscalls.asm"
%include "print.asm"

init_memory:
    call _malloc_heap_init
    call _malloc_chunk_init
    call _malloc_lifo_init
    ret

; allocates memory.
;
; arguments:
;     rdi : number of bytes to allocate.
; returns:
;     rax : pointer to allocated memory.
;
malloc:
.handle_null:
    ; save clobbered registers.
    push rcx
    push rdx
    ; allocating 0 bytes means don't do anything.
    test rdi, rdi
    jz .return_null
    ; TODO: attempt to use bin cache
    call _malloc_chunk_create
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

; free: releases memory allocated with malloc.
;
; arguments:
;     rdi : pointer to address of memory to be freed.
;
free:
    call _malloc_chunk_find
    test rax, rax
    jz .chunk_not_found_error
    push rax
    mov rdi, rax
    call _malloc_lifo_add_chunk
    test rax, rax
    pop rax
    jz .chunk_add_error
    mov rdi, rax
    call _malloc_remove_chunk
    jmp .done
.chunk_not_found_error:
    push rdi
    mov rdi, _free_msg_no_chunk
    call println
    pop rdi
    jmp .done
.chunk_add_error:
    push rdi
    mov rdi, _free_msg_add_fail
    call println
    pop rdi
.done:
    ret

%endif
