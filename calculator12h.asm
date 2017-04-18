bits 16

org 0x100

section .text

main:

    mov ax, 0x0013
    int 0x10
    
    mov       ax, 0x0500      ;Set page #0
    int       10H

    call setup_graph
    call setup_menu

    call take_function

    ; TODO: After enter is pressed in take_function, print curvies.

    ; Switch back to text mode and return.
    mov ax, 0x0000
    int 0x10

    ret

INPUT_DEFAULT_X     equ 9
INPUT_DEFAULT_Y     equ 18
INPUT_MAX_DIGITS    equ 4

take_function:
    mov byte [drawchar_x],   INPUT_DEFAULT_X
    mov byte [drawchar_y],   INPUT_DEFAULT_Y

    mov si, x_field
    mov bl, 7
    call draw_x
    mov bl, 20
    call draw_y

; Loop for input, displaying characters, until user presses enter.
.loop:
    ; Take input; keep input in ah for duration of loop.
    mov ah, 0x00
    int 0x16
    
    ; VVVVVV TODO VVVVVV
    ; If it's 'Enter', return from this function.
    cmp al, 0x00
    je .end_func

    ; If it's 'X' or 'Y', switch control.
    cmp al, 'x'
    je .switchto_x
    cmp al, 'y'
    je .switchto_y
    jmp .no_switch
.switchto_y:
    mov si, y_field
    mov byte [drawchar_y], INPUT_DEFAULT_Y + 1
    mov dl, byte [si]
    mov byte [drawchar_x], dl
    add byte [drawchar_x],   INPUT_DEFAULT_X

    mov bl, 20
    call draw_x
    mov bl, 7
    call draw_y

    jmp .no_switch
.switchto_x:
    mov si, x_field
    mov byte [drawchar_y], INPUT_DEFAULT_Y
    mov dl, byte [si]
    mov byte [drawchar_x], dl
    add byte [drawchar_x],   INPUT_DEFAULT_X

    mov bl, 7
    call draw_x
    mov bl, 20
    call draw_y

    jmp .no_switch
.no_switch:
    ; If it's a backspace, do the backspace thingy.
    cmp ah, 0x0e
    mov bl, 100
    jne .draw_normal
; if backspace go back one and draw a black square.
    cmp byte [si], 0 ; if x_field_chars is 0, retry input.
    jle .loop

    mov al, 219
    mov bl, 0
    dec byte [drawchar_x]

    ; Replace the appropriate char with a 0.
    add si, 4 ; si now points at index of next char to add.
    mov byte [si], 0 ; char has been moved.
    sub si, 4 ; si not points at the beginning of the struct.

    dec byte [si] ; decrement char count for x.

    call draw_letter
    jmp .carryon
.draw_normal:
    call is_digit
    cmp dh, 0 ; If dh is 0 (ah is not a digit), retry input.
    je .loop

    cmp word [si], INPUT_MAX_DIGITS ; if x_field_chars is above INPUT_MAX_DIGITS, retry input.
    jge .loop

    ; If ALL error-checking is clear, draw normally(whew)
    call draw_letter
    inc word [si] ; increment char count for x.

    ; And then add the character to [si].
    ; dx is now smashable.
    mov dx, [si]
    ; Replace the appropriate char with a 0.
    add si, 4 ; si now points at index of next char to add.
    mov byte [si], al ; char has been moved.
    sub si, 4 ; si not points at the beginning of the struct.

    inc byte [drawchar_x]
.carryon:
    jmp .loop

.end_func:
    ret

; Takes a char array from a field struct pointed to by dx
; The chars should only be digits (no error checking).
; The number TWO WORDS BACK from dx should be the number of characters.
; Returns a number in dx equal to the value of those chars.
; Smashes dx with the return value
get_number_from_chars:
    push si
    push ax
    push bx

    mov si, dx  ; si now points at the beginning of digit chars.
    sub dx, 4   ; dx now points at the number of digit chars.
    mov ax, 0   ; ax will be our temporary sum variable.
    mov bx, 0   ; bx will be our worktable to convert the chars to ints.

    cmp dx, 0   ; Just because it's assembly doesn't mean we can't have error checking!
    je .end_loop 
; while dx > 0, keep adding to sum.
.loop:
    imul ax, 10 ; make room for next digit.

    mov bl, byte [si]
    sub bl, 48  ; mov digit at si to bx convert it to an int.
    
    add ax, bx  ; add it on.

    inc si
    dec dx
    cmp dx, 0
    jne .loop
.end_loop:
    mov dx, ax

    pop bx
    pop ax
    pop si
    
    ret

; Use this for number-checking input through int 0x10.
; Checks if the character in al is a digit.
; Returns 1 or 0 in dh.
; Smashes dx
is_digit:
    mov dl, al
    cmp dl, '0'
    jl .false
    cmp dl, '9'
    jg .false
.true:
    mov dh, 1
    jmp .end
.false:
    mov dh, 0
.end:
    ret

; Draws a 1-pixel-wide horizontal line across the screen.
; ax is (drawline_x).
; bx is (drawline_y).
; cx is the endpoint (drawline_x or drawline_y).
; dx is whether the line is horizontal (1) or vertical (0).
; Make sure the endpoint is larger than the origin!
; You should either NOT multitask this function or redesign it to handle multiple users.
; Depends on drawline_x, drawline_y, drawline_color, drawline_dir, and drawline_end.
draw_line:
    mov word [drawline_x], ax
    mov word [drawline_y], bx
    mov word [drawline_end], cx
    mov word [drawline_dir], dx
.loop:
    cmp word [drawline_dir], 0
    je  .inc_y ; if drawline_dir == 0 inc drawline_x
               ; else inc drawline_x
    inc word [drawline_x]
    mov dx, word[drawline_x]
    cmp dx, word [drawline_end]
    je  .drawline_end
    jmp .continue
.inc_y:
    inc word [drawline_y]
    mov dx, word[drawline_y]
    cmp dx, word [drawline_end]
    je  .drawline_end
.continue:
    mov ah, 0x0c
    mov al, byte [drawline_color]
    mov bx, [1]
    mov cx, [drawline_x]
    mov dx, [drawline_y]
    int 10h

    jmp .loop

.drawline_end:
    ret

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

; Draws a character to the screen.
; This kills nothing.
; Set bl ahead of time if you want pretty colors.
; Depends on drawchar_x and drawchar_y. Don't TOUCH those!
draw_letter:
    push ax
    push bx
    push cx
    push dx

    mov ah, 0x02
    mov bh, 0x00
    mov dh, byte [drawchar_y]
    mov dl, byte [drawchar_x]
    int 0x10

    mov ah, 0x09
    mov bh, 1
    mov cx, 1
    int 0x10

    pop dx
    pop cx
    pop bx
    pop ax

    ret

draw_x:
    ; X:[    ]
    ; Preserve old drawchar coordinates.
    push word [drawchar_x]
    push word [drawchar_y]

    mov word [drawchar_x], 6
    mov word [drawchar_y], 18
    mov al, 'X'
    call draw_letter

    inc word [drawchar_x]
    mov al, ':'
    call draw_letter

    inc word [drawchar_x]
    mov al, '['
    call draw_letter
    add word [drawchar_x], INPUT_MAX_DIGITS
    inc word [drawchar_x]
    mov al, ']'
    call draw_letter

    ; Restore old drawchar coordinates.
    pop ax
    mov word [drawchar_y], ax
    pop ax
    mov word [drawchar_x], ax
    
    ret
draw_y:
    ; Y:[    ]
    ; Preserve old drawchar coordinates.
    push word [drawchar_x]
    push word [drawchar_y]
    
    mov word [drawchar_x], 6
    mov word [drawchar_y], 19
    mov al, 'Y'
    call draw_letter

    inc word [drawchar_x]
    mov al, ':'
    call draw_letter
    
    inc word [drawchar_x]
    mov al, '['
    call draw_letter
    add word [drawchar_x], INPUT_MAX_DIGITS
    inc word [drawchar_x]
    mov al, ']'
    call draw_letter

    ; Restore old drawchar coordinates.
    pop ax
    mov word [drawchar_y], ax
    pop ax
    mov word [drawchar_x], ax

    ret

setup_menu:
    mov bl, 7
    call draw_x
    mov bl, 20
    call draw_y

    ; Graph It!
    ; change drawline_color to dark blue
    mov word [drawline_color], 1;104
    ; draw title text
    mov bl, 1
    mov word [drawchar_x], 16
    mov word [drawchar_y], 1
    mov al, 'G'
    call draw_letter
    inc word [drawchar_x]
    mov al, 'r'
    call draw_letter
    inc word [drawchar_x]
    mov al, 'a'
    call draw_letter
    inc word [drawchar_x]
    mov al, 'p'
    call draw_letter
    inc word [drawchar_x]
    mov al, 'h'
    call draw_letter
    inc word [drawchar_x]
    mov al, ' '
    call draw_letter
    inc word [drawchar_x]
    mov al, 'I'
    call draw_letter
    inc word [drawchar_x]
    mov al, 't'
    call draw_letter
    inc word [drawchar_x]
    mov al, '!'
    call draw_letter

    ret
setup_graph:

    mov byte [drawline_color], 1
    ; draw outline box
    mov ax, 40
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 40
    mov bx, 140
    mov cx, 280
    mov dx, 1
    call draw_line
    mov ax, 280
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 40
    mov bx, 20
    mov cx, 280
    mov dx, 1
    call draw_line

    ; change drawline_color to light blue
    mov byte [drawline_color], 78
    ; draw vertical intermediate graph lines
    mov ax, 265
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 250
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 235
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 220
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 205
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 190
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 175
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line

    mov ax, 145
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 130
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 115
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 100
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 85
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 70
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 55
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line

    ; draw horizontal intermediate graph lines
    mov ax, 40
    mov bx, 35
    mov cx, 280
    mov dx, 1
    call draw_line
    mov ax, 40
    mov bx, 50
    mov cx, 280
    mov dx, 1
    call draw_line
    mov ax, 40
    mov bx, 65
    mov cx, 280
    mov dx, 1
    call draw_line

    mov ax, 40
    mov bx, 95
    mov cx, 280
    mov dx, 1
    call draw_line
    mov ax, 40
    mov bx, 110
    mov cx, 280
    mov dx, 1
    call draw_line
    mov ax, 40
    mov bx, 125
    mov cx, 280
    mov dx, 1
    call draw_line
    
    ; change drawline_color to white
    mov byte [drawline_color], 1
    ; Split graph in quadrants
    mov ax, 160
    mov bx, 20
    mov cx, 140
    mov dx, 0
    call draw_line
    mov ax, 40
    mov bx, 80
    mov cx, 280
    mov dx, 1
    call draw_line

    ret


section .data
    ; Field struct: 
    ; First word is number of chars (max 6), 
    ; second word is order in sequence with other structs,
    ; third and fourth words are characters contained.
    ; Fifth word is the resulting number, after conversion.
    x_field         times 5 dw 0
    
    y_field         times 5 dw 0

    drawline_end    dw 0
    drawline_dir    dw 0
    drawline_x      dw 0
    drawline_y      dw 0
    drawline_color  db 0

    drawchar_x      db 5
    drawchar_y      db 20