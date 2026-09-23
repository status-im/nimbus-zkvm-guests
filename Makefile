# Nimbus
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
#    http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or
#    http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

# make                 build the guest for every zkVM
# make guest_zisk      build one
# make test_zisk       execute it over the committed fixtures
# make vk_zisk         derive its verification key
#
# The real work lives in the per-zkVM directories; the targets below are
# shorthand for `make -C <zkvm> <goal>`.
ZKVMS := zisk

# Not .PHONY below: make skips pattern rules for phony targets.
.PHONY: all guests test vk clean help

all: guests

guests: $(addprefix guest_,$(ZKVMS))
test: $(addprefix test_,$(ZKVMS))
vk: $(addprefix vk_,$(ZKVMS))

clean:
	@for z in $(ZKVMS); do $(MAKE) --no-print-directory -C $$z $@ || exit 1; done

guest_%:
	$(MAKE) --no-print-directory -C $* elf

test_% vk_%:
	$(MAKE) --no-print-directory -C $(word 2,$(subst _, ,$@)) $(word 1,$(subst _, ,$@))

# The directories exist, so `make zisk` would otherwise be a silent no-op.
.PHONY: $(ZKVMS)
$(ZKVMS):
	@echo "no such goal: try 'make guest_$@', or 'make help'" >&2; exit 1

help:
	@echo "make               build the guest for every zkVM: $(ZKVMS)"
	@echo "make guests        the same"
	@echo "make test          execute every guest over the committed fixtures"
	@echo "make vk            derive every verification key"
	@echo "make clean         drop build/"
	@echo
	@for z in $(ZKVMS); do \
	  echo "make guest_$$z     build just this one"; \
	  echo "make test_$$z      execute just this one"; \
	  echo "make vk_$$z        its verification key"; \
	done
