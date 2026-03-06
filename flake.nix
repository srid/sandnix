{
  description = "Flake-parts module for wrapping programs with landrun sandbox";

  outputs = { self }: {
    lib = ./nix/lib.nix;

    flakeModule = ./modules/flake-parts/sandnix;

    sandnixModules = {
      gh = import ./modules/sandnix/gh.nix;
      git = import ./modules/sandnix/git.nix;
      haskell = import ./modules/sandnix/haskell.nix;
      markitdown = import ./modules/sandnix/markitdown.nix;
      sandnix = ./modules/flake-parts/sandnix/sandnix.nix;
      sandnixApps = ./modules/flake-parts/sandnix/sandnixApps.nix;
    };
  };
}
