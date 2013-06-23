
#define PLD(code...) code
#ifdef SUNXI
#define __LINUX_ARM_ARCH__ 7
#define L1_CACHE_BYTES 64
#else
#define __LINUX_ARM_ARCH__ 6
#define L1_CACHE_BYTES 32
#endif
#define PAGE_SZ 4096

#define ENTRY(proc) asm_function proc

#define ENDPROC(proc) .endfunc

#define CALGN(code...)

#define pull            lsl
#define push            lsr
#define W(instr)        instr

