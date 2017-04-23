    ; because if the output is that large, it should probably be negative...
    mov cx, ax
    and cx, 0xf000
    cmp cx, 0
    je .pos
    
    .neg:
    	mov bl, 1
    	mov byte [is_neg], bl
    	neg ax
    .pos:
    
    ;Place this in [drawchar_y].
    
    mov word [drawchar_y], ax
    mov word [coordinate_y], ax

    ; TODO: Correct both x and y to (0,160); try to just add 80 each.
    
    ; add 80 to x regardless (not counting for scaling; a TODO)
    
    add word [coordinate_x], 80
    
	; for y, if positive, 80 - y
	; if negative, 80 - y also.
	
	
	cmp byte [is_neg], 1
	je .neg_handle
	
	.pos_handle:
	
	; y is positive. Is it too big to graph?
	cmp word [coordinate_y], 80
	
	ja .no_graph
	
	; otherwise, easy
	mov bx, 80
	sub bx, word [coordinate_y]
	mov word [coordinate_y], bx
	
	jmp .hdone
	
	.neg_handle:
	
	cmp word [coordinate_y], 80
	ja .no_graph
	
	mov bx, 80
	add bx, word [coordinate_y]
	mov word [coordinate_y], bx
	
	.hdone:

