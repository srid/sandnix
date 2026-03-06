{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    sandnix.url = "path:../../";
  };

  outputs = inputs@{ flake-parts, sandnix, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];

      imports = [ sandnix.flakeModule ];

      perSystem = { pkgs, system, ... }: {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };

        sandnixApps.default = {
          name = "claude";
          imports = [
            sandnix.sandnixModules.gh # So, Claude can run `gh` CLI
            sandnix.sandnixModules.git # So, Claude can run `git` CLI
            sandnix.sandnixModules.markitdown # So, Claude can run `markitdown` with CPU info access
            sandnix.sandnixModules.haskell # So, Claude can use Haskell tooling
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

              # Known Claude Code variables
              "CLAUDE_CODE_USE_VERTEX"
              "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS"
              "ANTHROPIC_API_KEY"
              "ANTHROPIC_BASE_URL"
              "ANTHROPIC_MODEL"
            ];
          };
        };
      };
    };
}
