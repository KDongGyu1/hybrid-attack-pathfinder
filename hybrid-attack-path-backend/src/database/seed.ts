import 'dotenv/config';
import { DataSource, In } from 'typeorm';
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
  // 2026-07-23: 상범님 엔진(GET /scenarios)에 실제로 curl로 확인한 결과, 엔진의 진짜
  // scenarioId는 S1-A/S1-B/S2/S3/S4였다. 여기 id가 그 값과 정확히 일치해야
  // GraphService의 GET /attack-paths/:scenarioId 호출이 404 없이 성공한다.
  // 이전 라운드의 'scn-*' 이름들은 실제 엔진에 없는 ID라 전부 지우고 교체.
  // riskLevel(HIGH)도 실제 엔진 응답(curl로 5건 전부 확인, 6.6~7.0점)을 그대로 반영.
  await scenarioRepo.delete({
    id: In([
      'scn-irsa-s3',
      'scn-onprem-access-key-to-s3',
      'scn-eks-irsa-to-secrets',
      'scn-eks-irsa-to-rds',
      'scn-internet-gitea-to-rds',
      'scn-onprem-to-restricted-assets',
    ]),
  });

  const demoScenarios: Partial<Scenario>[] = [
    {
      id: 'S1-A',
      name: 'dev-01 Access Key 탈취 후 고객 S3 직접 접근',
      description:
        '탈취된 dev-01 IAM Access Key로 hap-dev-01-user 인증 후, S3에 직접 연결된 정책을 통해 고객 데이터 S3 Bucket에 접근 가능한 경로',
      severity: 'HIGH',
      graphId: 'S1-A',
      mitreTactics: ['Credential Access', 'Exfiltration'],
    },
    {
      id: 'S1-B',
      name: 'dev-01 Access Key로 Readonly Role Assume 후 고객 S3 접근',
      description:
        '탈취된 dev-01 IAM Access Key로 hap-s3-readonly-role을 Assume하여 고객 데이터 S3 Bucket에 접근 가능한 경로',
      severity: 'HIGH',
      graphId: 'S1-B',
      mitreTactics: ['Credential Access', 'Privilege Escalation', 'Exfiltration'],
    },
    {
      id: 'S2',
      name: '인터넷 노출 ALB를 통한 Gitea Pod 경유 RDS 접근',
      description:
        '인터넷 트래픽이 hap-prod-alb(HTTP/80)로 도달해 pod-gitea-app으로 이동하고, 해당 Pod가 Gitea RDS PostgreSQL(hap-gitea-db)에 연결되는 경로',
      severity: 'HIGH',
      graphId: 'S2',
      mitreTactics: ['Initial Access', 'Lateral Movement'],
    },
    {
      id: 'S3',
      name: '온프레미스 WordPress 키를 통한 고객 S3 제한 접근',
      description:
        '침해된 온프레미스 WordPress 웹서버(hap-onprem-web)가 hap-onprem-web-key를 사용해, 허용된 고객 S3 백업 prefix에만 쓰기 가능한 경로',
      severity: 'HIGH',
      graphId: 'S3',
      mitreTactics: ['Credential Access', 'Exfiltration'],
    },
    {
      id: 'S4',
      name: 'Gitea Pod IRSA를 통한 Secret 및 RDS 접근',
      description:
        'Gitea Pod(pod-gitea-app)가 gitea-sa로 hap-irsa-gitea-role을 Assume하여 hap-db-secret 기반 DB Credential을 읽고, RDS(hap-gitea-db)에 접근 가능한 경로',
      severity: 'HIGH',
      graphId: 'S4',
      mitreTactics: ['Credential Access', 'Lateral Movement'],
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
