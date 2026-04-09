[![GitHub Discussions](https://img.shields.io/github/discussions/srid/sandnix)](https://github.com/srid/sandnix/discussions)

# sandnix

A Nix flake-parts module for wrapping programs with a sandboxed environment using [landrun](https://github.com/Zouuup/landrun) (Landlock) on Linux, and `sandbox-exec` on macOS.

## Usage

In your `flake.nix`:

```nix
{
  inputs.sandnix.url = "github:srid/sandnix";

  outputs = { flake-parts, sandnix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ sandnix.flakeModule ];

      perSystem = { pkgs, ... }: {
        sandnixApps.my-app-sandboxed = {
          program = "${pkgs.my-app}/bin/my-app";
          features = {
            tty = true;      # Terminal support
            nix = true;      # Nix store access (default)
            network = true;  # Network access
            tmp = true;      # /tmp access (default)
          };
          # Raw arguments to pass to `landrun` CLI
          cli = {
            rw = [ "$HOME/.config/my-app" ];
            rox = [ "/etc/hosts" ];
          };
        };
      };
    };
}
```

Run with: `nix run .#my-app-sandboxed`

## Reusable Modules

sandnix provides reusable modules for common applications via `sandnixModules.*`. These can be imported into your app configurations:

```nix
{
  inputs.sandnix.url = "github:srid/sandnix";

  outputs = { flake-parts, sandnix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ sandnix.flakeModule ];

      perSystem = { pkgs, ... }: {
        sandnixApps.my-app = {
          imports = [
            sandnix.sandnixModules.gh  # Import GitHub CLI module
          ];
          program = "${pkgs.my-app}/bin/my-app";
          features.network = true;
        };
      };
    };
}
```

### Available Modules

| Module | Description |
|--------|-------------|
| `sandnixModules.gh` | GitHub CLI (`gh`) configuration with D-Bus keyring support |
| `sandnixModules.git` | Git configuration with TTY support and repository access |
| `sandnixModules.haskell` | Haskell tooling with Cabal configuration and state directory access |
| `sandnixModules.markitdown` | Markitdown configuration with `/proc/cpuinfo` access |

## Examples

### Claude Code

Sandbox [Claude Code](https://claude.ai/code) with access to project directory, config files, and network.

See [examples/claude-sandboxed](./examples/claude-sandboxed/flake.nix) for a complete working example.

Try it: 

```sh
nix run 'github:srid/sandnix?dir=examples/claude-sandboxed'
```

## Features

High-level feature flags automatically configure common sandboxing patterns:

| Feature | Default | Description |
|---------|---------|-------------|
| `features.tty` | `false` | TTY devices, terminfo, locale env vars |
| `features.nix` | `true` | Nix store, system paths, PATH env var |
| `features.network` | `false` | DNS resolution, SSL certificates, unrestricted network |
| `features.tmp` | `true` | Read-write access to /tmp |
| `features.dbus` | `false` | D-Bus session bus, keyring access for Secret Service API |

## CLI Options

Fine-grained control via `cli.*`:

| Option | Description |
|--------|-------------|
| `rox` | Read-only + execute paths |
| `ro` | Read-only paths |
| `rwx` | Read-write-execute paths |
| `rw` | Read-write paths |
| `env` | Environment variables to pass through |
| `unrestrictedNetwork` | Allow all network access |
| `addExec` | Auto-add executable to rox (default: true) |

### Dynamic Sandbox Arguments (Linux Only)

On Linux, sandnix generates an alternative binary variant named `<name>-with-args`. This variant allows you to dynamically pass sandbox configuration arguments directly to the underlying `landrun` executable at runtime.

When using this variant, arguments passed *before* a `--` separator are provided to `landrun`, while all arguments *after* the `--` separator are passed to the wrapped program. If no `--` is provided, all arguments are passed to `landrun`.

**Example:**
```sh
nix run .#my-app-sandboxed-with-args -- --rw /my/dynamic/path -- arg1 arg2
```

**Important:** In scripts or wrappers that may provide program arguments dynamically, you should always explicitly include the `--` separator. This ensures that a `--` meant for the wrapped program (or a wrapper within it) is not misinterpreted by the sandnix wrapper as the delimiter for sandbox arguments.

## Discussions

https://github.com/srid/sandnix/discussions

## License

GPL-3.0

## Similar projects

- [nixpak](https://github.com/nixpak/nixpak): a fancy declarative wrapper around bubblewrap.
- [jail.nix](https://sr.ht/~alexdavid/jail.nix/): helper to make it easy and ergonomic to wrap your derivations in bubblewrap.

