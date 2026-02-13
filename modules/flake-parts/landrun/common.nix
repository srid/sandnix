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
        ];
        rox = [
          "/dev/zero"
          "/dev/random"
          "/dev/urandom"
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
        ];
        rw = [
          "$HOME/.cache/nix"
        ];
        ro = [
          "/etc/nix"
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
        rwx = [ "/tmp" ];
      })

      # D-Bus support (for keyring/Secret Service API)
      (lib.mkIf config.features.dbus {
        rw = [
          "$HOME/.local/share/keyrings" # Keyring storage
        ];
        env = [
          "DBUS_SESSION_BUS_ADDRESS" # D-Bus session bus
          "XDG_RUNTIME_DIR" # Runtime directory
        ];
      })
    ];
  };
}
