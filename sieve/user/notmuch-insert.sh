#!/usr/bin/env bash

set -eu
set -o pipefail

folder=$1
shift

args=()
mark_unread=1

if [ "$folder" != "INBOX" ]; then
  args+=("--folder=.$folder")
fi

for flag in "$@"; do
  if [ "$flag" = "-unread" ]; then
    mark_unread=0
  fi
done

if [ "$mark_unread" -eq 1 ]; then
  args+=("+unread")
fi

notmuch insert \
  --create-folder \
  --keep \
  --decrypt=false \
  "${args[@]}" "$@"
