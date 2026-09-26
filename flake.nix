{
  description = "Codex packaged for Nix from OpenAI's official release binaries";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      packageFor = system: nixpkgs.legacyPackages.${system}.callPackage ./packages/codex.nix { };
    in
    {
      packages = forAllSystems (
        system:
        let
          codex = packageFor system;
        in
        {
          inherit codex;
          default = codex;
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.codex}/bin/codex";
          meta.description = "Run Codex";
        };
      });

      checks = forAllSystems (system: {
        codex = self.packages.${system}.codex;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      overlays.default = final: _previous: {
        codex = final.callPackage ./packages/codex.nix { };
      };

      nixosModules.default = import ./modules/nixos.nix { inherit self; };
      homeManagerModules.default = import ./modules/home-manager.nix { inherit self; };
    };
}
