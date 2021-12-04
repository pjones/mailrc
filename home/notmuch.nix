{ config, lib, ... }:
let
  ##############################################################################
  addrs = import ./addresses.nix { };
  allAddrs = [ addrs.primary ] ++ addrs.secondary;

  ##############################################################################
  ini = {
    database = {
      path = "${config.home.homeDirectory}/mail";
      hook_dir = "${config.xdg.dataHome}/notmuch/hooks";
    };

    user = {
      name = "Peter J. Jones";
      primary_email = addrs.primary;
      other_email = addrs.secondary;
    };

    new = {
      tags = [ "new" ];
      ignore = [ ];
    };

    search = {
      exclude_tags = [ "deleted" "spam" ];
    };

    maildir = {
      synchronize_flags = true;
    };

    index = {
      decrypt = false;
    };
  };

  ##############################################################################
  qOr = lib.concatMapStringsSep " or " (s: "( ${s} )");
  qAnd = lib.concatMapStringsSep " and " (s: "( ${s} )");

  ##############################################################################
  mkFolderRule = folder: tag: {
    add = [ tag ];
    remove = [ "new" "unread" ];
    query = qAnd [ "folder:.${folder}" "tag:new" ];
  };

  ##############################################################################
  mkMailingList = to: tag: {
    add = [ "mailing-list" tag ];
    query = qAnd [ "to:${to}" "tag:new" ];
  };

  ##############################################################################
  postNewTags = [
    # New messages in certain folders need default tags:
    (mkFolderRule "Junk" "spam")
    (mkFolderRule "Trash" "deleted")
    (mkFolderRule "Sent" "sent")
    (mkFolderRule "Archive" "archived")

    # Mailing lists:
    (mkMailingList "notmuch@notmuchmail.org" "notmuch")
    (mkMailingList "haskell-cafe@haskell.org" "haskell-cafe")

    # Message from me should be tagged as such so they can be moved
    # to the sent folder if necessary:
    {
      add = [ "from-me" ];
      query =
        let fromMe = (qOr (map (addr: "from:${addr}") allAddrs));
        in qAnd [ fromMe "tag:new" ];
    }

    # Messages to me should also be flagged.
    {
      add = [ "to-me" ];
      query =
        let toMe = (qOr (map (addr: "to:${addr}") allAddrs));
        in qAnd [ toMe "tag:new" ];
    }

    # Final rule, remove the "new" tag.
    { remove = [ "new" ]; query = "tag:new"; }
  ];

in
{
  mailrc.notmuch = {
    inherit ini postNewTags;
  };
}
