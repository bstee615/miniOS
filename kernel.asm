bits 16

org 0x100

section .text

;-------------------------------------------------
;                       BUGS:
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

yield:
    ; save first state registers
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    push bp
    ; switch to second state context
first_yield:

    ; I think this is the problem - in start_thread we change sp to the TOP of each stack,
    ; so we're actually popping values from above stack 1.
    xchg sp, [saved_sp]
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
push ax
    mov ah, 0x0e
    mov al, '2'
    int 0x10
pop ax
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
    push ax
    mov [saved_sp], ax ; save sp internally.
    mov sp, [original_sp]

    ; TODO: add functionality to sub 0x10 (16 bytes) from saved_sp starting point so that sp starts from the right place.

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

    ; should start func1. This should NOT be manual, especially once we have more than two tasks
    ; Maybe it could be manual once we add multiple (more than two stacks) functionality
    mov sp, 0x700 - 0x10 ; end of stack 1
    mov word [saved_sp], 0x600  - 0x10
    jmp first_yield

    ; should never get here.
    mov ah, 0x0e
    mov al, '!'
    int 0x10

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
    saved_sp    dw 0
    original_sp dw 0
    msg_taska   db "I am task A!", 0
    msg_taskb   db "I am task B!", 0
    padwithspaces   db "                                                                    ",0