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
  notmuch-scripts = pkgs.callPackage ./notmuch-scripts.nix { };

  sieve-user = pkgs.callPackage ./sieve-user.nix {
    inherit mkSieveDerivation;
  };

  sieve-system = pkgs.callPackage ./sieve-system.nix {
    inherit mkSieveDerivation;
  };
}
