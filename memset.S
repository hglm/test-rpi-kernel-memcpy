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
 *
 *  Optimization for modern ARM platforms
 *  Copyright 2013 Harm Hanemaaijer
 *
 */
#include "kernel_defines.h"

	.text
#ifndef CONFIG_THUMB2_KERNEL
	.p2align 5
#endif

ENTRY(kernel_memset)
	ands	r3, r0, #3		@ 1 unaligned?
	mov	ip, r0			@ preserve ip as return value
	bne	6f			@ 1
/*
 * we know that the pointer in r0 is aligned to a word boundary.
 */
1:	orr	r1, r1, r1, lsl #8
	cmp	r2, #8
	orr	r1, r1, r1, lsl #16
	mov	r3, r1
	blt	4f

#if ! CALGN_MEMSET(1)+0

/*
 * We need 2 extra registers for this loop - use r4 and r5
 */
	cmp	r2, #64
	stmfd	sp!, {r4}
	blt	7f
	stmfd	sp!, {r5}
	mov	r4, r1
	mov	r5, r1

2:	stmia	r0!, {r1, r3, r4, r5}	@ 64 bytes at a time.
	subs	r2, r2, #64
	stmia	r0!, {r1, r3, r4, r5}
	cmp	r2, #64
	stmia	r0!, {r1, r3, r4, r5}
	stmia	r0!, {r1, r3, r4, r5}
	bge	2b

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
	stmfd	sp!, {r4}
	blt	7f
	stmfd	sp!, {r5}
	mov	r4, r1
	mov	r5, r1

.if MEMSET_WRITE_ALIGN_BYTES == 8
	tst	r0, #4
	beq	3f

	cmp	r2, #68
	str	r1, [r0], #4
        sub	r2, r2, #4
	blt     9f
.else	/* MEMSET_WRITE_ALIGN_BYTES == 32 */
	tst	r0, #31
	beq	3f
	tst     r0, #4
	strne	r1, [r0], #4
        subne	r2, r2, #4
	tst     r0, #8
	stmneia r0!, {r1, r3}
        subne   r2, r2, #8
	tst	r0, #16
	stmneia r0!, {r1, r3}
        subne   r2, r2, #16
        stmneia r0!, {r1, r3}
	cmp	r2, #64
	blt	9f
.endif

3:	stmia	r0!, {r1, r3, r4, r5}
	subs	r2, r2, #64		/* Thumb16 */
	stmia	r0!, {r1, r3, r4, r5}
	cmp     r2, #64
	stmia	r0!, {r1, r3, r4, r5}
	stmia	r0!, {r1, r3, r4, r5}
	bge	3b
#endif

	/* Early exit if there are 0 bytes left. */
THUMB(	cbz	r2, 8f	)
ARM(	teq	r2, #0	)
ARM(	beq	8f	)
9:	ldmfd	sp!, {r5}

	/* Handle 8-64 bytes. */
7:	bics	r4, r2, #7
	sub	r2, r2, r4
	rsb	r4, r4, #64
	/* The stmia instruction is 32-bit for ARM, 16-bit for Thumb2. */
THUMB(	lsrs	r4, r4, #2	)
ARM(	lsrs	r4, r4, #1	)
	add	pc, pc, r4
	nop
	stmia	r0!, {r1, r3}
	stmia	r0!, {r1, r3}
	stmia	r0!, {r1, r3}
	stmia	r0!, {r1, r3}
	stmia	r0!, {r1, r3}
	stmia	r0!, {r1, r3}
	stmia	r0!, {r1, r3}
	stmia	r0!, {r1, r3}
	ldmfd	sp!, {r4}

4:	cmp	r2, #4
	strge	r1, [r0], #4
	/* Early exit for multiple of 4 size. */
	tst	r2, #3
	moveq	r0, ip
	moveq	pc, lr
/*
 * When we get here, we've got less than 4 bytes to zero.  We
 * may have an unaligned pointer as well.
 */
5:	tst	r2, #2
	strneb	r1, [r0], #1
	strneb	r1, [r0], #1
	tst	r2, #1
	strneb	r1, [r0], #1
	mov	r0, ip
	mov	pc, lr

8:	ldmfd	sp!, {r5}
	ldmfd	sp!, {r4}
	mov	r0, ip
	mov	pc, lr

6:	subs	r2, r2, #4		@ 1 do we have enough
	blt	5b			@ 1 bytes to align with?
	cmp	r3, #2			@ 1
	strltb	r1, [r0], #1		@ 1
	strleb	r1, [r0], #1		@ 1
	strb	r1, [r0], #1		@ 1
	add	r2, r2, r3		@ 1 (r2 = r2 - (4 - r3))
	b	1b
ENDPROC(kernel_memset)
