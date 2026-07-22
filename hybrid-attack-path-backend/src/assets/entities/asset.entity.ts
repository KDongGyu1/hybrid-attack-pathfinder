import { Column, Entity, PrimaryColumn } from 'typeorm';
import { AssetType } from '../../common/enums/asset-type.enum';
import { Environment } from '../../common/enums/environment.enum';
import { SensitivityLevel } from '../../common/enums/sensitivity-level.enum';

// 자산 인벤토리 문서 기준 자산 테이블. id는 Backend 1(Neo4j) 그래프 엔진이 실제로
// 사용하는 노드 id(예: hap-gitea-db, hap-customer-data-s3)를 그대로 PK로 사용해
// 그래프와 자산 목록 간 id 불일치가 생기지 않도록 한다.
@Entity('assets')
export class Asset {
  @PrimaryColumn()
  id: string;

  @Column()
  name: string;

  @Column({ type: 'enum', enum: AssetType })
  type: AssetType;

  @Column({ type: 'enum', enum: Environment })
  environment: Environment;

  @Column({ type: 'enum', enum: SensitivityLevel })
  sensitivityLevel: SensitivityLevel;

  @Column({ type: 'jsonb', nullable: true })
  tags?: string[];

  @Column({ type: 'jsonb', nullable: true })
  properties?: Record<string, unknown>;

  // 그래프(엣지 수)/시나리오 연관 정보는 Backend 1(Neo4j) 도메인이라 이 테이블에는 저장하지 않는다.
  // AssetResponseDto.relatedEdgeCount / relatedScenarioIds는 그래프 어댑터 연동 시점에 채운다 (TODO).
  @Column({ type: 'jsonb', nullable: true })
  relatedScenarioIds?: string[];
}
