{ pkgs ?
  let sources = import ../nix/sources.nix;
  in import sources.nixpkgs { }
}:
let
  sievec =
    pkgs.makeSetupHook
      {
        deps = with pkgs; [
          dovecot_pigeonhole
        ];

        substitutions = {
          shell = pkgs.runtimeShell;
        };
      } ../support/setup-hooks/sievec.sh;

  mkSieveDerivation =
    pkgs.callPackage ./mk-sieve-derivation.nix {
      inherit sievec;
    };
in
{
  dovecot-scripts = pkgs.callPackage ./dovecot-scripts.nix { };

  sieve-user = pkgs.callPackage ./sieve-user.nix {
    inherit mkSieveDerivation;
  };

  sieve-system = pkgs.callPackage ./sieve-system.nix {
    inherit mkSieveDerivation;
  };

  notmuch = pkgs.notmuch.overrideAttrs (orig: rec {
    version = "0.31";
    src = pkgs.fetchurl {
      url = "https://notmuchmail.org/releases/${orig.pname}-${version}.tar.xz";
      sha256 = "1543l57viqzqikjgfzp2abpwz3p0k2iq0b1b3wmn31lwaghs07sp";
    };
    preCheck = ''
      mkdir -p test/test-databases
      ${orig.preCheck}
    '';
  });
}
