
#ifdef ARMV7
#define __LINUX_ARM_ARCH__ 7
#define L1_CACHE_BYTES 64
#else
#define __LINUX_ARM_ARCH__ 6
#define L1_CACHE_BYTES 32
#endif

#if __LINUX_ARM_ARCH__ == 6
#define PREFETCH_DISTANCE 3
#else
#define PREFETCH_DISTANCE 3
#endif
#define PAGE_SZ 4096

#define PLD(code...) code
#define NO_PLD(code...)

#define ENTRY(proc) asm_function proc

#define ENDPROC(proc) .endfunc

#if __LINUX_ARM_ARCH__ >= 6
#define CALGN(code...) code
#if __LINUX_ARM_ARCH__ == 6
#define WRITE_ALIGN_BYTES 32
#else
#define WRITE_ALIGN_BYTES 32
#endif
#else
#define CALGN(code...)
#endif
#if __LINUX_ARM_ARCH__ == 6
#define CALGN_MEMSET(code...) code
#define MEMSET_WRITE_ALIGN_BYTES 8
#else
#define CALGN_MEMSET(code...)
#endif

#define pull            lsr
#define push            lsl
#define W(instr)        instr

.macro asm_function function_name
    .global \function_name
.func \function_name
.type \function_name, function
\function_name:
.endm
