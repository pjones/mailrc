#!/usr/bin/env bash

set -eu
set -o pipefail

folder=$1
shift

tags=()

case "$folder" in
*)
  tags+=("-new" "+unread")
  ;;
esac

if [ "$folder" != "INBOX" ]; then
  folder=".$folder"
fi

notmuch insert \
  --create-folder \
  --no-hooks \
  --keep \
  --decrypt=false \
  --folder="$folder" \
  "$@" "${tags[@]}"
