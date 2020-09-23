#!/usr/bin/env bash

################################################################################
# Generate a single line of a Dovecot password file.
set -eu
set -o pipefail

################################################################################
option_username=
option_password_file=
option_uid=
option_gid=
option_home_dir=

################################################################################
usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

  -h      This message
  -u NAME Username
  -p FILE File containing the password
  -U UID  User ID
  -G GID  Group ID
  -d DIR  User home directory
EOF
}

################################################################################
main() {
  local password

  if [ -z "$option_username" ]; then
    echo >&2 "ERROR: username cannot be blank"
    exit 1
  fi

  if [ ! -r "$option_password_file" ]; then
    echo >&2 "ERROR: can't read password from $option_password_file"
    exit 1
  fi

  password=$(head --lines=1 "$option_password_file")
  echo "${option_username}:${password}:${option_uid}:${option_gid}::${option_home_dir}::"
}

################################################################################
# Option arguments are in $OPTARG
while getopts "hu:p:U:G:d:" o; do
  case "${o}" in
  h)
    usage
    exit
    ;;

  u)
    option_username=$OPTARG
    ;;

  p)
    option_password_file=$OPTARG
    ;;

  U)
    option_uid=$OPTARG
    ;;

  G)
    option_gid=$OPTARG
    ;;

  d)
    option_home_dir=$OPTARG
    ;;

  *)
    exit 1
    ;;
  esac
done

shift $((OPTIND - 1))
main
