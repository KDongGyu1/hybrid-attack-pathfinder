#!/bin/bash
# hap-soc-collector 도구 설치 스크립트 (Amazon Linux 2023 대응)
#
# 실행: sudo ./install-tools.sh
#
# v2 (2026-07-23): 
#   - AWS CLI v2 rpm 기본 설치 인식 (재설치 스킵)
#   - Scout Suite virtualenv 격리 (시스템 rpm 보호)
#   - Trivy 공식 install.sh 사용 (URL 안정성)
#   - 각 단계 idempotent 처리

set -e

echo "===== hap-soc-collector 도구 설치 시작 ====="
echo ""

# 1. 시스템 업데이트
echo "[1/6] 시스템 업데이트"
sudo dnf update -y

# 2. 필수 rpm 도구
echo ""
echo "[2/6] 기본 도구 (unzip, nmap, python3, pip)"
sudo dnf install -y unzip nmap python3 python3-pip

# 3. AWS CLI (Amazon Linux 2023은 기본 제공)
echo ""
echo "[3/6] AWS CLI 확인"
if command -v aws &> /dev/null; then
    echo "  이미 설치됨: $(aws --version 2>&1)"
else
    echo "  AWS CLI 설치 시작"
    cd /tmp
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip -q awscliv2.zip
    sudo ./aws/install
    rm -rf awscliv2.zip aws/
fi

# 4. Trivy (공식 install 스크립트)
echo ""
echo "[4/6] Trivy 설치"
if command -v trivy &> /dev/null; then
    echo "  이미 설치됨: $(trivy --version 2>&1 | head -1)"
else
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
      | sudo sh -s -- -b /usr/local/bin
fi

# 5. Scout Suite (virtualenv 격리)
echo ""
echo "[5/6] Scout Suite 설치 (virtualenv 격리)"
if [ -d /opt/scoutsuite-env ] && [ -f /opt/scoutsuite-env/bin/scout ]; then
    echo "  이미 설치됨: $(/opt/scoutsuite-env/bin/scout --version 2>&1 | head -1)"
else
    sudo python3 -m venv /opt/scoutsuite-env
    sudo /opt/scoutsuite-env/bin/pip install --upgrade pip --quiet
    sudo /opt/scoutsuite-env/bin/pip install scoutsuite --quiet
    sudo ln -sf /opt/scoutsuite-env/bin/scout /usr/local/bin/scout
fi

# 6. 최종 확인
echo ""
echo "[6/6] 설치 결과 확인"
echo "======================================"
aws --version
python3 --version
nmap --version | head -1
trivy --version 2>&1 | head -1
scout --version 2>&1 | head -1
echo "======================================"

echo ""
echo "===== 설치 완료 ====="
echo ""
echo "다음 단계:"
echo "  1. cp .env.production.example .env.production"
echo "  2. vi .env.production (필요 시 수정)"
echo "  3. aws sts get-caller-identity (자격증명 확인)"