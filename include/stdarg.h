#ifndef _STDARG_H
#define _STDARG_H

typedef char *va_list; 

/* Amount of space required in an argument list for an arg of type TYPE.
   TYPE may alternatively be an expression whose type is used.  */

#define __va_rounded_size(TYPE)  \
  (((sizeof (TYPE) + sizeof (int) - 1) / sizeof (int)) * sizeof (int))

#ifndef __sparc__
#define va_start(AP, LASTARG) 						\ //获取传给函数的可变参数列表的第一个参数的地址
 (AP = ((char *) &(LASTARG) + __va_rounded_size (LASTARG)))
#else
#define va_start(AP, LASTARG) 						\
 (__builtin_saveregs (),						\
  AP = ((char *) &(LASTARG) + __va_rounded_size (LASTARG)))
#endif

void va_end (va_list);		/* Defined in gnulib */ //所有参数读取完毕后调用
#define va_end(AP)
 
#define va_arg(AP, TYPE)						\ //每调用一次就会取出当前的参数的值,并移向下一个参数的首地址
 (AP += __va_rounded_size (TYPE),					\
  *((TYPE *) (AP - __va_rounded_size (TYPE))))

#endif /* _STDARG_H */
