// GET /assets 전용 (자산 인벤토리 문서 시스템 영역 11종과 1:1 매핑)
// 2026-07-14: 멘토링 피드백 반영 - VPN Gateway/Bastion/Management Server는 v2
// 아키텍처(VPN Peering + IAM Access Key 기반)에서 이미 제거된 구성이라 여기서도 삭제.
// 주의: GET /graph, GET /graph/paths 응답의 노드 type은 이 enum에 갇히지 않는다.
// 그래프 응답 노드 타입은 Backend 1 Neo4j 스키마를 그대로 통과시키는
// GraphNodeType(문서 6.2 참고, INTERNET/IAM_USER/IAM_ROLE/IAM_POLICY/VPC/SUBNET/
// SECURITY_GROUP/ON_PREM_SERVER/EKS_POD/S3_BUCKET/FINDING 등 포함)이며 별도 enum 검증을 하지 않는다.
export enum AssetType {
  WEB_SERVER = 'WEB_SERVER',
  DB_SERVER = 'DB_SERVER',
  ALB = 'ALB',
  APP_SERVER = 'APP_SERVER',
  APP_POD = 'APP_POD',
  RDS = 'RDS',
  S3 = 'S3',
  IAM_ACCOUNT = 'IAM_ACCOUNT',
  NAT_GATEWAY = 'NAT_GATEWAY',
  NETWORK_CONFIG = 'NETWORK_CONFIG',
  SERVICE_ACCOUNT = 'SERVICE_ACCOUNT',
  // TODO: 인프라팀 인벤토리 갱신(IAM_POLICY 독립 자산화, Redis/ECR/Secrets Manager 추가)
  // 확정되면 여기에 반영
}
