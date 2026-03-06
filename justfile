# Run the claude-sandboxed example with local sandnix override
run-example:
    nix run ./examples/claude-sandboxed --override-input sandnix .

# Run integration tests
test:
    #!/usr/bin/env bash
    if [ "$(uname)" = "Darwin" ]; then
      # macOS: BSD script syntax: script -q <output> <command>
      SCRIPT_ARGS="-q /dev/null ./tests/test.bats"
    else
      # Linux: util-linux script syntax: script -qec <command> <output>
      SCRIPT_ARGS="-qec ./tests/test.bats /dev/null"
    fi
    nix develop ./tests --override-input sandnix path:./. -c script $SCRIPT_ARGS
