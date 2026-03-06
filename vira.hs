-- Pipeline configuration for Vira <https://vira.nixos.asia/>

\ctx pipeline ->
  let
    isMain = ctx.branch == "master"
  in
  pipeline
    { build.systems =
        [ "x86_64-linux"
        , "aarch64-darwin"
        ]
    , build.flakes =
        [ "."
        , "./examples/claude-sandboxed" { overrideInputs = [("sandnix", ".")] }
        , "./examples/standalone" { overrideInputs = [("sandnix", ".")] }
        , "./tests" { overrideInputs = [("sandnix", ".")] }
        ]
    , signoff.enable = True
    }
