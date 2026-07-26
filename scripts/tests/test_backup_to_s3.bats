#!/usr/bin/env bats
# Tests scripts/backup-to-s3.sh using a real local tar (safe - it's just
# archiving a temp directory) and a mocked `aws` so no real S3 call ever
# happens, plus dry-run mode for the argument-shape checks.

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../backup-to-s3.sh"
  WORK_DIR="$(mktemp -d)"
  MOCK_DIR="$(mktemp -d)"
  PATH="$MOCK_DIR:$PATH"
  export PATH WORK_DIR MOCK_DIR

  mkdir -p "$WORK_DIR/chain"
  echo "fake chain state" > "$WORK_DIR/chain/state.db"

  cat > "$MOCK_DIR/aws" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "$MOCK_DIR/aws-calls.log"
exit 0
EOF
  chmod +x "$MOCK_DIR/aws"
}

teardown() {
  rm -rf "$WORK_DIR" "$MOCK_DIR"
}

@test "fails fast with a clear message if BACKUP_BUCKET is not set" {
  run bash -c "unset BACKUP_BUCKET; NODE_NAME=n1 DATA_MOUNT='$WORK_DIR/chain' '$SCRIPT'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"BACKUP_BUCKET"* ]]
}

@test "fails fast with a clear message if NODE_NAME is not set" {
  run bash -c "unset NODE_NAME; BACKUP_BUCKET=b1 DATA_MOUNT='$WORK_DIR/chain' '$SCRIPT'"
  [ "$status" -ne 0 ]
  [[ "$output" == *"NODE_NAME"* ]]
}

@test "dry run does not create an archive or call aws" {
  DRY_RUN=1 BACKUP_BUCKET=test-bucket NODE_NAME=node1 \
    DATA_MOUNT="$WORK_DIR/chain" LOCAL_BACKUP_DIR="$WORK_DIR/backups" \
    run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ ! -f "$MOCK_DIR/aws-calls.log" ]
  run bash -c "ls '$WORK_DIR/backups' 2>/dev/null | wc -l"
  [ "$output" -eq 0 ]
}

@test "real run creates a tar.gz and uploads it to the correct s3 key" {
  BACKUP_BUCKET=test-bucket NODE_NAME=node1 \
    DATA_MOUNT="$WORK_DIR/chain" LOCAL_BACKUP_DIR="$WORK_DIR/backups" \
    run "$SCRIPT"
  [ "$status" -eq 0 ]

  run bash -c "ls '$WORK_DIR/backups'/node1-*.tar.gz 2>/dev/null | wc -l"
  [ "$output" -eq 1 ]

  [ -f "$MOCK_DIR/aws-calls.log" ]
  run cat "$MOCK_DIR/aws-calls.log"
  [[ "$output" == *"s3 cp"* ]]
  [[ "$output" == *"s3://test-bucket/node1/"* ]]
}

@test "uploaded archive actually contains the chain data" {
  BACKUP_BUCKET=test-bucket NODE_NAME=node1 \
    DATA_MOUNT="$WORK_DIR/chain" LOCAL_BACKUP_DIR="$WORK_DIR/backups" \
    run "$SCRIPT"
  [ "$status" -eq 0 ]

  archive="$(ls "$WORK_DIR"/backups/node1-*.tar.gz)"
  run tar --list --file "$archive"
  [[ "$output" == *"chain/state.db"* ]]
}
