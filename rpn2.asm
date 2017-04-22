bits 16
org 0x100

section .text

main:
	mov dx, msg_hello
	call puts
	
	mov dx, rpn_buff
	mov cx, 100
	call gets
	
	call _execute_rpn
	
; cx is value
_execute_rpn:

	pusha
	
	mov word [int_cur_num], cx
	
	mov di, 0
	mov word [cur_index], di
.topLoop:
	
	cmp di, [ipt_len]
	ja .endloop
	
	mov di, word [cur_index]
	call _rpn_get_char
	mov word [cur_index], di
	
	mov bx,ax
	
	mov	ah, 0x0e
	mov al, bl
	int 0x10
	
	cmp 	bl, 0
	jl		.endloop		
	
	cmp     bl, 'w'
	je      .printItOut
	
	cmp		bl, byte '0'
	jb      .ops
	cmp		bl, byte '9'
	ja      .ops

	
	sub		bl, byte '0'	
	
	mov		word [we_have_a_number_rejoice], word 1

	xor dx,dx
	mov dl, bl
	
	mov bx, dx
	
	mov		ax, word [int_number]		
	
	imul	ax,10

	add		ax, bx
	
	mov		word [int_number],ax
	
	jmp 	.topLoop

.hazUGotANumber:

	mov 	ax, 0
	
	cmp		word [we_have_a_number_rejoice], ax
	je		.opsin

	
	;push the number
	push cx
	mov		cx, word [int_number]
	call	_push_stack
	pop cx

	
	mov		ax, 0
	mov 	word [we_have_a_number_rejoice], 0
	mov		word [int_number], 0
	
	jmp		.opsin
.ops:

	jmp		.hazUGotANumber
.opsin:

	cmp		bx, 'x'
	je		.opsX
	cmp		bx, '+'
	je		.opsPlus
	cmp		bx, '-'
	je		.opsMinus
	cmp		bx, '*'
	je		.opsMul
	cmp		bx, '/'
	je		.opsDiv
	cmp		bx, '~'
	je		.opsNeg
	
	jmp .topLoop
.printItOut:
	
	call	_print_stack
	
	jmp .topLoop
	
.opsPlus:
	mov	ah, 0x0e
	mov al, 'P'
	int 0x10




	call	_pop_stack
	mov		cx, ax
	
	push cx 
	
	call	_pop_stack
	
	pop cx
	;ax

	
	add		ax, cx
	
	push cx
	mov cx, ax
	call	_push_stack
	pop cx
	
	jmp		.topLoop
	
.opsMinus:
	
	call	_pop_stack
	mov		cx, ax
	push cx
	call	_pop_stack
	pop cx
	;ax
	
	sub		ax, cx
	push cx
	mov cx,	ax
	call	_push_stack
	pop cx
	
	jmp		.topLoop
	
.opsNeg:
	
	call	_pop_stack
	;ax
	
	neg		ax
	push cx
	mov cx,	ax
	call	_push_stack
	pop cx
	
	jmp		.topLoop

.opsMul:


	call	_pop_stack
	mov		cx, ax
	
	push cx 
	
	call	_pop_stack
	
	pop cx
	;ax
	
	imul	ax, cx
	
	
	push cx
	mov cx,	ax
	call	_push_stack
	pop cx
	
	jmp		.topLoop

.opsDiv:


	call	_pop_stack
	mov		cx, ax
	
	push cx 		
	call	_pop_stack	
	pop cx

	;ax
	
	cdq
	idiv	cx
	
	
	push cx
	mov cx,	ax
	call	_push_stack
	pop cx
	
	jmp		.topLoop


.opsX:
	
	push cx
	mov cx, word [int_cur_num]
	call _push_stack
	pop cx
	
	jmp .topLoop


.endloop:

	
	popa
	ret
	
; dx is position in buffer
; returns ax = 0 if there is no more space in buffer
; otherwise returns character
_rpn_get_char:
	push bx
	mov bx,di
	mov ax, [rpn_buff + bx]

	inc di
	pop bx
	
	ret
	

; cx is what to push
_push_stack: 
		
		mov ah, 0x0e
		mov al, '!'
		int 0x10
		; [bp+8]   == what to push
		mov   ax, word [int_top_stack]
		
		cmp	 	ax, 200
		je		.mod
		jmp		.cont
.mod:
		
		mov		ax, 0
		jmp 	.conti
		
		
.cont:
		
		add		ax, 1
.conti:
		mov word [int_top_stack], ax
		
		;cmp ax, 0
		;jb .notzero
		
		;mov ax, word 0

		
.notzero:		
		
		push bx
		mov bx, ax
		add bx,bx
		mov		word [rpn_stack+bx], cx
		
		pop bx
		
		mov		word [int_top_stack], ax

        ret

; Pops off value from stack to ax
; or exits with grace if the stack is empty.
_pop_stack: 
		
		push bx
		push dx
		; pop into ax
		
		mov		bx, word [int_top_stack]

		
		cmp		bx, 200
		je		.bad
		
		push bx
		add bx,bx
		mov		ax, word [rpn_stack+bx]
		pop bx
		
		cmp		bx, 0
		ja		.dec
		
		mov		bx,	201
		jmp		.dec

.dec:		
		add 	bx, -1
		mov		word [int_top_stack], bx
		
		
		jmp 	.end

.bad:

		mov dx,str_err_pattern
		call puts
		
.end:
	   pop dx
	   pop bx
	   ret
	   
; Attempts to print the top of the stack
_print_stack:
		push ax
		push bx
		push cx
		push dx
		
		call	_pop_stack
		mov    bx, ax
		push ax
		
		
		

		mov dx, bx
		
		.beg:
			rol dx,4 
			mov cx, dx
			and cx, 0xf
			mov	ah, 0x0e
			
			mov bx, cx
			mov al, byte [digits + bx]
			int 0x10
			
			cmp cx, 0
			jne .beg			
		
		pop ax		
		mov cx,	ax
		call	_push_stack
			
		pop dx	
		pop cx
		pop bx
		pop ax
		ret


; print NUL-terminated string from DS:DX to the screen (at the current "cursor" location) using BIOS INT 0x10
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

; read NUL-terminated string from keyboard into CX-sized buffer at DS:DX using BIOS INT 0x16
; takes pointer to buffer in DS:DX, takes size of buffer in CX-sized
; clobbers nothing (but ax, the return value)
; returns number of characters read/stored (not counting NUL) in ax
gets:
	cmp	cx, 1
	ja	.ok
	xor	ax, ax
	ret
.ok:
	push	di
	push	cx
	
	mov	di, dx
	dec	cx		; Reserve space for NUL
.loop:
	mov	ah, 0x10
	int	0x16
	cmp	al, 13		; Stop on CR (Enter key)
	je	.gotcr
	
	push	cx		; Echo entered character
	mov	cx, 1
	mov	ah, 0x0e
	int	0x10
	pop	cx
	
	mov	[di], al	; Stash entered character
	inc	di
	loop	.loop
.flush:
	cmp	al, 13		; Read (and drop) chars until we get a CR
	je	.gotcr		; (This happens if we run out of room before CR)
	mov	ah, 0x10
	int	0x16
	
	push	cx		; Echo entered character
	mov	cx, 1
	mov	ah, 0x0e
	int	0x10
	pop	cx
	
	jmp	.flush
	
.gotcr:	mov	byte [di], 0	; Tack on the NUL
	
	sub di, dx
	mov word [ipt_len], di
	
	mov	ax, 0x0e0a	; Always emit a CRLF pair
	mov	cx, 1
	int	0x10
	mov	al, 13
	int	0x10
	
	mov	ax, di		; Compute &end - &start - 1 (number of non-NUL chars)
	sub	ax, dx
	
	pop	cx
	pop	di
	ret

end:

section	.data
digits		db	"0123456789abcdef",10,0
counter		dw	0
ivt8_offset	dw	0
ivt8_segment	dw	0
msg_finish	db	"Enter an empty string to quit...", 10, 13, 10, 13, 0
msg_prompt	db	"What is your name? ", 0
msg_hello	db	"RPN Demo",10, 0
rpn_buff	times 100 db 0
input_buff	times 32 db 0
rpn_stack	times 32 dw 0
str_err_pattern db "STACK UNDERFLOW",0x0e, 0x0a,0

ipt_len dw 0
cur_index dw 0

int_cur_num dw 0
sad_fish	dw	0
int_top_stack dw 200
int_unumber	dw 0
bool_have_number dw 0
we_have_a_number_rejoice dw 0
int_number_pad3 dw 0
int_number dw 0
int_number_pad dw 0
int_number_pad2 dw 0
