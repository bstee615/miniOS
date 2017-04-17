; CpS 230 Lab 8: Benjamin J. Steenhoek (bstee615)
;---------------------------------------------------
; Bootloader that loads/runs a single-sector payload
; program from the boot disk.
;---------------------------------------------------
bits 16

; Our bootloader is 512 raw bytes: we treat it all as code, although
; it has data mixed into it, too.
section	.text

; The BIOS will load us into memory at 0000:7C00h; NASM needs
; to know this so it can generate correct absolute data references.
org	0x7C00

; First instruction: jump over initial data and start executing code
start:	jmp	main

; Embedded data
boot_msg    db	"CpS 230 Bootloading Lab", 13, 10
name_msg    db	"by Benjamin Steenhoek", 13, 10, 0
boot_disk   db	0		; Variable to store the number of the disk we boot from
retry_msg   db	"Error reading payload from disk; retrying...", 13, 10, 0

main:
	; TODO: Set DS == CS (so data addressing is normal/easy)
    mov ax, cs
    mov ds, ax
	; TODO: Save the boot disk number (we get it in register DL
    mov [boot_disk], dl
	; TODO: Set SS == 0x0800 (which will be the segment we load everything into later)
    mov dx, 0x0800
    mov ss, dx
	; TODO: Set SP == 0x0000 (stack pointer starts at the TOP of segment; first push decrements by 2, to 0xFFFE)
    mov sp, 0x0000
	; TODO: Print the boot message/banner
	mov dx, boot_msg
    call puts

.retry:
	; TODO: use BIOS raw disk I/O to load sector 2 from disk number <boot_disk> into memory at 0800:0000h (retry on failure)
	;AH = 02
    mov ah, 0x02
	;AL = number of sectors to read	(1-128 dec.)
    mov al, 1
	;CH = track/cylinder number  (0-1023 dec., see below)
    mov ch, 0
	;CL = sector number  (1-17 dec.)
    mov cl, 2
	;DH = head number  (0-15 dec.)
    mov dh, 0
	;DL = drive number (0=A:, 1=2nd floppy, 80h=drive 0, 81h=drive 1)
    mov dl, [boot_disk]
	;ES:BX = pointer to buffer
    mov bx, ss
    mov es, bx
    mov bx, sp

	int 0x13
	jc .retry

	; Finally, jump to address 0800h:0000h (sets CS == 0x0800 and IP == 0x0000)
	jmp	0x0800:0x0000

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

; NASM mumbo-jumbo to make sure the boot sector signature starts 510 bytes from our origin
; (logic: subtract the START_ADDRESS_OF_OUR_SECTION [$$] from the CURRENT_ADDRESS [$],
;	yielding the number of bytes of code/data in the section SO FAR; then subtract
;	this size from 510 to give us BYTES_OF_PADDING_NEEDED; finally, emit
;	BYTES_OF_PADDING_NEEDED zeros to pad out the section to 510 bytes)
	times	510 - ($ - $$)	db	0

; MAGIC BOOT SECTOR SIGNATURE (*must* be the last 2 bytes of the 512 byte boot sector)
	dw	0xaa55