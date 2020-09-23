# A complete mail stack (Postfix, Dovecot, Spam Filtering, and OpenDKIM).
{ config, lib, pkgs, ... }:
let
  cfg = config.mailrc;
in
{
  ###### Other Modules
  imports = [
    ./dovecot
    ./opendkim
    ./options.nix
    ./postfix
    ./rspamd
  ];

  ###### Implementation
  config = lib.mkIf cfg.enable {

    ############################################################################
    # Open firewall ports for the services.
    networking.firewall.allowedTCPPorts =
      [ 25 ]
      ++ lib.optionals (cfg.mode == "primary") [ 465 993 ];

    ############################################################################
    # SSL/TLS certificates.
    security.acme.certs = {
      ${cfg.officialName} = {
        postRun = ''
          systemctl restart postfix.service
          systemctl restart dovecot2.service
        '';
      };
    };

    ############################################################################
    # Run a DNS caching server.
    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = true;
      servers = [ "1.1.1.1" "8.8.8.8" "8.8.4.4" ];

      extraConfig = ''
        expand-hosts
        domain-needed
        domain=${cfg.externalServerName}
      '';
    };

    ############################################################################
    # Monitoring:
    services.prometheus = {
      exporters.dovecot = {
        enable = true;
        scopes = [ "user" "global" ];
        socketPath = "/var/run/dovecot2/old-stats";
      };

      exporters.postfix = {
        enable = true;
        showqPath = "/var/lib/postfix/queue/public/showq";
        systemd.enable = true;
        group = "postfix";
      };

      exporters.rspamd = { enable = true; };
    };
  };
}
