#!/usr/bin/env bash
# WordPress 데이터(파일+DB 덤프) -> S3(hap-customer-data-s3) 백업.
# 실행 계정의 IAM 키가 시나리오 S1/S3의 탈취 대상 크리덴셜.
set -euo pipefail

BUCKET="${CUSTOMER_DATA_BUCKET:-hap-customer-data-s3}"
DB_HOST="192.168.0.30"
DB_NAME="${WORDPRESS_DB_NAME:-wordpress}"
DB_USER="${WORDPRESS_DB_USER:-wordpress}"
DB_PASSWORD="${WORDPRESS_DB_PASSWORD:-changeme}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="/tmp/hap-backup-${TIMESTAMP}"
LOG_FILE="/var/log/hap/backup.log"

mkdir -p "$WORK_DIR" /var/log/hap
trap 'rm -rf "$WORK_DIR"' EXIT

log() {
  echo "$(date -Is) $1" >>"$LOG_FILE"
}

ACCOUNT="$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo unknown)"
log "backup started (bucket=${BUCKET}, account=${ACCOUNT})"

if tar czf "${WORK_DIR}/wordpress-files-${TIMESTAMP}.tar.gz" -C /var/www/html . \
  && mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > "${WORK_DIR}/wordpress-db-${TIMESTAMP}.sql" \
  && aws s3 cp "${WORK_DIR}/wordpress-files-${TIMESTAMP}.tar.gz" "s3://${BUCKET}/wordpress-files/" --only-show-errors \
  && aws s3 cp "${WORK_DIR}/wordpress-db-${TIMESTAMP}.sql" "s3://${BUCKET}/wordpress-db/" --only-show-errors
then
  log "backup succeeded (bucket=${BUCKET}, account=${ACCOUNT})"
else
  log "backup FAILED (bucket=${BUCKET}, account=${ACCOUNT})"
fi
