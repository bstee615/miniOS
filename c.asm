bits 16

org 0x100

section .text

X_BOUND equ 40
X_START equ 21
Y_START equ 0
Y_BOUND equ 25
main:

	mov bx, next_cells_array
	add bx, 0x59
	mov byte[bx], 0x1
	inc bx
	mov byte[bx], 0x1
	inc bx
	mov byte[bx], 0x1
	
	mov ah, 0x0
	mov al, 0x12
	int 0x10
	
	.loop:
	
	call check_cells

	call print_grid
	
	mov ah,0
	int 0x16
	
	
	jmp .loop
	
	
ret

print_grid:
	mov cx, 1
	mov dx, 1
	
	.loop:
	
	push cx
	push dx
	
	call dbl_index
	call check_index
	
	cmp ax, 1
	jne .npr
	.pr:
	
	
	
		mov byte [row], cl
		mov byte [col], dl
		
		;AH = 02
		mov ah, 0x2
		mov bh, 0x0
		;BH = page number (0 for graphics modes)
		;DH = row
		mov dh, byte[row]
		;DL = column
		mov dl, byte[col]
		
		int 0x10
		
		;AH = 09
		mov ah, 0x9
		;AL = ASCII character to write
		mov al, 'o'
		;BH = display page  (or mode 13h, background pixel value)
		mov bh, 0
		;BL = character attribute (text) foreground color (graphics)
		mov bl, 0x3
		;CX = count of characters to write (CX >= 1)
		mov cx, 1
		
		int 0x10

	
	jmp .done
	.npr:
	
		mov byte [row], cl
		mov byte [col], dl
		
		;AH = 02
		mov ah, 0x2
		mov bh, 0x0
		;BH = page number (0 for graphics modes)
		;DH = row
		mov dh, byte[row]
		;DL = column
		mov dl, byte[col]
		
		int 0x10
		
		;AH = 09
		mov ah, 0x9
		;AL = ASCII character to write
		mov al, '`'
		;BH = display page  (or mode 13h, background pixel value)
		mov bh, 0
		;BL = character attribute (text) foreground color (graphics)
		mov bl, 0x3
		;CX = count of characters to write (CX >= 1)
		mov cx, 1
		
		int 0x10
	
	.done:
	
	pop dx
	pop cx	
	
	call next_index
	
	cmp cx, 0
	jne .loop
	
	
	ret


; Tells whether a given cell in cells_array will live in next state.
; Index is si.
; Return value is 1 or 0 in bl.
survive:
    push dx

    ; A cell C (number at si) is represented by a 1 when alive,
    ; or 0 when dead, in an m-by-m (or m×m) square array of cells.
    ; We calculate N - the sum of live cells in C's eight-location neighbourhood,
    ; then cell C is alive or dead in the next generation based on the following table:
    ;
    ; C   N                 new C
    ; 1   0,1             ->  0  # Lonely
    ; 1   4,5,6,7,8       ->  0  # Overcrowded
    ; 1   2,3             ->  1  # Lives
    ; 0   3               ->  1  # It takes three to give birth!
    ; 0   0,1,2,4,5,6,7,8 ->  0  # Barren
    
    call search_cells
    cmp dl, 2
    jl .dies
    cmp dl, 3
    jg .dies
    ; Else he lives!
    mov bl, 1
    jmp .return
.dies:
    mov bl, 0
.return:
    pop dx
    ret

; Takes a cell at si.
; Returns the number of live cells around it through dl.
; Kills nothing.
search_cells:
    push di
    push si
    
    ; Zero all parameters.
    ; all the others are replaced later anyways.
    mov dx, 0

    ; First: Naive version that just counts live cells.
    mov di, si
    sub di, cells_array
    ; di now contains the index in cells_array of the current cell.
    ; Get left cell.
    dec di
    mov dl, byte [di]
    mov byte [left], dl
    inc di  ; Reset

    ; Get right cell.
    inc di
    mov dl, byte [di]
    mov byte [right], dl
    dec di  ; Reset

    ; Get up cell.
    add di, 20
    mov dl, byte [di]
    mov byte [up], dl
        ; Keep the value for now, to easily get topleft and topright.
    ; Get topleft cell.
    dec di
    mov dl, byte [di]
    mov byte [topleft], dl
    inc di  ; Reset

    ; Get topright cell.
    inc di
    mov dl, byte [di]
    mov byte [topright], dl
    dec di  ; Reset

    sub di, 20  ; NOW fully reset to OG di.
    
    ; Get down cell.
    sub di, 20
    mov dl, byte [di]
    mov byte [down], dl
        ; Keep the value for now, to easily get topleft and topright.
    ; Get topleft cell.
    dec di
    mov dl, byte [di]
    mov byte [bottomleft], dl
    inc di  ; Reset
    ; Get topright cell.
    inc di
    mov dl, byte [di]
    mov byte [bottomright], dl
    dec di  ; Reset

    add di, 20  ; NOW fully reset to OG di.

    mov dx, 0
    add dl, byte [left]
    add dl, byte [right]
    add dl, byte [up]
    add dl, byte [down]
    add dl, byte [topleft]
    add dl, byte [topright]
    add dl, byte [bottomleft]
    add dl, byte [bottomright]

    pop di
    pop si

    ret


check_cells:
	pusha
	call copy_next_to_new
	call clear_next
	mov cx, 1
	mov dx, 1
	
	.loop:
	
	call check_cell
	call next_index
	
	cmp cx, 0
	jne .loop
	popa
	
	ret

; takes cx and dx as row and column
; and returns count in ax
check_cell:
	
	
	mov bx, 0
	; to the right!
		inc dx
		call dbl_index
		call check_index
		add bx, ax

	; up!
		dec cx
		call dbl_index
		call check_index
		add bx, ax

	; left!
		dec dx
		call dbl_index
		call check_index
		add bx, ax
		
	; left!
		dec dx
		call dbl_index
		call check_index
		add bx, ax

	; down!
		inc cx
		call dbl_index
		call check_index
		add bx, ax

	; down!
		inc cx
		call dbl_index
		call check_index
		add bx, ax
	
	; right!
		inc dx
		call dbl_index
		call check_index
		add bx, ax

	; right!
		inc dx
		call dbl_index
		call check_index
		add bx, ax
		
	;actual!
		dec dx
		dec cx
		call dbl_index
		call check_index
		add bx, ax
	
	cmp ax, 1
	jne .dead
	
	.live:
	cmp bx, 2
	jb .done
	cmp bx, 3
	ja .done
	
	jmp .regen
	.dead:
	cmp bx, 3
	jne .done
	
	jmp .regen
	
	.regen:
	
	call dbl_index
	mov bx, next_cells_array
	add bx, ax
	
	mov byte [bx], 1
	
	jmp .end
	
	.done:

	call dbl_index
	mov bx, next_cells_array
	add bx, ax
	
	mov byte [bx], 0
	

	.end:
	
	ret
	

;takes ax and returns cx and dx
	

; takes ax as parameter,
; returns its checked state to ax
check_index:
	push bx
	mov bx,ax
	xor ax,ax
	mov al, byte[cells_array + bx]
	pop bx
	ret

; calculates index of arr[cx][dx]
; assuming arr[25][20].
; outputs index to ax
    
dbl_index:
	mov ax, 25
	imul ax, cx
	add ax, dx
	ret
	
; assuming we're at cx, dx
; increments them to next indices
; if cx = 0 then we're done.
next_index:	
	inc dx
	cmp dx, 19
	jne .done
	mov dx, 1
	inc cx
	.done:
	cmp cx, 24
	jne .end
	mov cx, 0
	.end:
	ret
	
copy_next_to_new:
	push di
	push si
    push ax
	push bx
    push cx

	mov di, 0

    mov di, cells_array
    mov si, next_cells_array
    mov cx, 500
.looper:
    mov bx, cx
    mov al, byte [si + bx]
    mov byte [di + bx], al
    loop .looper
	
    pop cx
    pop bx
    pop ax
    pop si
	pop di
	ret

clear_next:
	push cx
	push si
	mov si, next_cells_array
    mov cx, 500
.looper:
	mov byte[si], 0
	inc si
	loop .looper
	
	pop si
	pop cx

    ret
	
end:


	
section .data
    ; Theoretically organized into 25 lines of 20.
    cells_array times 500 db 0
    next_cells_array times 500 db 0

    left        db 0
    right       db 0
    up          db 0
    down        db 0
    topleft     db 0
    topright    db 0
    bottomleft  db 0
    bottomright db 0
    
    
    row db 0
    col db 0
    
    on db "O",0
    off db "X",0