{
  description = "Yandex Browser for NixOS";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
  in {
    packages.${system} = {
      yandex-browser = pkgs.callPackage ./package.nix {};
      default = self.packages.${system}.yandex-browser;
    };

    overlays.default = final: prev: {
      yandex-browser = final.callPackage ./package.nix {};
    };
  };
}
