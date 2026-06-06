MEMORY
{
	RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS
{
	.text : {
	      _stext = .;
	      *(.text)
	      _etext = .;
	} > RAM
}
