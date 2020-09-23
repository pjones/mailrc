#!/usr/bin/env bash

################################################################################
# Compile a sieve script.
#
# $1: The sieve file to compile.
# $2: Path to the Dovecot configuration file (optional).
compileSieveScript() {
  local file=$1
  local config=${2:-/dev/null}

  sievec -c "$config" "$file" \
    "$(dirname "$file")/$(basename "$file" ".sieve").svbin"
}

################################################################################
# Install all *.sieve files from the current directory and compile them.
#
# $1: Output directory
# $2: Path to the Dovecot configuration file (optional).
installSieveScripts() {
  local out=$1
  local config=${2:-/dev/null}

  mkdir -p "$out"

  for sieve in *.sieve; do
    install -m0444 "$sieve" "$out/sieve"
    compileSieveScript "$out/sieve/$(basename "$sieve")" "$config"
  done
}

################################################################################
# Install all sieve-related *.sh files.
#
# $1: Output directory
# $2: PATH entries to use.
installSieveShellScripts() {
  local out=$1
  local path=$2

  for script in *.sh; do
    install -m 0555 "$script" "$out/share/scripts/"

    makeWrapper \
      "$out/share/scripts/$(basename "$script")" \
      "$out/bin/$(basename "$script")" \
      --prefix PATH : "$path"
  done
}
