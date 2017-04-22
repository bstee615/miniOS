bits 16

org 0x100

section .text

main:
	mov	ax, cs
	mov	ds, ax
    ; Switch to 320x200 video mode (i.e. mode 13h)
    ;mov ah, 0x00
    ;mov al, 0x13
    ;int 0x10
    ;--------------------------------
    ; Set up new interrupt 8 handler.
    ;--------------------------------
    
    ; Where to find the INT 8 handler vector within the IVT [interrupt vector table]
    IVT8_OFFSET_SLOT	equ	4 * 8			; Each IVT entry is 4 bytes; this is the 8th
    IVT8_SEGMENT_SLOT	equ	IVT8_OFFSET_SLOT + 2	; Segment after Offset
	; Set ES=0x0000 (segment of IVT)
	mov	ax, 0x0000
	mov	es, ax
	
	; TODO Install interrupt hook
	; 0. disable interrupts (so we can't be...INTERRUPTED...)
    cli
	; 1. save current INT 8 handler address (segment:offset) into ivt8_offset and ivt8_segment
    mov dx, [es:IVT8_OFFSET_SLOT]
    mov word [ivt8_offset], dx
    mov dx, [es:IVT8_SEGMENT_SLOT]
    mov word [ivt8_segment], dx
	; 2. set new INT 8 handler address (OUR code's segment:offset)
    mov ax, timer_isr
	mov word [es:IVT8_OFFSET_SLOT], ax
	mov ax, cs
    mov word [es:IVT8_SEGMENT_SLOT], ax

	; Start all the threads.
    call setup

    ; this is so that the comparison in yield between these two is easier.
    ;sub word [num_threads], 1 ; make sure no tasks are added after this.
    mov word [current_thread], 0

    ; Have to manually set sp so that the stack pointer manager saves the right address for stack 2.
    mov sp, 0x500 - 0x10

    ; Finally, enable interrupts (because you disabled them when setting up interrupts).
    sti

    jmp first_yield

    ; The program should never get here.
    ret

; INT 8 Timer ISR (interrupt service routine)
; cannot clobber anything; must CHAIN to original caller (for interrupt acknowledgment)
; DS/ES == ???? (at entry, and must retain their original values at exit)
timer_isr:
    ; Registers used are saved in the function.
    call yield
	
    push dx
    mov dx, msg_timer
    call puts
    pop dx

	; Chain (i.e., jump) to the original INT 8 handler
	jmp	far [cs:ivt8_offset]	; Use CS as the segment here, since who knows what DS is now

func1:
    mov dx, msg_taska
    call puts
    ;call yield
    jmp func1
func2:
    mov dx, msg_taskb
    call puts
    ;call yield
    jmp func2
func3:
    mov dx, msg_taskc
    call puts
    ;call yield
    jmp func3
func4:
    mov dx, msg_taskd
    call puts
    ;call yield
    jmp func4
func5:
    mov dx, msg_taske
    call puts
    ;call yield
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

    inc word [cs:current_thread]
    mov dx, [cs:num_threads]
    cmp dx, [cs:current_thread]
    je .zero ; if current_thread is equal to num_threads, set current_thread to 0.
    jmp first_yield
.zero:
    mov word [cs:current_thread], 0

    ; switch to next state context
first_yield:
    mov bx, [cs:current_thread]
    add bx, bx
    mov sp, [cs:stack_pointer + bx]

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
    msg_timer   db "I am the timer!", 13, 10, 0
    ;padwithspaces   db "                                                                    ",0
    boot_msg    db	"Successfully loaded kernel.", 13, 10, 0

    pause_execution dw 0

    ivt8_offset	dw	0
    ivt8_segment	dw	0

;section .bss
 ;   stack_pointer: resb 64