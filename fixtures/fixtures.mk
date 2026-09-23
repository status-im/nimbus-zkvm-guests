# Nimbus
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
#    http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or
#    http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.
#
# The fixtures beside this file are copied out of fixtures_zkevm.tar.gz of
# https://github.com/ethereum/execution-specs/releases/tag/tests-zkevm@v0.8.4.
# The guest takes bare bytes in and writes bare bytes out, so each fixture is
# unpacked into the input to feed it and the output to expect back.

FIXTURES := $(wildcard $(ROOT)/fixtures/*.json)
INPUTS := $(patsubst $(ROOT)/fixtures/%.json,$(BUILD)/fixtures/%.input.bin,$(FIXTURES))

$(BUILD)/fixtures/%.input.bin: $(ROOT)/fixtures/%.json
	mkdir -p $(dir $@)
	jq -re '.[].blocks[0].statelessInputBytes' $< | cut -c3- | tr a-f A-F \
	  | basenc -d --base16 > $@
	jq -re '.[].blocks[0].statelessOutputBytes' $< | cut -c3- | tr a-f A-F \
	  | basenc -d --base16 > $(@:.input.bin=.output.bin)
