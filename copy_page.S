/*
 *  linux/arch/arm/lib/copypage.S
 *
 *  Copyright (C) 1995-1999 Russell King
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 *  ASM optimised string functions
 */
#include "kernel_defines.h"

/*
 * Notes for Raspberry Pi:
 * RPi does not like paired preloads in a 64-byte loop. Instead,
 * use a 32-byte loop with one preload per loop. In addition,
 * make sure no prefetching happens beyond the source region.
 * The prefetch distance is set to 3 (96 bytes).
 *
 * This version should also be usable on architectures other than
 * armv6 with properly defined L1_CACHE_BYTES and PREFETCH_DISTANCE
 * (e.g. armv7 with L1_CACHE_BYTES == 64).
 */

#define COPY_COUNT (PAGE_SZ / (L1_CACHE_BYTES))

		.text
#ifndef CONFIG_KERNEL_THUMB2
		.p2align	5
#endif
/*
 * StrongARM optimised copy_page routine
 * now 1.78bytes/cycle, was 1.60 bytes/cycle (50MHz bus -> 89MB/s)
 * Note that we probably achieve closer to the 100MB/s target with
 * the core clock switching.
 */
ENTRY(kernel_copy_page)
		stmfd	sp!, {r4-r8, lr}		@	2
	PLD(	pld	[r1, #0]		)
	PLD(	pld	[r1, #L1_CACHE_BYTES]		)
.if PREFETCH_DISTANCE > 2
	PLD(	pld	[r1, #2 * L1_CACHE_BYTES]	)
.if PREFETCH_DISTANCE > 3
	PLD(	pld	[r1, #3 * L1_CACHE_BYTES]	)
.if PREFETCH_DISTANCE > 4
	PLD(	pld	[r1, #4 * L1_CACHE_BYTES]	)
.endif
.endif
.endif
		mov	r2, #COPY_COUNT			@	1
1:	PLD(	pld	[r1, #PREFETCH_DISTANCE * L1_CACHE_BYTES])
2:
.if L1_CACHE_BYTES == 32
		ldmia	r1!, {r3-r6}			@	4+1
	PLD(	sub	r2, r2, #1		)	@	1
	NO_PLD(	subs	r2, r2, #1		)	@	1
		ldmia   r1!, {r7, r8, ip, lr}
		stmia	r0!, {r3-r6}			@	4
	PLD(	cmp	r2, #PREFETCH_DISTANCE	)
		stmia   r0!, {r7, r8, ip, lr}
.else /* L1_CACHE_BYTES == 64 */
		ldmia   r1!, {r3-r8, ip, lr}
	PLD(	sub	r2, r2, #1		)	@	1
	NO_PLD(	subs	r2, r2, #1		)	@	1
		stmia	r0!, {r3-r8, ip, lr}		@	4
		ldmia   r1!, {r3-r8, ip, lr}
	PLD(	cmp	r2, #PREFETCH_DISTANCE	)
		stmia	r0!, {r3-r8, ip, lr}		@	4
.endif
	PLD(	bgt	1b			)	@	1
	NO_PLD(	bne	1b			)
	PLD(	teq	r2, #0			)
	PLD(	bne	2b			)
		ldmfd	sp!, {r4-r8, pc}		@	3
ENDPROC(kernel_copy_page)
