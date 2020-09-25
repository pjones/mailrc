#!/usr/bin/env bash

set -eu
set -o pipefail

folder=$1
shift

args=()

if [ "$folder" != "INBOX" ]; then
  args+=("--folder=.$folder")
fi

notmuch insert \
  --create-folder \
  --keep \
  --decrypt=false \
  "${args[@]}" "$@" "+unread"
