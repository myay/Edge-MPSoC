	.section .text
	.global _start

_start:
	/* Initialize Stack Pointer to the top of the 64kB Exec SRAM */
	li sp, 0x10000

	/* Jump to the C main function */
	call main

_end:
	j _end
