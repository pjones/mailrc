{ stdenvNoCC
, lib
, makeWrapper
, gnupg
, dovecot_pigeonhole
, mblaze
}:
let
  path = lib.makeBinPath [
    dovecot_pigeonhole
    gnupg
    mblaze
  ];

  user = import ../common/user.nix;
in
stdenvNoCC.mkDerivation {
  name = "mailrc-client-tests";
  src = ./.;
  phases = [ "unpackPhase" "installPhase" "fixupPhase" ];

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    mkdir -p "$out/bin" "$out/mail" "$out/share/scripts"
    install -m 0555 test.sh "$out/share/scripts"

    makeWrapper \
      "$out/share/scripts/test.sh" \
      "$out/bin/mailrc-tests" \
      --prefix PATH : "${path}" \
      --set TEST_ROOT "$out" \
      --set TEST_EMAIL "${user.systemUser}@${user.systemDomain}"

    for file in mail/*; do
      install -m 0444 "$file" "$out/mail/"
    done
  '';
}
