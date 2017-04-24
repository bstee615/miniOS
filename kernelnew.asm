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

    call setup

    ret

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
    mov ax, 0x1000
    mov bx, 0x300
    mov cx, calculator
    call start_thread

    mov ax, 0x1300
    mov bx, 0x100
    mov cx, rainbow
    call start_thread

    ; this is so that the comparison in yield between these two is easier.
    ;sub word [num_threads], 1 ; make sure no tasks are added after this.
    mov word [current_thread], 0

    ; Have to manually set sp so that the stack pointer manager saves the right address for stack 2.
    mov sp, 0x1300 - 0x10
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

; CALCULATOR!
;----------------------------------------
calculator:
    mov ah, 0x00
    mov al, 0x13
    int 0x10

    ;call rainbow

    call setup_graph
    call setup_menu

.ask_again:
    call input_function
	
	; copy input to calculator buffer
	call copy_string_data
    ; TODO: After enter is pressed in input_function, print curvies.
    call plot_function
    jmp .ask_again

    ; Switch back to text mode and return.
    mov ah, 0x00
    mov al, 0x00
    int 0x10

    ret

INPUT_DEFAULT_X     equ 5
INPUT_DEFAULT_Y     equ 20
INPUT_MAX_DIGITS    equ 4
Y_MAX_CHARS         equ 12
input_function:
    call draw_graphit

    mov byte [drawchar_x],   INPUT_DEFAULT_X
    mov byte [drawchar_y],   INPUT_DEFAULT_Y

    mov bl, 7
    call draw_y
    mov bl, 20
    call draw_Xscale
    mov bl, 20
    call draw_Yscale

    mov si, y_field
    mov byte [drawchar_y], INPUT_DEFAULT_Y
    mov dl, byte [si]
    mov byte [drawchar_x], dl
    add byte [drawchar_x], INPUT_DEFAULT_X

    ; Loop for input, displaying characters, until user presses enter.
.loop:
    ; Take input; keep input in ah for duration of loop.
    mov ah, 0x00
    int 0x16

    cmp ah, 0x1c
    je .end_func

    ; If it's 'y' or 'X' or 'Y', switch control.
    cmp al, 'y'
    je .switchto_y
    cmp al, 'X'
    je .switchto_Xscale
    cmp al, 'Y'
    je .switchto_Yscale
    ; else
    jmp .no_switch
.switchto_y:
    mov bl, 7
    call draw_y
    mov bl, 20
    call draw_Xscale
    mov bl, 20
    call draw_Yscale

    mov si, y_field
    mov byte [drawchar_y], INPUT_DEFAULT_Y
    mov dl, byte [si]
    mov byte [drawchar_x], dl
    add byte [drawchar_x], INPUT_DEFAULT_X

    jmp .no_switch
.switchto_Xscale:
    mov bl, 20
    call draw_y
    mov bl, 7
    call draw_Xscale
    mov bl, 20
    call draw_Yscale

    mov si, Xscale_field
    mov byte [drawchar_y], INPUT_DEFAULT_Y + 1
    mov dl, byte [si]
    mov byte [drawchar_x], dl
    add byte [drawchar_x], INPUT_DEFAULT_X + 7

    jmp .no_switch
.switchto_Yscale:
    mov bl, 20
    call draw_y
    mov bl, 20
    call draw_Xscale
    mov bl, 7
    call draw_Yscale

    mov si, Yscale_field
    mov byte [drawchar_y], INPUT_DEFAULT_Y + 2
    mov dl, byte [si]
    mov byte [drawchar_x], dl
    add byte [drawchar_x], INPUT_DEFAULT_X + 7

    jmp .no_switch

.no_switch:
    ; If it's a backspace, do the backspace thingy.
    cmp ah, 0x0e
    mov bl, 100
    jne .draw_normal

    ; if backspace go back one and draw a black square.
    cmp byte [si], 0 ; if field_chars is 0, retry input.
    jle .loop

    mov al, 219
    mov bl, 0
    dec byte [drawchar_x]

    ; Replace the appropriate char with a 0.
    add si, 4 ; si now points at index of next char to add.
    mov byte [si], 0 ; char has been moved.
    sub si, 4 ; si not points at the beginning of the struct.

    dec byte [si] ; decrement char count.

    call draw_letter
    jmp .carryon
.draw_normal:
    cmp si, y_field
    je .is_on_y
.not_on_y:
    cmp byte [si], INPUT_MAX_DIGITS ; if field_chars is above INPUT_MAX_DIGITS, retry input.
    jge .loop

    call is_digit
    cmp dh, 0 ; If dh is 0 (ah is not a digit), retry input.
    je .loop

    jmp .compare
.is_on_y:
    cmp byte [si], Y_MAX_CHARS      ; if field_chars is above Y_MAX_CHARS, retry input.
    jge .loop

    call is_digit
    cmp dh, 1 ; If dh is 1 (ah is a digit), skip other tests.
    je .compare

    cmp al, 'x'
    je .compare
    cmp al, '+'
    je .compare
    cmp al, '-'
    je .compare
    cmp al, '*'
    je .compare
    cmp al, '/'
    je .compare
    cmp al, ' '
    je .compare
    
    jmp .loop
.compare:
    ; If ALL error-checking is clear, draw normally(whew)
    call draw_letter
    inc byte [si] ; increment char count.

    ; And then add the character to [si]:
    movzx dx, [si]
    ; Replace the appropriate char with a 0.
    add si, dx ; si now points at index of next char to add.
    mov byte [si], al ; char has been moved.
    sub si, dx ; si not points at the beginning of the struct.

    inc byte [drawchar_x]
.carryon:
    jmp .loop

.end_func:

    ret

plot_function:
    call draw_graphing

    ; If there's no input, then end the function.
    cmp byte [y_field], 0
    je .end_func

    ; TODO: Print 160 pixels, moving every pixel.
    ; This means loop 160 times.
    mov cx, 160
    ; TODO: Use coordinates x = (-80,80) and y = (-80,80)
    mov word [coordinate_x], -80
    mov word [coordinate_y], 0
    ; TODO: Calculate y for all pixels.
.looper:

	mov bl, 0
	mov byte [is_neg], bl
    ; RPN Function should take a reference to a character array 
    ; and the length of the array, calculate the result, and return a number.
    ; This function should DEFINITELY NOT smash the char array.
    ; Maybe just hardcode the length of the array since it'll just be used for y (12 characters).

    ; TODO: Save cx so that the count doesn't get screwed up.
    push cx
	push word [coordinate_x]
    ; TODO: Call RPN function to get the result of the equation(y_field character list).
    
    mov cx, word[coordinate_x]
    call _execute_rpn
    
    mov word [coordinate_y], ax
        
    ; is the output a negative number?
	;; removed a bunch of adjusting code that wasn't working    
	add word [coordinate_x], 80
	mov bx, 70
	sub bx, word [coordinate_y]
	mov word [coordinate_y], bx 

    cmp word [coordinate_y], 70
    ja .no_graph
	    
    ; TODO: Print the pixel in the appropriate place.
    ;AH = 0C
    mov ah, 0x0c
	;AL = color value (XOR'ED with current pixel if bit 7=1)
    mov al, 0x26
	;BH = page number, see VIDEO PAGES
    mov bh, 0

	;CX = column number (zero based)
    mov cx, word [coordinate_x]
	;DX = row number (zero based)
    mov dx, word [coordinate_y]
    ; Don't forget to actually CALL int 0x10 :)
    int 0x10
    
    ;sometimes off the page and we don't want to graph
    .no_graph:
    
    ; TODO: restore cx and coordinates.
    pop word [coordinate_x]
    pop cx
    ;sub word [coordinate_x], 80
    ;sub word [coordinate_y], 70

    inc word [coordinate_x]
    loop .looper

.end_func:

    mov ah, 0x00
    int 0x16

    call setup_graph

    ret

rainbow:
    mov cx, 16000
    mov al, 0
    mov word [rainbow_x], 160
    mov word [rainbow_y], 100

.looparino:
    push cx

    ;AH = 0C
    mov ah, 0x0c
	;AL = color value (XOR'ED with current pixel if bit 7=1)

    cmp al, 255
    jne .color_continue
    mov al, 0
    call yield
.color_continue:
    ;inc al ; Inc al after because al can only go up to 255.
	;BH = page number, see VIDEO PAGES
    mov bh, 0
	;CX = column number (zero based)
    mov cx, word [rainbow_x]

    inc word [rainbow_x]
    cmp word [rainbow_x], 320
    jne .x_continue ; If rainbow_x is 320, reset x and inc y.
    add al, 200
    mov word [rainbow_x], 160
    inc word [rainbow_y]
    cmp word [rainbow_y], 200
    jne .x_continue
    mov word [rainbow_y], 100
.x_continue:
	;DX = row number (zero based)
    mov dx, word [rainbow_y]
    ; Don't forget to actually CALL int 0x10 :)
    int 0x10

    pop cx
    
    jmp .looparino

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

draw_graphit:; Graph It!
    pusha

    ; change drawline_color to dark blue
    mov word [drawline_color], 1;104
    ; draw title text
    mov bl, 0
    mov word [drawchar_x], 5
    mov word [drawchar_y], 18
    mov al, 219
    call draw_letter

    inc word [drawchar_x]

    mov bl, 1
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
    inc word [drawchar_x]

    mov bl, 0
    mov word [drawchar_x], 15
    mov word [drawchar_y], 18
    mov al, 219
    call draw_letter

    popa 
    ret

draw_graphing:
    pusha

    ; change drawline_color to dark blue
    mov word [drawline_color], 1;104
    ; draw title text
    mov bl, 1
    mov word [drawchar_x], 5
    mov word [drawchar_y], 18
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
    mov al, 'i'
    call draw_letter
    inc word [drawchar_x]
    mov al, 'n'
    call draw_letter
    inc word [drawchar_x]
    mov al, 'g'
    call draw_letter
    inc word [drawchar_x]
    mov al, '.'
    call draw_letter
    inc word [drawchar_x]
    mov al, '.'
    call draw_letter
    inc word [drawchar_x]
    mov al, '.'
    call draw_letter

    popa
    ret

draw_y:
    pusha
    ; Y:[    ]
    ; Preserve old drawchar coordinates.
    push word [drawchar_x]
    push word [drawchar_y]
    
    mov word [drawchar_x], 3
    mov word [drawchar_y], 20
    mov al, 'y'
    call draw_letter

    inc word [drawchar_x]
    mov al, '='
    call draw_letter
    inc word [drawchar_x]

    ; Restore old drawchar coordinates.
    pop ax
    mov word [drawchar_y], ax
    pop ax
    mov word [drawchar_x], ax

    popa
    ret
draw_Xscale:
    pusha
    ; Xscale:[    ]
    ; Preserve old drawchar coordinates.
    mov ah, byte [drawchar_x]
    mov al, byte [drawchar_y]
    push ax

    mov byte [drawchar_x], 3
    mov byte [drawchar_y], 21
    mov al, 'X'
    call draw_letter
    inc byte [drawchar_x]
    mov al, ' '
    call draw_letter
    inc byte [drawchar_x]
    mov al, 'S'
    call draw_letter
    inc byte [drawchar_x]
    mov al, 'c'
    call draw_letter
    inc byte [drawchar_x]
    mov al, 'a'
    call draw_letter
    inc byte [drawchar_x]
    mov al, 'l'
    call draw_letter
    inc byte [drawchar_x]
    mov al, 'e'
    call draw_letter

    inc byte [drawchar_x]
    mov al, ':'
    call draw_letter

    inc byte [drawchar_x]
    mov al, '['
    call draw_letter
    add byte [drawchar_x], INPUT_MAX_DIGITS
    inc byte [drawchar_x]
    mov al, ']'
    call draw_letter

    ; Restore old drawchar coordinates.
    pop ax
    mov byte [drawchar_y], al
    mov byte [drawchar_x], ah
    
    popa
    ret
draw_Yscale:
    pusha
    ; Yscale:[    ]
    ; Preserve old drawchar coordinates.
    mov ah, byte [drawchar_x]
    mov al, byte [drawchar_y]
    push ax

    mov byte [drawchar_x], 3
    mov byte [drawchar_y], 22
    mov al, 'Y'
    call draw_letter
    inc byte [drawchar_x]
    inc byte [drawchar_x]
    mov al, ' '
    call draw_letter
    mov al, 'S'
    call draw_letter
    inc byte [drawchar_x]
    mov al, 'c'
    call draw_letter
    inc byte [drawchar_x]
    mov al, 'a'
    call draw_letter
    inc byte [drawchar_x]
    mov al, 'l'
    call draw_letter
    inc byte [drawchar_x]
    mov al, 'e'
    call draw_letter

    inc byte [drawchar_x]
    mov al, ':'
    call draw_letter

    inc byte [drawchar_x]
    mov al, '['
    call draw_letter
    add byte [drawchar_x], INPUT_MAX_DIGITS
    inc byte [drawchar_x]
    mov al, ']'
    call draw_letter

    ; Restore old drawchar coordinates.
    pop ax
    mov byte [drawchar_y], al
    mov byte [drawchar_x], ah
    popa
    ret

setup_menu:
    pusha
    ; Draw fields
    mov bl, 7
    call draw_y
    mov bl, 20
    call draw_Xscale
    mov bl, 20
    call draw_Yscale

    ; TODO: One Time Only: Underline the hotkeys for each field. (shoutout to Jake for this)

    call draw_graphit

    popa
    ret

GRAPH_X_BOUND equ 160
GRAPH_Y_BOUND equ 140
setup_graph:
    pusha

    mov ah, 0x02
    mov bh, 0
    mov dl, 0
    mov dh, 0
    int 0x10

    mov al, 219
    mov bl, 0

    mov cx, 17
.drawchar_loop:
    inc dh
    mov ah, 0x02
    int 0x10

    push cx
    mov ah, 0x09
    mov cx, 20
    int 0x10
    pop cx

    loop .drawchar_loop

    mov byte [drawline_color], 1
    ; draw outline box
    mov ax, 0
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, 0
    mov bx, GRAPH_Y_BOUND
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line
    mov ax, GRAPH_X_BOUND
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, 0
    mov bx, 0
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line

    ; change drawline_color to light blue
    mov byte [drawline_color], 78
    ; draw vertical intermediate graph lines
    mov ax, GRAPH_X_BOUND - 10
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, GRAPH_X_BOUND - 20
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, GRAPH_X_BOUND - 30
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, GRAPH_X_BOUND - 40
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, GRAPH_X_BOUND - 50
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, GRAPH_X_BOUND - 60
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, GRAPH_X_BOUND - 70
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line

    mov ax, GRAPH_X_BOUND - 90
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, GRAPH_X_BOUND - 100
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, GRAPH_X_BOUND - 110
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, GRAPH_X_BOUND - 120
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, GRAPH_X_BOUND - 130
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, GRAPH_X_BOUND - 140
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, GRAPH_X_BOUND - 150
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line

    ; draw horizontal intermediate graph lines
    mov ax, 0
    mov bx, GRAPH_Y_BOUND - 130
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line
    mov ax, 0
    mov bx, GRAPH_Y_BOUND - 120
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line
    mov ax, 0
    mov bx, GRAPH_Y_BOUND - 110
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line
    mov ax, 0
    mov bx, GRAPH_Y_BOUND - 100
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line
    mov ax, 0
    mov bx, GRAPH_Y_BOUND - 90
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line
    mov ax, 0
    mov bx, GRAPH_Y_BOUND - 80
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line

    mov ax, 0
    mov bx, GRAPH_Y_BOUND - 60
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line
    mov ax, 0
    mov bx, GRAPH_Y_BOUND - 50
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line
    mov ax, 0
    mov bx, GRAPH_Y_BOUND - 40
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line
    mov ax, 0
    mov bx, GRAPH_Y_BOUND - 30
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line
    mov ax, 0
    mov bx, GRAPH_Y_BOUND - 20
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line
    mov ax, 0
    mov bx, GRAPH_Y_BOUND - 10
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line
    
    ; Split graph in quadrants
    mov byte [drawline_color], 1
    mov ax, GRAPH_X_BOUND / 2
    mov bx, 0
    mov cx, GRAPH_Y_BOUND
    mov dx, 0
    call draw_line
    mov ax, 0
    mov bx, GRAPH_Y_BOUND / 2
    mov cx, GRAPH_X_BOUND
    mov dx, 1
    call draw_line

    popa

    ret


; rpn code

; cx is value
; returns value in ax
_execute_rpn:
    push si
    push di
    push bx
    push cx
    push dx
	
	mov word [int_cur_num], cx
	
	mov di, 0
	mov word [cur_index], di
.topLoop:
	
	;cmp di, [ipt_len]
	;ja .endloop
	
	mov di, word [cur_index]
	call _rpn_get_char
	mov word [cur_index], di
	
	mov bx,ax

	mov byte [char_rem], bl
		
	cmp 	bl, 0
	je		.endloop		
	
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
	
	mov bl, byte [char_rem]	
	cmp		bl, 'x'
	je		.opsX
	cmp		bl, '+'
	je		.opsPlus
	cmp		bl, '-'
	je		.opsMinus
	cmp		bl, '*'
	je		.opsMul
	cmp		bl, '/'
	je		.opsDiv
	cmp		bl, '~'
	je		.opsNeg
	
	jmp .topLoop
.printItOut:
	
	call	_print_stack
	
	jmp .topLoop
	
.opsPlus:

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
    ;cmp word [we_have_a_number_rejoice], 1
    ;jne .endfunc
    ;mov cx, word [int_number]
    ;call _push_stack

.endfunc:
	call _pop_stack

    pop dx
    pop cx
    pop bx
    pop di
    pop si

    ret
	
; dx is position in buffer
; returns ax = 0 if there is no more space in buffer
; otherwise returns character
_rpn_get_char:
	push bx
	mov bx,di
	movzx ax, byte [rpn_buff + bx]

	inc di
	pop bx
	
	ret
	

; cx is what to push
_push_stack: 
		
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
		push di
		call	_pop_stack
		mov    bx, ax
		push ax
		
		
		

		mov dx, bx
		
		mov di, 0
		.beg:
			rol dx,4 
			mov cx, dx
			and cx, 0xf
			mov	ah, 0x0e
			
			mov bx, cx
			mov al, byte [digits + bx]
			int 0x10
			
			inc di
			cmp di, 4
			jne .beg			
		
		pop ax		
		mov cx,	ax
		call	_push_stack
			
		pop di
		pop dx	
		pop cx
		pop bx
		pop ax
		ret


	
; copy y field data to rpn buffer
copy_string_data:
	pusha

	mov dx, y_field
	mov bx, rpn_buff
	
	mov di, 1
	.begcpy:
		; address of y-field
		mov bx, y_field
		; current reading point
		add bx, di
		mov al, byte[bx]
		
		; go to the right point in rpn
		mov bx, rpn_buff
        dec di
		add bx, di
        inc di
		mov byte[bx], al
		
		inc di
		cmp di, 16
		jne .begcpy
	
	
	popa
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
    ;padwithspaces   db "                                                                    ",0
    boot_msg    db	"Successfully loaded kernel.", 13, 10, 0

    pause_execution dw 0

; CALCULATOR

    ; First word is number of chars (max 4), 
    ; second word is order in sequence with other structs,
    ; third and fourth words are characters contained.
    ; Fifth word is the resulting number, after conversion.
    Xscale_field    times 5 dw 0
    Yscale_field    times 5 dw 0
    ; y field is structured similarly but can hold 12 characters.
    y_field         times 9 dw 0

    drawline_end    dw 0
    drawline_dir    dw 0
    drawline_x      dw 0
    drawline_y      dw 0
    drawline_color  db 0

    drawchar_x      db 0
    drawchar_y      db 0

    coordinate_x    dw 0
    coordinate_y    dw 0

    rainbow_x       dw 0
    rainbow_y       dw 0
    
    
    ;rpn stuff
    should_graph dw 0
    cur_graph_pos dw 0
    is_neg db 0
    
    
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
	char_rem db 0

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

    