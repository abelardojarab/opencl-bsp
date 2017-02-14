#ifndef __ACL_QPIMMD_H__
#define __ACL_QPIMMD_H__

#ifdef _WIN32
#else
#include <unistd.h>
typedef unsigned char BYTE;
typedef unsigned char UCHAR;
typedef unsigned short WORD;
typedef unsigned short USHORT;
#ifdef _LP64
typedef unsigned int  DWORD;
typedef unsigned int  ULONG;
typedef unsigned long int ULONGLONG;
typedef unsigned int *LPTR;
#else
typedef unsigned long DWORD;
typedef unsigned long ULONG;
typedef unsigned long int ULONGLONG;
typedef unsigned long *LPTR;
#endif
#endif


#endif
