/*
 *  linux/arch/arm/lib/memset.S
 *
 *  Copyright (C) 1995-2000 Russell King
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 *  ASM optimised string functions
 */
#include "kernel_defines.h"

	.text
	.p2align 5

ENTRY(kernel_memset)
	ands	r3, r0, #3		@ 1 unaligned?
	mov	ip, r0			@ preserve r0 as return value
	bne	6f			@ 1
/*
 * we know that the pointer in r0 is aligned to a word boundary.
 */
6:	orr	r1, r1, r1, lsl #8
	cmp	r2, #16
	orr	r1, r1, r1, lsl #16
	mov	r3, r1
	blt	4f

#if ! CALGN_MEMSET(1)+0

/*
 * We need 2 extra registers for this loop - use r8 and the LR
 */
	stmfd	sp!, {r8, lr}
	mov	r8, r1
	mov	lr, r1

2:	subs	r2, r2, #64
	stmgeia	ip!, {r1, r3, r8, lr}	@ 64 bytes at a time.
	stmgeia	ip!, {r1, r3, r8, lr}
	stmgeia	ip!, {r1, r3, r8, lr}
	stmgeia	ip!, {r1, r3, r8, lr}
	bgt	2b
	ldmeqfd	sp!, {r8, pc}		@ Now <64 bytes to go.
/*
 * No need to correct the count; we're only testing bits from now on
 */
	tst	r2, #32
	stmneia	ip!, {r1, r3, r8, lr}
	stmneia	ip!, {r1, r3, r8, lr}
	tst	r2, #16
	stmneia	ip!, {r1, r3, r8, lr}
	ldmfd	sp!, {r8, lr}

#else

/*
 * This version aligns the destination pointer in order to write
 * whole cache lines at once.
 *
 * However, at least some architectures don't like writing 32 bytes
 * at a time. Since it's unlikely that it will hurt performance,
 * write 16 bytes at a time, eliminating save/restore of extra
 * registers on the stack.
 */

	cmp	r2, #64
	stmfd	sp!, {r8, lr}
	mov	r8, r1
	mov	lr, r1
	blt	7f
.if MEMSET_WRITE_ALIGN_BYTES == 8
	tst	ip, #4
	beq	3f

	cmp	r2, #68
	str	r1, [ip], #4
        sub	r2, r2, #4
	blt     7f
.else	/* MEMSET_WRITE_ALIGN_BYTES == 32 */
	tst	ip, #31
	beq	3f
	tst     ip, #4
	strne	r1, [ip], #4
        subne	r2, r2, #4
	tst     ip, #8
	stmneia ip!, {r1, r3}
        subne   r2, r2, #8
	tst	ip, #16
	stmneia ip!, {r1, r3}
        subne   r2, r2, #16
        stmneia ip!, {r1, r3}
	cmp	r2, #64
	blt	7f
.endif

3:	stmia	ip!, {r1, r3, r8, lr}
	sub	r2, r2, #64
	stmia	ip!, {r1, r3, r8, lr}
	cmp     r2, #64
	stmia	ip!, {r1, r3, r8, lr}
	stmia	ip!, {r1, r3, r8, lr}
	bge	3b
	tst     r2, #63
	ldmeqfd	sp!, {r8, pc}

7:	tst	r2, #32
	stmneia	ip!, {r1, r3, r8, lr}
	stmneia	ip!, {r1, r3, r8, lr}
	tst	r2, #16
	stmneia	ip!, {r1, r3, r8, lr}
	ldmfd	sp!, {r8, lr}

#endif

4:	tst	r2, #8
	stmneia	ip!, {r1, r3}
	tst	r2, #4
	strne	r1, [ip], #4
/*
 * When we get here, we've got less than 4 bytes to zero.  We
 * may have an unaligned pointer as well.
 */
5:	tst	r2, #2
	strneb	r1, [ip], #1
	strneb	r1, [ip], #1
	tst	r2, #1
	strneb	r1, [ip], #1
	mov	pc, lr

6:	subs	r2, r2, #4		@ 1 do we have enough
	blt	5b			@ 1 bytes to align with?
	cmp	r3, #2			@ 1
	strltb	r1, [ip], #1		@ 1
	strleb	r1, [ip], #1		@ 1
	strb	r1, [ip], #1		@ 1
	add	r2, r2, r3		@ 1 (r2 = r2 - (4 - r3))
	b	1b
ENDPROC(kernel_memset)
