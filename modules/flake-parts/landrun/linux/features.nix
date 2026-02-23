{ lib, config, pkgs, ... }:
{
  config = lib.mkIf (!pkgs.stdenv.isDarwin) {
    # Auto-configure CLI options based on high-level flags
    cli = lib.mkMerge [
      # TTY support
      (lib.mkIf config.features.tty {
        rw = [
          "/dev/pts"
          "/dev/ptmx"
        ];
        rox = [
          "/dev/full"
          "/etc/terminfo"
          "/etc/profile" # Shell initialization
        ];
      })

      # Nix support
      (lib.mkIf config.features.nix {
        rox = [
          "/lib64"
        ];
        ro = [
          "/proc/self" # Required for GC to read thread stack info
          "/proc/stat"
          "$HOME/.local/share/nix"
        ];
      })

      # D-Bus support (for keyring/Secret Service API)
      (lib.mkIf config.features.dbus {
        rw = [
          "/run/user/$UID/bus" # D-Bus socket
        ];
      })
    ];
  };
}
