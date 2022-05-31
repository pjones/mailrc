{ pkgs, config, lib, ... }:
let
  cfg = config.mailrc;
  mailpkgs = import ../pkgs { inherit pkgs; };

in
{
  options.mailrc = {
    enable = lib.mkEnableOption "Mail Configuration";

    sieve = {
      enable = lib.mkEnableOption "Install sieve scripts";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable && cfg.sieve.enable) {
      # Dovecot is too smart for its own good and will only traverse a
      # single symbolic link.  Therefore we need to manually link
      # files to the Nix store directly:
      home.activation.link-dovecot-sieve-files =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          $DRY_RUN_CMD rm -rf \
            "${config.xdg.configHome}/dovecot/sieve"

          $DRY_RUN_CMD mkdir -p \
            "${config.xdg.configHome}/dovecot/sieve"

          $DRY_RUN_CMD ln -nfs \
            "${mailpkgs.sieve-user}/sieve" \
            "${config.xdg.configHome}/dovecot/sieve/scripts"

          $DRY_RUN_CMD ln -nfs \
            "${mailpkgs.sieve-user}/sieve/mail.sieve" \
            "${config.xdg.configHome}/dovecot/sieve/active"
        '';
    })
  ];
}
