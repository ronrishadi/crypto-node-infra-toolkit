#!/usr/bin/env bash
# Idempotent host setup: creates the dedicated system user, installs the
# systemd unit and healthcheck timer, and enables (but does not start) the
# service. Safe to re-run - every step checks current state first instead
# of assuming a blank machine, so a second run after a config change only
# touches what actually changed.
set -euo pipefail

NODE_USER="${NODE_USER:-chainnode}"
DATA_MOUNT="${DATA_MOUNT:-/data/chain}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

log() { printf '[bootstrap] %s\n' "$*"; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "bootstrap-node.sh must run as root (it manages users, systemd units, and /etc)" >&2
    exit 1
  fi
}

ensure_user() {
  if id -u "$NODE_USER" >/dev/null 2>&1; then
    log "user '$NODE_USER' already exists, skipping"
  else
    log "creating system user '$NODE_USER'"
    useradd --system --create-home --shell /usr/sbin/nologin "$NODE_USER"
  fi
}

ensure_data_dir() {
  mkdir -p "$DATA_MOUNT"
  chown "$NODE_USER:$NODE_USER" "$DATA_MOUNT"
  log "data directory $DATA_MOUNT owned by $NODE_USER"
}

install_systemd_unit() {
  local src="$REPO_ROOT/systemd/chainnode.service"
  local dest="/etc/systemd/system/chainnode.service"
  if [ ! -f "$src" ]; then
    echo "expected unit file at $src, not found" >&2
    exit 1
  fi
  if cmp -s "$src" "$dest" 2>/dev/null; then
    log "systemd unit already up to date"
  else
    log "installing systemd unit to $dest"
    cp "$src" "$dest"
    systemctl daemon-reload
  fi
  systemctl enable chainnode.service >/dev/null
  log "chainnode.service enabled (not started - start it explicitly once config is in place)"
}

install_logrotate_policy() {
  local dest="/etc/logrotate.d/chainnode"
  cat > "$dest" <<'EOF'
/var/log/chainnode/*.log {
  daily
  rotate 14
  compress
  delaycompress
  missingok
  notifempty
  copytruncate
}
EOF
  log "logrotate policy installed at $dest (14-day retention, daily rotation)"
}

main() {
  require_root
  ensure_user
  ensure_data_dir
  install_systemd_unit
  install_logrotate_policy
  log "bootstrap complete"
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
