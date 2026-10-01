#!/usr/bin/env bash

# nimbus-zkvm-guests
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

#
# Lists the stateless changes in nimbus-eth1 between two commits.
# Used for the release notes.
#
#   stateless-changelog.sh <base-ref> <head-ref>
#
# A commit counts as stateless if its subject starts with `stateless:`
#

set -euo pipefail

base=${1:?base ref}
head=${2:?head ref}
repo=${NIMBUS_REPO:-https://github.com/status-im/nimbus-eth1}

# --filter=tree:0 fetches the commits alone
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
git init -q "$dir"
git -C "$dir" fetch -q --filter=tree:0 "$repo" "$base" "$head"

git -C "$dir" log --format='%s' --grep='^stateless:' -i "$base..$head" |
  sed -E "s|^(.*) \(#([0-9]+)\)\$|- \1 ([#\2]($repo/pull/\2))|; t; s|^|- |"
