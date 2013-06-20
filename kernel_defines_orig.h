
#define __LINUX_ARM_ARCH__ 6
#define PLD(code...) code
#define L1_CACHE_BYTES 32
#define PAGE_SZ 4096

#define ENTRY(proc) asm_function proc

#define ENDPROC(proc) .endfunc

#define CALGN(code...)

#define pull            lsl
#define push            lsr
#define W(instr)        instr

