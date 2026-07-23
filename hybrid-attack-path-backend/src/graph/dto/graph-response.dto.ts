import { ApiProperty } from '@nestjs/swagger';
import { NodeDto } from './node.dto';
import { EdgeDto } from './edge.dto';

export class GraphMetaDto {
  @ApiProperty({ example: 5 })
  nodeCount: number;

  @ApiProperty({ example: 4 })
  edgeCount: number;

  // 이 그래프 안에서 도달 가능한 경로들의 riskScore 중 최댓값
  // (Backend 1 케이스 스터디 v1.1 2.6절 위험도 산정 기준을 따름)
  @ApiProperty({ example: 9.4 })
  maxRiskScore: number;

  @ApiProperty({ example: 'CRITICAL', enum: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'] })
  maxRiskLevel: string;
}

export class GraphResponseDto {
  @ApiProperty({ example: 'S1-A' })
  graphId: string;

  @ApiProperty({ example: 'S1-A' })
  scenarioId: string;

  @ApiProperty({ example: '2026-07-02T09:00:00.000Z' })
  generatedAt: string;

  @ApiProperty({ type: [NodeDto] })
  nodes: NodeDto[];

  @ApiProperty({ type: [EdgeDto] })
  edges: EdgeDto[];

  @ApiProperty({ type: GraphMetaDto })
  meta: GraphMetaDto;
}
