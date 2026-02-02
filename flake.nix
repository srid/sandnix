{
  description = "Flake-parts module for wrapping programs with landrun sandbox";

  outputs = { self }: {
    lib = ./nix/lib.nix;

    flakeModule = ./modules/flake-parts/landrun;

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
