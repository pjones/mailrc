{ pkgs, config, lib, ... }:
let
  cfg = config.mailrc;
  types = import ./types.nix { inherit lib pkgs; };
  mailpkgs = import ../pkgs { inherit pkgs; };

  mkHookScript = name: lines: {
    "${cfg.notmuch.ini.database.path}/.notmuch/hooks/${name}".source =
      pkgs.writeShellScript "notmuch-${name}-hook" ''
        export PATH=${lib.makeBinPath cfg.notmuch.packages}''${PATH:+:}$PATH
        ${lines}
      '';
  };

  # Generate a call to `notmuch tag` using the given list of tag commands.
  notmuchTagCmd = name: tagList:
    let tagFile = pkgs.writeText name (types.tags.toString tagList);
    in "notmuch tag --batch --input=${tagFile}";

in
{
  imports = [
    ./notmuch.nix
  ];

  options.mailrc = {
    enable = lib.mkEnableOption "Mail Configuration";

    notmuch = {
      ini = lib.mkOption {
        type = types.notmuchIni.type;
        default = { };
        description = "Notmuch INI config as an attrset.";
      };

      postNewTags = lib.mkOption {
        type = lib.types.listOf types.tags.type;
        default = [ ];
        description = "List of tag assignments for the post-new hook.";
      };

      postNewScript = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Commands to run in the post-new hook";
      };

      postInsertTags = lib.mkOption {
        type = lib.types.listOf types.tags.type;
        default = [ ];
        description = "List of tag assignments for the post-insert hook.";
      };

      postInsertScript = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Commands to run in the post-insert hook";
      };

      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [
          mailpkgs.notmuch
          pkgs.muchsync
          pkgs.mblaze
        ];
        description = ''
          List of packages to put in PATH for all hook scripts.
        '';
      };
    };

    sieve = {
      enable = lib.mkEnableOption "Install sieve scripts";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      home.packages = cfg.notmuch.packages;

      home.file = {
        ".notmuch-config".text = types.notmuchIni.toString cfg.notmuch.ini;
      }
      // lib.optionalAttrs
        (cfg.notmuch.postInsertTags != [ ]
          || cfg.notmuch.postInsertScript != "")
        (mkHookScript "post-insert" ''
          ${notmuchTagCmd "post-insert-tags" cfg.notmuch.postInsertTags}
          ${cfg.notmuch.postNewScript}
        '')
      // lib.optionalAttrs
        (cfg.notmuch.postNewTags != [ ]
          || cfg.notmuch.postNewScript != "")
        (mkHookScript "post-new" ''
          ${notmuchTagCmd "post-new-tags" cfg.notmuch.postNewTags}
          ${cfg.notmuch.postInsertScript}
        '');
    })

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
