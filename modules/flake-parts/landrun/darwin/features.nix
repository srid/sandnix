{ lib, config, pkgs, ... }:
{
  config = lib.mkIf pkgs.stdenv.isDarwin {
    cli = lib.mkMerge [
      # Nix support
      (lib.mkIf config.features.nix {
        rox = [
          "/bin"
        ];
        ro = [
          "/var/run/syslog" # Often needed for logging on macOS
        ];
      })

      # Tmp support
      (lib.mkIf config.features.tmp {
        rwx = [ "/var/folders" ];
      })
    ];
  };
}
