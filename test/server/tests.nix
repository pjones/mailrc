{ stdenv
, writeText
, writeShellScript
, msmtp
, fetchmail
, username
, password
, domain
}:
let
  msg = writeText "test-mailstack.email" ''
    From: ${username}@${domain}
    Subject: Test

    TEST
  '';

  smtp = writeShellScript "test-mailstack-smtp-script" ''
    set -e
    set -u

    to='${username}@${domain}'

    if [ $# -gt 0 ]; then
      to=$1
      shift
    fi

    ${msmtp}/bin/msmtp \
      --host=localhost \
      --port=465 \
      --auth=plain \
      --user='${username}@${domain}' \
      --passwordeval='echo ${password}' \
      --tls=on \
      --tls-starttls=off \
      --tls-certcheck=off \
      --from="$to" \
      --timeout=5 \
      "$to" < ${msg}
  '';

  netrc = writeText "netrc" ''
    machine localhost login ${username}@${domain} password ${password}
  '';

  imap = writeShellScript "test-mailstack-imap-script" ''
    set -e
    set -u

    # So fetchmail can find the creds:
    export HOME_ETC=/tmp/fetchmail-home
    mkdir $HOME_ETC
    cp ${netrc} $HOME_ETC/.netrc

    ${fetchmail}/bin/fetchmail \
      --check \
      --verbose \
      --protocol IMAP \
      --service 993 \
      --timeout 5 \
      --ssl \
      --nosslcertck \
      --user '${username}@${domain}' \
      --auth password \
      localhost
  '';

in
stdenv.mkDerivation {
  name = "mail-tools-for-${username}";
  phases = [ "installPhase" ];
  installPhase = ''
    mkdir -p $out/bin
    ln -nfs ${smtp} $out/bin/test-smtp
    ln -nfs ${imap} $out/bin/test-imap
  '';
}
