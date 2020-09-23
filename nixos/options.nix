{ config, lib, pkgs, ... }:
let
  ##############################################################################
  cfg = config.mailrc;

  ##############################################################################
  # Virtual Mail Accounts:
  accountOpts = { name, ... }: {
    options = {
      username = lib.mkOption {
        type = lib.types.str;
        example = "jdoe";
        description = ''
          Account username and local part of the email address.
        '';
      };

      aliases = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "joe@host.com" ];
        description = "Additional addresses this user is allowed to use.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.path;
        example = "/run/secrets/account-password-file";
        description = ''
          Path to a file that contains the account's hashed password.
          The contents of the file should look something like:

          {SSHA}XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
        '';
      };

      home = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "/home/jdoe";
        description = "Home directory.  Defaults to virtual home.";
      };

      uid = lib.mkOption {
        type = lib.types.int;
        default = cfg.virtualUID;
        example = 1000;
        description = "UID for file permissions.  Defaults to virtual UID.";
      };

      gid = lib.mkOption {
        type = lib.types.int;
        default = cfg.virtualGID;
        example = 1000;
        description = "GID for file permissions.  Defaults to virtual GID.";
      };
    };

    config = {
      username = lib.mkDefault name;
    };
  };

  ##############################################################################
  # Virtual Host Configuration:
  hostOpts = { name, ... }: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        example = "example.com";
        description = "FQDN of the host.";
      };

      aliases = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          john = "jdoe";
        };
        description = "List of virtual aliases.";
      };

      accounts = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule accountOpts);
        default = { };
        example = {
          jdoe = {
            passwordFile = "/run/secrets/jdoe";
          };
        };
      };
    };

    config = {
      name = lib.mkDefault name;
    };
  };

in
{
  ###### Interface
  options.mailrc = {

    ##########################################################################
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the full mail stack";
    };

    ##########################################################################
    mode = lib.mkOption {
      type = lib.types.enum [ "primary" "secondary" ];
      default = "primary";

      description = ''
        Mail server mode.

        primary: Final endpoint for mail with virtual users and IMAP.

        secondary: Backup MX host.  No IMAP.
      '';
    };

    ##########################################################################
    externalServerName = lib.mkOption {
      type = lib.types.str;
      default = "pmade.com";
      example = "pmade.com";
      description = "Local users must be configured for this domain.";
    };

    ##########################################################################
    primaryDomain = lib.mkOption {
      type = lib.types.str;
      default = "pmade.com";
      description = "The main domain for relay hosts.";
    };

    ##########################################################################
    officialName = lib.mkOption {
      type = lib.types.str;
      default = "mail.pmade.com";
      description = "FQDN used in SSL certs, etc.";
    };

    ##########################################################################
    primaryMailServer = lib.mkOption {
      type = lib.types.str;
      default = "mail.pmade.com";
      description = "For mail relays, where to send mail.";
    };

    ##########################################################################
    postfixBaseDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/postfix";
      example = "/var/lib/postfix";
      description = "Base directory where postfix files are stored.";
    };

    ##########################################################################
    aliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        root = "jdoe";
        postmaster = "root";
      };
      description = "Entries for the master aliases file.";
    };

    ##########################################################################
    blockedSenders = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "foo@example.com" ];
      description = ''
        List of sender address to immediately reject.
        See http://www.postfix.org/access.5.html
      '';
    };

    ##########################################################################
    trustedRelayServers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "192.168.1.2" ];
      description = "IP addresses that Postfix should trust as a relay.";
    };

    ##########################################################################
    systemUsers = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule accountOpts);
      default = { };
      example = {
        jdoe = {
          passwordFile = "/run/secrets/jdoe";
          home = "/home/jdoe";
        };
      };
    };

    ##########################################################################
    virtualhosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule hostOpts);
      default = { };
      example = {
        "example.com" = {
          accounts.jdoe.passwordFile = "/run/secrets/jdoe";
          aliases.john = "jdoe";
        };
      };
    };

    ##########################################################################
    postfixUser = lib.mkOption {
      type = lib.types.str;
      default = "postfix";
      example = "postfix";
      description = "The username used for the Postfix mail server.";
    };

    ##########################################################################
    postfixGroup = lib.mkOption {
      type = lib.types.str;
      default = cfg.postfixUser;
      example = "postfix";
      description = "The group name used for the Postfix mail server.";
    };

    ##########################################################################
    postfixSetgidGroup = lib.mkOption {
      type = lib.types.str;
      default = "postdrop";
      example = "postdrop";
      description = "Name of the setgid Postfix group.";
    };

    ##########################################################################
    vhostDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/virtmail";
      example = "/var/lib/virtmail";
      description = "The directory where virtual mail users live.";
    };

    ##########################################################################
    virtualUser = lib.mkOption {
      type = lib.types.str;
      default = "vmail";
      example = "vmail";
      description = "The username used for the virtualhosts accounts.";
    };

    ##########################################################################
    virtualGroup = lib.mkOption {
      type = lib.types.str;
      default = cfg.virtualUser;
      example = "vmail";
      description = "The group name used for the virtualhosts accounts.";
    };

    ##########################################################################
    virtualUID = lib.mkOption {
      type = lib.types.int;
      default = 5000;
      example = 5000;
      description = "The UID used for virtualhost accounts.";
    };

    ##########################################################################
    virtualGID = lib.mkOption {
      type = lib.types.int;
      default = cfg.virtualUID;
      example = 5000;
      description = "The GID used for virtualhost accounts.";
    };

    ##########################################################################
    dovecotAuthSocket = lib.mkOption {
      type = lib.types.str;
      default = "dovecot-auth";
      description = "The name of the dovecot auth socket.";
    };

    ##########################################################################
    dovecotLMTPSocket = lib.mkOption {
      type = lib.types.str;
      default = "dovecot-lmtp";
      description = "The name of the Dovecot LMTP socket.";
    };

    ##########################################################################
    rspamdMilterPort = lib.mkOption {
      type = lib.types.int;
      default = 11332;
      description = "The port number for the rspamd proxy worker.";
    };

    ##########################################################################
    sslServerKeyFile = lib.mkOption {
      type = lib.types.path;
      default = "${config.security.acme.certs.${cfg.officialName}.directory}/key.pem";
      description = "Path to the SSL key file.";
    };

    ##########################################################################
    sslServerCertFile = lib.mkOption {
      type = lib.types.path;
      default = "${config.security.acme.certs.${cfg.officialName}.directory}/fullchain.pem";
      description = "Path to the SSL cert file.";
    };
  };
}
