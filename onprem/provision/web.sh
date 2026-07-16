#!/usr/bin/env bash
# hap-onprem-web 프로비저닝: Apache+PHP+WordPress(표준 설치, 취약 플러그인 없음),
# AWS CLI, S3 백업/로그 전송 cron. IAM 키는 env로 주입된 placeholder만 사용한다.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

WP_DB_NAME="${WORDPRESS_DB_NAME:-wordpress}"
WP_DB_USER="${WORDPRESS_DB_USER:-wordpress}"
WP_DB_PASSWORD="${WORDPRESS_DB_PASSWORD:-changeme}"
DB_HOST="192.168.0.30"
WP_VERSION="6.5.5"
PRIVATE_IP="192.168.0.10"

# ubuntu/jammy64(cloud-init) 이미지에서 Vagrant의 private_network 설정이
# 재부팅 시 유지되지 않는 문제 회피: netplan 고정 설정 + cloud-init 네트워크 재설정 비활성화
cat > /etc/netplan/60-hap-static.yaml <<EOF
network:
  version: 2
  ethernets:
    enp0s8:
      dhcp4: no
      addresses: [${PRIVATE_IP}/24]
EOF
chmod 600 /etc/netplan/60-hap-static.yaml
cat > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg <<EOF
network: {config: disabled}
EOF
netplan apply

apt-get update -y
apt-get install -y apache2 php php-mysql php-curl php-gd php-xml php-mbstring php-zip \
  libapache2-mod-php mysql-client unzip curl auditd

# --- WordPress (표준 설치, 버전 고정) ---
if [ ! -f /var/www/html/wp-load.php ]; then
  curl -sSL "https://wordpress.org/wordpress-${WP_VERSION}.tar.gz" -o /tmp/wordpress.tar.gz
  tar xzf /tmp/wordpress.tar.gz -C /tmp
  rm -rf /var/www/html
  mv /tmp/wordpress /var/www/html
  chown -R www-data:www-data /var/www/html
fi

if [ ! -f /var/www/html/wp-config.php ]; then
  cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
  sed -i "s/database_name_here/${WP_DB_NAME}/" /var/www/html/wp-config.php
  sed -i "s/username_here/${WP_DB_USER}/" /var/www/html/wp-config.php
  sed -i "s/password_here/${WP_DB_PASSWORD}/" /var/www/html/wp-config.php
  sed -i "s/localhost/${DB_HOST}/" /var/www/html/wp-config.php
  chown www-data:www-data /var/www/html/wp-config.php
fi

systemctl enable apache2
systemctl restart apache2

# --- AWS CLI v2 ---
if ! command -v aws >/dev/null 2>&1; then
  curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q -o /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install --update
fi

# IAM 액세스 키: placeholder. 실값은 절대 하드코딩 금지, Vagrantfile의 env 주입값 사용.
mkdir -p /root/.aws
cat > /root/.aws/credentials <<EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID:-REPLACE_WITH_IAM_ACCESS_KEY}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY:-REPLACE_WITH_IAM_SECRET_KEY}
EOF
cat > /root/.aws/config <<EOF
[default]
region = ${AWS_DEFAULT_REGION:-ap-northeast-2}
output = json
EOF
chmod 600 /root/.aws/credentials /root/.aws/config

# --- 백업/로그 전송 스크립트 배치 (file provisioner가 /tmp에 SCP로 전달) ---
mkdir -p /usr/local/bin /var/log/hap
cp /tmp/backup-to-s3.sh /usr/local/bin/backup-to-s3.sh
cp /tmp/ship-logs-to-s3.sh /usr/local/bin/ship-logs-to-s3.sh
chmod 750 /usr/local/bin/backup-to-s3.sh /usr/local/bin/ship-logs-to-s3.sh

cat > /etc/environment.hap <<EOF
export CUSTOMER_DATA_BUCKET=${CUSTOMER_DATA_BUCKET:-hap-customer-data-s3}
export SOC_LOG_BUCKET=${SOC_LOG_BUCKET:-hap-soc-log-s3}
export WORDPRESS_DB_NAME=${WP_DB_NAME}
export WORDPRESS_DB_USER=${WP_DB_USER}
export WORDPRESS_DB_PASSWORD=${WP_DB_PASSWORD}
export HAP_LOG_ROLE=web
EOF

cat > /etc/cron.d/hap-web <<EOF
SHELL=/bin/bash
*/15 * * * * root . /etc/environment.hap && /usr/local/bin/backup-to-s3.sh
*/5  * * * * root . /etc/environment.hap && /usr/local/bin/ship-logs-to-s3.sh
EOF
chmod 644 /etc/cron.d/hap-web

systemctl enable auditd
systemctl restart auditd
