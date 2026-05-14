#!/bin/bash

# use like this: ./gen_mem 1024
# the number is the number of elements in the memory

# Check if a parameter was provided
if [ -z "$1" ]; then
    echo "Usage: $0 <number_of_elements>"
    exit 1
fi

NUM_ELEMENTS=$1
OUTPUT_FILE="sram_init.mem"

# Remove existing file to ensure a clean start
rm -f "$OUTPUT_FILE"

# Use a loop to generate hex values
for (( i=1; i<=NUM_ELEMENTS; i++ ))
do
    # %016X: 16-digit Hex (64-bit), capitalized, with leading zeros
    printf "%016X\n" "$i" >> "$OUTPUT_FILE"
done

echo "Successfully generated $NUM_ELEMENTS entries in $OUTPUT_FILE."
