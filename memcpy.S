/*
 *  linux/arch/arm/lib/memcpy.S
 *
 *  Author:	Nicolas Pitre
 *  Created:	Sep 28, 2005
 *  Copyright:	MontaVista Software, Inc.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License version 2 as
 *  published by the Free Software Foundation.
 */

#include "kernel_defines.h"

#define LDR1W_SHIFT	0
#define STR1W_SHIFT	0
#define COPY_FUNCTION_MEMCPY
// #define COPY_FUNCTION_FROM_USER
// #define COPY_FUNCTION_TO_USER

	.macro ldr1w ptr reg abort
	W(ldr) \reg, [\ptr], #4
	.endm

#ifdef COPY_FUNCTION_FROM_USER
        .macro ldr4w ptr reg1 reg2 reg3 reg4 abort
        ldr1w \ptr, \reg1, \abort
        ldr1w \ptr, \reg2, \abort
        ldr1w \ptr, \reg3, \abort
        ldr1w \ptr, \reg4, \abort
        .endm
#else
	.macro ldr4w ptr reg1 reg2 reg3 reg4 abort
	ldmia \ptr!, {\reg1, \reg2, \reg3, \reg4}
	.endm
#endif

#ifdef COPY_FUNCTION_FROM_USER
        .macro ldr8w ptr reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 abort
        ldr4w \ptr, \reg1, \reg2, \reg3, \reg4, \abort
        ldr4w \ptr, \reg5, \reg6, \reg7, \reg8, \abort
        .endm
#else
	.macro ldr8w ptr reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 abort
	ldmia \ptr!, {\reg1, \reg2, \reg3, \reg4, \reg5, \reg6, \reg7, \reg8}
	.endm
#endif

	.macro ldr1b ptr reg cond=al abort
	ldr\cond\()b \reg, [\ptr], #1
	.endm

	.macro str1w ptr reg abort
	W(str) \reg, [\ptr], #4
	.endm

#ifdef COPY_FUNCTION_TO_USER
        .macro str4w ptr reg1 reg2 reg3 reg4 abort
        str1w \ptr, \reg1, \abort
        str1w \ptr, \reg2, \abort
        str1w \ptr, \reg3, \abort
        str1w \ptr, \reg4, \abort
        .endm
#else
	.macro str4w ptr reg1 reg2 reg3 reg4 abort
	stmia \ptr!, {\reg1, \reg2, \reg3, \reg4}
	.endm
#endif

#ifdef COPY_FUNCTION_TO_USER
        .macro str8w ptr reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 abort
        str1w \ptr, \reg1, \abort
        str1w \ptr, \reg2, \abort
        str1w \ptr, \reg3, \abort
        str1w \ptr, \reg4, \abort
        str1w \ptr, \reg5, \abort
        str1w \ptr, \reg6, \abort
        str1w \ptr, \reg7, \abort
        str1w \ptr, \reg8, \abort
        .endm
#else
	.macro str8w ptr reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 abort
	stmia \ptr!, {\reg1, \reg2, \reg3, \reg4, \reg5, \reg6, \reg7, \reg8}
	.endm
#endif

	.macro str1b ptr reg cond=al abort
	str\cond\()b \reg, [\ptr], #1
	.endm

	.macro enter_no_regs
	/* Push the destination onto the stack. */
	stmdb sp!, {r0}
	.endm

	.macro exit_no_regs
	/* Return the original destination in r0. */
	ldr r0, [sp], #4
	mov pc, lr
	.endm

	.text
	.p2align 5

/* Prototype: void *memcpy(void *dest, const void *src, size_t n); */

ENTRY(kernel_memcpy)

#include "copy_template.S"

ENDPROC(kernel_memcpy)
