extern inline unsigned char get_fs_byte(const char * addr) //或者一个字节的用户空间的数据 ,*addr是用户空间的偏移地址,将fs:addr指向的内存地址的一个字节复制并返回
{
	unsigned register char _v;

	__asm__ ("movb %%fs:%1,%0":"=r" (_v):"m" (*addr));
	return _v;
}

extern inline unsigned short get_fs_word(const unsigned short *addr)
{
	unsigned short _v;

	__asm__ ("movw %%fs:%1,%0":"=r" (_v):"m" (*addr));
	return _v;
}

extern inline unsigned long get_fs_long(const unsigned long *addr)
{
	unsigned long _v;

	__asm__ ("movl %%fs:%1,%0":"=r" (_v):"m" (*addr)); \
	return _v;
}

extern inline void put_fs_byte(char val,char *addr) //从核心态拷贝一个字节的数据到用户态
{
__asm__ ("movb %0,%%fs:%1"::"r" (val),"m" (*addr));
}

extern inline void put_fs_word(short val,short * addr)
{
__asm__ ("movw %0,%%fs:%1"::"r" (val),"m" (*addr));
}

extern inline void put_fs_long(unsigned long val,unsigned long * addr)
{
__asm__ ("movl %0,%%fs:%1"::"r" (val),"m" (*addr));
}

/*
 * Someone who knows GNU asm better than I should double check the followig.
 * It seems to work, but I don't know if I'm doing something subtly wrong.
 * --- TYT, 11/24/91
 * [ nothing wrong here, Linus ]
 */

extern inline unsigned long get_fs() 
{
	unsigned short _v;
	__asm__("mov %%fs,%%ax":"=a" (_v):);
	return _v;
}

extern inline unsigned long get_ds() 
{
	unsigned short _v;
	__asm__("mov %%ds,%%ax":"=a" (_v):);
	return _v;
}

extern inline void set_fs(unsigned long val)
{
	__asm__("mov %0,%%fs"::"a" ((unsigned short) val));
}

