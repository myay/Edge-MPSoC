# UVM Verification with Verilator

## Prerequisites

### Supported versions

This project has been tested with:

* **Verilator:** `5.052`
* **UVM:** IEEE 1800.2-2020, release **2020.3.2**
* **Verilator-specific UVM branch:** `uvm-2020-3.2-vlt`

Verilator 5.052 documents support for UVM 2020-3.2. The Verilator extended-test repository also uses the `uvm-2020-3.2-vlt` branch from the `chipsalliance/uvm-verilator` repository.

References:

* Verilator 5.052 release notes: https://verilator.org/guide/latest/changes.html?page=1
* Verilator extended tests: https://github.com/verilator/verilator_ext_tests
* UVM for Verilator: https://github.com/chipsalliance/uvm-verilator

## Install Verilator 5.052

Clone the Verilator repository and check out version `v5.052`:

```bash
git clone https://github.com/verilator/verilator.git
cd verilator
git checkout v5.052

autoconf
./configure
make -j"$(nproc)"
sudo make install
```

## Install the correct UVM library

Use the Verilator-specific UVM repository:

```text
https://github.com/chipsalliance/uvm-verilator
```

For UVM 2020.3.2 with Verilator, use the `uvm-2020-3.2-vlt` branch:

```bash
git clone --branch uvm-2020-3.2-vlt \
    https://github.com/chipsalliance/uvm-verilator.git \
    uvm-verilator
```

## Set `UVM_HOME`

For the simulation script in this project, `UVM_HOME` must point to the UVM `src` directory:

```bash
export UVM_HOME=/path/to/uvm-verilator/src
```

## Required UVM workaround for Verilator 5.052

Verilator 5.052 can fail to resolve the inherited `size_t` typedef used by `uvm_lru_cache`. The following small compatibility workaround is required for this setup.

Open:

```text
$UVM_HOME/base/uvm_lru_cache.svh
```

Find:

```systemverilog
class uvm_lru_cache#(type KEY_T=int, type DATA_T=int) extends uvm_cache#(KEY_T, DATA_T);

  typedef uvm_lru_cache#(KEY_T,DATA_T) this_type;
```

Add a local `size_t` typedef immediately after `this_type`:

```systemverilog
class uvm_lru_cache#(type KEY_T=int, type DATA_T=int) extends uvm_cache#(KEY_T, DATA_T);

  typedef uvm_lru_cache#(KEY_T,DATA_T) this_type;
  typedef int unsigned size_t;
```

This avoids the Verilator error:

```text
Reference to 'size_t' before declaration
```

The workaround is specific to this Verilator 5.052/UVM 2020.3.2 combination and should be reapplied when a fresh UVM checkout is created.

## Build and run

After setting `UVM_HOME`, run:

```bash
./run_soc_tb.sh
```

## Version summary

| Component            | Version / branch                                 |
| -------------------- | ------------------------------------------------ |
| Verilator            | `v5.052`                                         |
| UVM standard release | `2020.3.2` / IEEE 1800.2-2020                    |
| Verilator UVM branch | `uvm-2020-3.2-vlt`                               |
| UVM repository       | `https://github.com/chipsalliance/uvm-verilator` |

## References

* Verilator: https://github.com/verilator/verilator
* Verilator v5.052: https://github.com/verilator/verilator/releases/tag/v5.052
* Verilator documentation: https://verilator.org/guide/latest/
* Verilator-specific UVM: https://github.com/chipsalliance/uvm-verilator
* UVM 2020.3.2 Verilator branch: https://github.com/chipsalliance/uvm-verilator/tree/uvm-2020-3.2-vlt
