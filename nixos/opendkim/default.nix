################################################################################
# My own custom module for OpenDKIM.
{ config, lib, pkgs, ... }:
let
  cfg = config.mailrc.opendkim;
  defaultUser = "opendkim";

  # The name of the TXT resource record type.
  mkResourceName = host: "${host.selector}._domainkey.${host.signingDomain}";

  # Entries in the SigningTable.
  mkSigningTable = hosts:
    lib.concatMapStrings
      (h: lib.concatMapStrings
        (a: "${a} ${mkResourceName h}\n")
        h.addressWildcards)
      hosts;

  signingTableFile = pkgs.writeTextFile {
    name = "sigtable";
    text = mkSigningTable (lib.attrValues cfg.hosts);
  };

  # Entries in the KeyTable.
  mkKeyTable = hosts:
    lib.concatMapStrings
      (host:
        "${mkResourceName host} "
        + lib.concatStringsSep ":" [
          host.signingDomain
          host.selector
          host.privateKeyFile
        ]
        + "\n")
      hosts;

  keyTableFile = pkgs.writeTextFile {
    name = "keytable";
    text = mkKeyTable (lib.attrValues cfg.hosts);
  };

  # Entries in the TrustedHosts file.
  mkTrustedHosts = confOpts:
    lib.concatStringsSep "\n" confOpts.extraTrustedHosts +
    "\n" + lib.concatMapStrings (h: "${h.signingDomain}\n")
      (lib.attrValues confOpts.hosts);

  trustedHostsFile = pkgs.writeTextFile {
    name = "trustedhosts";
    text = mkTrustedHosts cfg;
  };

  # The configuration file.
  mkOpenDKIMConf = confOpts: ''
    AutoRestart             No
    Syslog                  Yes
    SyslogSuccess           Yes
    LogWhy                  Yes
    LogResults              Yes

    UMask                   002
    Socket                  inet:${toString confOpts.port}@${confOpts.interface}

    Canonicalization        relaxed/simple
    Mode                    sv

    OversignHeaders         From
    AlwaysAddARHeader       Yes

    SignatureAlgorithm      rsa-sha256
    ExternalIgnoreList      refile:${trustedHostsFile}
    InternalHosts           refile:${trustedHostsFile}
    KeyTable                refile:${keyTableFile}
    SigningTable            refile:${signingTableFile}

    ${confOpts.extraConf}
  '';

  openDKIMConfFile = pkgs.writeTextFile {
    name = "opendkim.conf";
    text = mkOpenDKIMConf cfg;
  };

  # Host configuration.
  hostOpts = { name, ... }: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        example = "example.com";
        description = "Name of the host.";
      };

      addressWildcards = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        example = [ "*@example.com" ];
        description = ''
          Wildcard patterns that are matched against the address found
          in the `From:' header field.
        '';
      };

      signingDomain = lib.mkOption {
        type = lib.types.str;
        example = "example.com";
        description = ''
          The name of the domain to use in the signature's `d=' value.

          A signature verifying server would use this value along with
          the `selector' value to figure out which DNS record to
          fetch.

          For example: selector._domainkey.signingDomain
        '';
      };

      selector = lib.mkOption {
        type = lib.types.str;
        example = "20150303";
        description = ''
          The name of the selector to use in the signature's `s=' value.

          A signature verifying server would use this value along with
          the `signingDomain' value to figure out which DNS record to
          fetch.

          For example: selector._domainkey.signingDomain
        '';
      };

      privateKeyFile = lib.mkOption {
        type = lib.types.path;
        description = ''
          Path to the RSA private key used for signing.
        '';
      };
    };

    config = {
      name = lib.mkDefault name;
    };
  };

in
{
  ###### Interface
  options.mailrc.opendkim = {
    enable = lib.mkEnableOption "Whether to run the OpenDKIM server";

    user = lib.mkOption {
      default = defaultUser;
      example = "john";
      type = lib.types.str;
      description = ''
        The name of an existing user account to use to own the
        OpenDKIM server process.  If not specified, a default user
        will be created to own the process.
      '';
    };

    interface = lib.mkOption {
      default = "127.0.0.1";
      example = "127.0.0.1";
      type = lib.types.str;
      description = ''
        The interface the OpenDKIM deamon will be listening to.  If
        `127.0.0.1', only clients on the local host can connect to
        it; if `0.0.0.0', clients can access it from any network
        interface.
      '';
    };

    port = lib.mkOption {
      default = 12301;
      example = 12301;
      type = lib.types.int;
      description = ''
        Specifies the port on which to listen.
      '';
    };

    extraTrustedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1" "localhost" "::1" ];
      example = [ "127.0.0.1" "localhost" "::1" ];
      description = ''
        Identifies an extra set internal hosts whose mail should be signed
        rather than verified.
      '';
    };

    extraConf = lib.mkOption {
      default = "";
      type = lib.types.lines;
      description = ''
        Extra config to add to the bottom of the `opendkim.conf' file.
      '';
    };

    hosts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule hostOpts);
      default = { };
      description = "The configuration for each host to sign mail for.";
      example =
        {
          "example.com" = {
            addressWildcard = "*@example.com";
            signingDomain = "example.com";
            selector = "20150303";
            privateKeyFile = "/run/secrets/example.com.pem";
          };
        };
    };
  };

  ###### Implementation
  config = lib.mkIf cfg.enable {
    systemd.services.opendkim = {
      description = "OpenDKIM Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.service" ];

      serviceConfig = {
        Restart = "on-failure";
        ExecStart = "${pkgs.opendkim}/bin/opendkim -f -x ${openDKIMConfFile}";
        User = cfg.user;
        Group = cfg.user;
        RuntimeDirectory = "opendkim";
      };
    };

    users.users = lib.optionalAttrs (cfg.user == defaultUser) {
      ${defaultUser} = {
        description = "OpenDKIM server daemon owner";
        group = defaultUser;
        uid = config.ids.uids.opendkim;
      };
    };

    users.groups = lib.optionalAttrs (cfg.user == defaultUser) {
      ${defaultUser} = {
        gid = config.ids.gids.opendkim;
        members = [ defaultUser ];
      };
    };
  };
}
