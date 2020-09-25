#!/usr/bin/env bash

set -eu
set -o pipefail

nix-build \
  --no-out-link \
  "$(dirname "$0")"
