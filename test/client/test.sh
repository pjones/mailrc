#!/usr/bin/env bash

################################################################################
set -eu
set -o pipefail

################################################################################
TEST_ROOT=${TEST_ROOT:-"$(dirname "$0")/.."}
TEST_EMAIL=${TEST_EMAIL:-"tester@test.com"}
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

################################################################################
GPG_KEY=password
MAIL_INPUT=/tmp/mailrc-test
MAIL_OUPUT=$HOME/mail

################################################################################
prepare_mail_input() {
  mkdir -p "$MAIL_INPUT"

  for file in "$TEST_ROOT"/mail/*.gpg; do
    out="$MAIL_INPUT/$(basename "$file" ".gpg")"

    gpg2 --decrypt --batch \
      --passphrase "$GPG_KEY" --pinentry-mode loopback \
      <"$file" >"$out"
  done
}

################################################################################
run_sieve() {
  local mail_file=$1

  sieve-test \
    -e -u "$TEST_EMAIL" \
    "$HOME/.config/dovecot/sieve/active" \
    "$MAIL_INPUT/$mail_file"
}

################################################################################
make_maildir_path() {
  local folder=$1

  if [ "$folder" = "INBOX" ]; then
    echo "$MAIL_OUPUT"
  else
    echo "$MAIL_OUPUT/.$folder"
  fi
}

################################################################################
maildir_count() {
  local maildir
  maildir=$(make_maildir_path "$1")

  if [ -d "$maildir" ]; then
    mlist "$maildir" | wc -l
  else
    echo "0"
  fi
}

################################################################################
assert() {
  local msg=$1
  shift

  if ! test "$@"; then
    echo >&2 "FAIL: ${FUNCNAME[1]}: $msg"
    echo >&2 "FAIL: ${FUNCNAME[1]}: $*"
    exit 1
  fi
}

################################################################################
should_file_into() {
  local mail=$1   # The mail message to insert.
  local folder=$2 # The folder that should be updated.
  local count=1   # The number of messages that should get the tag.

  maildir_count=$(maildir_count "$folder")

  run_sieve "$mail"

  assert "inserting $mail should increment the $folder message count" \
    "$((maildir_count + count))" -eq "$(maildir_count "$folder")"
}

################################################################################
should_all_be_unseen() {
  local maildir
  maildir=$(make_maildir_path "$1")

  assert "$1 folder should only have unseen messages" \
    "$(mlist -S "$maildir" | wc -l)" -eq 0
}

################################################################################
run_tests() {
  should_file_into "github.mail" "mlists"
  should_file_into "travel.mail" "Travel"
  should_all_be_unseen "mlists"
  should_file_into "fromme.mail" "INBOX"
  should_file_into "postmaster.mail" "root"
}

################################################################################
main() {
  prepare_mail_input
  run_tests
}

################################################################################
main
