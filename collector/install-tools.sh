#!/bin/bash
# hap-soc-collector 도구 설치 스크립트
# 실행: sudo ./install-tools.sh

set -e

echo "===== hap-soc-collector 도구 설치 시작 ====="

# 시스템 업데이트
sudo yum update -y

# AWS CLI v2
if ! command -v aws &> /dev/null; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip -q awscliv2.zip
  sudo ./aws/install
  rm -rf awscliv2.zip aws/
fi

# Python 3 + pip
sudo yum install -y python3 python3-pip

# Nmap
sudo yum install -y nmap

# Trivy
if ! command -v trivy &> /dev/null; then
  sudo rpm -ivh https://github.com/aquasecurity/trivy/releases/download/v0.50.0/trivy_0.50.0_Linux-64bit.rpm
fi

# Scout Suite
sudo pip3 install --upgrade pip
sudo pip3 install scoutsuite

# 확인
echo "===== 설치 완료 ====="
aws --version
python3 --version
nmap --version | head -1
trivy --version | head -1