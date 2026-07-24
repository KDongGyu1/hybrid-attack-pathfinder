import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { NodeDto } from './node.dto';
import { EdgeDto } from './edge.dto';

// Backend 1 엔진의 finding(취약점 스캔 결과) 필드는 snake_case로 온다 —
// GraphService.mapFinding()에서 camelCase로 변환한다.
export class FindingDto {
  @ApiProperty({ example: 'finding-gitea-critical-cve' })
  id: string;

  @ApiProperty({ example: 'finding-gitea-critical-cve' })
  name: string;

  @ApiProperty({ example: 'TRIVY' })
  source: string;

  @ApiProperty({ example: 'CRITICAL' })
  severity: string;

  @ApiPropertyOptional({ example: 9.8 })
  cvssScore?: number | null;

  @ApiPropertyOptional({ example: 'CVE-2026-0001' })
  cveId?: string | null;

  @ApiProperty({ example: 'CONTAINER_VULNERABILITY' })
  findingType: string;

  @ApiProperty({ example: 'OPEN' })
  status: string;

  @ApiProperty({ example: 'pod-gitea-app' })
  assetId: string;
}

export class DynamicPathDto {
  @ApiProperty({ example: 'dynamic-path-1' })
  pathId: string;

  @ApiProperty({ example: 'internet' })
  sourceAssetId: string;

  @ApiProperty({ example: 'gitea-db-credentials' })
  targetAssetId: string;

  @ApiProperty({ example: 6 })
  hopCount: number;

  @ApiProperty({ example: 7.7 })
  riskScore: number;

  @ApiProperty({ example: 'HIGH', enum: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'] })
  riskLevel: string;

  @ApiProperty({ example: 2 })
  findingCount: number;

  @ApiProperty({ type: [FindingDto] })
  findings: FindingDto[];

  @ApiProperty({ example: 'Dynamic attack path from internet to gitea-db-credentials with 6 hops and risk score 7.7.' })
  summary: string;

  @ApiProperty({ type: [NodeDto] })
  nodes: NodeDto[];

  @ApiProperty({ type: [EdgeDto] })
  edges: EdgeDto[];
}

export class DynamicPathsResponseDto {
  @ApiProperty({ example: 67 })
  pathCount: number;

  @ApiProperty({ example: 42 })
  nodeCount: number;

  @ApiProperty({ example: 58 })
  edgeCount: number;

  @ApiProperty({ example: 7.7 })
  highestRiskScore: number;

  @ApiProperty({ example: 'HIGH', enum: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'] })
  highestRiskLevel: string;

  @ApiProperty({ type: [DynamicPathDto] })
  paths: DynamicPathDto[];
}
