# nimbus-zkvm-guests

zkVM builds of the Nimbus stateless guest program.

The guest lives in [nimbus-eth1](https://github.com/status-im/nimbus-eth1) under
`execution_chain/stateless`. This repository pins a commit of it, builds one ELF
per zkVM, derives the verification key and publishes both.

## Targets

| zkVM | Version | Status |
|---|---|---|
| [ZisK](https://github.com/0xPolygonHermez/zisk) | `v1.1.0-alpha` | Working |
| [SP1](https://github.com/succinctlabs/sp1) | - | Not supported yet |
| [OpenVM](https://github.com/openvm-org/openvm) | - | Not supported yet |

## Prerequisites

Linux x86_64, with `git`, `curl`, `make` and a host C toolchain. The Makefiles
check out nimbus-eth1 and build the ZisK platform archive; the rest is installed
beforehand, at the versions in [`versions.env`](versions.env) and
[`zisk/versions.env`](zisk/versions.env).

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

Rust nightly with `rust-src`, which `-Z build-std` needs:

```bash
rustup toolchain install nightly-2026-09-20 --component rust-src
```

The emulator and the prover, into `~/.zisk`. `SETUP_KEY` fetches the 3.7 GB
proving key, which `vk` needs and `test` does not. `ziskup` also installs a Rust
toolchain nothing here uses:

```bash
export ZISK_VERSION=1.1.0-alpha SETUP_KEY=proving-no-consttree USE_GPU=false
curl -sSf https://raw.githubusercontent.com/0xPolygonHermez/zisk/v1.1.0-alpha/ziskup/ziskup | bash
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

## Building

Each input is a variable. Unset, they fall back to the name on `PATH`, except
`NIMBUS` and `ZISK_LIB`, which are fetched and built under `build/`:

| variable | what | default |
|---|---|---|
| `NIMBUS` | nimbus-eth1 checkout | cloned at `NIMBUS_REF` into `build/nimbus` |
| `ZISK_LIB` | `libziskos_staticlib.a` for `riscv64im-unknown-none-elf` | built from ZisK `ZISK_REF` into `build/zisk-<ref>` |
| `ZKVM_GCC` | `riscv-none-elf-gcc` that emits rv64im | `riscv-none-elf-gcc` |
| `ZISK_EMULATOR` | `ziskemu`, for `test` | `ziskemu` |
| `ZISK_PROVER` | `cargo-zisk-dev`, for `vk` | `cargo-zisk-dev` |

```bash
make guest_zisk ZKVM_GCC=~/.local/xPacks/riscv-none-elf-gcc/bin/riscv-none-elf-gcc
make test_zisk  ZISK_EMULATOR=~/.zisk/bin/ziskemu
make vk_zisk    ZISK_PROVER=~/.zisk/bin/cargo-zisk-dev
make help

# or put them on PATH and drop the variables
export PATH=~/.local/xPacks/riscv-none-elf-gcc/bin:~/.zisk/bin:$PATH
make guest_zisk && make test_zisk
```

`NIMBUS=~/src/nimbus-eth1` builds a working tree instead of the pinned
revision; the build prints the commit it used and carries on.

Everything lands under `build/`: the checkout in `build/nimbus`, ZisK sources
in `build/zisk-<ref>`, unpacked fixtures in `build/fixtures`, the ELF and key in
`build/artifacts`. `make clean` drops the lot.

`test` runs the fixtures in [`fixtures/`](fixtures). The whole EEST bundle runs
through
[zkevm-benchmark-workload](https://github.com/eth-act/zkevm-benchmark-workload),
which is also where the metrics come from. Support for Nimbus is still to be
added there.

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

The `.vk` identifies one compiled guest: for ZisK the Merkle root of the ELF's
ROM trace, so any rebuild that changes a byte changes the key, and a proof
carries it in its public values.

## License

Licensed and distributed under either of:

- MIT license ([LICENSE-MIT](LICENSE-MIT) or
  https://opensource.org/licenses/MIT)
- Apache License, Version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
  https://www.apache.org/licenses/LICENSE-2.0)

at your option.
