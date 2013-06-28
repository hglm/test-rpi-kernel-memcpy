/*
 *  linux/arch/arm/lib/copy_template.s
 *
 *  Code template for optimized memory copy functions
 *
 *  Author:	Nicolas Pitre
 *  Created:	Sep 28, 2005
 *  Copyright:	MontaVista Software, Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License version 2 as
 *  published by the Free Software Foundation.
 */

/*
 * Theory of operation
 * -------------------
 *
 * This file provides the core code for a forward memory copy used in
 * the implementation of memcopy(), copy_to_user() and copy_from_user().
 *
 * The including file must define the following accessor macros
 * according to the need of the given function:
 *
 * ldr1w ptr reg abort
 *
 *	This loads one word from 'ptr', stores it in 'reg' and increments
 *	'ptr' to the next word. The 'abort' argument is used for fixup tables.
 *
 * ldr4w ptr reg1 reg2 reg3 reg4 abort
 * ldr8w ptr, reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 abort
 *
 *	This loads four or eight words starting from 'ptr', stores them
 *	in provided registers and increments 'ptr' past those words.
 *	The'abort' argument is used for fixup tables.
 *
 * ldr1b ptr reg cond abort
 *
 *	Similar to ldr1w, but it loads a byte and increments 'ptr' one byte.
 *	It also must apply the condition code if provided, otherwise the
 *	"al" condition is assumed by default.
 *
 * str1w ptr reg abort
 * str8w ptr reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 abort
 * str1b ptr reg cond abort
 *
 *	Same as their ldr* counterparts, but data is stored to 'ptr' location
 *	rather than being loaded.
 *
 * enter reg1 reg2
 *
 *	Preserve the provided registers on the stack plus any additional
 *	data as needed by the implementation including this code. Called
 *	upon code entry.
 *
 * exit reg1 reg2
 *
 *	Restore registers with the values previously saved with the
 *	'preserv' macro. Called upon code termination.
 *
 * LDR1W_SHIFT
 * STR1W_SHIFT
 *
 *	Correction to be applied to the "ip" register when branching into
 *	the ldr1w or str1w instructions (some of these macros may expand to
 *	than one 32bit instruction in Thumb-2)
 *
 * L1_CACHE_BYTES
 *
 *      The cache line size used for prefetches. Preloads are performed at
 *      L1_CACHE_BYTES aligned addresses. However, if L1_CACHE_BYTES == 64,
 *      in the case of unaligned copies preload instructions are performed
 *      at 32 bytes aligned addresses. The code could be modified to strictly
 *      preload at 64 bytes aligned addresses, at the cost of increasing code
 *      size and complexity. However, the armv7 architecture doesn't seem
 *      to incur a big penalty for the unnecessary preload instructions.
 *      Additionally unaligned copies are rare.
 *
 * PREFETCH_DISTANCE
 *
 *      The prefetch distance in units of L1_CACHE_BYTES used for prefetches.
 *
 * WRITE_ALIGN_BYTES
 *
 *      Write aligning is enabled if the CALGN macro expands to instructions
 *      instead of nothing. When enabled, WRITE_ALIGN_BYTES defines the number
 *      of bytes to align to (it must be 16 or 32).
 *
 * COPY_FUNCTION_MEMCPY
 *
 *      When COPY_FUNCTION_MEMCPY is defined, there no need to use single word
 *      loads and stores in the alignment and tail parts for the word aligned
 *      case. This results in a measurable speed-up for modern ARM platforms.
 *      Additionally, write alignment is disabled when COPY_FUNCTION_MEMCPY
 *      is not defined.
 *
 * COPY_FUNCTION_FROM_USER
 *
 *      This is defined when compiling the copy_from_user function. The write
 *      alignment code is disabled because it is slower (the main loop will
 *      load single words any way, and the write alignment code only
 *      constitutes overhead).
 *
 * COPY_FUNCTION_TO_USER
 *
 *      This is defined when compiling the copy_to_user and copy_to_user_std
 *      functions. The write alignment code is disabled because it is slower
 *      (the main loop will write single words any way, and the write alignment
 *      code only constitutes overhead).
 *
 */

#ifdef COPY_FUNCTION_MEMCPY
/* The small size threshold must be >= 15 for COPY_FUNCTION_MEMCPY. */
#define SMALL_SIZE_THRESHOLD 15
/*
 * For regular memcpy, doing word-aligned small sizes by jumping into an
 * unrolled loop might be faster for dual-issue architectures. Currently
 * disabled.
 */
/* #define SMALL_SIZE_THRESHOLD 32 */
/* #define SMALL_SIZE_UNROLLED */
/*
 * For regular memcpy, we have a fast path handling up to 256 bytes for
 * word aligned requests. Because the fast path doesn't do write aligning,
 * on platforms that appreciate write aligning setting the threshold to a
 * lower value than 256 bytes might have a benefit.
 */
#define FAST_PATH_SIZE_THRESHOLD 256
#endif
#ifdef COPY_FUNCTION_FROM_USER
#define SMALL_SIZE_THRESHOLD 8
#define FAST_PATH_SIZE_THRESHOLD 95
/*
 * For copy_from_user, the fast path is unoptimal for sizes greater or
 * equal to about 96 bytes.
 */
#define DISABLE_WRITE_ALIGNMENT
#endif
#ifdef COPY_FUNCTION_TO_USER
#define SMALL_SIZE_THRESHOLD 8
/*
 * When copy_to_user_memcpy is enabled in the kernel configuration
 * (CONFIG_UACCESS_WITH_MEMCPY), the assembler copy_to_user function
 * will only be called for sizes less than 64 bytes. Ideally, the
 * fast path threshold for copy_to_user should be 63 or higher to
 * avoid the non-fast path code completely.
 *
 * Otherwise, it seems the fast path is faster or almost as fast even
 * for larger sizes.
 */
#define FAST_PATH_SIZE_THRESHOLD 256
#define DISABLE_WRITE_ALIGNMENT
#endif

#define OPTIMIZED_FUNCTION_ENTRY

#ifdef OPTIMIZED_FUNCTION_ENTRY
		/*
                 * For small aligned memcpy/copy_to_user/copy_from_user
                 * operations, the current implementation has some
                 * overhead. By creating a fast path for common small
                 * aligned requests, performance is increased. This
		 * applies to both memcpy and copy_to/from_user.
                 */
		cmp	r2, #SMALL_SIZE_THRESHOLD
		/* Calculate the aligned base for preloads. */
		bic	ip, r1, #(L1_CACHE_BYTES - 1)
		enter_no_regs
		pld	[ip]
		orr	r3, r0, r1
		ble	36f
		cmp	r2, #FAST_PATH_SIZE_THRESHOLD
		tstle	r3, #3
		bne	37f

		/*
		 * At this point, we have a small (<= FAST_PATH_SIZE_THRESHOLD
		 * bytes) word-aligned request of size greater than
		 * SMALL_SIZE_THRESHOLD, which must be >= 15 so the size
		 * is >= 16 when we get here.
		 */
.macro check_preload bytes_to_go
.if \bytes_to_go >= (PREFETCH_DISTANCE * L1_CACHE_BYTES) && \
(\bytes_to_go % L1_CACHE_BYTES) == 0
	PLD(	pld     [r1, r5]	)
	NO_PLD(	nop )
.else
		nop
.endif
.endm
#ifdef COPY_FUNCTION_MEMCPY
	PLD(	pld	[ip, #L1_CACHE_BYTES] )
		stmdb	sp!, {r4, r5, lr}
		bic	r3, r2, #15
		/*
                 * Use a heuristic to determine whether the preload
		 * at aligned_base + 2 * L1_CACHE_BYTES will be useful.
		 */
	PLD(	cmp	r2, #(2 * L1_CACHE_BYTES - L1_CACHE_BYTES / 2)	)
	PLD(	add	r5, ip, #(3 * L1_CACHE_BYTES) )
		sub	r2, r2, r3
	PLD(	blt	40f	)
	PLD(	pld	[ip, #(2 * L1_CACHE_BYTES)] )
40:		rsb	r3, r3, #256
	PLD(	sub	r5, r5, r1		)
		add	pc, pc, r3
		nop
		/* 256 bytes to go. */
		check_preload 256
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		/* 240 bytes go. */
		nop
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		/* 224 bytes to go. */
		check_preload 224
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		/* 204 bytes go. */
		nop
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		/* 192 bytes to go. */
		check_preload 192
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		/* 176 bytes go. */
		nop
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		/* 160 bytes to go. */
		check_preload 160
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		/* 144 bytes go. */
		nop
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		/* 128 bytes to go. */
		check_preload 128
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		/* 112 bytes go. */
		nop
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		/* 96 bytes to go. */
		check_preload 96
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		/* 90 bytes to go. */
		nop
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		/* 64 bytes to go. */
		check_preload 64
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		nop
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		nop
		ldmia	r1!, {r3, r4, ip, lr}
		nop
		stmia	r0!, {r3, r4, ip, lr}
		/* At this point there are 16 to 31 bytes to go. */
		tst	r2, #15
		ldmia	r1!, {r3, r4, ip, lr}
		cmpne	r2, #8
		/*
		 * If r2 == 8, we need to clear the eq flag while
		 * making sure carry remains set.
		 */
		tsteq	r2, #15
		stmia	r0!, {r3, r4, ip, lr}
		/*
		 * The equal is set if there are no bytes left.
		 * The carry flag is set is there are >= 8 bytes left.
		 */
		beq	43f
		ldrcs	ip, [r1], #4
		ldrcs	r3, [r1], #4
		strcs	ip, [r0], #4
		strcs	r3, [r0], #4
		tst	r2, #4
		ldmfd	sp!, {r4, r5, lr}
		ldrne	ip, [r1], #4
		strne	ip, [r0], #4
		tst	r2, #3
		ldmeqfd	sp!, {r0}
		moveq	pc, lr
		b	38f
43:		ldmfd	sp!, {r4, r5, lr}
		ldmfd	sp!, {r0}
		mov	pc, lr
#else
		/*
                 * For copy_to_user and copy_from_user, the fast path
		 * uses single word loads and stores, but due to the
		 * decreased overhead this can be a big win for small
		 * sizes which are very common.
		 */
32:		ldr1w	r1, r3, abort=22f
		cmp	r2, #16
		ldr1w	r1, ip, abort=22f
		str1w	r0, r3, abort=22f
		sub	r2, r2, #8
		str1w	r0, ip, abort=22f
		bge	32b
		tst	r2, #4
		beq	34f
		ldr1w	r1, r3, abort=22f
		str1w	r0, r3, abort=22f
#endif
34:		tst	r2, #3
		bne	38f
		exit_no_regs

36:		/*
                 * At this point, we have <= SMALL_SIZE_THRESHOLD bytes that
		 * may not be aligned. This code is optimized for < 4 bytes
		 * or word aligned source and destination; otherwise, branch
		 * to the general case.
                 */
#if defined(COPY_FUNCTION_MEMCPY) && defined(SMALL_SIZE_UNROLLED)
		cmp	r2, #4
		blt	38f
		tst	r3, #3
		bic	r3, r2, #7
		bne	37f
		rsb	ip, r3, #32
		sub	r0, r0, ip
		sub	r1, r1, ip
		add	pc, pc, ip, lsl #1
		nop
		ldr	r3, [r1]
		ldr	ip, [r1, #4]
		str	r3, [r0] 
		str	ip, [r0, #4]
		ldr	r3, [r1, #8]
		ldr	ip, [r1, #12]
		str	r3, [r0, #8]
		str	ip, [r0, #12]
		ldr	r3, [r1, #16]
		ldr	ip, [r1, #20]
		str	r3, [r0, #16]
		str	ip, [r0, #20]
		ldr	r3, [r1, #24]
		ldr	ip, [r1, #28]
		str	r3, [r0, #24]
		str	ip, [r0, #28]
		add	r0, r0, #32
		add	r1, r1, #32
		tst	r2, #4
		ldrne	r3, [r1], #4
		strne	r3, [r0], #4
#else
		cmp	r2, #4
		blt	38f
		tst	r3, #3
		sub	r2, r2, #3
		bne	35f
		/* Word aligned source and destination, >= 4 bytes. */
44:		ldr1w	r1, r3, abort=22f
		subs	r2, r2, #4
		str1w	r0, r3, abort=22f
		bgt	44b
		adds	r2, r2, #3
		beq	39f
#endif
38:		movs	r2, r2, lsl #31
		ldr1b	r1, r3, ne, abort=22f
		ldr1b	r1, ip, cs, abort=22f
		str1b	r0, r3, ne, abort=22f
		ldr1b	r1, r3, cs, abort=22f
		str1b	r0, ip, cs, abort=22f
		str1b	r0, r3, cs, abort=22f
39:		exit_no_regs
#if defined(COPY_FUNCTION_MEMCPY) && defined(SMALL_SIZE_UNROLLED)
		/* Special case of size of 4 word aligned. */
45:		ldr	r3, [r1]
		str	r3, [r0]
		exit_no_regs
#endif
#endif

35:		add	r2, r2, #3
		/*
		 * This is the entry point of the original function.
		 * ip holds the aligned source base address.
		 */
37:		stmdb	sp!, {r4, lr}

33:		subs	r2, r2, #4
		mov	r3, ip
		blt	8f
		ands	ip, r0, #3
	PLD(	pld	[r3, #L1_CACHE_BYTES]	)
		bne	9f
		ands	ip, r1, #3
		bne	10f

1:		subs	r2, r2, #(28)
		stmfd	sp!, {r5 - r9}
		mov	r8, r3
		blt	5f

#ifndef DISABLE_WRITE_ALIGNMENT
		/* For regular memcpy, use conditional multiloads/stores. */
	CALGN(	ands	ip, r0, #(WRITE_ALIGN_BYTES - 1)	)
	CALGN(	rsb	r3, ip, #WRITE_ALIGN_BYTES		)
	CALGN(	sbcnes	r4, r3, r2		)  @ C is always set here
	CALGN(	bcs	2f			)
#ifdef COPY_FUNCTION_MEMCPY
	CALGN(	tst     r3, #4			)
	CALGN(	ldrne   r4, [r1], #4		)
	CALGN(	strne   r4, [r0], #4		)
	CALGN(	tst     r3, #8			)
	CALGN(  ldmneia r1!, {r4-r5}		)
	CALGN(	sub     r2, r2, r3		)
	CALGN(	stmneia r0!, {r4-r5}		)
.if WRITE_ALIGN_BYTES == 32
	CALGN(	tst	r3, #16			)
	CALGN(	ldmneia r1!, {r4-r7}		)
	CALGN(	stmneia r0!, {r4-r7}		)
.endif
#else
	CALGN(	adr	r4, 6f			)
.if WRITE_ALIGN_BYTES == 16
	CALGN(  add	ip, ip, #16		)
.endif
	CALGN(	subs	r2, r2, r3		)  @ C gets set
	CALGN(	add	pc, r4, ip		)
#endif
#endif

2:
.if L1_CACHE_BYTES == 64
		subs    r2, r2, #32
		blt     30f
.endif
		/*
                 * Assume a preload at aligned base + 2 * L1_CACHE_BYTES will
		 * be useful.
		 */
	PLD(	pld	[r8, #(2 * L1_CACHE_BYTES)]	)

	PLD(	add     r9, r1, #(PREFETCH_DISTANCE * L1_CACHE_BYTES)	)
	PLD(	bic     r3, r9, #(L1_CACHE_BYTES - 1)			)
	PLD(	subs	r2, r2, #(PREFETCH_DISTANCE * L1_CACHE_BYTES)	)
	PLD(	sub	r9, r3, r1			)
	PLD(	add	r8, #(3 * L1_CACHE_BYTES)	)
	PLD(	blt	4f				)

		/*
        	 * "Catch-up" the early preloads (which have been performed up
		 * to aligned base + 2 * L1_CACHE_BYTES) to the preload offset
		 * used in the main loop.
	         */
	PLD(	cmp	r8, r3				)
	PLD(	bge	41f				)
42:	PLD(	add	r8, r8, #L1_CACHE_BYTES		)
	PLD(	cmp	r8, r3				)
	PLD(	pld	[r8, #(- L1_CACHE_BYTES)]	)
	PLD(	blt	42b				)
41:

.if L1_CACHE_BYTES == 32
3:	PLD(	pld	[r1, r9]		)
4:		ldr8w	r1, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
		subs	r2, r2, #32
		str4w	r0, r3, r4, r5, r6, abort=20f
		str4w   r0, r7, r8, ip, lr, abort=20f
		bge	3b
	PLD(	cmn	r2, #(PREFETCH_DISTANCE * 32)	)
	PLD(	bge	4b			)
.else /* L1_CACHE_BYTES == 64 */
3:		pld	[r1, r9]
4:		ldr8w	r1, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
		subs	r2, r2, #64
		str8w	r0, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
		ldr8w	r1, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
		str8w	r0, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
		bge	3b
		cmn	r2, #(PREFETCH_DISTANCE * 64)
		bge	4b

30:		tst     r2, #32
		beq	31f
		ldr8w	r1, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
		str8w	r0, r3, r4, r5, r6, r7, r8, ip, lr, abort=20f
31:
.endif

5:
#ifdef COPY_FUNCTION_MEMCPY
		/*
		 * For regular memcpy, use conditional multiloads/stores
		 * for the tail.
		 */
		tst     r2, #16
		ldmneia r1!, {r4-r7}
		stmneia r0!, {r4-r7}
		tst     r2, #8
		ldmneia r1!, {r4-r5}
		stmneia r0!, {r4-r5}
		tst     r2, #4
		ldrne   r4, [r1], #4
		strne   r4, [r0], #4
		b	7f
#else
		ands	ip, r2, #28
		rsb	ip, ip, #32
#if LDR1W_SHIFT > 0
		lsl	ip, ip, #LDR1W_SHIFT
#endif
		addne	pc, pc, ip		@ C is always clear here
		b	7f
6:
		.rept	(1 << LDR1W_SHIFT)
		W(nop)
		.endr
		ldr1w	r1, r3, abort=20f
		ldr1w	r1, r4, abort=20f
		ldr1w	r1, r5, abort=20f
		ldr1w	r1, r6, abort=20f
		ldr1w	r1, r7, abort=20f
		ldr1w	r1, r8, abort=20f
		ldr1w	r1, lr, abort=20f

#if LDR1W_SHIFT < STR1W_SHIFT
		lsl	ip, ip, #STR1W_SHIFT - LDR1W_SHIFT
#elif LDR1W_SHIFT > STR1W_SHIFT
		lsr	ip, ip, #LDR1W_SHIFT - STR1W_SHIFT
#endif
		add	pc, pc, ip
		nop
		.rept	(1 << STR1W_SHIFT)
		W(nop)
		.endr
		str1w	r0, r3, abort=20f
		str1w	r0, r4, abort=20f
		str1w	r0, r5, abort=20f
		str1w	r0, r6, abort=20f
		str1w	r0, r7, abort=20f
		str1w	r0, r8, abort=20f
		str1w	r0, lr, abort=20f

#ifndef DISABLE_WRITE_ALIGNMENT
	CALGN(	bcs	2b	)
#endif
#endif	/* defined(COPY_FUNCTION_MEMCPY) */

7:		ldmfd	sp!, {r5 - r9}

8:		movs	r2, r2, lsl #31
		ldr1b	r1, r3, ne, abort=21f
		ldr1b	r1, r4, cs, abort=21f
		ldr1b	r1, ip, cs, abort=21f
		str1b	r0, r3, ne, abort=21f
		str1b	r0, r4, cs, abort=21f
		str1b	r0, ip, cs, abort=21f

		ldmfd	sp!, {r4, lr}
		exit_no_regs

9:		rsb	ip, ip, #4
		cmp	ip, #2
		ldr1b	r1, r3, gt, abort=21f
		ldr1b	r1, r4, ge, abort=21f
		ldr1b	r1, lr, abort=21f
		str1b	r0, r3, gt, abort=21f
		str1b	r0, r4, ge, abort=21f
		subs	r2, r2, ip
		str1b	r0, lr, abort=21f
		blt	8b
		ands	ip, r1, #3
		beq	1b

10:		bic	r1, r1, #3
		cmp	ip, #2
		ldr1w	r1, lr, abort=21f
		beq	17f
		bgt	18f


		.macro	forward_copy_shift pull push

		subs	r2, r2, #28
		blt	14f

#ifndef DISABLE_WRITE_ALIGNMENT
	CALGN(	ands	ip, r0, #(WRITE_ALIGN_BYTES - 1)	)
	CALGN(	rsb	ip, ip, #WRITE_ALIGN_BYTES		)
	CALGN(	sbcnes	r4, ip, r2		)  @ C is always set here
	CALGN(	subcc	r2, r2, ip		)
	CALGN(	bcc	15f			)
#endif
		/*
		 * We need the aligned base used for early preloads,
		 * but because this is an entry point from multiple
		 * code paths, we don't have the value available in
		 * all cases and so cannot match up the early preloads
		 * with the preloads in the main loop.
		 */
11:		stmfd	sp!, {r5 - r10}

        PLD(    add     r10, r1, #(PREFETCH_DISTANCE * L1_CACHE_BYTES)	)
        PLD(    bic     r3, r10, #(L1_CACHE_BYTES - 1)	)
        PLD(    subs    r2, r2, #(PREFETCH_DISTANCE * 32)	)
        PLD(    sub     r10, r3, r1		)
        PLD(    blt     13f                     )
.if PREFETCH_DISTANCE >= 4
	PLD(	pld	[r3, #(- 3 * L1_CACHE_BYTES)]	)
.endif
.if PREFETCH_DISTANCE >= 3
	PLD(	pld	[r3, #(- 2 * L1_CACHE_BYTES)]	)
.endif
	PLD(	pld	[r3, #(- L1_CACHE_BYTES)]	)

		/*
		 * Note that when L1_CACHE_BYTES is 64, we are
		 * prefetching every 32 bytes. Although not optimal
		 * there doesn't seem to be big penalty for the extra
		 * preload instructions and it prevents greater
		 * code size and complexity.
		 */
12:	PLD(	pld	[r1, r10]		)
13:		ldr4w	r1, r4, r5, r6, r7, abort=19f
		mov	r3, lr, pull #\pull
		subs	r2, r2, #32
		ldr4w	r1, r8, r9, ip, lr, abort=19f
		orr	r3, r3, r4, push #\push
		mov	r4, r4, pull #\pull
		orr	r4, r4, r5, push #\push
		mov	r5, r5, pull #\pull
		orr	r5, r5, r6, push #\push
		mov	r6, r6, pull #\pull
		orr	r6, r6, r7, push #\push
		mov	r7, r7, pull #\pull
		orr	r7, r7, r8, push #\push
		mov	r8, r8, pull #\pull
		orr	r8, r8, r9, push #\push
		mov	r9, r9, pull #\pull
		orr	r9, r9, ip, push #\push
		mov	ip, ip, pull #\pull
		orr	ip, ip, lr, push #\push
		str8w	r0, r3, r4, r5, r6, r7, r8, r9, ip, , abort=19f
		bge	12b
	PLD(	cmn	r2, #(PREFETCH_DISTANCE * 32)	)
	PLD(	bge	13b				)

		ldmfd	sp!, {r5 - r10}

14:		ands	ip, r2, #28
		beq	16f

15:		mov	r3, lr, pull #\pull
		ldr1w	r1, lr, abort=21f
		subs	ip, ip, #4
		orr	r3, r3, lr, push #\push
		str1w	r0, r3, abort=21f
		bgt	15b
#ifndef DISABLE_WRITE_ALIGNMENT
	CALGN(	cmp	r2, #0			)
	CALGN(	bge	11b			)
#endif

16:		sub	r1, r1, #(\push / 8)
		b	8b

		.endm


		forward_copy_shift	pull=8	push=24

17:		forward_copy_shift	pull=16	push=16

18:		forward_copy_shift	pull=24	push=8


/*
 * Abort preamble and completion macros.
 * If a fixup handler is required then those macros must surround it.
 * It is assumed that the fixup code will handle the private part of
 * the exit macro.
 */

	.macro	copy_abort_preamble
19:	ldmfd	sp!, {r5 - r10}
	b	21f
20:	ldmfd	sp!, {r5 - r9}
21:	ldmfd	sp!, {r4, lr}
22:
	.endm

	.macro	copy_abort_end
	exit_no_regs
	.endm
