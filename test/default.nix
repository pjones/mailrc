{ pkgs ?
  let sources = import ../nix/sources.nix;
  in import sources.nixpkgs { }
}:
{
  server = import ./server { inherit pkgs; };
  client = import ./client { inherit pkgs; };
}
