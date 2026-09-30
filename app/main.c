// To send data over the AXI crossbar, you use Memory-Mapped I/O (MMIO). You define a pointer to the specific memory address your target peripheral is mapped to on the AXI bus. Using the volatile keyword tells the C compiler that the value at this address can change outside the program's flow, preventing the compiler from optimizing away your memory accesses.

#include "dataTransferTest.c"
// Memory-mapped address of AXI peripheral
//#define AXI_TARGET_ADDR 0x10000000
//#define STATUS_ADDR 0x1000ff10
// Define PASS and FAIL values
//#define PASS 0x00000001
//#define FAIL 0x00000000

int main(void) {
    // 1. Create a volatile pointer to the memory address
    //volatile unsigned int *axi_bus = (volatile unsigned int *)AXI_TARGET_ADDR;

    // 2. Write data to the address. 
    // The CPU will translate this into an AXI write transaction (AW/W channels).
    // *axi_bus = 0xDEADB00F;

    // 3. Read data from the address (optional).
    // The CPU will translate this into an AXI read transaction (AR/R channels).
    // volatile unsigned int read_data = *axi_bus;
    //volatile unsigned int *status_ptr = (volatile unsigned int *)STATUS_ADDR;
    // *status_ptr = 0xABCD0001; // Indicate success
    /*
    if (read_data == 0xDEADB00F) {
        *status_ptr = 0xABCD0001; // Indicate success
    } else {
        *status_ptr = 0xABCD0000; // Indicate failure
    }
    */
    test_dataSRAM_transfer();
    // 4. Trap the CPU in an infinite loop
    /*
    while (1) {
        // Halt
    }
    */
    return 0;
}
