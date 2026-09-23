#!/usr/bin/env bash

# nimbus-zkvm-guests
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

# The ZisK proving key needs ~22 GB at peak: a 3.7 GB download, 14 GB unpacked,
# and ~3.6 GB of program-setup output. GitHub documents 14 GB of storage for a
# standard Linux runner, and the image arrives with a good deal of it spent, so
# drop the largest preinstalled toolchains first. The df below reports what the
# runner actually had.

set -euo pipefail

sudo rm -rf \
    /usr/local/lib/android \
    "${AGENT_TOOLSDIRECTORY:-/opt/hostedtoolcache}" \
    /usr/share/dotnet \
    /usr/lib/jvm

df -h / | tail -1
