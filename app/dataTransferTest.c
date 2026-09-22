#include <stdio.h>

// Define the memory-mapped address (based address) of the data SRAM
#define DATA_SRAM_ADDR 0x10000000
#define SRAM_WORDS 4  // Number of words to test in SRAM
/*
 * ================================================================================
 * Function: test_dataSRAM_transfer
 * Description: This function tests the data transfer between CPU and data SRAM through the AXI crossbar.
 * It writes a known value to the SRAM, reads it back, and compares it with the expected value.
 * If the values match, it indicates that the data transfer is successful; otherwise, it indicates a failure.
 * ================================================================================
*/
int test_dataSRAM_transfer(void) {

    // Create a volatile pointer to the SRAM address
    volatile unsigned int *sram_ptr = (volatile unsigned int *)DATA_SRAM_ADDR;

    // Create a list of initial values to write to SRAM
    unsigned int init_values[SRAM_WORDS] = {0xDEADBEEF, 0xCAFEBABE, 0x12345678, 0x87654321};

    // Write the initial values to SRAM
    for (int i = 0; i < SRAM_WORDS; i++) {
        sram_ptr[i] = init_values[i];
    }

    // Read back the value from SRAM
    for (int i =0; i < SRAM_WORDS; i++) {
        unsigned int read_value = sram_ptr[i];
        // Compare the read value with the known value
        if (read_value == init_values[i]) {
            printf("Data transfer successful for word %d: 0x%X\n", i, read_value);
        } else {
            printf("Data transfer failed for word %d: expected 0x%X, got 0x%X\n", i, init_values[i], read_value);
            return -1; // Failure
        }
    }

    return 0; // Success
}
