{
  description = "tamagotchi.nvim dev shell";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs }:
  let
    forAllSystems = f:
      nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ] (system:
        f (import nixpkgs { inherit system; }));
  in
  {
    devShells = forAllSystems (pkgs:
      let
        luaPkgs = pkgs.luajitPackages;
      in {
        default = pkgs.mkShell {
          packages = [
            pkgs.neovim
            pkgs.gnumake
            pkgs.git
            pkgs.stylua
            luaPkgs.luacheck

            # scripts/test.sh runs these inside headless nvim.
            luaPkgs.busted
            luaPkgs.luassert
          ];

          shellHook = ''
            echo
            echo "tamagotchi.nvim dev shell"
            echo "  make lint    # luacheck + stylua --check"
            echo "  make test    # busted specs in headless nvim"
            echo "  make ci      # both, exactly what CI runs"
            echo
          '';
        };
      });
  };
}
