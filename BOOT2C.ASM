		page	66,132
;====================================================================
;
; BOOT2C - A program to force a floppy in A: to boot the C: drive
;
; Copyright (c) 1993 Douglas Boling
;
;====================================================================
		code	segment
		assume	cs:code

		org	100h
;====================================================================
;BOOT2C Boot record
; Entry:     
;   CS:IP - 0:7C00h
;      DL - boot drive
;   ES:SI - Ptr to partition table boot entry (if hard disk.)
;   All other registers undefined
;====================================================================

bytes_per_sec   equ     word ptr [bp+0bh]
sec_per_cluster equ     byte ptr [bp+0dh]
reserved_sec    equ     word ptr [bp+0eh]
number_of_fats  equ     byte ptr [bp+10h]
root_size       equ     word ptr [bp+11h]
total_sec       equ     word ptr [bp+13h]
media_des_byte  equ     byte ptr [bp+15h]
sec_per_fat     equ     word ptr [bp+16h]
sec_per_track   equ     word ptr [bp+18h]
number_of_heads equ     word ptr [bp+1ah]
num_hidden_sec  equ     word ptr [bp+1ch]
total_sec_long  equ     word ptr [bp+20h]
drive_number   	equ     word ptr [bp+24h]
reserved        equ     word ptr [bp+25h]
extended_flag   equ     word ptr [bp+26h]
vol_serial      equ     word ptr [bp+27h]
vol_name        equ     word ptr [bp+2bh]
boot_flag	equ	word ptr [bp+3feh]	;Offset + 512 needed for code

boot_disk       equ     byte ptr [bp + offset boot_disko - offset entry]
reloc_entry	equ	offset boot_2 - offset entry
boot_initmsg	equ	7a00h + offset program - offset entry
boot_chgmsg	equ	7a00h + offset change_msg - offset entry
boot_errmsg 	equ	7a00h + offset error_msg - offset entry
boot_rerrmsg	equ     7a00h + offset readerr_msg - offset entry

;--------------------------------------------------------------------
;Boot sector code
;--------------------------------------------------------------------
entry:		jmp	initialize
boot_data	db	64 dup (0)		;Leave room for BPB
boot_dataend	=	$

boot_disko	db	80h			;Disk to boot

boot_1:
	        cli				;Disable interrupts
	        cld                             ;Set direction UP.
	        mov     ax,7a00h
	        xor     bx,bx
	        mov     ss,bx                   ;SS:SP = 0:7A00
	        mov     sp,ax
	        sti				;Interrupts OK
		push	si			;Save Part table ptr
		push	bp
		mov	bp,ax

	        mov     ds,bx                   ;DS = 0
	        mov     es,bx                   ;ES = 0
	        mov     di,ax  			;Move boot code 
		mov	si,7c00h
	        mov     cx,100h
	        rep     movsw

	        push    es			;Push re-entry segment
	        mov     al,reloc_entry		;  and offset on the
	        push    ax			;  stack
	        retf				;Return Far to jump
boot_2:
		mov	si,boot_initmsg		;Announce we are here
		call	bprint_msg
		xor	ax,ax			;Read boot sector
		cwd
		mov	bx,7c00h		;To address 0:7C00
		call	boot_read_disk
		jc	boot_error1
		cmp	boot_flag,0AA55h	;Check for boot sig
		jne	boot_error
		mov	si,boot_chgmsg		;Tell user about 
		call	bprint_msg		;  switch
		pop	bp			;Restore BP for 
		pop	si			;  stupid DR-DOS bug
		jmp	bx			;Jump to new boot rec
boot_error:
		mov	si,boot_errmsg		;Print err message
boot_error1:
		call	bprint_msg
boot_halt:
		jmp	boot_halt		;STOP!

;-----------------------------------------------------------------------
; Read disk - Reads one sector from the disk
; Entry: DX,AX - Absolute sector to read
;        BX - address of buffer.
; Exit:  CF - Clear if read successful.
;-----------------------------------------------------------------------
boot_read_disk	proc	near
	        push    bx
		div	sec_per_track		;Get sectors per track
	        inc     dx
read_2:
		mov	bx,dx			;Save sector
	        cwd
	        div     number_of_heads         ;Compute head and cylinder
	        xchg    ah,al                   ;Swap cyl low and high bytes
	        mov     cl,6
	        shl     al,cl                   ;Shift high cyl bits
	        xchg    cx,ax                   ;Copy cyl into CX
	        or      cl,bl                   ;Combine cyl with sector
	        mov     dh,dl                   ;Move head number
	        mov     si,5                    ;Try to read 5 times.
	        pop     bx
read_3:
	        mov     dl,boot_disk            ;Get disk to read
		mov	ax,0201h		;Read 1 sector
	        int     13h                     ;Read/Write disk.
	        jnc     read_exit               ;No error, exit
	        xor     ax,ax                   ;Reset disk before reading
	        int     13h
		dec	si
		jnz	read_3
	        mov     si,boot_rerrmsg		;Read error message
		stc
read_exit:
	        ret
boot_read_disk	endp

;--------------------------------------------------------------------
; Print Msg - Prints a message to the screen
; Entry: DS:SI - Points to ASCIIZ message
;--------------------------------------------------------------------
bprint_msg	proc	near
		push	bx
		push	bp
bprint_msg1:
		lodsb
		or	al,al
		je	bprint_exit
		mov	ah,0eh
		mov	bx,7h
		push	si
		int	10h
		pop	si
		jmp	short bprint_msg1
bprint_exit:
		mov	ax,0e0dh		;Append CR - LF
		int	10h
		mov	ax,0e0ah
		int	10h
		pop	bp
		pop	bx
		ret
bprint_msg	endp
program  	db	13,10,"BOOT2C 1.0 Copyright 1993 Douglas Boling"
                db      13,10,"First published in PC Magazine, " 
		db	"March 30, 1993",13,10,0
change_msg	db	"Redirecting boot to "
change_dest	db	13 dup (0)
error_msg	db	"Error: Target disk not bootable"
		db	13,10,"System halted",0
readerr_msg	db	"Error: reading target drive"
		db	13,10,"System halted",0
bootcode_end	=	$
		org	2feh
		dw	0AA55h			;Boot signature
boot_end	=	$
;====================================================================
;Start of nonresident install code
;====================================================================
infomsg1	db	"USAGE: BOOT2C x: [nn]",13,10
		db	"x: is the target diskette to "
		db	"modify",13,10
		db	"nn is the disk number that the boot is "
		db	"redirected to.",0
		

infomsg2 	db	"Boot2C installed on "
msg2_drive	db	"A:",13,10,"Boot will be redirected to ",0
msg2_hard 	db	"hard disk ",0
msg2_floppy	db	"diskette ",0

errmsg1		db	"Drives not specified",0
errmsg2  	db	"Target diskette not a DOS formatted "
		db	"disk",0
errmsg3 	db	"Unable to fit BOOT2C code on "
		db	"target disk",0
errmsg4		db	"Illegal redirection disk number",0

targ_disk	db	0h			;Disk to modify

doserr_tbl	dw	offset	doserr_00
	 	dw	offset	doserr_01
		dw	offset	doserr_02
		dw	offset	doserr_03
		dw	offset	doserr_04
		dw	offset	doserr_05
		dw	offset	doserr_06
		dw	offset	doserr_07
		dw	offset	doserr_08
		dw	offset	doserr_09
		dw	offset	doserr_10
		dw	offset	doserr_11
		dw	offset	doserr_12
		dw	offset	doserr_unk
doserr_tblend	=	$

doserr_00	db	"Disk Write Protected",0
doserr_01	db	"Unknown Unit",0
doserr_02	db	"Drive not ready",0
doserr_03	db	"Unknown Command",0
doserr_04	db	"CRC Data Error",0
doserr_05	db	"Bad request structure",0
doserr_06	db	"Disk Seek error",0
doserr_07	db	"Not a DOS disk",0
doserr_08	db	"Sector not found",0
doserr_09	db	"Printer out of paper",0
doserr_10	db	"Disk Write fault",0
doserr_11	db	"Disk Read fault",0
doserr_12	db	"General failure",0
doserr_unk	db	"Unknown DOS error",0

;--------------------------------------------------------------------
; INITIALIZE - Entry point of nonresident code
;--------------------------------------------------------------------
initialize:
		cld				;String ops UP
		mov	si,offset program	;Print copyright msg
		call	print_msg

		mov	si,offset infomsg1     	;Syntax msg text
		cmp	byte ptr ds:[80h],0	;See if any command line
		je	init_1			;  exists
		
		mov	si,81h			;Point to cmd line
		call	findnextchar		;Get first character
		jnc	init_2
init_1:		
		mov	si,offset errmsg1	;Syntax error message
		jmp	init_error
init_numerr:
		mov	si,offset errmsg4
		jmp	init_error
init_2:
		and	al,0dfh			;Add drive letter to msg
		mov	msg2_drive,al		;  text.
		or	al,20h			;Convert to lower case
		sub	al,'a'			;See if between a - z
		jb	init_1
		cmp	al,25
		ja	init_1
		mov	ah,al
		lodsb				;See if trailing :
		cmp	al,':'			;  present.
		jne	init_1
		mov	targ_disk,ah

		call	findnextchar		;Find next char on line
		jc	init_4

		call	make_num		;Convert to number
		jc	init_numerr
		xor	ah,ah
		cmp	byte ptr [si],' '	;Check for end of num
		jbe	init_3
		mov	ah,al
		lodsb
		call	make_num		;Convert to number
		jc	init_numerr
		cmp	byte ptr [si],' '	;Check for end of num
                ja	init_numerr

		cmp	ah,8	   		;Only allow 2 digits
		jne	init_numerr		;  if 1st indicates
		mov	ah,80h			;  hard drive.
init_3:
		or	al,ah
		mov	boot_disko,al		;Save dest boot disk num
init_4:
		mov	al,boot_disko		;Get dest boot disk num
		mov	di,offset change_dest
		mov	si,offset msg2_floppy
		test	al,80h
		je	init_5
		mov	si,offset msg2_hard
init_5:
		lodsb				;Copy destination disk msg
		or	al,al			;  to boot record.
		je	init_6
		stosb
		jmp	short init_5
init_6:
		mov	ah,boot_disko		;Get redir disk number, convert
		and	ah,0fh			;  to ASCII and print
		je	init_8
		inc	ah
		mov	al,' '
		add	ah,'0'
		cmp	ah,'9'
		jbe	init_7
		mov	ax,3031h		;Force 10 as digit
init_7:
		mov	[di],ax
init_8:
		call	install			;Install Boot2C
		jc	init_error

		mov	si,offset infomsg2	;Print installed msg
		call	print_line
		mov	si,offset change_dest	;Print destination
		call	print_msg
		xor	ax,ax
init_exit:
		mov	ah,4ch			;Terminate program
		int	21h
init_error:
		call	print_msg		;Print error message
		mov	al,1
		jmp	short init_exit

;--------------------------------------------------------------------
;FINDNEXTCHAR - Finds the next character on the command line
; Entry: SI - Ptr to command line
; Exit:  AL - Character
;        SI - Points to next char
;        CF - Set if end of line found
;--------------------------------------------------------------------
findnextchar	proc	near
		lodsb
		cmp	al,13			;See if end of line
		je	fnchar_err
		cmp	al,20h			;If space, keep looking
		jbe	findnextchar
		clc
fnchar_exit:
		ret
fnchar_err:
		stc
		jmp	short fnchar_exit
findnextchar	endp

;--------------------------------------------------------------------
;MAKE NUM - Converts and ASCII digit to a decimal digit
; Entry: AL - ASCII digit
; Exit:  AL - decimal digit
;        CF - Set if invalid number
;--------------------------------------------------------------------
make_num	proc	near
		sub	al,'0'
		jb	makenum_error
		cmp	al,9
		ja	makenum_error
		clc
makenum_exit:
		ret
makenum_error:
		stc
		jmp	short makenum_exit
make_num	endp

;--------------------------------------------------------------------
;INSTALL - Installs the BOOT2C boot record on the target diskette
; Exit:  CF - Set if error
;        DX - Offset of error message if CF set
;--------------------------------------------------------------------
install		proc	near
		mov	di,offset entry
		mov	al,0e9h			;JMP short opcode
		stosb
		mov	ax,offset boot_1 - offset boot_data
		stosw
		mov	al,targ_disk		;Get target disk
		mov 	cx,1			;read 1 sector
		xor	dx,dx			;Sector 0
		mov	si,dx
		mov	bx,offset end_of_code
		call	read_absolute		;Read current boot rec
		jc	install_error

		mov	si,bx			;Copy ptr to boot rec
		lodsb
		mov	dl,al			;Get opcode
		lodsw
		mov	bx,si
		cmp	dl,0ebh			;See if short JMP opcode
		jne	install_1
					
		xor	ah,ah			;If short JMP, clear 
		jmp	install_2		;  high byte
install_1:
		mov	si,offset errmsg2
		cmp	dl,0e9h			;Check for long JMP
		jne	install_error
install_2:
		mov	si,offset errmsg3
		dec	ax
		cmp	ax,offset boot_dataend - offset entry 
		ja	install_error
		mov	si,bx
		mov	di,offset boot_data	;Copy boot data to 
		mov	cx,ax			;  BOOT2C boot rec
		rep	movsb

		mov	al,targ_disk		;Get target disk
		mov	bx,offset entry
		mov 	cx,1			;read 1 sector
		xor	dx,dx			;Sector 0
		xor	si,si
		call	write_absolute		;Write new boot rec
install_exit:
		ret
install_error:
		stc
		jmp	short install_exit
install		endp

;--------------------------------------------------------------------
; READ ABSOLUTE - Reads sectors from the disk.
; Entry:   AL - Drive to read
;          CX - Number of sectors to read.  
;       SI,DX - Sector to start read (SI only used on huge disks)
;       DS:BX - Pointer to data buffer. 
;--------------------------------------------------------------------
read_abs_hstruc	=	$			;Needed for >32M disks
read_abs_start	dd	0			;Starting sector
read_abs_cnt	dw	0			;Number of sectors to read
read_abs_dbp	dd	0			;Data buffer ptr

read_absolute   proc    near
		push	bx
		push	cx
		push	ds
		call	huge_disk_check
		jc	read_abs_2
		je	read_abs_1
		push	ds			;Save ptr to data buffer
		push	bx
		push	cs
		pop	ds
		mov	bx,offset read_abs_hstruc
		mov	[bx],dx			;More than 64K sectors
		mov	[bx+2],si		;  -> huge disk uses a
		mov	[bx+4],cx		;  different format
		pop	[bx+6]			;  than std int 25h.	
		pop	[bx+8]
		mov	cx,-1
read_abs_1:
	        int     25h                     ;DOS Absolute Disk Read
	        pop     bx                      ;Clean off old flags
		call	seterrmsg
	        cld
read_abs_2:
		pop	ds
		pop	cx
		pop	bx
	        ret
read_absolute   endp

;--------------------------------------------------------------------
; WRITE ABSOLUTE - Writes sectors to the disk.
; Entry:   AL - Drive to write
;          CX - Number of sectors to write  
;       SI,DX - Sector to start write (SI only used on huge disks)
;       DS:BX - Pointer to data buffer. 
;--------------------------------------------------------------------
write_absolute  proc    near
		push	bx
		push	cx
		push	ds
		call	huge_disk_check
		jc	write_abs_2	
		je	write_abs_1
		push	ds			;Save data buffer pointer
		push	bx
		push	cs
		pop	ds
		mov	bx,offset read_abs_hstruc
		mov	[bx],dx			;More than 64K sectors
		mov	[bx+2],si		;  -> huge disk uses a
		mov	[bx+4],cx		;  different format
		pop	[bx+6]			;  than std int 26h.	
		pop	[bx+8]
		mov	cx,-1				
write_abs_1:
	        int     26h                     ;DOS Absolute Disk Write
	        pop     bx                      ;Clean off old flags
		call	seterrmsg
	        cld
write_abs_2:
		pop	ds
		pop	cx
		pop	bx
	        ret
write_absolute  endp

;--------------------------------------------------------------------
; HUGE DISK CHECK - Checks if disk is greater than 32 Meg
; Entry: AL - Disk to check
; Exit:  ZF - Clear if > 32 Meg disk
;        CF - Set if error
;        DI - Sectors per cluster
;--------------------------------------------------------------------
last_disk_read	db	-1
last_disk_huge	db	0
last_disk_spc 	dw	0
huge_disk_check	proc	near
		push	ax
		push	bx
		push	cx
		push	dx
		cmp	al,last_disk_read	;Save last disk checked, if
		jne	huge_disk_check_1	;  same as last disk, just
		mov	di,last_disk_spc	;  get saved answer.
		cmp	last_disk_huge,0	
		jmp	short huge_disk_check_3
huge_disk_check_1:
		mov	last_disk_read,al
		mov	last_disk_huge,0
		mov	dl,al			;Copy disk number
		mov	ah,36h			;DOS Get Free disk space
		inc	dl
		int	21h		
		cmp	ax,-1
		jne	huge_disk_check_2
		mov	last_disk_read,-1
		stc
		jmp	short huge_disk_check_4
huge_disk_check_2:
		mov	di,ax			;Save sectors per cluster
		mov	last_disk_spc,di
		mul	dx
		or	dx,dx			;See if more than 64K sectors
		je	huge_disk_check_3
		mov	last_disk_huge,1
huge_disk_check_3:
		clc
huge_disk_check_4:
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		ret
huge_disk_check	endp

;--------------------------------------------------------------------
; SETERRMSG - Assigns a DOS error message to the value in AL
; Entry: AL - Error code
;        CF - Set if error
; Exit:  SI - Points to error message
;--------------------------------------------------------------------
seterrmsg	proc	near
		push	bx
		pushf
		jnc	seterrmsg_exit
		mov	bx,ax
		xor	bh,bh
		shl	bx,1
		cmp	bx,offset doserr_tblend - offset doserr_tbl
		jbe	seterrmsg_1
		mov	bx,26
seterrmsg_1:
		mov	si,[bx+doserr_tbl]
seterrmsg_exit:
		popf
		pop	bx
		ret
seterrmsg	endp

;--------------------------------------------------------------------
; Print Msg - Prints a message to the screen
; Entry: DS:SI - Points to ASCIIZ message
;--------------------------------------------------------------------
crlf_msg	db	13,10,0
print_msg	proc	near
		call	print_line
		mov	si,offset crlf_msg
		call	print_line
		ret
print_msg	endp

;--------------------------------------------------------------------
; Print Line - Prints a line to the screen
; Entry: DS:SI - Points to ASCIIZ message
;--------------------------------------------------------------------
print_line	proc	near
		lodsb
		or	al,al
		je	print_lineexit
		mov	dl,al
		mov	ah,02
		int	21h
		jmp	short print_line
print_lineexit:
		ret
print_line	endp

		even	
end_of_code	=	$
code		ends
end		entry
