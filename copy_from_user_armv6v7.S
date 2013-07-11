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
#define COPY_FUNCTION_FROM_USER

	.macro ldr1w ptr reg abort
	W(ldr) \reg, [\ptr], #4
	.endm

	.macro ldr1wcond ptr reg cond abort
	ldr\cond \reg, [\ptr], #4
	.endm

        .macro ldr2w ptr reg1 reg2 abort
        ldr1w \ptr, \reg1, \abort
        ldr1w \ptr, \reg2, \abort
	.endm

        .macro ldr4w ptr reg1 reg2 reg3 reg4 abort
        ldr1w \ptr, \reg1, \abort
        ldr1w \ptr, \reg2, \abort
        ldr1w \ptr, \reg3, \abort
        ldr1w \ptr, \reg4, \abort
        .endm

        .macro ldr8w ptr reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 abort
        ldr4w \ptr, \reg1, \reg2, \reg3, \reg4, \abort
        ldr4w \ptr, \reg5, \reg6, \reg7, \reg8, \abort
        .endm

	.macro ldr1b ptr reg cond=al abort
	ldr\cond\()b \reg, [\ptr], #1
	.endm

	.macro str1w ptr reg abort
	W(str) \reg, [\ptr], #4
	.endm

	.macro str1wcond ptr reg cond abort
	str\cond \reg, [\ptr], #4
	.endm

	.macro str2w ptr reg1 reg2 abort
	stmia \ptr!, {\reg1, \reg2}
	.endm

	.macro str4w ptr reg1 reg2 reg3 reg4 abort
	stmia \ptr!, {\reg1, \reg2, \reg3, \reg4}
	.endm

	.macro str8w ptr reg1 reg2 reg3 reg4 reg5 reg6 reg7 reg8 abort
	stmia \ptr!, {\reg1, \reg2, \reg3, \reg4, \reg5, \reg6, \reg7, \reg8}
	.endm

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
#ifndef CONFIG_KERNEL_THUMB2
	.p2align 5
#endif

/* Prototype: void *copy_from_user(void *dest, const void *src, size_t n); */

ENTRY(kernel_copy_from_user_armv6v7)

#include "copy_user_template_armv6v7.S"

ENDPROC(kernel_copy_from_user_armv6v7)