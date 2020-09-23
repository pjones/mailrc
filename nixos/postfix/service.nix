{ config, lib, pkgs, ... }:

################################################################################
# A function that takes a package of configuration files and returns a
# service that manages Postfix.
#
# This package must have at least two directories:
#
#   - etc: Containing master.cf, main.cf, and optionally aliases
#   - maps: Files that need to have postmap run on them
confFiles:
let
  cfg = config.mailrc;
  util = pkgs.callPackage ../util.nix { };
in
{
  systemd.services.postfix = {
    description = "Postfix Mail Server";
    wantedBy = [ "multi-user.target" ];

    wants = [
      "acme-${cfg.officialName}.service"
      "acme-selfsigned-${cfg.officialName}.service"
      "rspamd.service"
    ];

    after = [
      "acme-selfsigned-${cfg.officialName}.service"
      "rspamd.service"
      "network.target"
    ];

    serviceConfig = {
      Restart = "on-failure";
      ExecStart = "${pkgs.postfix}/bin/postfix -c ${cfg.postfixBaseDir}/etc start";
      ExecStop = "${pkgs.postfix}/bin/postfix -c ${cfg.postfixBaseDir}/etc stop";
      KillMode = "process";
      Type = "forking";
    };

    preStart = ''
      # Create directories and set permissions:
      #
      # NOTE: ignore warnings about permissions for now.  Setting
      # the correct perms prevents postfix from starting.
      #
      #   warning: not owned by root: /var/lib/postfix/queue/.
      #   warning: not owned by root: /var/lib/postfix/queue/pid
      #   warning: group or other writable: /var/lib/postfix/queue/.
      #   warning: group or other writable: /var/lib/postfix/queue/pid
      #   warning: not owned by group postdrop: /var/lib/postfix/queue/public
      #
      rm -rf ${cfg.postfixBaseDir}/etc
      mkdir -p ${cfg.postfixBaseDir}/{etc,cache,queue}
      mkdir -p /var/spool/mail
      chown -R ${cfg.postfixUser}:${cfg.postfixGroup} ${cfg.postfixBaseDir}

      chown -R ${cfg.postfixUser}:${cfg.postfixGroup} ${cfg.postfixBaseDir}/queue
      chmod -R ug+rwX ${cfg.postfixBaseDir}/queue

      # Mail spools:
      chown root:root /var/spool/mail
      chmod a+rwxt /var/spool/mail
      ln -snf /var/spool/mail /var/mail

      # Install the configuration files:
      for f in ${confFiles}/etc/* ${confFiles}/maps/*; do
        # FIXME: This would be a great place to decrypt config files.
        install -m 0440 -o ${cfg.postfixUser} -g ${cfg.postfixGroup} \
          "$f" ${cfg.postfixBaseDir}/etc/
      done

      # Process the aliases file:
      if [ -e "${cfg.postfixBaseDir}/etc/aliases" ]; then
        ${pkgs.postfix}/bin/postalias \
          -c ${cfg.postfixBaseDir}/etc \
          ${cfg.postfixBaseDir}/etc/aliases
      fi

      # Process all the map files:
      for f in ${confFiles}/maps/*; do
        ${pkgs.postfix}/bin/postmap \
          -c ${cfg.postfixBaseDir}/etc \
          ${cfg.postfixBaseDir}/etc/$(basename "$f")
      done

      # Expose this whole thing under /etc/postfix:
      ln -nfs ${cfg.postfixBaseDir}/etc /etc/postfix
    ''
    + lib.optionalString (cfg.mode == "primary")
      ("mkdir -p ${cfg.vhostDir}\n"
        + lib.concatMapStrings
        (host:
          lib.concatMapStrings
            (account: ''
              mkdir -p ${util.homeDir cfg { inherit host account; }}
            '')
            (lib.attrValues host.accounts))
        (lib.attrValues cfg.virtualhosts)
        + ''
        chown -R \
          ${toString cfg.virtualUID}:${toString cfg.virtualGID} ${cfg.vhostDir}
      '');
  };
}
