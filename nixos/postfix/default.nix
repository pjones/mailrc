# Postfix configuration:
{ config, lib, pkgs, ... }:
let
  cfg = config.mailrc;
  util = pkgs.callPackage ../util.nix { };
  masterCf = import ./mastercf.nix { inherit config lib pkgs; };
  mainCf = import ./maincf.nix { inherit config lib pkgs; };

  # Aliases Files:
  aliasList = { aliases, suffix ? "" }:
    lib.concatMapStrings
      (n: "${n}${suffix}\t${lib.getAttr n aliases}\n")
      (lib.attrNames aliases);

  # Postfix Hostnames File:
  hostnamesCf = ''
    localhost 1
    ${cfg.externalServerName} 1
    ${config.networking.hostName}.${config.networking.domain} 1
  '';

  # Postfix Sender Access File:
  # FIXME: can we use just hostnames in here?
  senderAccess =
    lib.concatMapStrings
      (addr: "${addr}\tREJECT\n")
      cfg.blockedSenders;

  # Postfix virtualhosts:
  virtualHostnames =
    lib.concatMapStrings (host: "${host.name}\t1\n")
      (lib.attrValues cfg.virtualhosts);

  # Postfix virtualdirs:
  # Where to place mail for users without unix accounts.
  virtualDirs = lib.concatMapStrings
    (host: lib.concatMapStrings
      (account:
        let
          dir =
            lib.removePrefix cfg.vhostDir
              (util.homeDir cfg { inherit host account; });
        in
        "${account.username}@${host.name}\t${dir}/mail/\n")
      (lib.attrValues host.accounts))
    (lib.attrValues cfg.virtualhosts);

  # Postfix virtualaliases:
  # Aliases for virtualhosts.
  virtualAliases =
    lib.concatMapStrings
      (host: aliasList { aliases = host.aliases; suffix = "@" + host.name; })
      (lib.attrValues cfg.virtualhosts);

  # A lookup table that maps sender email addresses to authenticated
  # user names.  This prevents users from sending email from forged
  # `From:' addresses:
  senderMap =
    let
      entry = user: hostname: email:
        "${email}\t${user.username}@${hostname}\n";

      addr = user: hostname:
        "${user.username}@${hostname}";

      # Hosts have accounts:
      hostEntries = host:
        lib.concatMapStrings
          (account: accountEntry host.name account)
          (lib.attrValues host.accounts);

      # System accounts are tied to the primary host:
      systemEntries =
        lib.concatMapStrings
          (account: accountEntry cfg.externalServerName account)
          (lib.attrValues cfg.systemUsers);

      # Accounts have a primary address associated with them:
      accountEntry = hostname: account:
        entry account hostname (addr account hostname) +
        accountAliases hostname account;

      # Accounts have a list of addresses they are allowed to send from:
      accountAliases = hostname: account:
        lib.concatMapStrings
          (alias: entry account hostname alias)
          account.aliases;

    in
    lib.concatMapStrings
      hostEntries
      (lib.attrValues cfg.virtualhosts)
    + systemEntries;

  # Relay transport maps:
  transportMap =
    let entry = host: "${host}\tsmtp:${cfg.primaryMailServer}:25\n";
    in
    lib.concatMapStrings entry
      ([ cfg.primaryDomain ] ++
        (map (x: x.name) (lib.attrValues cfg.virtualhosts)));

  # Map of all email address to relay.
  relayRecipientsMap =
    let
      entry = addr: "${addr}\tOK\n";

      # Extract account names and aliases from a host:
      hostAddrs = host:
        map
          (account: "${account.username}@${host.name}")
          (lib.attrValues host.accounts)
        ++
        lib.concatMap
          (account: account.aliases)
          (lib.attrValues host.accounts);

      # Extract host aliases:
      hostAliases = host:
        map (name: "${name}@${host.name}") (lib.attrNames host.aliases);

      # Virtual account names:
      vNames = lib.concatMap hostAddrs (lib.attrValues cfg.virtualhosts);

      # Virtual host aliases:
      vAliases = lib.concatMap hostAliases (lib.attrValues cfg.virtualhosts);

    in
    lib.concatMapStrings entry
      (lib.unique (vNames ++ vAliases ++ [ "@${cfg.primaryDomain}" ]));

  ##############################################################################
  # Put the Files in the Nix Store:
  masterCfFile = pkgs.writeText "postfix-master.cf" masterCf;
  mainCfFile = pkgs.writeText "postfix-main.cf" mainCf;
  masterAliasFile = pkgs.writeText "postfix-aliases" (aliasList { aliases = cfg.aliases; suffix = ":"; });
  hostnamesCfFile = pkgs.writeText "postfix-hostnames" hostnamesCf;
  senderAccessFile = pkgs.writeText "postfix-senderaccess" senderAccess;
  virtualHostnamesFile = pkgs.writeText "postfix-virtualhosts" virtualHostnames;
  virtualDirsFile = pkgs.writeText "postfix-virtualdirs" virtualDirs;
  virtualAliasesFile = pkgs.writeText "postfix-virtualaliases" virtualAliases;
  senderMapFile = pkgs.writeText "postfix-sendermap" senderMap;
  transportMapFile = pkgs.writeText "postfix-transport" transportMap;
  relayRecipientsMapFile = pkgs.writeText "postfix-relayrecipients" relayRecipientsMap;

  ##############################################################################
  # Create a package of configuration files:
  confFiles = pkgs.stdenv.mkDerivation {
    name = "postfix-config";
    phases = [ "installPhase" ];
    installPhase = ''
      mkdir -p "$out/etc"               "$out/maps"
      ln -nfs ${masterCfFile}           "$out/etc/master.cf"
      ln -nfs ${mainCfFile}             "$out/etc/main.cf"
      ln -nfs ${masterAliasFile}        "$out/etc/aliases"
      ln -nfs ${hostnamesCfFile}        "$out/maps/hostnames"
      ln -nfs ${senderAccessFile}       "$out/maps/senderaccess"
      ln -nfs ${virtualHostnamesFile}   "$out/maps/virtualhosts"
      ln -nfs ${virtualDirsFile}        "$out/maps/virtualdirs"
      ln -nfs ${virtualAliasesFile}     "$out/maps/virtualaliases"
      ln -nfs ${senderMapFile}          "$out/maps/sendermap"
      ln -nfs ${transportMapFile}       "$out/maps/transport"
      ln -nfs ${relayRecipientsMapFile} "$out/maps/relayrecipients"
    '';
  };
in
{
  ###### Implementation
  config = lib.mkIf cfg.enable
    (lib.mkMerge [
      {
        assertions = [
          {
            assertion = config.networking.hostName != null;
            message = "mailrc requires that networking.hostName must be set";
          }
          {
            assertion = config.networking.domain != null;
            message = "mailrc requires that networking.domain be set";
          }
        ];
      }
      (import ./environment.nix { inherit config pkgs; })
      (import ./users.nix { inherit config; })
      (import ./service.nix { inherit config pkgs lib; } confFiles)
    ]);
}
