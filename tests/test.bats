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

@test "test-ls can list /nix/store" {
  run test-ls -d /nix/store
  log_output
  [ "$status" -eq 0 ]
}

@test "test-ls cannot list / (restricted by default)" {
  run test-ls /
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
  export SPECIAL_VAR="line1
line2
special !@#\$%^&*()"
  run test-special-env -c "echo \"\$SPECIAL_VAR\""
  log_output
  [ "$status" -eq 0 ]
  [ "$output" == "$SPECIAL_VAR" ]
}

@test "test-unrestricted-fs: can access /" {
  run test-unrestricted-fs -c "ls -d /"
  log_output
  [ "$status" -eq 0 ]
}
