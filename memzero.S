/*
 *  linux/arch/arm/lib/memzero.S
 *
 *  Copyright (C) 1995-2000 Russell King
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 */
#include "kernel_defines.h"

	.text
	.align	5
/*
 * Align the pointer in r0.  r3 contains the number of bytes that we are
 * mis-aligned by, and r1 is the number of bytes.  If r1 < 4, then we
 * don't bother; we use byte stores instead.
 */
1:	subs	r1, r1, #4		@ 1 do we have enough
	blt	5f			@ 1 bytes to align with?
	cmp	r3, #2			@ 1
	add	r1, r1, r3		@ 1 (r1 = r1 - (4 - r3))
	strltb	r2, [r0], #1		@ 1
	strleb	r2, [r0], #1		@ 1
	mov	r3, r2
	strb	r2, [r0], #1		@ 1
/*
 * The pointer is now aligned and the length is adjusted.  Try doing the
 * memzero again.
 */
	b	6f

	.p2align 5
ENTRY(__kernel_memzero)
	ands	r3, r0, #3		@ 1 unaligned?
	mov	r2, #0			@ 1
	bne	1b			@ 1
/*
 * r3 = 0, and we know that the pointer in r0 is aligned to a word boundary.
 */

#if ! CALGN_MEMSET(1)+0

6:	cmp	r1, #16			@ 1 we can skip this chunk if we
	blt	4f			@ 1 have < 16 bytes

/*
 * We need an extra register for this loop - save the return address and
 * use the LR
 */
	str	lr, [sp, #-4]!		@ 1
	mov	ip, r2			@ 1
	mov	lr, r2			@ 1

3:	subs	r1, r1, #64		@ 1 write 32 bytes out per loop
	stmgeia	r0!, {r2, r3, ip, lr}	@ 4
	stmgeia	r0!, {r2, r3, ip, lr}	@ 4
	stmgeia	r0!, {r2, r3, ip, lr}	@ 4
	stmgeia	r0!, {r2, r3, ip, lr}	@ 4
	bgt	3b			@ 1
	ldmeqfd	sp!, {pc}		@ 1/2 quick exit
/*
 * No need to correct the count; we're only testing bits from now on
 */
	tst	r1, #32			@ 1
	stmneia	r0!, {r2, r3, ip, lr}	@ 4
	stmneia	r0!, {r2, r3, ip, lr}	@ 4
	tst	r1, #16			@ 1 16 bytes or more?
	stmneia	r0!, {r2, r3, ip, lr}	@ 4
	ldr	lr, [sp], #4		@ 1

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

6:	str	lr, [sp, #-4]!

	cmp	r1, #64
	mov	ip, r2
	mov     lr, r2
	blt	7f

.if MEMSET_WRITE_ALIGN_BYTES == 8
	tst	r0, #4
	beq	3f

	cmp	r1, #68
	str	r2, [r0], #4
        sub	r1, r1, #4
	blt     7f
.else	/* MEMSET_WRITE_ALIGN_BYTES == 32 */
	tst	r0, #31
	beq	3f
	tst     r0, #4
	strne	r2, [r0], #4
        subne	r1, r1, #4
	tst     r0, #8
	stmneia r0!, {r2, r3}
        subne   r1, r1, #8
	tst	r0, #16
	stmneia r0!, {r2, r3}
        subne   r1, r1, #16
        stmneia r0!, {r2, r3}
	cmp	r1, #64
	blt	7f
.endif

3:	stmia	r0!, {r2, r3, ip, lr}
	subs	r1, r1, #64
	stmia	r0!, {r2, r3, ip, lr}
	cmp	r1, #64
	stmia	r0!, {r2, r3, ip, lr}
	stmia	r0!, {r2, r3, ip, lr}
	bge	3b
	tst	r1, #63
	ldmeqfd	sp!, {pc}

7:	tst	r1, #32
	stmneia	r0!, {r2, r3, ip, lr}
	stmneia	r0!, {r2, r3, ip, lr}
	tst	r1, #16
	stmneia	r0!, {r2, r3, ip, lr}
	ldr	lr, [sp], #4

#endif

4:	tst	r1, #8			@ 1 8 bytes or more?
	stmneia	r0!, {r2, r3}		@ 2
	tst	r1, #4			@ 1 4 bytes or more?
	strne	r2, [r0], #4		@ 1
/*
 * When we get here, we've got less than 4 bytes to zero.  We
 * may have an unaligned pointer as well.
 */
5:	tst	r1, #2			@ 1 2 bytes or more?
	strneb	r2, [r0], #1		@ 1
	strneb	r2, [r0], #1		@ 1
	tst	r1, #1			@ 1 a byte left over
	strneb	r2, [r0]		@ 1
	mov	pc, lr			@ 1
ENDPROC(__kernel_memzero)
