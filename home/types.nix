{ lib, pkgs, ... }:
let
  initialTagsType = { config, ... }: {
    options = {
      add = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Tags to add";
      };

      remove = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Tags to remove";
      };

      query = lib.mkOption {
        type = lib.types.str;
        description = "Query to run";
      };
    };

    config = {
      # FIXME:
      # assertions = [
      #   {
      #     assertion = config.add == [ ] && config.remove == [ ];
      #     message = "Must either add tags or remove tags";
      #   }
      # ];
    };
  };

  # A function to generate the initial tagging file:
  mkInitialTagFile = lines:
    let
      plus = tag: "+${tag}";
      minus = tag: "-${tag}";
    in
    (lib.concatMapStringsSep "\n"
      (line:
        lib.concatStringsSep " " [
          (lib.concatStringsSep " "
            (map plus line.add
            ++ map minus line.remove))
          "--"
          line.query
        ])
      lines) + "\n";

  # A function that knows how to encode the strange Notmuch values.
  #
  # Adapted from https://github.com/nix-community/home-manager/
  mkNotmuchIniKeyValue = key: value:
    let
      tweakVal = v:
        if builtins.isString v then
          v
        else if builtins.isList v then
          lib.concatMapStringsSep ";" tweakVal v
        else if builtins.isBool v then
          (if v then "true" else "false")
        else
          builtins.toString v;
    in
    "${key}=${tweakVal value}";
in
{
  tags = {
    type = lib.types.submodule initialTagsType;
    toString = mkInitialTagFile;
  };

  notmuchIni = {
    type = lib.types.attrs;
    toString = lib.generators.toINI { mkKeyValue = mkNotmuchIniKeyValue; };
  };
}
