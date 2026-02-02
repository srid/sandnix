#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  echo "This is a secret" > test_secret
}
teardown() {
  rm -f test_secret
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

@test "test-ls cannot list /etc (restricted by default)" {
  run test-ls /etc
  log_output
  [ "$status" -ne 0 ]
}

@test "test-curl-deny fails to connect to example.com" {
  run test-curl-deny --connect-timeout 2 https://example.com
  log_output
  [ "$status" -ne 0 ]
}

@test "test-curl-allow can connect to example.com" {
  run test-curl-allow -I https://example.com
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
  run test-no-access -c "cat test_secret"
  log_output
  [ "$status" -ne 0 ]
  [ "$output" == "cat: test_secret: Permission denied" ]
}
