{ pkgs, lib ? pkgs.lib, ... }:

rec {
  evalModules = { name ? "sandnix", modules }: (lib.evalModules {
    modules = [
      ../modules/flake-parts/sandnix/sandnix.nix
      { _module.args = { inherit pkgs name; }; }
    ] ++ modules;
  });

  makeSandnix = { name, modules }: (evalModules {
    inherit name modules;
  }).config.wrappedPackage;
}
