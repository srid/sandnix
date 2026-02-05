{ lib, ... }:
let
  inherit (lib)
    mkOption
    types;
in
{
  options = {
    program = mkOption {
      type = types.str;
      description = "The program to wrap with landrun (e.g., \${pkgs.foo}/bin/foo)";
    };

    features = mkOption {
      type = types.submodule {
        options = {
          tty = mkOption {
            type = types.bool;
            default = false;
            description = "Enable full TTY/terminal support for interactive applications";
          };

          nix = mkOption {
            type = types.bool;
            default = true;
            description = "Enable access to Nix store and system paths";
          };

          network = mkOption {
            type = types.bool;
            default = false;
            description = "Enable network access with DNS resolution and SSL certificates";
          };

          tmp = mkOption {
            type = types.bool;
            default = true;
            description = "Enable read-write-execute access to /tmp for temporary files";
          };

          dbus = mkOption {
            type = types.bool;
            default = false;
            description = "Enable D-Bus access for keyring and Secret Service API";
          };
        };
      };
      default = { };
      description = "High-level feature flags for common patterns";
    };

    cli = mkOption {
      type = types.submodule {
        options = {
          rox = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Paths with read-only + execute access. Non-existent paths are silently ignored.";
          };

          ro = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Paths with read-only access. Non-existent paths are silently ignored.";
          };

          rwx = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Paths with read-write-execute access";
          };

          rw = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Paths with read-write access";
          };

          env = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Environment variables to pass through";
          };

          unrestrictedNetwork = mkOption {
            type = types.bool;
            default = false;
            description = "Allow unrestricted network access";
          };

          unrestrictedFilesystem = mkOption {
            type = types.bool;
            default = false;
            description = "Allow unrestricted filesystem access";
          };

          addExec = mkOption {
            type = types.bool;
            default = true;
            description = "Automatically add executable path to --rox";
          };

          extraArgs = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Additional landrun arguments";
          };
        };
      };
      default = { };
      description = "Landrun CLI arguments configuration";
    };

    meta = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Metadata for the wrapped package";
    };

    wrappedPackage = mkOption {
      type = types.package;
      internal = true;
      description = "The resulting wrapped package (internal)";
    };
  };
}
