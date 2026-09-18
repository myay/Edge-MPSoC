	.section .text
	.global _start
_start:
	
	# Store addresses in register x0 and x1
    li x1, 0x10000010
	li x2, 0x10000014

	# Read data from address 0x10000010
	lw x3, 0(x1)

	# Write data from x2 to address 0x10000014
	sw x3, 0(x2)

	# Compare data from 0x10000010 and 0x10000014 ==> same ==> transfer successfully
	# --------------------------------------------==> diff ==> fail
	# write a test bench for checking and display on terminal
