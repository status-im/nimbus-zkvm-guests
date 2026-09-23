# Nimbus
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
#    http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or
#    http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

# The ZisK guest.
#
#   make -C zisk elf     compile and link the guest
#   make -C zisk test    execute it over the committed fixtures
#   make -C zisk vk      its verification key
#
# Toolchain, platform archive, emulator and prover are inputs: install them how
# you like and pass the paths. See the README, or .github/workflows/ci.yml.

include ../versions.env
include versions.env

ZKVM := zisk

### paths

ROOT := $(abspath ..)
BUILD := $(ROOT)/build
OUT ?= $(BUILD)/artifacts

# The name eth-act's harness resolves guests by, and ere-guests pins.
ARTIFACT := $(OUT)/stateless-validator-nimbus-$(ZKVM)-$(ZISK_REF)
ELF := $(ARTIFACT).elf
VK := $(ARTIFACT).vk

JOBS := $(shell nproc)  # for nimbus-eth1's build

### inputs

# A riscv-none-elf-gcc that can emit rv64im, and a cargo with a nightly
# toolchain and rust-src for the platform archive. NIMBUS and ZISK_LIB are
# fetched and built at the pinned revisions when not already there.
#
# These carry nimbus-eth1's own names, because a command-line override reaches
# every nested make: `STATICLIB` collides with libnatpmp's, for one.
NIMBUS ?= $(BUILD)/nimbus
NIMBUS_SRC := $(NIMBUS)/Makefile
ZKVM_GCC ?= riscv-none-elf-gcc
ZISK_SRC := $(BUILD)/zisk-$(ZISK_REF)
ZISK_LIB ?= $(ZISK_SRC)/libziskos_staticlib.a

ZISK_EMULATOR ?= ziskemu
ZISK_PROVER ?= cargo-zisk-dev

TEST_TIMEOUT ?= 30

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:

.DELETE_ON_ERROR:

.PHONY: all elf nimbus staticlib test vk clean

all: elf

require = $(if $(1),,$(error $(2)))

### guest

# `git clone` cannot shallow-fetch a commit before git 2.49, only tag/branch
nimbus: $(NIMBUS_SRC)
$(NIMBUS_SRC):
	git init -q $(NIMBUS)
	git -C $(NIMBUS) fetch -q --depth 1 $(NIMBUS_REPO) $(NIMBUS_REF)
	git -C $(NIMBUS) checkout -q --detach FETCH_HEAD

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

elf: $(ELF)
$(ELF): $(NIMBUS_SRC) $(ZISK_LIB)
	head=$$(git -C $(NIMBUS) rev-parse HEAD 2>/dev/null || echo unknown)
	[ "$$head" = "$(NIMBUS_REF)" ] || \
	  echo "note: $(NIMBUS) is at $$head, versions.env says $(NIMBUS_REF)" >&2
	mkdir -p $(OUT)
	# Not `update`: that hard-resets every submodule, working tree included.
	$(MAKE) -C $(NIMBUS) -j$(JOBS) CI_CACHE=NimBinCache init
	# Without --require-defined a vendor-archive-less link still succeeds.
	$(MAKE) -C $(NIMBUS) -j$(JOBS) CI_CACHE=NimBinCache ZKVM=$(ZKVM) \
	  ZKVM_GCC=$(ZKVM_GCC) ZISK_LIB=$(ZISK_LIB) ZKVM_ELF=$@ \
	  ZKVM_EXTRA_PASSL=-Wl,--require-defined=_start stateless_guest_zkvm
	echo "built $@ ($$(stat -c%s $@) bytes)"

### run

include ../fixtures/fixtures.mk

test: $(INPUTS)
	$(call require,$(wildcard $(ELF)),$(ELF) is missing: run `make elf` first)
	$(ROOT)/scripts/run-test-fixtures.sh $(ZISK_EMULATOR) $(ELF) $(TEST_TIMEOUT) $(INPUTS)

# Merkle root of the compiled ROM trace
vk: $(VK)
$(VK):
	$(call require,$(wildcard $(ELF)),$(ELF) is missing: run `make elf` first)
	out=$$(mktemp -d -p $(BUILD))
	trap 'rm -rf "$$out"' EXIT
	$(ZISK_PROVER) program-setup --elf $(ELF) --output-dir $$out
	cp $$out/*.verkey.bin $@
	[ $$(stat -c%s $@) -eq 32 ]
	printf 'VK: 0x%s\n' "$$(od -An -v -tx1 $@ | tr -d ' \n')"

### clean-up

clean:
	rm -rf $(BUILD)
