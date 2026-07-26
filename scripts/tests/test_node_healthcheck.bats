#!/usr/bin/env bats
# Tests scripts/node-healthcheck.sh's decision logic (exit codes 0/1/2) by
# putting mock systemctl/curl/df/aws/journalctl binaries ahead of the real
# ones on PATH, rather than requiring a real systemd unit, a real node RPC
# port, or real AWS credentials to exercise every branch.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../node-healthcheck.sh"
  MOCK_DIR="$(mktemp -d)"
  PATH="$MOCK_DIR:$PATH"
  export PATH MOCK_DIR

  # Defaults: everything healthy unless a test overrides a mock below.
  cat > "$MOCK_DIR/systemctl" <<'EOF'
#!/usr/bin/env bash
[ "$1" = "is-active" ] && exit "${MOCK_SYSTEMCTL_EXIT:-0}"
exit 0
EOF
  cat > "$MOCK_DIR/curl" <<'EOF'
#!/usr/bin/env bash
exit "${MOCK_CURL_EXIT:-0}"
EOF
  cat > "$MOCK_DIR/df" <<'EOF'
#!/usr/bin/env bash
echo "Filesystem 1024-blocks Used Available Capacity Mounted"
echo "/dev/xvdf  1000000  ${MOCK_DF_PERCENT:-50}0000  ok  ${MOCK_DF_PERCENT:-50}% /data/chain"
EOF
  cat > "$MOCK_DIR/journalctl" <<'EOF'
#!/usr/bin/env bash
printf '%b' "${MOCK_JOURNAL_OUTPUT:-INFO nothing happened\n}"
EOF
  cat > "$MOCK_DIR/aws" <<'EOF'
#!/usr/bin/env bash
exit "${MOCK_AWS_EXIT:-0}"
EOF
  chmod +x "$MOCK_DIR"/*
  export PUBLISH_METRICS=1 MOCK_AWS_EXIT=0
}

teardown() {
  rm -rf "$MOCK_DIR"
}

@test "exits 0 when service, RPC, disk, and logs are all healthy" {
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"overall status: healthy"* ]]
}

@test "exits 2 immediately when the systemd service is not active" {
  MOCK_SYSTEMCTL_EXIT=1 run "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "exits 2 when RPC does not respond, even if the service is active" {
  MOCK_CURL_EXIT=1 run "$SCRIPT"
  [ "$status" -eq 2 ]
}

@test "exits 1 (degraded, not down) when disk usage is over threshold" {
  MOCK_DF_PERCENT=95 DISK_WARN_PERCENT=80 run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"disk usage at 95%"* ]]
}

@test "does not flag disk usage right at the threshold minus one" {
  MOCK_DF_PERCENT=79 DISK_WARN_PERCENT=80 run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "exits 1 when recent logs contain error-level lines" {
  MOCK_JOURNAL_OUTPUT='INFO ok\nERROR: peer connection dropped\n' run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" == *"error-level log line"* ]]
}

@test "a failed CloudWatch publish is non-fatal" {
  MOCK_AWS_EXIT=1 run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "PUBLISH_METRICS=0 skips CloudWatch entirely and never calls the aws mock" {
  MARKER="$MOCK_DIR/aws-was-called"
  cat > "$MOCK_DIR/aws" <<EOF
#!/usr/bin/env bash
touch "$MARKER"
exit 0
EOF
  chmod +x "$MOCK_DIR/aws"
  PUBLISH_METRICS=0 run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "$MARKER" ]
}

@test "disk_used_percent extracts exactly the capacity field from df -P" {
  # Run in a subshell so sourcing the script (which sets -euo pipefail)
  # cannot leak shell options into the rest of this test.
  result="$(MOCK_DF_PERCENT=63 bash -c "source '$SCRIPT'; disk_used_percent")"
  [ "$result" = "63" ]
}
