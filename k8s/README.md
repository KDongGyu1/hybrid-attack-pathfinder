# Gitea 배포 (EKS)

`terraform/`가 만든 `hap-eks` 클러스터 위에 Gitea를 올리는 매니페스트와 스크립트.
Terraform 스코프 밖(K8s 애드온 설치·이미지 미러링·앱 배포)이라 여기 별도로 둠.

## 사전 준비

```bash
aws eks update-kubeconfig --region ap-northeast-2 --name hap-eks
```

Terraform output에서 필요한 값 꺼내기 (아래 단계에서 `${...}` 치환에 사용):

```bash
cd terraform
export IRSA_GITEA_ROLE_ARN=$(terraform output -raw irsa_gitea_role_arn)
export IRSA_LB_CONTROLLER_ROLE_ARN=$(terraform output -raw irsa_lb_controller_role_arn)
export PROD_TARGET_GROUP_ARN=$(terraform output -raw prod_target_group_arn)
export PROD_VPC_ID=$(terraform output -raw prod_vpc_id)
export GITEA_DB_ENDPOINT=$(terraform output -raw gitea_db_endpoint)
export ECR_REPO_URL=$(terraform output -raw ecr_repository_url)
cd ..
```

## 1. AWS Load Balancer Controller 설치 (클러스터 애드온, 1회만)

`hap-prod-alb`의 타깃 그룹에 실제 Gitea Pod를 등록하려면 필요. IRSA 역할은
Terraform이 이미 만들어둠(`hap-irsa-lb-controller-role`, 공식 업스트림 정책 적용).

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update

envsubst < k8s/addons/aws-load-balancer-controller-values.yaml > /tmp/lbc-values.yaml
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  -f /tmp/lbc-values.yaml
```

## 2. Secrets Store CSI Driver 설치 (클러스터 애드온, 1회만)

`hap-db-secret`을 Pod에 마운트하기 위한 드라이버 + AWS provider. 기본 옵션만으로
설치하면 아래 두 가지가 막히므로 반드시 옵션을 같이 지정할 것:

- `tokenRequests` 미설정 시 IRSA 토큰을 못 받아 마운트가
  `CSI token error: serviceAccount.tokens not provided` 로 실패함.
- `syncSecret.enabled=true` 없이는 `secretproviderclass.yaml`의 `secretObjects`
  동기화가 동작하지 않아 `gitea-db-credentials` 시크릿이 생성되지 않고,
  Pod가 `CreateContainerConfigError`(secret not found)로 멈춤.

```bash
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm repo update
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver \
  -n kube-system \
  --set syncSecret.enabled=true \
  --set-json 'tokenRequests=[{"audience":"sts.amazonaws.com","expirationSeconds":3600}]'

kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml
```

이미 옵션 없이 설치해버렸다면 `helm upgrade`로 같은 옵션을 주면 됨 (재설치 불필요).
단, 이미 떠 있던 Pod는 CSIDriver의 `tokenRequests`를 반영한 projected token이
없으므로 `kubectl delete pod -n prod -l app=gitea`로 재생성해야 함.

## 3. Gitea 이미지 미러링 (Docker Hub → hap-ecr)

버전 `1.26.4`로 고정(미러링 시점 최신 1.26.x 패치). 아래 Gitea 배포 매니페스트도
같은 태그를 참조함 — 버전 올릴 때는 두 곳 다 같이 바꿀 것.

```bash
./k8s/scripts/mirror-gitea-image.sh 1.26.4
export GITEA_IMAGE_TAG=1.26.4
```

`hap-ecr`는 IMMUTABLE이라 태그 재사용 불가 — 버전 올릴 때마다 새 태그로 미러링.

## 4. Gitea 배포

```bash
kubectl apply -f k8s/gitea/namespace.yaml

envsubst < k8s/gitea/serviceaccount.yaml | kubectl apply -f -
kubectl apply -f k8s/gitea/secretproviderclass.yaml
envsubst < k8s/gitea/deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/gitea/service.yaml
envsubst < k8s/gitea/targetgroupbinding.yaml | kubectl apply -f -
```

## 5. 확인

```bash
kubectl -n prod get pods,svc,targetgroupbinding
curl http://$(cd terraform && terraform output -raw prod_alb_dns_name)
```

ALB 타깃 그룹(콘솔 또는 `aws elbv2 describe-target-health`)에서 Gitea Pod가
healthy로 뜨는지 확인. IRSA로 시크릿을 못 읽으면(`hap-gitea-role-policy`가
아직 stage 8에서 안 만들어진 상태) Pod가 `/mnt/secrets-store` 마운트에서
멈출 수 있음 — stage 8 완료 후 재확인 필요.
