{ lib, config, pkgs, ... }:
let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  config = {
    # Auto-configure CLI options based on high-level flags
    cli = lib.mkMerge [
      # TTY support
      (lib.mkIf config.features.tty {
        rw = [
          "/dev/null"
          "/dev/tty"
        ] ++ lib.optionals (!isDarwin) [
          "/dev/pts"
          "/dev/ptmx"
        ];
        rox = [
          "/dev/zero"
          "/dev/random"
          "/dev/urandom"
          "/usr/share/terminfo"
        ] ++ lib.optionals (!isDarwin) [
          "/dev/full"
          "/etc/terminfo"
          "/etc/profile" # Shell initialization
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
        ] ++ lib.optionals (!isDarwin) [
          "/lib64"
        ] ++ lib.optionals isDarwin [
          "/bin"
        ];
        rw = [
          "$HOME/.cache/nix"
        ];
        ro = [
          "/etc/nix"
        ] ++ lib.optionals (!isDarwin) [
          "/proc/self" # Required for GC to read thread stack info
          "/proc/stat"
          "$HOME/.local/share/nix"
        ] ++ lib.optionals isDarwin [
          "/var/run/syslog" # Often needed for logging on macOS
        ];
        env = [
          "PATH" # Required for programs to find executables
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
        rwx = [ "/tmp" ] ++ lib.optionals isDarwin [ "/var/folders" ];
      })

      # D-Bus support (for keyring/Secret Service API)
      (lib.mkIf config.features.dbus {
        rw = [
          "$HOME/.local/share/keyrings" # Keyring storage
        ] ++ lib.optionals (!isDarwin) [
          "/run/user/$UID/bus" # D-Bus socket
        ];
        env = [
          "DBUS_SESSION_BUS_ADDRESS" # D-Bus session bus
          "XDG_RUNTIME_DIR" # Runtime directory
        ];
      })
    ];
  };
}
