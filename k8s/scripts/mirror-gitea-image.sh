#!/usr/bin/env bash
# Mirrors gitea/gitea from Docker Hub to hap-ecr with a fixed version tag.
# hap-ecr is IMMUTABLE (supply-chain security) - tags cannot be overwritten,
# so 'latest' must not be used; each mirror needs its own version tag.
#
# Usage: ./mirror-gitea-image.sh <gitea-version>
#   e.g. ./mirror-gitea-image.sh 1.22.3
set -euo pipefail

GITEA_VERSION="${1:?Usage: $0 <gitea-version>, e.g. 1.22.3}"
AWS_REGION="ap-northeast-2"

ECR_REPO_URL="$(terraform -chdir="$(dirname "$0")/../../terraform" output -raw ecr_repository_url)"
ECR_REGISTRY="${ECR_REPO_URL%%/*}"

aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$ECR_REGISTRY"

docker pull "gitea/gitea:${GITEA_VERSION}"
docker tag "gitea/gitea:${GITEA_VERSION}" "${ECR_REPO_URL}:${GITEA_VERSION}"
docker push "${ECR_REPO_URL}:${GITEA_VERSION}"

echo "Mirrored gitea/gitea:${GITEA_VERSION} -> ${ECR_REPO_URL}:${GITEA_VERSION}"
echo "hap-ecr scans on push (Scan on Push) - check ECR console for the Trivy-equivalent findings."
