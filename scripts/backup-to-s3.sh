#!/usr/bin/env bash
# Tars the node's data directory and uploads it to the S3 backup bucket the
# instance role is scoped to (see terraform/modules/node-instance - the
# role can only write under s3://<bucket>/<name>/, nothing else). Prunes
# local tarballs older than a retention window so the data volume doesn't
# fill up with its own backups.
set -euo pipefail

DATA_MOUNT="${DATA_MOUNT:-/data/chain}"
BACKUP_BUCKET="${BACKUP_BUCKET:?set BACKUP_BUCKET to the target s3 bucket}"
NODE_NAME="${NODE_NAME:?set NODE_NAME - also the S3 key prefix the instance role is scoped to}"
LOCAL_BACKUP_DIR="${LOCAL_BACKUP_DIR:-/data/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
DRY_RUN="${DRY_RUN:-0}"

log()  { printf '[backup] %s\n' "$*"; }
run()  { if [ "$DRY_RUN" = "1" ]; then printf '[backup] (dry-run) %s\n' "$*"; else "$@"; fi; }

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive_name="${NODE_NAME}-${timestamp}.tar.gz"
archive_path="${LOCAL_BACKUP_DIR}/${archive_name}"
s3_key="${NODE_NAME}/${archive_name}"

mkdir -p "$LOCAL_BACKUP_DIR"

log "archiving $DATA_MOUNT -> $archive_path"
# Exclude the backups directory itself and any *.lock / socket files that
# would corrupt the archive if the node process is mid-write.
run tar --create --gzip \
  --exclude="$(basename "$LOCAL_BACKUP_DIR")" \
  --exclude='*.lock' \
  --exclude='*.sock' \
  --file "$archive_path" \
  -C "$(dirname "$DATA_MOUNT")" "$(basename "$DATA_MOUNT")"

log "uploading to s3://${BACKUP_BUCKET}/${s3_key}"
run aws s3 cp "$archive_path" "s3://${BACKUP_BUCKET}/${s3_key}"

log "pruning local backups older than ${RETENTION_DAYS} days"
if [ "$DRY_RUN" = "1" ]; then
  find "$LOCAL_BACKUP_DIR" -maxdepth 1 -name '*.tar.gz' -mtime "+${RETENTION_DAYS}" -print
else
  find "$LOCAL_BACKUP_DIR" -maxdepth 1 -name '*.tar.gz' -mtime "+${RETENTION_DAYS}" -delete
fi

log "done"
