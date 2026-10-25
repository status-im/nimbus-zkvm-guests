#!/usr/bin/env bash

# nimbus-zkvm-guests
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

# Feeds each <name>.input.bin to the guest and requires <name>.output.bin back.
#
# usage: run-test-fixtures.sh <zkvm> <emulator> <elf> <timeout-seconds> <name.input.bin>...

set -euo pipefail

[ $# -ge 5 ] || { echo "usage: $0 <zkvm> <emulator> <elf> <timeout> <name.input.bin>..." >&2; exit 2; }
zkvm=$1 emulator=$2 elf=$3 timeout_s=$4
shift 4

case "$zkvm" in
  zisk | sp1) ;;
  *) echo "unknown zkvm: $zkvm" >&2; exit 2 ;;
esac

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

failed=0
for input in "$@"; do
  name=$(basename "$input" .input.bin)
  expected=${input%.input.bin}.output.bin
  size=$(stat -c%s "$expected")

  case "$zkvm" in
    # --legacy-inputs takes the payload as it is; -i would want it wrapped in
    # the emulator's length-prefixed container.
    zisk) args=(-e "$elf" --legacy-inputs "$input" -o "$work/output") ;;
    sp1) args=("$elf" "$input" "$work/output") ;;
  esac

  rm -f "$work/output"
  if ! timeout "$timeout_s" "$emulator" "${args[@]}" >"$work/log" 2>&1; then
    echo "FAIL $name: emulator exited non-zero or timed out"
    sed -n '1,3p' "$work/log" | sed 's/^/  /'
    failed=$((failed + 1))

  # ZisK zeroes the 256-byte output region and exits 0 whatever the guest did,
  # so the expected bytes have to match and the rest has to still be zero. SP1
  # commits exactly the bytes the guest wrote, so there is no rest.
  elif ! cmp -s -n "$size" "$work/output" "$expected"; then
    echo "FAIL $name: output differs from the expected bytes"
    echo "  got  $(od -An -tx1 -N16 "$work/output" | tr -d ' \n')..."
    echo "  want $(od -An -tx1 -N16 "$expected" | tr -d ' \n')..."
    failed=$((failed + 1))

  elif [ "$zkvm" = sp1 ] && [ "$(stat -c%s "$work/output")" -ne "$size" ]; then
    echo "FAIL $name: output is $(stat -c%s "$work/output") bytes, expected $size"
    failed=$((failed + 1))

  elif [ -n "$(tail -c "+$((size + 1))" "$work/output" | tr -d '\0')" ]; then
    echo "FAIL $name: output region has non-zero trailing bytes"
    failed=$((failed + 1))

  else
    echo "ok   $name"
  fi
done

echo "$(($# - failed))/$# fixtures match their expected output"
[ "$failed" -eq 0 ]
