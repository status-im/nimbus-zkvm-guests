# nimbus-zkvm-guests

zkVM builds of the Nimbus stateless guest program.

The guest lives in [nimbus-eth1](https://github.com/status-im/nimbus-eth1) under
`execution_chain/stateless`. This repository pins a commit of it, builds one ELF
per zkVM, derives the verification key and publishes both.

## Targets

| zkVM | Version | Status |
|---|---|---|
| [ZisK](https://github.com/0xPolygonHermez/zisk) | `v1.3.2-alpha` | Working |
| [SP1](https://github.com/succinctlabs/sp1) | `v6.9.0` | Working |
| [OpenVM](https://github.com/openvm-org/openvm) | - | Not supported yet |

## Prerequisites

Linux x86_64, with `git`, `curl`, `make` and a host C toolchain. Versions are
pinned in [`versions.env`](versions.env) and `<zkvm>/versions.env`.

The xPack `riscv-none-elf-gcc`, the compiler the guest is tested with:

```bash
V=15.2.0-1
B=https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/download/v$V
curl -sSLO "$B/xpack-riscv-none-elf-gcc-$V-linux-x64.tar.gz" \
     -sSLO "$B/xpack-riscv-none-elf-gcc-$V-linux-x64.tar.gz.sha"
sha256sum -c "xpack-riscv-none-elf-gcc-$V-linux-x64.tar.gz.sha"
mkdir -p ~/.local/xPacks/riscv-none-elf-gcc
tar -xzf "xpack-riscv-none-elf-gcc-$V-linux-x64.tar.gz" \
    -C ~/.local/xPacks/riscv-none-elf-gcc --strip-components=1
```

### ZisK

Rust nightly with `rust-src`, which `-Z build-std` needs for the platform
archive:

```bash
rustup toolchain install nightly-2026-09-20 --component rust-src
```

The emulator and prover, into `~/.zisk`. `SETUP_KEY` fetches the 3.7 GB proving
key, which `vk` needs and `test` does not. `ziskup` also installs a Rust
toolchain nothing here uses:

```bash
export ZISK_VERSION=1.3.2-alpha SETUP_KEY=proving-no-consttree USE_GPU=false
curl -sSf https://raw.githubusercontent.com/0xPolygonHermez/zisk/v1.3.2-alpha/ziskup/ziskup | bash
```

Their shared libraries. On Ubuntu, for `test`:

```bash
sudo apt-get install -y libsodium23 libomp5 libopenmpi3 openmpi-bin \
  openmpi-common jq
```

and for `vk`, which runs a host compiler over the assembly it generates:

```bash
sudo apt-get install -y libgomp1 build-essential libgmp-dev
```

### SP1

Stable Rust 1.88 or later, for [`sp1/execute`](sp1/execute).

For `vk`, `cargo-prove`:

```bash
V=v6.9.0
mkdir -p ~/.local/bin
curl -sSL https://github.com/succinctlabs/sp1/releases/download/$V/cargo_prove_${V}_linux_amd64.tar.gz \
  | tar -xz -C ~/.local/bin cargo-prove
```

## Building

Inputs are make variables; unset, they take the defaults below.

| variable | what | default |
|---|---|---|
| `NIMBUS` | nimbus-eth1 checkout | cloned at `NIMBUS_REF` into `build/nimbus` |
| `ZKVM_GCC` | `riscv-none-elf-gcc` that emits rv64im | `riscv-none-elf-gcc` |

`NIMBUS=~/src/nimbus-eth1` builds a working tree instead of the pinned
revision; the build prints the commit it used and carries on.

The ELF and key land in `build/artifacts`. `make clean` removes `build/`,
`make help` lists the targets.

`test` runs the fixtures in [`fixtures/`](fixtures). The whole EEST bundle runs
through
[zkevm-benchmark-workload](https://github.com/eth-act/zkevm-benchmark-workload),
which is also where the metrics come from. Support for Nimbus is still to be
added there.

### ZisK

| variable | what | default |
|---|---|---|
| `ZISK_LIB` | `libziskos_staticlib.a` for `riscv64im-unknown-none-elf` | built from ZisK `ZISK_REF` into `build/zisk-<ref>` |
| `ZISK_EMULATOR` | `ziskemu`, for `test` | `ziskemu` |
| `ZISK_PROVER` | `cargo-zisk-dev`, for `vk` | `cargo-zisk-dev` |

```bash
make guest_zisk ZKVM_GCC=~/.local/xPacks/riscv-none-elf-gcc/bin/riscv-none-elf-gcc
make test_zisk  ZISK_EMULATOR=~/.zisk/bin/ziskemu
make vk_zisk    ZISK_PROVER=~/.zisk/bin/cargo-zisk-dev

# or put them on PATH and drop the variables
export PATH=~/.local/xPacks/riscv-none-elf-gcc/bin:~/.zisk/bin:$PATH
make guest_zisk && make test_zisk
```

### SP1

| variable | what | default |
|---|---|---|
| `SP1_SDK` | unpacked `zkevm-sdk-<ref>.tar.gz`: `libzkevm.a` and `zkvm.ld` | fetched at `SP1_REF` into `build/sp1-sdk-<ref>`, checked against `SP1_SDK_SHA256` |
| `SP1_EXECUTOR` | `sp1-execute`, for `test` | built from `sp1/execute` with SP1's `Cargo.lock` at `SP1_REF` into `build/sp1-execute` |
| `SP1_CARGO_PROVE` | `cargo-prove`, for `vk` | `cargo-prove` |

```bash
make guest_sp1 ZKVM_GCC=~/.local/xPacks/riscv-none-elf-gcc/bin/riscv-none-elf-gcc
make test_sp1
make vk_sp1    SP1_CARGO_PROVE=~/.local/bin/cargo-prove
```

`sp1-execute` runs an ELF as Ere does and writes its public values:

```bash
build/sp1-execute/release/sp1-execute <guest.elf> <input.bin> <output.bin>
```

## Releasing

A `v*` tag builds every target, executes each ELF over the fixtures, and drafts
a pre-release.
Assets are named as [ere-guests](https://github.com/eth-act/ere-guests) resolves
them:

```
stateless-validator-nimbus-<zkvm>-<zkvm_version>.elf
stateless-validator-nimbus-<zkvm>-<zkvm_version>.vk
```

The release notes carry the SHA256 digests that
[`artifact-registry.json`](https://github.com/eth-act/ere-guests/blob/main/artifact-registry.json)
pins, alongside SHA512.

The `.vk` identifies one compiled guest, so any rebuild that changes a byte
changes the key. For ZisK it is the Merkle root of the ELF's ROM trace, which a
proof carries in its public values. For SP1 it is the 32-byte Poseidon2 digest
of the verifying key.

## License

Licensed and distributed under either of:

- MIT license ([LICENSE-MIT](LICENSE-MIT) or
  https://opensource.org/licenses/MIT)
- Apache License, Version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
  https://www.apache.org/licenses/LICENSE-2.0)

at your option.
