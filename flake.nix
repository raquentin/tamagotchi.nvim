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
            luaPkgs.busted
            luaPkgs.luaunit
            pkgs.stylua
            pkgs.git
          ];

          shellHook = ''
            echo
            echo "tamagotchi.nvim dev shell"
            echo "Lint:"
            echo "  luacheck lua/ plugin/"
            echo "  stylua --check .      # or: stylua .   (to format)"
            echo
            echo "tests (pick your runner):"
            echo "  # If using Busted (files like *_spec.lua):"
            echo "  busted"
            echo
            echo "  # If using LuaUnit (files like test_*.lua):"
            echo "  lua -e \"luaunit=require('luaunit'); os.exit(luaunit.LuaUnit.run())\" test/"
            echo
            echo "headless Neovim (Plenary+Busted style):"
            echo "  nvim --headless -c \"lua require('plenary.busted').run()\" -c qa"
            echo
          '';
        };
      });
  };
}
