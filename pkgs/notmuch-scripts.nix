{ stdenvNoCC
, lib
, makeWrapper
, notmuch
, mblaze
}:
let
  path = lib.makeBinPath [
    mblaze
    notmuch
  ];

in
stdenvNoCC.mkDerivation {
  name = "notmuch-scripts";
  src = ../scripts/notmuch;

  phases = [ "unpackPhase" "installPhase" "fixupPhase" ];

  nativeBuildInputs = [
    makeWrapper
  ];

  installPhase = ''
    mkdir -p "$out/bin" "$out/scripts"

    for file in *; do
      install -m 0555 "$file" "$out/scripts"

      makeWrapper \
        "$out/scripts/$(basename "$file")" \
        "$out/bin/$(basename "$file")" \
        --prefix PATH : "${path}"
    done
  '';
}
