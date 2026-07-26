#!/usr/bin/env bash
# Health check for a running blockchain node: service state, RPC liveness,
# disk headroom on the chain-data volume, and a scan of recent logs for
# error patterns. Meant to run on a systemd timer (see
# systemd/chainnode-healthcheck.timer) or an EC2 user-data cron entry.
#
# Exit codes (stable - other tooling depends on these, don't renumber):
#   0 = healthy
#   1 = degraded (a soft check failed - recent errors in the log)
#   2 = down (service not running, or RPC unreachable)
#
# Every external command this script calls (systemctl, curl, df, aws,
# journalctl) is invoked by its plain name and resolved via PATH, so tests
# can inject mock binaries ahead of the real ones on PATH without touching
# this script - see scripts/tests/test_node_healthcheck.bats.
set -euo pipefail

SERVICE_NAME="${SERVICE_NAME:-chainnode}"
RPC_URL="${RPC_URL:-http://127.0.0.1:26657/status}"
DATA_MOUNT="${DATA_MOUNT:-/data/chain}"
DISK_WARN_PERCENT="${DISK_WARN_PERCENT:-80}"
LOG_LOOKBACK="${LOG_LOOKBACK:-10 minutes ago}"
METRICS_NAMESPACE="${METRICS_NAMESPACE:-CryptoNodeInfra}"
INSTANCE_ID="${INSTANCE_ID:-unknown}"
PUBLISH_METRICS="${PUBLISH_METRICS:-1}"

log()  { printf '[healthcheck] %s\n' "$*"; }
warn() { printf '[healthcheck] WARN: %s\n' "$*" >&2; }
fail() { printf '[healthcheck] FAIL: %s\n' "$*" >&2; }

check_service_running() {
  if ! systemctl is-active --quiet "$SERVICE_NAME"; then
    fail "systemd unit '$SERVICE_NAME' is not active"
    return 1
  fi
  log "service '$SERVICE_NAME' is active"
}

check_rpc_alive() {
  if ! curl --fail --silent --show-error --max-time 5 "$RPC_URL" >/dev/null; then
    fail "RPC endpoint $RPC_URL did not respond"
    return 1
  fi
  log "RPC endpoint responded"
}

# Parses the POSIX `df -P` output format explicitly (not locale-dependent
# `df -h`) so the percentage field position is guaranteed regardless of the
# host's df version or locale.
disk_used_percent() {
  df -P "$DATA_MOUNT" | awk 'NR==2 { gsub("%","",$5); print $5 }'
}

check_disk_space() {
  local used
  used="$(disk_used_percent)"
  if [ -z "$used" ]; then
    warn "could not read disk usage for $DATA_MOUNT"
    return 1
  fi
  if [ "$used" -ge "$DISK_WARN_PERCENT" ]; then
    warn "disk usage at ${used}% (threshold ${DISK_WARN_PERCENT}%)"
    return 1
  fi
  log "disk usage at ${used}%, below ${DISK_WARN_PERCENT}% threshold"
  return 0
}

publish_disk_metric() {
  [ "$PUBLISH_METRICS" = "1" ] || return 0
  local used
  used="$(disk_used_percent)"
  [ -n "$used" ] || return 0
  if aws cloudwatch put-metric-data \
    --namespace "$METRICS_NAMESPACE" \
    --metric-name DiskUsedPercent \
    --dimensions InstanceId="$INSTANCE_ID" \
    --value "$used" \
    --unit Percent >/dev/null 2>&1; then
    log "published DiskUsedPercent=$used to CloudWatch namespace $METRICS_NAMESPACE"
  else
    warn "failed to publish CloudWatch metric (non-fatal)"
  fi
}

# Log analysis lives in log-analyze.sh so it can be reused (and tested) on
# its own against an arbitrary log file, not just live journal output.
check_recent_errors() {
  local since="$LOG_LOOKBACK" errors
  errors="$(journalctl -u "$SERVICE_NAME" --since "$since" --no-pager 2>/dev/null \
    | "$(dirname "${BASH_SOURCE[0]}")/log-analyze.sh" --count-only)"
  if [ "${errors:-0}" -gt 0 ]; then
    warn "$errors error-level log line(s) in the last: $since"
    return 1
  fi
  log "no error-level log lines in the last: $since"
  return 0
}

main() {
  local status=0

  check_service_running || { publish_disk_metric || true; exit 2; }
  check_rpc_alive || { publish_disk_metric || true; exit 2; }

  check_disk_space || status=1
  check_recent_errors || status=1
  publish_disk_metric || true

  if [ "$status" -eq 0 ]; then
    log "overall status: healthy"
  else
    warn "overall status: degraded"
  fi
  exit "$status"
}

# Allow sourcing this file (e.g. from tests) without running main.
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
