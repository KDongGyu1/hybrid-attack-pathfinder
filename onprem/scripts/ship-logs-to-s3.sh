#!/usr/bin/env bash
# 온프렘 로그(WordPress/MySQL/OS/백업) -> S3(hap-soc-log-s3/onprem/...) 전송.
# collector는 AWS private 이라 직접 전송 불가 -> IAM 키로 S3에 저장, SOC collector가 S3에서 읽어감.
# HAP_LOG_ROLE(web|db)에 따라 대상 로그 목록이 달라진다.
set -euo pipefail

ROLE="${HAP_LOG_ROLE:?HAP_LOG_ROLE not set (web|db)}"
BUCKET="${SOC_LOG_BUCKET:-hap-soc-log-s3}"
HOST_NAME="$(hostname)"
LOG_FILE="/var/log/hap/ship-logs-to-s3.log"

mkdir -p /var/log/hap

sync_file() {
  local src="$1" prefix="$2"
  [ -f "$src" ] || return 0
  aws s3 cp "$src" "s3://${BUCKET}/onprem/${prefix}/${HOST_NAME}/$(basename "$src")" \
    --only-show-errors >>"$LOG_FILE" 2>&1
}

case "$ROLE" in
  web)
    sync_file /var/log/apache2/access.log wordpress
    sync_file /var/log/apache2/error.log  wordpress
    sync_file /var/log/hap/backup.log     backup
    ;;
  db)
    sync_file /var/log/mysql/mysql.log      mysql
    sync_file /var/log/mysql/error.log      mysql
    sync_file /var/log/mysql/mysql-slow.log mysql
    ;;
  *)
    echo "unknown HAP_LOG_ROLE: ${ROLE}" >&2
    exit 1
    ;;
esac

# OS 로그(web/db 공통) - 로그인/sudo/권한변경 추적
sync_file /var/log/syslog       os
sync_file /var/log/auth.log     os
sync_file /var/log/audit/audit.log os
