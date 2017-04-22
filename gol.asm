bits 16

org 0x100

section .text

X_BOUND equ 40
X_START equ 21
Y_START equ 0
Y_BOUND equ 25
main:
    mov ah, 0x00
    mov al, 0x13
    int 0x10

    call gol_setup

    ; Move cursor
    ;AH = 02
    mov ah, 0x02
	;BH = page number (0 for graphics modes)
    mov bh, 0
	;DH = row
    mov dh, 0
	;DL = column
    mov dl, 20
    int 0x10

    ; Print
    mov ah, 0x0a
    mov al, 219
    mov bl, 1
    mov cx, 1

    mov si, 0
.looper:
    ; Move cursor
    mov ah, 0x02
    ; bl will now contain either black or blue.
    inc dl
    cmp dl, X_BOUND
    jl .normal_X
    ; Else move cursor back to the start of the row and inc the row count.
    mov dl, X_START
    inc dh
.normal_X:
    cmp dh, Y_BOUND
    jl .normal
    ; Else move cursor back to the start of the game.
    mov dl, X_START
    mov dh, Y_START
.normal:
    int 0x10

; Print
    inc si
    ;call survive

    mov ah, 0x0a
    int 0x10

    jmp .looper

gol_setup:
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

section .data
    ; Theoretically organized into 25 lines of 20.
    cells_array times 260 db 0

    left        db 0
    right       db 0
    up          db 0
    down        db 0
    topleft     db 0
    topright    db 0
    bottomleft  db 0
    bottomright db 0