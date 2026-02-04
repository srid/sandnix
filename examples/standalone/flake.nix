{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    landrun-nix.url = "path:../../";
  };

  outputs = { self, nixpkgs, landrun-nix }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      landrunLib = import landrun-nix.lib { inherit pkgs; };
    in
    {
      packages.${system}.default = landrunLib.makeLandrun {
        name = "hello-wrapped";
        modules = [
          {
            program = "${pkgs.hello}/bin/hello";
            features.tty = true;
          }
        ];
      };
    };
}
