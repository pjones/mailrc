{ pkgs, lib, ... }:


{
  ##############################################################################
  # Calculate an Account's Home Directory:
  homeDir = cfg: { host, account }:
    if account.home != null
    then account.home
    else "${cfg.vhostDir}/${host.name}/${account.username}";

}
