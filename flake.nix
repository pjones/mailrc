{
  description = "NixOS Mail Server (Postfix, Dovecot, etc.)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "i686-linux"
      ];

      # Function to generate a set based on supported systems:
      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Attribute set of nixpkgs for each system:
      nixpkgsFor = forAllSystems (system:
        import nixpkgs { inherit system; });
    in
    {
      packages = forAllSystems (system:
        import ./pkgs { pkgs = nixpkgsFor.${system}; });

      nixosModules.mailrc = import ./nixos;
      homeManagerModules.mailrc = import ./home;

      checks = forAllSystems (system:
        let pkgs = nixpkgsFor.${system}; in
        {
          # Tests:
          server = import ./test/server { inherit pkgs; };
          client = import ./test/client { inherit pkgs home-manager; };
        });

      devShell = forAllSystems
        (system:
          let pkgs = nixpkgsFor.${system}; in
          pkgs.mkShell {
            buildInputs = with pkgs; [
              postfix
              dovecot
              notmuch
            ];
            inputsFrom = builtins.attrValues self.packages.${system};
          });
    };
}
