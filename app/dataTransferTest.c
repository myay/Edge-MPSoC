
#include <stdint.h>
// Define the memory-mapped address (based address) of the data SRAM
#define DATA_SRAM_ADDR 0x10000000
// Define address storing status
#define STATUS_ADDR 0x1000ff10
// Number of words to test in SRAM
#define SRAM_WORDS 4
// Define PASS and FAIL values
#define PASS 0x00000001
#define FAIL 0x00000000
/*
 * ================================================================================
 * Function: test_dataSRAM_transfer
 * Description: This function tests the data transfer between CPU and data SRAM through the AXI crossbar.
 * It writes a known value to the SRAM, reads it back, and compares it with the expected value.
 * If the values match, it indicates that the data transfer is successful; otherwise, it indicates a failure.
 * ================================================================================
*/
void test_dataSRAM_transfer(void) {

    // Create a volatile pointer to the SRAM address
    volatile uint64_t *sram_ptr = (volatile uint64_t *)DATA_SRAM_ADDR;
    volatile uint64_t *status_ptr = (volatile uint64_t *)STATUS_ADDR;
    
    // Create a list of initial values to write to SRAM
    uint64_t init_values[SRAM_WORDS] = {0xDEADBEEF, 0xCAFEBABE12345678, 0x12345678, 0x87654321};
    for (int i = 0; i < SRAM_WORDS; i++) {
        *(sram_ptr + i) = init_values[i];
    }

    // Read back the value from SRAM
    for (int i = 0; i < SRAM_WORDS; i++) {
        uint64_t read_value = *(sram_ptr + i);
        // Compare the read value with the known value
        if (read_value == init_values[i]) {
            *status_ptr = PASS; // Indicate success
        } else {
            *status_ptr = FAIL + (DATA_SRAM_ADDR + i); // Indicate failure at specific address
            break; // Exit the loop on first failure
        }
    }
}
