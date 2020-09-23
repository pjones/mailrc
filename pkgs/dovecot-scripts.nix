{ stdenvNoCC
}:

stdenvNoCC.mkDerivation {
  name = "dovecot-scripts";
  phases = [ "unpackPhase" "installPhase" "fixupPhase" ];
  src = ../scripts/dovecot;

  installPhase = ''
    mkdir -p "$out/bin"

    for bin in *.sh; do
      install -m 0555 "$bin" "$out/bin/"
    done
  '';
}
