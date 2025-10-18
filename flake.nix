{
  description = "tamagotchi.nvim dev shell";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";

  outputs = { self, nixpkgs }:
  let
    forAllSystems = f:
      nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ] (system:
        f (import nixpkgs { inherit system; }));
  in
  {
    devShells = forAllSystems (pkgs:
      let
        luaPkgs = pkgs.luaPackages;
      in {
        default = pkgs.mkShell {
          buildInputs = [
            pkgs.neovim
            pkgs.lua
            pkgs.luarocks
            luaPkgs.luacheck
            luaPkgs.luaunit
            pkgs.stylua
            pkgs.git
          ];

          shellHook = ''
            echo
            echo "tamagotchi.nvim dev shell"
            echo
          '';
        };
      });
  };
}
