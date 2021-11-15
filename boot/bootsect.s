!
! SYS_SIZE is the number of clicks (16 bytes) to be loaded.
! 0x3000 is 0x30000 bytes = 196kB, more than enough for current
! versions of linux
!
SYSSIZE = 0x3000 #定义system模块的长度 段地址
!
!	bootsect.s		(C) 1991 Linus Torvalds
!
! bootsect.s is loaded at 0x7c00 by the bios-startup routines, and moves
! iself out of the way to address 0x90000, and jumps there.
!
! It then loads 'setup' directly after itself (0x90200), and the system
! at 0x10000, using BIOS interrupts. 
!
! NOTE! currently system is at most 8*65536 bytes long. This should be no
! problem, even in the future. I want to keep it simple. This 512 kB
! kernel size should be enough, especially as this doesn't contain the
! buffer cache as in minix
!
! The loader has been made as simple as possible, and continuos
! read errors will result in a unbreakable loop. Reboot by hand. It
! loads pretty fast by getting whole sectors at a time whenever possible.

.globl begtext, begdata, begbss, endtext, enddata, endbss
.text
begtext:
.data
begdata:
.bss
begbss:
.text

SETUPLEN = 4				! nr of setup-sectors  //setup的扇区数目的值
BOOTSEG  = 0x07c0			! original address of boot-sector //bootseg的段地址 以下都是段地址
INITSEG  = 0x9000			! we move boot here - out of the way //转移之后bootseg的地址
SETUPSEG = 0x9020			! setup starts here //setup的地址
SYSSEG   = 0x1000			! system loaded at 0x10000 (65536). //system地址
ENDSEG   = SYSSEG + SYSSIZE		! where to stop loading

! ROOT_DEV:	0x000 - same type of floppy as boot.
!		0x301 - first partition on first drive etc
ROOT_DEV = 0x306 //这里指定的是根文件系统设备(第几个硬盘,第几个分区)

entry start
start:
	mov	ax,#BOOTSEG
	mov	ds,ax      //设置此时的bootseg段地址到ds
	mov	ax,#INITSEG
	mov	es,ax  //设置此时initseg段地址到es
	mov	cx,#256  //循环的次数,执行256次
	sub	si,si //ds:si 将ds的偏移地址设为0
	sub	di,di //es::di 将es的偏移地址设为0
	rep //执行movw的操作256次
	movw
	jmpi	go,INITSEG // 段间跳转, 此时, CS段地址是INITSEG, 偏移地址是go,
go:	mov	ax,cs  
	mov	ds,ax //将cs段地址给ds
	mov	es,ax //将cs段地址es
! put stack at 0x9ff00.
	mov	ss,ax  //将cs地址给ss
	mov	sp,#0xFF00		! arbitrary value >>512  //使得ss的栈大于system +setup区域, (0x200+0x200*4+堆栈大小)

! load the setup-sectors directly after the bootblock.
! Note that 'es' is already set up.

load_setup: //这里吧setup的数据读入到0x90000处
	mov	dx,#0x0000		! drive 0, head 0  //设置读入磁盘的位置
	mov	cx,#0x0002		! sector 2, track 0 //同上
	mov	bx,#0x0200		! address = 512, in INITSEG // ES:BX缓冲地址,读入的目标位置
	mov	ax,#0x0200+SETUPLEN	! service 2, nr of sectors // 高位表示方式,地位表示目标位置的扇区数
	int	0x13			! read it  //开始读数
	jnc	ok_load_setup		! ok - continue   //读入完成后跳转
	mov	dx,#0x0000
	mov	ax,#0x0000		! reset the diskette
	int	0x13
	j	load_setup  //读数错误后死循环

ok_load_setup: //获取磁盘驱动器的一系列参数

! Get disk drive parameters, specifically nr of sectors/track

	mov	dl,#0x00          //驱动器号
	mov	ax,#0x0800		! AH=8 is get drive parameters
	int	0x13   
	mov	ch,#0x00  
	seg cs //表示下一条语句的操作数在cs中
	mov	sectors,cx  //此时cx是每磁道的扇区数目
	mov	ax,#INITSEG  
	mov	es,ax //设置es段的地址为0x9000, 原因是因为取磁道的参数导致es发生了变化

! Print some inane message

	mov	ah,#0x03		! read cursor pos 
	xor	bh,bh  //异或,两值不同为真,这里等于0表示以图形显示
	int	0x10  //读取光标位置,存储到dx中,
	
	mov	cx,#24 //显示字符的长度
	mov	bx,#0x0007		! page 0, attribute 7 (normal)  //
	mov	bp,#msg1  //显示的字符串,es:bp指向该位置,es是该文件的地址0x90000
	mov	ax,#0x1301		! write string, move cursor // 写字符串
	int	0x10 //利用中断执行

! ok, we've written the message, now
! we want to load the system (at 0x10000)

	mov	ax,#SYSSEG  
	mov	es,ax		! segment of 0x010000 //设置es段地址为0x010000 
	call	read_it //读数据
	call	kill_motor

! After that we check which root-device to use. If the device is
! defined (!= 0), nothing is done and the given device is used.
! Otherwise, either /dev/PS0 (2,28) or /dev/at0 (2,8), depending
! on the number of sectors that the BIOS reports currently.
//找根文件设备
	seg cs
	mov	ax,root_dev
	cmp	ax,#0
	jne	root_defined
	seg cs
	mov	bx,sectors
	mov	ax,#0x0208		! /dev/ps0 - 1.2Mb
	cmp	bx,#15
	je	root_defined
	mov	ax,#0x021c		! /dev/PS0 - 1.44Mb
	cmp	bx,#18
	je	root_defined
undef_root:
	jmp undef_root
root_defined:
	seg cs
	mov	root_dev,ax

! after that (everyting loaded), we jump to
! the setup-routine loaded directly after
! the bootblock:

	jmpi	0,SETUPSEG

! This routine loads the system at address 0x10000, making sure
! no 64kB boundaries are crossed. We try to load it as fast as
! possible, loading whole tracks whenever we can.
!
! in:	es - starting address segment (normally 0x1000)
!
sread:	.word 1+SETUPLEN	! sectors read of current track
head:	.word 0			! current head
track:	.word 0			! current track

read_it:
	mov ax,es //测试输入的段值
	test ax,#0x0fff //测试ax的值与0x0fff的关系,
die:	jne die			! es must be at 64kB boundary
	xor bx,bx		! bx is starting address within segment
rp_read:   //判断是否读完,没有读完跳到ok1_read
	mov ax,es
	cmp ax,#ENDSEG		! have we loaded all yet? 
	jb ok1_read
	ret
ok1_read:  //计算和验证当前磁道需要读取的扇区数目
	seg cs
	mov ax,sectors //取每磁道扇区数
	sub ax,sread //减去当前已经读入的扇区数目
	mov cx,ax //未读的扇区
	shl cx,#9  //将cx左移动9位 ,cx=cx*512
	add cx,bx //cx保存此时读入的字节数
	jnc ok2_read  
	je ok2_read
	xor ax,ax
	sub ax,bx
	shr ax,#9
ok2_read:
	call read_track
	mov cx,ax
	add ax,sread
	seg cs
	cmp ax,sectors
	jne ok3_read
	mov ax,#1
	sub ax,head
	jne ok4_read
	inc track
ok4_read:
	mov head,ax
	xor ax,ax
ok3_read:
	mov sread,ax
	shl cx,#9
	add bx,cx
	jnc rp_read
	mov ax,es
	add ax,#0x1000
	mov es,ax
	xor bx,bx
	jmp rp_read

read_track:
	push ax
	push bx
	push cx
	push dx
	mov dx,track
	mov cx,sread
	inc cx
	mov ch,dl
	mov dx,head
	mov dh,dl
	mov dl,#0
	and dx,#0x0100
	mov ah,#2
	int 0x13
	jc bad_rt
	pop dx
	pop cx
	pop bx
	pop ax
	ret
bad_rt:	mov ax,#0
	mov dx,#0
	int 0x13
	pop dx
	pop cx
	pop bx
	pop ax
	jmp read_track

/*
 * This procedure turns off the floppy drive motor, so
 * that we enter the kernel in a known state, and
 * don't have to worry about it later.
 */
kill_motor:
	push dx
	mov dx,#0x3f2
	mov al,#0
	outb
	pop dx
	ret

sectors:
	.word 0

msg1:
	.byte 13,10 //回车换行的ascii码
	.ascii "Loading system ..."
	.byte 13,10,13,10

.org 508
root_dev:
	.word ROOT_DEV
boot_flag:
	.word 0xAA55

.text
endtext:
.data
enddata:
.bss
endbss: 
