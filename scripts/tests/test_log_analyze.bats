#!/usr/bin/env bats
# Tests for scripts/log-analyze.sh - pure stdin-in, stdout-out, no mocking
# needed since it has no external dependencies beyond grep/cat.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../log-analyze.sh"
}

@test "counts zero errors in a clean log" {
  run bash -c "printf 'INFO starting up\nINFO ready\n' | '$SCRIPT' --count-only"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}

@test "counts error-level lines case-insensitively" {
  run bash -c "printf 'INFO ok\nerror: connection refused\nCRITICAL disk full\nWarn: retrying\n' | '$SCRIPT' --count-only"
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}

@test "does not count WARN as an error" {
  run bash -c "printf 'WARN: retrying\nWARNING: slow query\n' | '$SCRIPT' --count-only"
  [ "$output" = "0" ]
}

@test "does not false-positive on substrings like 'errorless' or 'terrorism'" {
  run bash -c "printf 'this run was errorless\nno terrorism here\n' | '$SCRIPT' --count-only"
  [ "$output" = "0" ]
}

@test "full report includes total, error, and warning line counts" {
  run bash -c "printf 'INFO a\nERROR b\nWARN c\n' | '$SCRIPT'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"total lines:        3"* ]]
  [[ "$output" == *"error-level lines:  1"* ]]
  [[ "$output" == *"warning-level lines: 1"* ]]
}

@test "full report lists the most recent error lines when errors exist" {
  run bash -c "printf 'INFO a\nERROR first\nERROR second\n' | '$SCRIPT'"
  [[ "$output" == *"most recent error/critical lines"* ]]
  [[ "$output" == *"ERROR first"* ]]
  [[ "$output" == *"ERROR second"* ]]
}

@test "rejects an unknown flag" {
  run bash -c "echo x | '$SCRIPT' --nonsense"
  [ "$status" -eq 64 ]
}

@test "handles empty input without error" {
  run bash -c "printf '' | '$SCRIPT' --count-only"
  [ "$status" -eq 0 ]
  [ "$output" = "0" ]
}
