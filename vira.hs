-- Pipeline configuration for Vira <https://vira.nixos.asia/>

\ctx ->
  let
    isMain = ctx.branch == "master"
  in
  ctx.pipeline
    { build.systems =
        [ "x86_64-linux"
        , "aarch64-darwin"
        ]
    , build.flakes =
        [ "."
        , "./examples/claude-sandboxed" { overrideInputs = [("landrun-nix", ".")] }
        , "./examples/standalone" { overrideInputs = [("landrun-nix", ".")] }
        ]
    , cache.url = if
        | isMain -> Just "https://cache.nixos.asia/oss"
        | otherwise -> Nothing
    }