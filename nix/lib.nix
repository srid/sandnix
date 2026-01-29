{ pkgs, lib ? pkgs.lib, ... }:

rec {
  evalModules = { name ? "landrun", modules }: (lib.evalModules {
    modules = [
      ../modules/flake-parts/landrun/landrun.nix
      { _module.args = { inherit pkgs name; }; }
    ] ++ modules;
  });

  makeLandrun = { name, modules }: (evalModules {
    inherit name modules;
  }).config.wrappedPackage;
}
