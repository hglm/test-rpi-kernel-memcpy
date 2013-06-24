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
	.align	5

1:	subs	r2, r2, #4		@ 1 do we have enough
	blt	5f			@ 1 bytes to align with?
	cmp	r3, #2			@ 1
	strltb	r1, [r0], #1		@ 1
	strleb	r1, [r0], #1		@ 1
	strb	r1, [r0], #1		@ 1
	add	r2, r2, r3		@ 1 (r2 = r2 - (4 - r3))
	b	6f
/*
 * The pointer is now aligned and the length is adjusted.  Try doing the
 * memset again.
 * Note: There is no need to recheck for alignment; by branching over the
 * alignment check we can push r0 and lr in the entry code.
 */

ENTRY(kernel_memset)
	ands	r3, r0, #3		@ 1 unaligned?
	stmfd	sp!, {r0, lr}
	bne	1b			@ 1
/*
 * we know that the pointer in r0 is aligned to a word boundary.
 */
6:	orr	r1, r1, r1, lsl #8
	orr	r1, r1, r1, lsl #16
	mov	r3, r1
	cmp	r2, #16
	blt	4f

#if ! CALGN_MEMSET(1)+0

/*
 * We need an extra register for this loop - save the return address and
 * use the LR
 */
	mov	ip, r1
	mov	lr, r1

2:	subs	r2, r2, #64
	stmgeia	r0!, {r1, r3, ip, lr}	@ 64 bytes at a time.
	stmgeia	r0!, {r1, r3, ip, lr}
	stmgeia	r0!, {r1, r3, ip, lr}
	stmgeia	r0!, {r1, r3, ip, lr}
	bgt	2b
	ldreq	sp!, {r0, pc}		@ Now <64 bytes to go.
/*
 * No need to correct the count; we're only testing bits from now on
 */
	tst	r2, #32
	stmneia	r0!, {r1, r3, ip, lr}
	stmneia	r0!, {r1, r3, ip, lr}
	tst	r2, #16
	stmneia	r0!, {r1, r3, ip, lr}

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

	cmp	r2, #96
	mov	ip, r1
	tstgt	r0, #31
	mov	lr, r1
	ble	3f

	and	ip, r0, #31
	rsb	ip, ip, #32
	sub	r2, r2, ip
	movs	ip, ip, lsl #(32 - 4)
	stmcsia	r0!, {r1, r3}
	stmcsia r0!, {r1, r3}
	stmmiia	r0!, {r1, r3}
	tst	ip, #(1 << 30)
	mov	ip, r3
	strne	r1, [r0], #4

3:	
	subs	r2, r2, #64
	stmgeia	r0!, {r1, r3, ip, lr}
	stmgeia	r0!, {r1, r3, ip, lr}
	stmgeia	r0!, {r1, r3, ip, lr}
	stmgeia	r0!, {r1, r3, ip, lr}
	bgt	3b
	ldmeqfd	sp!, {r0, pc}

	tst	r2, #32
	stmneia	r0!, {r1, r3, ip, lr}
	tst	r2, #16
	stmneia	r0!, {r1, r3, ip, lr}

#endif

4:	tst	r2, #8
	stmneia	r0!, {r1, r3}
	tst	r2, #4
	strne	r1, [r0], #4
/*
 * When we get here, we've got less than 4 bytes to zero.  We
 * may have an unaligned pointer as well.
 */
5:	tst	r2, #2
	strneb	r1, [r0], #1
	strneb	r1, [r0], #1
	tst	r2, #1
	strneb	r1, [r0], #1
	ldmfd	sp!, {r0, pc}
ENDPROC(kernel_memset)
