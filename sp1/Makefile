# nimbus-zkvm-guests
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

# The SP1 guest.
#
#   make -C sp1 elf     compile and link the guest
#   make -C sp1 test    execute it over the committed fixtures
#   make -C sp1 vk      its verification key
#
# Toolchain and prover are inputs: install them how you like and pass the
# paths. See the README, or .github/workflows/ci.yml.

include versions.env

ZKVM := sp1
ZKVM_VERSION := $(SP1_REF)

include ../guest.mk

### inputs

SP1_SDK ?= $(BUILD)/sp1-sdk-$(SP1_REF)
SP1_EXECUTE := $(BUILD)/sp1-execute/release/sp1-execute
SP1_EXECUTOR ?= $(SP1_EXECUTE)
# The ZISK_PROVER counterpart, not named SP1_PROVER as that clashes with the
# environment variable the SP1 SDK in cargo-prove reads its mode from.
SP1_CARGO_PROVE ?= cargo-prove

GUEST_VARS = SP1_SDK=$(SP1_SDK)
EMULATOR = $(SP1_EXECUTOR)

.PHONY: sdk executor

### guest

# The prebuilt libzkevm.a and zkvm.ld the guest links with, from SP1's release.
sdk: $(SP1_SDK)/libzkevm.a
$(BUILD)/sp1-sdk-$(SP1_REF)/libzkevm.a:
	archive=$(BUILD)/zkevm-sdk-$(SP1_REF).tar.gz
	trap 'rm -f "$$archive"' EXIT
	rm -rf $(dir $@) && mkdir -p $(dir $@)
	curl -sSL --proto '=https' --tlsv1.2 -o $$archive \
	  $(SP1_REPO)/releases/download/$(SP1_REF)/zkevm-sdk-$(SP1_REF).tar.gz
	echo "$(SP1_SDK_SHA256)  $$archive" | sha256sum -c --quiet
	tar -xzf $$archive -C $(dir $@) --strip-components=1

$(ELF): $(SP1_SDK)/libzkevm.a

### run

# SP1 ships no executor binary. The tag placeholder in execute/Cargo.toml is set
# to SP1_REF, and SP1's Cargo.lock at that tag pins the dependencies.
executor: $(SP1_EXECUTE)
$(SP1_EXECUTE): versions.env execute/Cargo.toml execute/src/main.rs
	crate=$(BUILD)/sp1-execute/crate
	rm -rf $$crate && mkdir -p $$crate && cp -r execute/src $$crate
	sed 's/tag = "SP1_REF"/tag = "$(SP1_REF)"/' execute/Cargo.toml > $$crate/Cargo.toml
	curl -fsSL --proto '=https' --tlsv1.2 -o $$crate/Cargo.lock \
	  $(subst github.com,raw.githubusercontent.com,$(SP1_REPO))/$(SP1_REF)/Cargo.lock
	cargo build -q --release --manifest-path $$crate/Cargo.toml \
	  --target-dir $(BUILD)/sp1-execute

# Builds the executor before testing, except when SP1_EXECUTOR is passed.
test: $(filter $(SP1_EXECUTE),$(SP1_EXECUTOR))

# Poseidon2 digest of the verifying key, packed into 32 bytes the way SP1's
# bytes32() does and Ere decodes it. `cargo prove vkey` only prints it as hex,
# which is decoded to write the 32 bytes to the file.
$(VK):
	$(call require,$(wildcard $(ELF)),$(ELF) is missing: run `make elf` first)
	hex=$$($(SP1_CARGO_PROVE) prove vkey --elf $(ELF) | sed -n 's/^0x\([0-9a-f]\{64\}\)$$/\1/p')
	[ -n "$$hex" ] || { echo "no verification key hash from $(SP1_CARGO_PROVE)" >&2; exit 1; }
	printf '%s' "$$hex" | tr a-f A-F | basenc -d --base16 > $@
	[ $$(stat -c%s $@) -eq 32 ]
	printf 'VK: 0x%s\n' "$$hex"
