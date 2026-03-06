{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    sandnix.url = "path:../../";
  };

  outputs = { self, nixpkgs, sandnix }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      sandnixLib = import sandnix.lib { inherit pkgs; };
    in
    {
      packages.${system}.default = sandnixLib.makeSandnix {
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
