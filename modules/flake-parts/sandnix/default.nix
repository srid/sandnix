{ lib, flake-parts-lib, ... }:
let
  inherit (flake-parts-lib)
    mkPerSystemOption;
in
{
  options = {
    perSystem = mkPerSystemOption
      ({ config, ... }: {
        imports = [ ./sandnixApps.nix ];

        config = {
          packages = lib.mapAttrs
            (name: cfg: cfg.wrappedPackage)
            config.sandnixApps;

          apps = lib.mapAttrs
            (name: cfg: {
              type = "app";
              program = lib.getExe cfg.wrappedPackage;
              meta = cfg.meta;
            })
            config.sandnixApps;
        };
      });
  };
}
