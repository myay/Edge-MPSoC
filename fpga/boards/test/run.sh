#!/usr/bin/env bash
# =============================================================================
# Board Build Runner
# Usage: ./run.sh [/path/to/pulp_axi]
# =============================================================================

set -euo pipefail

export PULP_AXI_PATH="/home/mikail/soc_development/axi"

# Anchor directories to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# 3. Validate path existence
if [ ! -d "${PULP_AXI_PATH}" ]; then
    echo "ERROR: PULP_AXI_PATH directory does not exist: ${PULP_AXI_PATH}" >&2
    echo "Please set it via 'export PULP_AXI_PATH=...'" >&2
    exit 1
fi

echo "========================================================"
echo " Starting Vivado Flow for target: $(basename "${SCRIPT_DIR}")"
echo " PULP_AXI_PATH: ${PULP_AXI_PATH}"
echo " Working Dir:   ${SCRIPT_DIR}"
echo "========================================================"

# 4. Navigate to board directory and execute Vivado
cd "${SCRIPT_DIR}"
vivado -mode batch -source run_synth.tcl
