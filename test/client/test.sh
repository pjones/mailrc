#!/usr/bin/env bash

################################################################################
set -eu
set -o pipefail

################################################################################
TEST_ROOT=${TEST_ROOT:-"$(dirname "$0")/.."}
TEST_USER=${TEST_USER:-tester}
XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

################################################################################
GPG_KEY=password
MAIL_INPUT=/tmp/mailrc-test
MAIL_OUPUT=$(notmuch config get database.path)

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

  assert "new database should have a single message" \
    "$(notmuch count)" -eq 1
}

################################################################################
run_sieve() {
  local mail_file=$1

  sieve-test \
    -e -u "$TEST_USER" \
    "$HOME/.config/dovecot/sieve/active" \
    "$MAIL_INPUT/$mail_file"
}

################################################################################
make_notmuch_folder_name() {
  local folder=$1

  if [ "$folder" = "INBOX" ]; then
    echo '""'
  else
    echo ".$folder"
  fi
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
# Inserting a message should increase the tag count by N.
should_increase_tag_count_by() {
  local mail=$1   # The mail message to insert.
  local folder=$2 # The folder that should be updated.
  local tag=$3    # The tag that should change.
  local count=$4  # The number of messages that should get the tag.
  local maildir_count
  local notmuch_count
  local notmuch_folder

  maildir_count=$(maildir_count "$folder")
  notmuch_count=$(notmuch count tag:"$tag")
  notmuch_folder=$(make_notmuch_folder_name "$folder")

  run_sieve "$mail"

  assert "inserting $mail should increment the $folder message count" \
    "$((maildir_count + 1))" -eq "$(maildir_count "$folder")"

  notmuch new

  assert "running 'notmuch new' for $mail should increment the tag:$tag count" \
    "$((notmuch_count + count))" -eq "$(notmuch count tag:"$tag")"

  assert "notmuch and maildir should agree on the number of messages in $folder" \
    "$(maildir_count "$folder")" -eq \
    "$(notmuch count folder:"$notmuch_folder")"
}

################################################################################
should_file_into() {
  should_increase_tag_count_by "$1" "$2" "unread" 1
}

################################################################################
should_all_be_unseen() {
  local maildir
  maildir=$(make_maildir_path "$1")

  assert "$1 folder should only have unseen messages" \
    "$(mlist -S "$maildir" | wc -l)" -eq 0
}

################################################################################
should_move_tagged_messages() {
  local tag=$1
  local from_folder=$2
  local to_folder=$3
  local from_count
  local to_count

  from_count=$(maildir_count "$from_folder")
  to_count=$(maildir_count "$to_folder")

  assert "number of messages in $from_folder should be greater than 0" \
    "$from_count" -gt 0

  # Tag messages so that they can be moved:
  notmuch tag +"$tag" +move -- \
    folder:"$(make_notmuch_folder_name "$from_folder")"

  assert "number of messages with tag:move should match $from_folder count" \
    "$(notmuch count tag:move)" -eq "$from_count"

  # Call the move hook to move messages around:
  "$XDG_DATA_HOME/notmuch/hooks/x-post-tag"

  assert "number of messages in $to_folder should increase by $from_count" \
    "$((to_count + from_count))" -eq "$(maildir_count "$to_folder")"

  assert "tag:move should have been removed from all messages" \
    "$(notmuch count tag:move)" -eq 0

  # Update notmuch database:
  notmuch new

  # Now move the messages back:
  notmuch-refile \
    "$from_folder" \
    folder:"$(make_notmuch_folder_name "$to_folder")"

  assert "refiling all messages from $to_folder to $from_folder should move files" \
    "$((from_count + to_count))" -eq "$(maildir_count "$from_folder")"
}

################################################################################
run_tests() {
  should_file_into "github.mail" "mlists"
  should_file_into "travel.mail" "Travel"
  should_all_be_unseen "mlists"
  should_increase_tag_count_by "fromme.mail" "INBOX" "from-me" 1
  should_increase_tag_count_by "postmaster.mail" "root" "unread" 0
  should_move_tagged_messages "archived" "INBOX" "Archive"
}

################################################################################
main() {
  prepare_mail_input
  prepare_notmuch_database
  run_tests
}

################################################################################
main
