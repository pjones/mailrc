{ pkgs, config, lib, ... }:
let
  cfg = config.mailrc;
  types = import ./types.nix { inherit lib pkgs; };
  mailpkgs = import ../pkgs { inherit pkgs; };

  # Return the full path to the given hook file.
  hookFile = name: "${cfg.notmuch.ini.database.hook_dir}/${name}";

  mkHookScript = name: lines: {
    ${hookFile name}.source =
      pkgs.writeShellScript "notmuch-${name}-hook" ''
        export PATH=${lib.makeBinPath cfg.notmuch.packages}''${PATH:+:}$PATH
        ${lines}
      '';
  };

  # Generate a call to `notmuch tag` using the given list of tag commands.
  notmuchTagCmd = name: tagList:
    let tagFile = pkgs.writeText name (types.tags.toString tagList);
    in "notmuch tag --batch --input=${tagFile}";

  # The notmuch configuration file:
  notmuchConfig = pkgs.writeText "notmuch-config"
    (types.notmuchIni.toString cfg.notmuch.ini);
in
{
  imports = [
    ./notmuch.nix
    ./muchsync.nix
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
          pkgs.notmuch
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
      home.packages =
        cfg.notmuch.packages
        ++ [ mailpkgs.notmuch-scripts ];

      home.file = {
        ".notmuch-config".source = notmuchConfig;

        ${hookFile "x-post-tag"}.source =
          "${mailpkgs.notmuch-scripts}/bin/notmuch-post-tag-hook";
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

      # Ensure we have a notmuch database path and database otherwise
      # we won't be able to insert new messages.
      home.activation.bootstrap-notmuch =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ ! -d "${cfg.notmuch.ini.database.path}" ]; then
            $DRY_RUN_CMD mkdir -p "${cfg.notmuch.ini.database.path}"
          fi

          if [ ! -d "${cfg.notmuch.ini.database.path}/.notmuch" ]; then
            $DRY_RUN_CMD env NOTMUCH_CONFIG=${notmuchConfig} \
              ${pkgs.notmuch}/bin/notmuch new
          fi
        '';
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
