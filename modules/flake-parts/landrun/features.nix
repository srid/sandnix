{ lib, config, ... }:
{
  config = {
    # Auto-configure CLI options based on high-level flags
    cli = lib.mkMerge [
      # TTY support
      (lib.mkIf config.features.tty {
        rw = [
          "/dev/null"
          "/dev/tty"
          "/dev/pts"
          "/dev/ptmx"
        ];
        rox = [
          "/dev/zero"
          "/dev/full"
          "/dev/random"
          "/dev/urandom"
          "/etc/terminfo"
          "/etc/profile"  # Shell initialization
          "/usr/share/terminfo"
        ];
        env = [
          "TERM"
          "SHELL"
          "COLORTERM"
          "LANG"
          "LC_ALL"
        ];
      })

      # Nix support
      (lib.mkIf config.features.nix {
        rox = [
          "/nix"
          "/usr"
          "/lib"
          "/lib64"
        ];
        rw = [
          "$HOME/.cache/nix"
        ];
        ro = [
          "/proc/self"  # Required for GC to read thread stack info
          "/proc/stat"
          "/etc/nix"
          "$HOME/.local/share/nix"
        ];
        env = [
          "PATH"  # Required for programs to find executables
          "NIX_PATH"
          "NIX_SSL_CERT_FILE"
        ];
      })

      # Network support
      (lib.mkIf config.features.network {
        rox = [
          "/etc/resolv.conf"
          "/etc/ssl"
        ];
        unrestrictedNetwork = true;
      })

      # Tmp support
      (lib.mkIf config.features.tmp {
        rw = [ "/tmp" ];
      })

      # D-Bus support (for keyring/Secret Service API)
      (lib.mkIf config.features.dbus {
        rw = [
          "$HOME/.local/share/keyrings"  # Keyring storage
          "/run/user/$UID/bus"           # D-Bus socket
        ];
        env = [
          "DBUS_SESSION_BUS_ADDRESS"     # D-Bus session bus
          "XDG_RUNTIME_DIR"              # Runtime directory
        ];
      })
    ];
  };
}
