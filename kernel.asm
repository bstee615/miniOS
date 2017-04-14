bits 16

org 0x100

section .text

;-------------------------------------------------
;                       BUGS:
; - line 55:  there is some issue with dynamically adding the right stack address to the stack. Getting closer.
;-------------------------------------------------

main:
    ; set up thread 1
    ; set up thread 2
    call setup

func1:
    mov dx, msg_taska
    call puts
    mov dx, padwithspaces
    call puts
    call yield
    jmp func1
func2:
    mov dx, msg_taskb
    call puts
    mov dx, padwithspaces
    call puts
    call yield
    jmp func2
func3:
    mov dx, msg_taskc
    call puts
    mov dx, padwithspaces
    call puts
    call yield
    jmp func3

yield:
    ; save first state registers
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    push bp

    ; advance thread number
    mov dx, [num_threads]
    cmp dx, [current_thread]
    jl first_yield
    mov word [current_thread], 0
.inc_word:
    inc word [current_thread]

    ; switch to second state context
first_yield:

    ; there is some issue with dynamically adding the right stack address to the stack.
    ; Getting closer.
    mov bx, [current_thread]
    add bx, bx

    xchg sp, [stack_pointer + bx]

    ; restore second state context
    pop bp
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax

    ret

; ax is the location of the bottom of the stack.
; bx is stack size.
; cx is the location of the next function's first instruction.
start_thread:
    ; set up stack1.
    ; push instruction pointer for func1 to stack 1.
    mov [original_sp], sp
    add ax, bx
    mov sp, ax

    ; this is critical to switching between functions, I think.
    ; better work on it.
    push cx

    ; make space for the 7 registers
    push 0
    push 0
    push 0
    push 0
    push 0
    push 0

    ;cmp word [num_threads], 0
    ;ne .not_first
    
    ; This ensures that when switching to this stack, the OS will pop register states from this stack and not the stack above.
    sub ax, 0x10

;.not_first:
    push ax

    push bx
    
    mov bx, [num_threads]
    add bx, bx
    mov [stack_pointer + bx], ax ; save sp internally.

    pop bx

    mov sp, [original_sp]
    inc word [num_threads]

    ret

setup:
    ; setup func1:
    mov ax, 0x500
    mov bx, 0x100
    mov cx, func1
    call start_thread
    
    ; setup func2:
    mov ax, 0x600
    mov bx, 0x100
    mov cx, func2
    call start_thread
    
    ; setup func3:
    mov ax, 0x700
    mov bx, 0x100
    mov cx, func3
    call start_thread

    ; Have to manually set sp so that the stack pointer manager saves the right address for stack 2.
    mov sp, 0x600 - 0x10
    jmp first_yield

    ; should never get here.
    mov ah, 0x0e
    mov al, '!'
    int 0x10

    mov word [current_thread], 0

    ret

; Sly-ly ripped from Mr. J's lab 9
; ---------------------------------------------------------------------
; print NUL-terminated string from DS:DX to screen using BIOS (INT 10h)
; takes NUL-terminated string pointed to by DS:DX
; clobbers nothing
; returns nothing
puts:
	push	ax
	push	cx
	push	si
	
	mov	ah, 0x0e
	mov	cx, 1		; no repetition of chars
	
	mov	si, dx
.loop:	mov	al, [si]
	inc	si
	cmp	al, 0
	jz	.end
	int	0x10
	jmp	.loop
.end:
	pop	si
	pop	cx
	pop	ax
	ret


section .data
    ; more funcs
    num_threads dw 0
    current_thread  dw 0
    stack_pointer times 32 dw 0

    ; two funcs
    original_sp dw 0
    msg_taska   db "I am task A!", 0
    msg_taskb   db "I am task B!", 0
    msg_taskc   db "I am task C!", 0
    padwithspaces   db "                                                                    ",0

;section .bss
 ;   stack_pointer: resb 64