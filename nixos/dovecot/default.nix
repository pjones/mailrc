# Dovecot configuration:
{ config, lib, pkgs, ... }:
let
  cfg = config.mailrc;
  mailpkgs = import ../../pkgs { inherit pkgs; };

  ##############################################################################
  # Sieve scripts:
  sieveBinDir = "/var/lib/dovecot/pipe-bin";

  # Sieve packages to extract required extensions and plugins from:
  sievePkgs = [
    mailpkgs.sieve-system
    mailpkgs.sieve-user
  ];

  # All extensions that must be configured.
  sieveExtensions =
    lib.unique
      (lib.concatMap
        (pkg: pkg.requiredSieveExtensions)
        sievePkgs);

  # All plugins that must be enabled.
  sievePlugins =
    lib.unique
      (lib.concatMap
        (pkg: pkg.requiredSievePlugins)
        sievePkgs);

  ##############################################################################
  # Helpers:
  util = pkgs.callPackage ../util.nix { };

  ##############################################################################
  # A shell script that can generate a Dovecot password file:
  passwordFileScript = dest:
    let
      # Invoke the password script for the given host and account.
      call = host: account: ''
        ${mailpkgs.dovecot-scripts}/bin/dovecot-password-entry.sh \
          -u "${account.username}@${host.name}" \
          -p "${account.passwordFile}" \
          -U "${toString account.uid}" \
          -G "${toString account.gid}" \
          -d "${util.homeDir cfg { inherit host account; }}" \
          >> "${dest}"
      '';

      lines = [
        "rm -f ${dest}"
        "touch ${dest}"
        "chmod 0400 ${dest}"
        "chown root:root ${dest}"
      ]
      # Virtual Users:
      ++ lib.concatMap
        (host: map (call host) (lib.attrValues host.accounts))
        (lib.attrValues cfg.virtualhosts)
      # System Users:
      ++ map
        (call { name = cfg.externalServerName; })
        (lib.attrValues cfg.systemUsers);
    in
    pkgs.writeShellScript
      "gen-dovecot-passwords"
      (lib.concatStringsSep "\n" lines);

  # Final location of the password file:
  passwordsFile = "/var/lib/dovecot/passwords";
in
{
  ###### Implementation
  config = lib.mkIf (cfg.enable && cfg.mode == "primary") {

    ############################################################################
    # Push Dovecot tools into the system PATH.
    environment.systemPackages = with pkgs; [ dovecot_pigeonhole ];

    ############################################################################
    # Dovecot Configuration:
    services.dovecot2.enable = true;
    services.dovecot2.enablePAM = false;
    services.dovecot2.enableImap = true;
    services.dovecot2.enablePop3 = false;
    services.dovecot2.enableLmtp = true;
    services.dovecot2.mailUser = cfg.virtualUser;
    services.dovecot2.mailGroup = cfg.virtualGroup;
    services.dovecot2.mailLocation = "maildir:~/mail:INBOX=~/mail";
    services.dovecot2.modules = with pkgs; [ dovecot_pigeonhole ];
    services.dovecot2.sslServerCert = "${cfg.sslServerCertFile}";
    services.dovecot2.sslServerKey = "${cfg.sslServerKeyFile}";

    # Extra dovecot2 config:
    services.dovecot2.extraConfig = ''
      auth_debug = no
      mail_debug = no
      postmaster_address = postmaster@${cfg.externalServerName}

      service auth {
        unix_listener ${cfg.postfixBaseDir}/${cfg.dovecotAuthSocket} {
          mode = 0660
          user = ${cfg.postfixUser}
          group = ${cfg.postfixGroup}
        }
      }

      service lmtp {
        unix_listener ${cfg.postfixBaseDir}/${cfg.dovecotLMTPSocket} {
          mode = 0660
          user = ${cfg.postfixUser}
          group = ${cfg.postfixGroup}
        }
      }

      passdb {
        driver = passwd-file
        args = scheme=CRYPT username_format=%u ${passwordsFile}
      }

      userdb {
        driver = passwd-file
        args = username_format=%u ${passwordsFile}
      }

      protocol imap {
        mail_max_userip_connections = 10
        imap_client_workarounds = delay-newmail
        mail_plugins = $mail_plugins imap_sieve
      }

      protocol lmtp {
        mail_plugins = $mail_plugins quota sieve
      }

      namespace inbox {
        inbox = yes
        separator = /

        mailbox Drafts {
          auto = create
          special_use = \Drafts
        }
        mailbox Junk {
          auto = create
          autoexpunge = 30d
          special_use = \Junk
        }
        mailbox Trash {
          auto = create
          special_use = \Trash
          autoexpunge = 30d
        }
        mailbox Sent {
          auto = subscribe
          special_use = \Sent
        }
      }

      # Sieve configuration for rspamd:
      plugin {
        sieve = file:~/.config/dovecot/sieve/scripts;active=~/.config/dovecot/sieve/active
        sieve_plugins = ${lib.concatStringsSep " " sievePlugins}
        sieve_extensions = ${lib.concatStringsSep " " sieveExtensions}
        sieve_pipe_bin_dir = ${sieveBinDir}

        # Move from elsewhere to Spam folder
        imapsieve_mailbox1_name = Junk
        imapsieve_mailbox1_causes = COPY
        imapsieve_mailbox1_before = file:${mailpkgs.sieve-system}/sieve/learn-spam.sieve

        # Move from Spam folder to elsewhere
        imapsieve_mailbox2_name = *
        imapsieve_mailbox2_from = Junk
        imapsieve_mailbox2_causes = COPY
        imapsieve_mailbox2_before = file:${mailpkgs.sieve-system}/sieve/learn-ham.sieve
      }

      service stats {
        inet_listener http {
          port = 9166
        }
      }

      metric auth_success {
        filter = (event=auth_request_finished AND success=yes)
      }

      metric auth_failure {
        filter = (event=auth_request_finished AND NOT success=yes)
      }

      metric imap_command {
        filter = event=imap_command_finished
        group_by = cmd_name tagged_reply_state
      }

      metric smtp_command {
        filter = event=smtp_server_command_finished
        group_by = cmd_name status_code duration:exponential:1:5:10
      }

      metric mail_delivery {
        filter = event=mail_delivery_finished
        group_by = duration:exponential:1:5:10
      }
    '';

    services.dovecot2.sieveScripts = {
      before = "${mailpkgs.sieve-system}/sieve/spam.sieve";
      before2 = "${mailpkgs.sieve-system}/sieve/subaddress.sieve";
    };

    ############################################################################
    # Install some scripts that are allowed to be used from sieves:
    systemd.services.dovecot2 = {
      preStart = ''
        # Generate the password file:
        ${passwordFileScript passwordsFile}
      ''
      + ''
        # Populate the sieve bin directory:
        rm -rf ${sieveBinDir}
        mkdir -p ${sieveBinDir}
      ''
      + lib.concatMapStrings
        (pkg: ''
          for bin in ${pkg}/bin/*; do
            ln -nfs "$bin" ${sieveBinDir}/
          done
        '')
        sievePkgs;

      # Force the service to wait for the TLS cert:
      wants = [
        "acme-${cfg.officialName}.service"
        "acme-selfsigned-${cfg.officialName}.service"
      ];
      after = [
        "acme-selfsigned-${cfg.officialName}.service"
      ];
    };
  };
}
