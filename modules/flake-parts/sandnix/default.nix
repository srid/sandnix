{ lib, flake-parts-lib, ... }:
let
  inherit (flake-parts-lib)
    mkPerSystemOption;
in
{
  options = {
    perSystem = mkPerSystemOption
      ({ config, pkgs, ... }: {
        imports = [ ./sandnixApps.nix ];

        config = {
          packages = lib.mapAttrs
            (name: cfg: cfg.wrappedPackage)
            config.sandnixApps
            // lib.optionalAttrs pkgs.stdenv.isLinux
              (lib.mapAttrs'
                (name: cfg: lib.nameValuePair "${cfg.name}-with-args" cfg.wrappedPackageWithSandboxArgs)
                config.sandnixApps);

          apps = lib.mapAttrs
            (name: cfg: {
              type = "app";
              program = lib.getExe cfg.wrappedPackage;
              meta = cfg.meta;
            })
            config.sandnixApps
            // lib.optionalAttrs pkgs.stdenv.isLinux
              (lib.mapAttrs'
                (name: cfg: {
                  name = "${cfg.name}-with-args";
                  value = {
                    type = "app";
                    program = lib.getExe cfg.wrappedPackageWithSandboxArgs;
                    meta = cfg.meta;
                  };
                })
                config.sandnixApps);
        };
      });
  };
}
