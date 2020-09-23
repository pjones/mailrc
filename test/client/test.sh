#!/usr/bin/env bash

################################################################################
set -eu
set -o pipefail

################################################################################
TEST_ROOT=${TEST_ROOT:-"$(dirname "$0")/.."}
TEST_USER=${TEST_USER:-pjones}

################################################################################
GPG_KEY=password
MAIL_INPUT=/var/lib/mailrc-test
MAIL_OUPUT=/home/"$TEST_USER"/mail

################################################################################
notmuch() {
  su - "$TEST_USER" -c "notmuch $*"
}

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
# Inject a message into the mailbox then init the notmuch database.
prepare_notmuch_database() {
  run_sieve "nixos.mail"
  notmuch new
}

################################################################################
run_sieve() {
  local mail_file=$1

  sieve-test \
    -e -u "$TEST_USER" \
    -l "maildir:~/mail:INBOX=~/mail" \
    /home/"$TEST_USER"/.config/dovecot/sieve/active \
    "$MAIL_INPUT/$mail_file"
}

################################################################################
make_folder_name() {
  local folder=$1

  if [ "$folder" = "INBOX" ]; then
    echo "$folder"
  else
    echo ".$folder"
  fi
}

################################################################################
make_maildir_path() {
  local folder

  folder=$(make_folder_name "$1")
  echo "$MAIL_OUPUT/$folder"
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
    echo >&2 "FAIL: $msg"
    echo >&2 "FAIL: $*"
    exit 1
  fi
}

################################################################################
should_file_into() {
  local mail=$1
  local folder=$2
  local maildir_count
  local notmuch_t_count
  local notmuch_f_count

  notmuch_folder_name=$(make_folder_name "$folder")
  notmuch_t_count=$(notmuch count "tag:unread")
  notmuch_f_count=$(notmuch count "folder:$notmuch_folder_name")
  maildir_count=$(maildir_count "$folder")

  run_sieve "$mail"

  assert "inserting $mail should increment the maildir message count" \
    "$((maildir_count + 1))" -eq "$(maildir_count "$folder")"

  assert "inserting $mail should increment the tag:unread count" \
    "$((notmuch_t_count + 1))" -eq "$(notmuch count "tag:unread")"

  assert "inserting $mail should increment the folder:$notmuch_folder_name count" \
    "$((notmuch_f_count + 1))" -eq "$(notmuch count "folder:$notmuch_folder_name")"
}

################################################################################
should_all_be_unseen() {
  local maildir
  local count

  maildir=$(make_maildir_path "$1")
  count=$(mlist "$maildir" | mscan -f %u | grep -Evc '^\.' || :)

  assert "$1 folder should only have unseen messages" \
    "$count" -eq 0
}

################################################################################
should_get_from_me_tag() {
  local mail=$1
  local folder=$2
  local maildir_count
  local notmuch_count
  local maildir

  maildir_count=$(maildir_count "$folder")
  notmuch_count=$(notmuch count tag:from-me)

  maildir=$(make_maildir_path "$folder")
  cp "$MAIL_INPUT/$mail" "$maildir/cur"

  assert "inserting $mail should increment the maildir message count" \
    "$((maildir_count + 1))" -eq "$(maildir_count "$folder")"

  notmuch new

  assert "running 'notmuch new' for $mail should increment the tag:from-me count" \
    "$((notmuch_count + 1))" -eq "$(notmuch count tag:from-me)"
}

################################################################################
run_tests() {
  should_file_into "github.mail" "mlists"
  should_all_be_unseen "mlists"
  should_get_from_me_tag "fromme.mail" "INBOX"
}

################################################################################
main() {
  prepare_mail_input
  prepare_notmuch_database
  run_tests
}

################################################################################
main
