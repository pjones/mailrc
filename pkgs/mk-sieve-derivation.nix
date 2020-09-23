{ stdenvNoCC
, lib
, writeText
, sievec
, makeWrapper
}:

{
  # List of packages to put in script PATH:
  path

  # List of required sieve extensions:
, extensions

  # List of required sieve plugins:
, plugins

  # Source:
, src

  # Package name:
, name
}@args:
let
  config = writeText "sieve.conf" ''
    plugin {
      sieve_plugins = ${lib.concatStringsSep " " plugins}
      sieve_global_extensions = ${lib.concatStringsSep " " extensions}
      sieve_extensions = ${lib.concatStringsSep " " extensions}
    }
  '';

in
stdenvNoCC.mkDerivation {
  inherit name src;

  phases = [ "unpackPhase" "installPhase" "fixupPhase" ];

  nativeBuildInputs = [
    makeWrapper
    sievec
  ];

  passthru = {
    # Plugins that must be enabled:
    requiredSievePlugins = plugins;

    # Extensions that must be enabled:
    requiredSieveExtensions = extensions;
  };

  installPhase = ''
    mkdir -p "$out/bin" "$out/sieve" "$out/share/scripts"
    installSieveScripts "$out" "${config}"
    installSieveShellScripts "$out" "${lib.makeBinPath path}"
  '';
}
