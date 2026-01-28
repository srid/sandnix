{ lib, pkgs, ... }:
let
  inherit (lib)
    mkOption
    types;
in
{
  options.landrunApps = mkOption {
    type = types.attrsOf (types.submoduleWith {
      modules = [
        ./options.nix
        ./features.nix
        ./wrapper.nix
        { _module.args = { inherit pkgs; }; }
      ];
    });
    default = { };
    description = "Applications to wrap with landrun sandbox";
  };
}
