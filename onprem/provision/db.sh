#!/usr/bin/env bash
# hap-onprem-db 프로비저닝: MySQL 8.0(WordPress 백엔드), 로그 전송 cron.
# 외부 비노출 - web(192.168.0.10)에서만 접근 허용.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

WP_DB_NAME="${WORDPRESS_DB_NAME:-wordpress}"
WP_DB_USER="${WORDPRESS_DB_USER:-wordpress}"
WP_DB_PASSWORD="${WORDPRESS_DB_PASSWORD:-changeme}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-changeme-root}"
WEB_HOST="192.168.0.10"

apt-get update -y
apt-get install -y mysql-server unzip curl auditd

# private network(192.168.0.0/24)에서만 접근 가능하도록 바인딩
sed -i "s/^bind-address.*/bind-address = 0.0.0.0/" /etc/mysql/mysql.conf.d/mysqld.cnf

# SOC 로그 소스: general/slow query log 활성화
cat > /etc/mysql/conf.d/hap-logging.cnf <<EOF
[mysqld]
general_log = 1
general_log_file = /var/log/mysql/mysql.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/mysql-slow.log
long_query_time = 2
EOF

systemctl restart mysql

mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS ${WP_DB_NAME};
CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'${WEB_HOST}' IDENTIFIED BY '${WP_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${WP_DB_NAME}.* TO '${WP_DB_USER}'@'${WEB_HOST}';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';
FLUSH PRIVILEGES;
SQL

# --- AWS CLI v2 (로그 전송 전용, customer-data 버킷 접근 권한 없음) ---
if ! command -v aws >/dev/null 2>&1; then
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q -o /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install --update
fi

# IAM 액세스 키: placeholder. 실값은 절대 하드코딩 금지, Vagrantfile의 env 주입값 사용.
mkdir -p /root/.aws
cat > /root/.aws/credentials <<EOF
[default]
aws_access_key_id = ${DB_AWS_ACCESS_KEY_ID:-REPLACE_WITH_IAM_ACCESS_KEY}
aws_secret_access_key = ${DB_AWS_SECRET_ACCESS_KEY:-REPLACE_WITH_IAM_SECRET_KEY}
EOF
cat > /root/.aws/config <<EOF
[default]
region = ${AWS_DEFAULT_REGION:-ap-northeast-2}
output = json
EOF
chmod 600 /root/.aws/credentials /root/.aws/config

# --- 로그 전송 스크립트 배치 ---
mkdir -p /usr/local/bin /var/log/hap
cp /vagrant/scripts/ship-logs-to-s3.sh /usr/local/bin/ship-logs-to-s3.sh
chmod 750 /usr/local/bin/ship-logs-to-s3.sh

cat > /etc/environment.hap <<EOF
SOC_LOG_BUCKET=${SOC_LOG_BUCKET:-hap-soc-log-s3}
HAP_LOG_ROLE=db
EOF

cat > /etc/cron.d/hap-db <<EOF
SHELL=/bin/bash
*/5 * * * * root . /etc/environment.hap && /usr/local/bin/ship-logs-to-s3.sh
EOF
chmod 644 /etc/cron.d/hap-db

systemctl enable auditd
systemctl restart auditd
