import 'dotenv/config';
import { DataSource } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User } from '../auth/entities/user.entity';
import { Asset } from '../assets/entities/asset.entity';
import { Scenario } from '../scenarios/entities/scenario.entity';
import { LogEntry } from '../logs/entities/log-entry.entity';
import { Role } from '../common/enums/role.enum';
import { AssetType } from '../common/enums/asset-type.enum';
import { Environment } from '../common/enums/environment.enum';
import { SensitivityLevel } from '../common/enums/sensitivity-level.enum';

// 데모/발표 시연용 초기 데이터 시드 스크립트.
// 실행: npm run seed (DB 서버가 떠 있고 .env에 DB_* 값이 설정된 상태여야 함)
async function seed() {
  const dataSource = new DataSource({
    type: 'postgres',
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT ?? 5432),
    username: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_DATABASE,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
    entities: [User, Asset, Scenario, LogEntry],
    synchronize: true,
  });

  await dataSource.initialize();
  console.log('DB 연결 성공. 시드 데이터 삽입 시작...');

  const userRepo = dataSource.getRepository(User);
  const assetRepo = dataSource.getRepository(Asset);
  const scenarioRepo = dataSource.getRepository(Scenario);

  // 1) 데모 계정 3종 (RBAC 시연용)
  const demoUsers: Array<{ email: string; password: string; role: Role }> = [
    { email: 'admin@hap.com', password: 'Admin1234!', role: Role.ADMIN },
    { email: 'analyst@hap.com', password: 'Analyst1234!', role: Role.ANALYST },
    { email: 'viewer@hap.com', password: 'Viewer1234!', role: Role.VIEWER },
  ];

  for (const u of demoUsers) {
    const exists = await userRepo.findOne({ where: { email: u.email } });
    if (exists) continue;
    const passwordHash = await bcrypt.hash(u.password, 10);
    await userRepo.save(userRepo.create({ email: u.email, passwordHash, role: u.role }));
    console.log(`계정 생성: ${u.email} / ${u.password} (${u.role})`);
  }

  // 2) 샘플 자산
  // 2026-07-22: id를 Backend 1(Neo4j) 그래프 엔진이 실제로 서빙하는 노드 id와 동일하게 맞춤
  // (cypher/01_seed_mvp.cypher 기준) — 이전에는 asset-rds-01 같은 자체 placeholder id를 썼는데,
  // 그래프 쪽 실제 노드 id와 달라 감사 로그/자산 목록과 그래프 화면이 서로 다른 이름을 가리키는
  // 불일치가 있었다. README 3.6/설계 문서에도 있던 미해결 항목이라 해소.
  // 2026-07-22 (2차 수정, 인프라팀 피드백 반영): rds-postgres-prod / onprem-admin-server는
  // 상범님이 이후 갱신한 실제 Neo4j seed와 맞지 않음 — VPN 폐지로 "관리서버(onprem-admin-server)"
  // 자산 자체가 폐기되었고(상범님 seed의 negative validation 쿼리가 management 노드 부재를 검증),
  // RDS도 hap-gitea-db로 개명됨. 아래 id로 교체.
  // 2026-07-22 (3차, 기준 재확정): 상범님 쪽 Neo4j seed는 아직 이 이름으로 push되지 않아
  // (hybrid-attack-pathfinder/cypher/01_seed_mvp.cypher 확인 결과 rds-postgres-prod로 남아있음)
  // 계속 바뀌는 중이라, 지훈님 판단으로 팀 공식 문서인 자산 인벤토리(윤지수, 자산 인벤토리 및
  // 민감도 등급 매핑)를 1차 기준으로 잠정 삼았었음.
  // 2026-07-22 (4차, 최종): 상범님이 직접 전달한 확정 노드 id 전체 목록 기준으로 재확인.
  // hap-onprem-web/hap-gitea-db/hap-customer-data-s3는 그대로 일치했고, pod만
  // eks-pod-gitea가 아니라 pod-gitea-app이 맞아서 교체함. (레포 파일 자체는 아직 이 최종 목록으로
  // push되지 않았을 수 있으니, 그래프 조회가 404 나면 엔진 쪽 push 여부부터 확인할 것)
  const demoAssets: Partial<Asset>[] = [
    {
      id: 'hap-onprem-web',
      name: 'On-Prem WordPress Web Server',
      type: AssetType.WEB_SERVER,
      environment: Environment.ON_PREM,
      sensitivityLevel: SensitivityLevel.INTERNAL,
    },
    {
      id: 'hap-gitea-db',
      name: 'RDS (Gitea DB)',
      type: AssetType.RDS,
      environment: Environment.AWS,
      sensitivityLevel: SensitivityLevel.RESTRICTED,
    },
    {
      id: 'hap-customer-data-s3',
      name: 'HAP Customer Dummy Data S3',
      type: AssetType.S3,
      environment: Environment.AWS,
      sensitivityLevel: SensitivityLevel.RESTRICTED,
    },
    {
      id: 'pod-gitea-app',
      name: 'Gitea EKS Pod',
      type: AssetType.APP_POD,
      environment: Environment.AWS_EKS,
      sensitivityLevel: SensitivityLevel.CONFIDENTIAL,
    },
  ];

  for (const a of demoAssets) {
    const exists = await assetRepo.findOne({ where: { id: a.id } });
    if (exists) continue;
    await assetRepo.save(assetRepo.create(a));
  }
  console.log(`샘플 자산 ${demoAssets.length}건 삽입 완료`);

  // 3) 시나리오 목록
  // 2026-07-10: GraphService가 상범님 Backend 1 엔진(FastAPI)에 실제로 연동되면서,
  // 여기 id는 그 엔진이 실제로 서빙하는 5개 시나리오 ID와 반드시 일치해야 한다
  // (안 그러면 GET /graph/:scenarioId가 엔진에서 404를 받는다). 목업 전용이던
  // 'scn-irsa-s3'는 실제 엔진에 없는 ID라 지우고 아래 5개로 교체한다.
  await scenarioRepo.delete({ id: 'scn-irsa-s3' });

  const demoScenarios: Partial<Scenario>[] = [
    {
      id: 'scn-onprem-access-key-to-s3',
      name: '온프레미스 서버 침해 후 AWS Access Key를 통한 S3 접근',
      description:
        '온프레미스 WordPress 웹서버(hap-onprem-web) 침해 후 저장된 AWS Access Key를 탈취하여 IAM User와 IAM Policy를 거쳐 고객 데이터 S3 Bucket에 접근 가능한 경로',
      severity: 'CRITICAL',
      graphId: 'scn-onprem-access-key-to-s3',
      mitreTactics: ['Credential Access', 'Privilege Escalation'],
    },
    {
      id: 'scn-eks-irsa-to-secrets',
      name: 'EKS Pod 침해 후 IRSA를 통한 Secrets Manager 접근',
      description:
        'Gitea EKS Pod 침해 후 ServiceAccount와 IRSA Role을 거쳐 Secrets Manager의 DB 비밀번호 Secret에 접근 가능한 경로',
      severity: 'CRITICAL',
      graphId: 'scn-eks-irsa-to-secrets',
      mitreTactics: ['Credential Access', 'Lateral Movement'],
    },
    {
      id: 'scn-eks-irsa-to-rds',
      name: 'EKS Pod 침해 후 Secrets Manager를 통한 RDS 접근',
      description:
        'Gitea EKS Pod 침해 후 IRSA Role로 Secrets Manager에 접근하고, 저장된 DB Credential을 통해 RDS PostgreSQL까지 이어지는 경로',
      severity: 'CRITICAL',
      graphId: 'scn-eks-irsa-to-rds',
      mitreTactics: ['Credential Access', 'Exfiltration'],
    },
    {
      id: 'scn-internet-gitea-to-rds',
      name: '인터넷 노출 Gitea를 통한 RDS 접근',
      description: '인터넷에 노출된 Gitea 애플리케이션 서버 침해 후 RDS PostgreSQL에 접근 가능한 네트워크 기반 공격 경로',
      severity: 'HIGH',
      graphId: 'scn-internet-gitea-to-rds',
      mitreTactics: ['Initial Access', 'Lateral Movement'],
    },
    {
      id: 'scn-onprem-to-restricted-assets',
      name: '온프레미스 서버 침해 후 Restricted 자산 접근 가능 경로',
      description: '온프레미스 WordPress 웹서버(hap-onprem-web) 침해 후 저장된 AWS Access Key를 통해 접근 가능한 모든 Restricted 등급 자산 탐색',
      severity: 'CRITICAL',
      graphId: 'scn-onprem-to-restricted-assets',
      mitreTactics: ['Credential Access', 'Discovery'],
    },
  ];

  for (const s of demoScenarios) {
    const exists = await scenarioRepo.findOne({ where: { id: s.id } });
    if (exists) continue;
    await scenarioRepo.save(scenarioRepo.create(s));
  }
  console.log(`시나리오 ${demoScenarios.length}건 삽입 완료 (Backend 1 엔진 실제 시나리오 ID 기준)`);

  await dataSource.destroy();
  console.log('시드 완료.');
}

seed().catch((err) => {
  console.error('시드 실패:', err);
  process.exit(1);
});
