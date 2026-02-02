-- Pipeline configuration for Vira <https://vira.nixos.asia/>

\ctx pipeline ->
  let
    isMain = ctx.branch == "master"
  in
  pipeline
    { build.systems =
        [ "x86_64-linux"
        ]
    , build.flakes =
        [ "."
        , "./examples/claude-sandboxed" { overrideInputs = [("landrun-nix", ".")] }
        , "./examples/standalone" { overrideInputs = [("landrun-nix", ".")] }
        , "./tests" { overrideInputs = [("landrun-nix", ".")] }
        ]
    , signoff.enable = True
    }
