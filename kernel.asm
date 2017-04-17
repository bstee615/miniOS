bits 16

org 0x0

section .text

main:
	mov	ax, cs
	mov	ds, ax
    ; Switch to 320x200 video mode (i.e. mode 13h)
    mov ah, 0x00
    mov al, 0x13
    int 0x10

    ;mov dx, boot_msg
    ;call puts
    call setup

func1:
    mov dx, msg_taska
    call puts
    call yield
    jmp func1
func2:
    mov dx, msg_taskb
    call puts
    call yield
    jmp func2
func3:
    mov dx, msg_taskc
    call puts
    call yield
    jmp func3
func4:
    mov dx, msg_taskd
    call puts
    call yield
    jmp func4
func5:
    mov dx, msg_taske
    call puts
    call yield
    jmp func5

yield:
    ; save first state registers
    push ax
    push bx
    push cx
    push dx
    push di
    push si
    push bp

    inc word [current_thread]
    mov dx, [num_threads]
    cmp dx, [current_thread]
    je .zero ; if current_thread is equal to num_threads, set current_thread to 0.
    jmp first_yield
.zero:
    mov word [current_thread], 0

    ; switch to next state context
first_yield:
    mov bx, [current_thread]
    add bx, bx
    mov sp, [stack_pointer + bx]

    ; restore next state registers
    pop bp
    pop si
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ; jump into next state's function.
    ret

; Task setup function: reserves a given amount of spack for a "partition" on the stack.
; Order is:  ...top of stack|IP|REG|REG|REG|REG|REG|REG|LOCAL_SP|bottom of stack...
; ax is the location of the bottom of the stack.
; bx is stack size.
; cx is the location of the next function's first instruction.
; Changes given ax, bx, and cx.
start_thread:
    ; preserve original sp.
    mov [original_sp], sp
    ; move stack to the end of desired function's reserved stack.
    add ax, bx
    mov sp, ax

    ; push instruction pointer for desired function.
    push cx
    ; make space for the 7 registers
    push 0
    push 0
    push 0
    push 0
    push 0
    push 0
    
    ; This ensures that when switching to this stack, the OS will pop register states from this stack and not the stack above.
    sub ax, 0x10
    ; push location of space reserved for registers.
    push ax

    ; save sp in the stack_pointer array.
    mov bx, [num_threads]
    add bx, bx
    mov word [stack_pointer + bx], ax ; save sp internally.

    mov sp, [original_sp]
    inc word [num_threads]

    ret

; Initial setup function. Should be called once, then never return as it hands control over to task management.
; This kills the registers
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
    
    ; setup func4:
    mov ax, 0x800
    mov bx, 0x100
    mov cx, func4
    call start_thread
    
    ; setup func5:
    mov ax, 0x900
    mov bx, 0x100
    mov cx, func5
    call start_thread

    ; this is so that the comparison in yield between these two is easier.
    ;sub word [num_threads], 1 ; make sure no tasks are added after this.
    mov word [current_thread], 0

    ; Have to manually set sp so that the stack pointer manager saves the right address for stack 2.
    mov sp, 0x500 - 0x10
    jmp first_yield

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
    push    bx
	
	mov	ah, 0x0e
	mov	cx, 1		; no repetition of chars
	
	mov	si, dx

    mov bh, 0
    mov bl, 150

.loop:	mov	al, [si]
	inc	si
	cmp	al, 0
	jz	.end
	int	0x10
	jmp	.loop
.end:
    pop bx
	pop	si
	pop	cx
	pop	ax
	ret

; Draws a 1-pixel-wide horizontal line across the screen.
; ax is (drawline_x).
; bx is (drawline_y).
; cx is the endpoint (drawline_x or drawline_y).
; dx is whether the line is horizontal (1) or vertical (0).
; Make sure the endpoint is larger than the origin!
;draw_line:
;    mov word [drawline_x], ax
;    mov word [drawline_y], bx
;    mov word [drawline_end], cx
;    mov word [drawline_dir], dx
;.loop:
;    cmp word [drawline_dir], 0
;    je  .inc_y ; if drawline_dir == 0 inc drawline_x
;               ; else inc drawline_x
 ;   inc word [drawline_x]
;    mov dx, word[drawline_x]
;    cmp dx, word [drawline_end]
;    je  .end
;    jmp .continue
;.inc_y:
;    inc word [drawline_y]
;    mov dx, word[drawline_y]
;    cmp dx, word [drawline_end]
;    je  .end
;.continue:
;    mov ah, 0x0c
;    mov al, 100
;    mov bx, [1]
;    mov cx, [drawline_x]
;    mov dx, [drawline_y]
;    int 10h

;    jmp .loop

;.end:
;    ret


section .data
    ; more funcs
    num_threads dw 0
    current_thread  dw 0
    stack_pointer times 32 dw 0

    ; two funcs
    original_sp dw 0
    msg_taska   db "I am task A!", 13, 10, 0
    msg_taskb   db "I am task B!", 13, 10, 0
    msg_taskc   db "I am task C!", 13, 10, 0
    msg_taskd   db "I am task D!", 13, 10, 0
    msg_taske   db "I am task E!", 13, 10, 0
    ;padwithspaces   db "                                                                    ",0
    boot_msg    db	"Successfully loaded kernel.", 13, 10, 0

    pause_execution dw 0

    drawline_x  dw 0
    drawline_y  dw 0
    drawline_end  dw 0
    drawline_dir  dw 0

;section .bss
 ;   stack_pointer: resb 64