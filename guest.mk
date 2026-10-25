# nimbus-zkvm-guests
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

# Shared parts for the different <zkvm>/Makefile.
# Before including this, set what its paths are built from:
#
#   ZKVM          the name nimbus-eth1's zkvm.mk and the artifacts carry
#   ZKVM_VERSION  the zkvm_version that names the artifacts
#
# After it, where BUILD, ELF and VK exist, add the vendor inputs and
#
#   GUEST_VARS    vendor inputs for nimbus-eth1's <zkvm>.mk, e.g. ZISK_LIB=...
#   EMULATOR      what runs the ELF over a fixture, see run-test-fixtures.sh
#   $(ELF): ...   the vendor inputs as prerequisites
#   $(VK):        the recipe deriving the verification key
#
# GUEST_VARS and EMULATOR are only expanded in recipes, so they can also be set
# before the include.

### paths

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD := $(ROOT)/build
OUT ?= $(BUILD)/artifacts

include $(ROOT)/versions.env

# The name eth-act's harness resolves guests by, and ere-guests pins.
ARTIFACT := $(OUT)/stateless-validator-nimbus-$(ZKVM)-$(ZKVM_VERSION)
ELF := $(ARTIFACT).elf
VK := $(ARTIFACT).vk

JOBS := $(shell nproc)  # for nimbus-eth1's build

### inputs

# A riscv-none-elf-gcc that can emit rv64im. NIMBUS is fetched at the pinned
# revision when not already there.
#
# Vendor inputs carry nimbus-eth1's own names, because a command-line override
# reaches every nested make: `STATICLIB` collides with libnatpmp's, for one.
NIMBUS ?= $(BUILD)/nimbus
NIMBUS_SRC := $(NIMBUS)/Makefile
ZKVM_GCC ?= riscv-none-elf-gcc

TEST_TIMEOUT ?= 30

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:

.DELETE_ON_ERROR:

.PHONY: all elf nimbus test vk clean

all: elf

require = $(if $(1),,$(error $(2)))

### guest

# `git clone` cannot shallow-fetch a commit before git 2.49, only tag/branch
nimbus: $(NIMBUS_SRC)
$(NIMBUS_SRC):
	git init -q $(NIMBUS)
	git -C $(NIMBUS) fetch -q --depth 1 $(NIMBUS_REPO) $(NIMBUS_REF)
	git -C $(NIMBUS) checkout -q --detach FETCH_HEAD

elf: $(ELF)
$(ELF): $(NIMBUS_SRC)
	head=$$(git -C $(NIMBUS) rev-parse HEAD 2>/dev/null || echo unknown)
	[ "$$head" = "$(NIMBUS_REF)" ] || \
	  echo "note: $(NIMBUS) is at $$head, versions.env says $(NIMBUS_REF)" >&2
	mkdir -p $(OUT)
	# Not `update`: that hard-resets every submodule, working tree included.
	$(MAKE) -C $(NIMBUS) -j$(JOBS) CI_CACHE=NimBinCache init
	# Without --require-defined a vendor-archive-less link still succeeds.
	$(MAKE) -C $(NIMBUS) -j$(JOBS) CI_CACHE=NimBinCache ZKVM=$(ZKVM) \
	  ZKVM_GCC=$(ZKVM_GCC) $(GUEST_VARS) ZKVM_ELF=$@ \
	  ZKVM_EXTRA_PASSL=-Wl,--require-defined=_start stateless_guest_zkvm
	echo "built $@ ($$(stat -c%s $@) bytes)"

### run

include $(ROOT)/fixtures/fixtures.mk

test: $(INPUTS)
	$(call require,$(wildcard $(ELF)),$(ELF) is missing: run `make elf` first)
	$(ROOT)/scripts/run-test-fixtures.sh $(ZKVM) $(EMULATOR) $(ELF) $(TEST_TIMEOUT) $(INPUTS)

vk: $(VK)

### clean-up

clean:
	rm -rf $(BUILD)
