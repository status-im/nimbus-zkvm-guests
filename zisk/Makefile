# nimbus-zkvm-guests
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

# The ZisK guest.
#
#   make -C zisk elf     compile and link the guest
#   make -C zisk test    execute it over the committed fixtures
#   make -C zisk vk      its verification key
#
# Toolchain, platform archive, emulator and prover are inputs: install them how
# you like and pass the paths. See the README, or .github/workflows/ci.yml.

include versions.env

ZKVM := zisk
ZKVM_VERSION := $(ZISK_REF)

include ../guest.mk

### inputs

# A cargo with a nightly toolchain and rust-src for the platform archive, which
# is built at the pinned tag when not already there.
ZISK_SRC := $(BUILD)/zisk-$(ZISK_REF)
ZISK_LIB ?= $(ZISK_SRC)/libziskos_staticlib.a

ZISK_EMULATOR ?= ziskemu
ZISK_PROVER ?= cargo-zisk-dev

GUEST_VARS = ZISK_LIB=$(ZISK_LIB)
EMULATOR = $(ZISK_EMULATOR)

.PHONY: staticlib

### guest

# ZisK ships no binary for riscv64im-unknown-none-elf, a Tier 3 target. The
# same cargo line is what nimbus-eth1's check_zisk_staticlib tells you to run.
staticlib: $(ZISK_LIB)
$(ZISK_SRC)/libziskos_staticlib.a:
	rm -rf $(ZISK_SRC)/src
	git clone -q --depth 1 --branch $(ZISK_REF) $(ZISK_REPO) $(ZISK_SRC)/src
	cd $(ZISK_SRC)/src
	cargo +$(RUST_NIGHTLY) build -p ziskos-staticlib --release \
	  --target riscv64im-unknown-none-elf -Z build-std=core,alloc \
	  --config 'profile.release.lto="fat"' --features panic-handler
	cp target/riscv64im-unknown-none-elf/release/libziskos_staticlib.a $@

$(ELF): $(ZISK_LIB)

### run

# Merkle root of the compiled ROM trace
$(VK):
	$(call require,$(wildcard $(ELF)),$(ELF) is missing: run `make elf` first)
	out=$$(mktemp -d -p $(BUILD))
	trap 'rm -rf "$$out"' EXIT
	$(ZISK_PROVER) program-setup --elf $(ELF) --output-dir $$out
	cp $$out/*.verkey.bin $@
	[ $$(stat -c%s $@) -eq 32 ]
	printf 'VK: 0x%s\n' "$$(od -An -v -tx1 $@ | tr -d ' \n')"
