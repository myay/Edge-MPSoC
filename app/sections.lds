MEMORY
{
	EXEC_RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
	/* Data RAM is still available for other uses, like DMA buffers */
	DATA_RAM (rw)  : ORIGIN = 0x10000000, LENGTH = 64K
}

/* Define a minimum stack size (e.g., 4 kB) */
__min_stack_size = 0x1000;

SECTIONS
{
	.text : {
		*(.text)
		*(.rodata*)
	} > EXEC_RAM

	/* If you want global variables in Exec SRAM too, uncomment below: */
	/* 
	.data : { *(.data*) } > EXEC_RAM 
	.bss  : { *(.bss*) *(COMMON) } > EXEC_RAM 
	*/

	/* This section doesn't consume binary space, it just runs a safety check */
	.stack_check (NOLOAD) : {
		. = ALIGN(4);
		__stack_bottom = .;
		. = . + __min_stack_size;
		__stack_top = .;
	} > EXEC_RAM
}
