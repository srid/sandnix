{
  description = "Flake-parts module for wrapping programs with landrun sandbox";

  outputs = { self }: {
    lib = ./nix/lib.nix;

    flakeModule = ./modules/flake-parts/landrun;

    om.ci.default = {
      example-claude-sandboxed = {
        dir = "./examples/claude-sandboxed";
        overrideInputs.landrun-nix = self;
      };
      example-standalone = {
        dir = "./examples/standalone";
        overrideInputs.landrun-nix = self;
      };
    };

    landrunModules = {
      gh = import ./modules/landrun/gh.nix;
      git = import ./modules/landrun/git.nix;
      haskell = import ./modules/landrun/haskell.nix;
      markitdown = import ./modules/landrun/markitdown.nix;
      landrun = import ./modules/landrun/landrun.nix;
      landrunApps = import ./modules/landrun/landrunApps.nix;
    };
  };
}
