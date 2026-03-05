{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    landrun-nix.url = "path:../../";
  };

  outputs = inputs@{ flake-parts, landrun-nix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      imports = [ landrun-nix.flakeModule ];

      perSystem = { pkgs, system, ... }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        landrunApps.default = {
          name = "claude";
          imports = [
            landrun-nix.landrunModules.gh # So, Claude can run `gh` CLI
            landrun-nix.landrunModules.git # So, Claude can run `git` CLI
            landrun-nix.landrunModules.markitdown # So, Claude can run `markitdown` with CPU info access
            landrun-nix.landrunModules.haskell # So, Claude can use Haskell tooling
          ];
          program = "${pkgs.claude-code}/bin/claude";
          features = {
            tty = true;
            nix = true;
            network = true;
          };
          cli = {
            rw = [
              "$HOME/.claude"
              "$HOME/.claude.json"
              "$HOME/.config/gcloud"
            ];
            rwx = [ "." ];
            env = [
              "HOME" # Needed for gcloud and claude to resolve ~/ paths for config/state files
              "CLAUDE_CODE_USE_VERTEX"
              "ANTHROPIC_MODEL"
            ];
          };
        };
      };
    };
}
