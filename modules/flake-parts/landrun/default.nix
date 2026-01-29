{ lib, flake-parts-lib, ... }:
let
  inherit (flake-parts-lib)
    mkPerSystemOption;
in
{
  options = {
    perSystem = mkPerSystemOption
      ({ config, ... }: {
        imports = [ ./landrunApps.nix ];

        config = {
          packages = lib.mapAttrs
            (name: cfg: cfg.wrappedPackage)
            config.landrunApps;

          apps = lib.mapAttrs
            (name: cfg: {
              type = "app";
              program = "${cfg.wrappedPackage}/bin/${name}";
              meta = cfg.meta;
            })
            config.landrunApps;
        };
      });
  };
}
