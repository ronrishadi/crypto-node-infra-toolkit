#!/usr/bin/env bash
# Summarizes log lines from stdin: counts by level, and pulls out the most
# recent error/critical lines so someone doesn't have to scroll a raw
# journalctl dump to find what actually broke.
#
# Usage:
#   journalctl -u chainnode --since "1 hour ago" | scripts/log-analyze.sh
#   scripts/log-analyze.sh --count-only < some.log     # just the error count, for healthcheck
#   scripts/log-analyze.sh --tail 5 < some.log         # last N error/critical lines
set -euo pipefail

COUNT_ONLY=0
TAIL_N=10

while [ $# -gt 0 ]; do
  case "$1" in
    --count-only) COUNT_ONLY=1; shift ;;
    --tail) TAIL_N="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 64 ;;
  esac
done

# Matches common log-level conventions (bracketed or bare, case-insensitive)
# without assuming one specific logging library's exact format.
ERROR_PATTERN='\b(ERROR|ERR|CRITICAL|CRIT|FATAL|PANIC)\b'

input="$(cat)"

error_count="$(printf '%s\n' "$input" | grep -Ec -i "$ERROR_PATTERN" || true)"

if [ "$COUNT_ONLY" = "1" ]; then
  printf '%s\n' "$error_count"
  exit 0
fi

echo "total lines:        $(printf '%s\n' "$input" | grep -c . || true)"
echo "error-level lines:  $error_count"
echo "warning-level lines: $(printf '%s\n' "$input" | grep -Ec -i '\b(WARN|WARNING)\b' || true)"

if [ "$error_count" -gt 0 ]; then
  echo ""
  echo "most recent error/critical lines (up to $TAIL_N):"
  printf '%s\n' "$input" | grep -E -i "$ERROR_PATTERN" | tail -n "$TAIL_N"
fi
