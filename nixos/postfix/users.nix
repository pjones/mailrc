{ config, ... }:
let
  cfg = config.mailrc;
in
{
  ############################################################################
  # User accounts.
  users.users = {
    "${cfg.postfixUser}" = {
      description = "Postfix mail server user";
      uid = config.ids.uids.postfix;
      group = cfg.postfixGroup;
    };
  };

  ############################################################################
  # Groups.
  users.groups = {
    ${cfg.postfixGroup}.gid = config.ids.gids.postfix;
    ${cfg.postfixSetgidGroup}.gid = config.ids.gids.postdrop;
  };
}
