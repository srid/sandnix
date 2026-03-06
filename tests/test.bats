#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  # Create a temp directory for artifacts
  TEST_TEMP_DIR="$(mktemp -d)"
  cd "$TEST_TEMP_DIR"
  echo "This is a secret" > test_secret
  OS="$(uname -s)"
}
teardown() {
  # shellcheck disable=SC2164
  cd "$BATS_TEST_DIRNAME"
  rm -rf "$TEST_TEMP_DIR"
}

log_output () {
  echo "Status: $status"
  echo "Output: $output"
}

@test "test-true runs successfully" {
  run test-true
  log_output
  [ "$status" -eq 0 ]
}

@test "test-prestart-dir: creates directory before sandbox starts" {
  # The hook runs 'mkdir -p ./created_by_hook'
  # The program runs 'ls -d ./created_by_hook' implicitly via test-ls command if arguments allow,
  # but here test-prestart-dir is 'ls', so we pass the directory as argument.

  run test-prestart-dir -d ./created_by_hook
  log_output
  [ "$status" -eq 0 ]
  [ -d "created_by_hook" ]
}

@test "test-prestart-env: sets environment variable in hook" {
  # The hook runs 'export HOOK_SECRET=decrypted_value'
  # The cli.env has "HOOK_SECRET".
  # Wrapper exports the var, landrun picks it up.

  run test-prestart-env -c 'echo $HOOK_SECRET'
  log_output
  [ "$status" -eq 0 ]
  [[ "$output" == *"decrypted_value"* ]]
}

@test "test-no-nix-fail: program cannot exec if it cannot access libs from nix store" {
  run test-no-nix-fail -c "echo ok"
  log_output
  [ "$status" -ne 0 ]
}

@test "test-no-nix-ldd-ok: program can exec if libs are made accessible with --ldd flag" {
  if [ "$OS" == "Darwin" ]; then
    skip "landrun specific flag --ldd is not supported on Darwin"
  fi
  run test-no-nix-ldd-ok -c "echo ok"
  log_output
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}

@test "test-add-exec-disabled-fail: program cannot exec if not explicitly allowed" {
  run test-add-exec-disabled-fail -c "echo ok"
  log_output
  [ "$status" -ne 0 ]
}

@test "test-add-exec-disabled-ldd-ok: script can exec if not explicitly allowed but interpreter and libs are" {
  if [ "$OS" == "Darwin" ]; then
    skip "landrun specific flag --ldd is not supported on Darwin"
  fi
  run test-add-exec-disabled-ldd-ok -c "echo ok"
  log_output
  [ "$status" -eq 0 ]
  [[ "$output" == "ok" ]]
}


@test "test-extra-args: passes extra arguments to landrun" {
  if [ "$OS" == "Darwin" ]; then
    skip "landrun specific flag -v (version) is not supported on Darwin"
  fi
  # We configured test-extra-args with cli.extraArgs = [ "-v" ]
  # In landrun, -v flag prints the version and exits.
  run test-extra-args -c "echo ok"
  log_output
  [ "$status" -eq 0 ]
  [[ "$output" == *"landrun version"* ]]
}



@test "test-ls can list /tmp" {
  run test-ls /tmp
  log_output
  [ "$status" -eq 0 ]
}

@test "test-mktemp can write to /tmp" {
  run test-mktemp /tmp/test.XXXXXX
  log_output
  [ "$status" -eq 0 ]
  # Check if output looks like a path
  [[ "$output" == /tmp/test.* ]]
}

@test "test-mktemp can write to default tmp directory" {
  run test-mktemp
  log_output
  [ "$status" -eq 0 ]
  # Verify the file was actually created and is writable
  [ -f "$output" ]
  [ -w "$output" ]
  rm "$output"
}

@test "test-mktemp-no-tmp fails to write to /tmp" {
  run test-mktemp-no-tmp /tmp/test.XXXXXX
  log_output
  [ "$status" -ne 0 ]
}

@test "test-exec-tmp can execute script in /tmp" {
  # We use test-env-var (bash) as it has features.tmp = true (default)
  run test-env-var -c '
    SCRIPT=$(mktemp /tmp/test-script.XXXXXX)
    echo "#!$BASH" > "$SCRIPT"
    echo "echo executed" >> "$SCRIPT"
    chmod +x "$SCRIPT"
    "$SCRIPT"
  '
  log_output
  # This implies checking if execution is allowed.
  # If status is 0, it allowed execution.
  # If status is 126 or 1 (EPERM), it denied.
  # We expect failure currently if tmp is not rwx
  if [ "$status" -eq 0 ]; then
    echo "Execution allowed"
  else
    echo "Execution denied"
    false
  fi
}

@test "test-ls can list /nix/store" {
  run test-ls -d /nix/store
  log_output
  [ "$status" -eq 0 ]
}

@test "test-ls cannot list / (restricted by default)" {
  run test-ls /etc
  log_output
  [ "$status" -ne 0 ]
}

@test "test-tty can access terminal info" {
  # This tries to read terminal settings
  run test-tty -a
  log_output
  [ "$status" -eq 0 ]

  # This tries to set terminal settings (requires write/ioctl access)
  # using 'stty sane' which resets terminal to sane values
  run test-tty sane
  log_output
  [ "$status" -eq 0 ]
}

@test "test-curl-deny fails to connect to google.com" {
  run test-curl-deny --connect-timeout 2 https://google.com
  log_output
  [ "$status" -ne 0 ]
}

@test "test-curl-allow can connect to google.com" {
  run test-curl-allow -I https://google.com
  log_output
  [ "$status" -eq 0 ]
}

@test "test-env-var cannot access arbitrary env vars" {
  export SOME_VAR="value"
  run -127 test-env-var -c 'set -u; echo $SOME_VAR'
  log_output
  [[ "$output" = *"SOME_VAR: unbound variable"* ]]
}

@test "test-env-var inherits configured env var" {
  export MY_TEST_VAR="passed_value"
  run test-env-var -c 'set -u; echo $MY_TEST_VAR'
  log_output
  [ "$status" -eq 0 ]
  [ "$output" = "passed_value" ]
}

@test "test-read-access: can read allowed file" {
  run test-read-access -c "cat test_secret"
  log_output
  [ "$status" -eq 0 ]
  [ "$output" = "This is a secret" ]
}

@test "test-write-access: can write allowed file" {
  run test-write-access -c "echo hi > test_secret && cat test_secret"
  log_output
  [ "$status" -eq 0 ]
  [ "$output" = "hi" ]
}

@test "test-no-access: cannot read file not allowed" {
  if [[ -n $IN_NIX_SANBOX ]]; then
    skip "this test fails in nix sanbox on CI runner"
  fi
  run test-no-access -c "cat test_secret"
  log_output
  [ "$status" -ne 0 ]
  # Linux (landrun) returns "Permission denied", Darwin (sandbox-exec) returns "Operation not permitted"
  [[ "$output" == "cat: test_secret: Permission denied" || "$output" == "cat: test_secret: Operation not permitted" ]]
}

@test "test-multi-paths: respects multiple paths" {
  touch ro1 ro2 rw1 rw2 rox1 rox2 rwx1 rwx2
  chmod +x rox1 rox2 rwx1 rwx2

  # Test read-only
  run test-multi-paths -c "cat ro1 && cat ro2"
  log_output
  [ "$status" -eq 0 ]

  run test-multi-paths -c "echo fail > ro1"
  log_output
  [ "$status" -ne 0 ]

  # Test read-write
  run test-multi-paths -c "echo success > rw1 && echo success > rw2"
  log_output
  [ "$status" -eq 0 ]

  # Test read-only-execute
  run test-multi-paths -c "./rox1 && ./rox2"
  log_output
  [ "$status" -eq 0 ]

  run test-multi-paths -c "echo fail > rox1"
  log_output
  [ "$status" -ne 0 ]

  # Test read-write-execute
  run test-multi-paths -c "./rwx1 && ./rwx2"
  log_output
  [ "$status" -eq 0 ]

  run test-multi-paths -c "echo success > rwx1"
  log_output
  [ "$status" -eq 0 ]
}

@test "test-nested-paths: rw inside ro works" {
  mkdir -p parent/child
  echo "ro" > parent/file
  echo "rw" > parent/child/file

  # Read parent/file should work
  run test-nested-paths -c "cat parent/file"
  log_output
  [ "$status" -eq 0 ]

  # Write parent/file should fail
  run test-nested-paths -c "echo fail > parent/file"
  log_output
  [ "$status" -ne 0 ]

  # Write parent/child/file should work
  run test-nested-paths -c "echo success > parent/child/file"
  log_output
  [ "$status" -eq 0 ]
}

@test "test-multi-env: passes multiple variables" {
  export VAR1="value1"
  export VAR2="value2"
  run test-multi-env -c "echo \$VAR1 && echo \$VAR2"
  log_output
  [ "$status" -eq 0 ]
  [[ "$output" == *"value1"* ]]
  [[ "$output" == *"value2"* ]]
}

@test "test-special-env: passes special characters and multiline" {
  export NOT_INHERITED='abc
  --efd
  '
  export SPECIAL_VAR='line1
line2
  special !@#\$%^&*()'

  run test-special-env -c "echo \"\$SPECIAL_VAR\""
  log_output

  [ "$status" -eq 0 ]
  [ "$output" == "$SPECIAL_VAR" ]

  local expected_line_count=3
  if [ "$(wc -l <<< "$output")" -ne $expected_line_count ]; then
    echo "Error: output must contain exactly $expected_line_count lines."
    return 1
  fi
}

@test "test-unrestricted-fs: can access /" {
  run test-unrestricted-fs -c "ls -d /etc"
  log_output
  [ "$status" -eq 0 ]
}
