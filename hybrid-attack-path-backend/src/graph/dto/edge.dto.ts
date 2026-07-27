import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

// relation은 Backend 1 Neo4j 엔진의 관계 타입(엔진 응답의 edge.type 필드)을 그대로
// 매핑한다 (GraphService.mapEdge 참고). 실제로 관측되는 값 예: STORES_CREDENTIAL,
// BELONGS_TO, HAS_POLICY, HAS_PERMISSION, USES_SERVICE_ACCOUNT, IRSA_LINKED_TO,
// EXPOSED_TO_INTERNET, CONNECTS_TO_DB 등 - 엔진 쪽 스키마가 바뀌면 값도 바뀔 수 있어
// 별도 enum으로 제한하지 않는다.
export class EdgeData {
  @ApiProperty({ example: 'rel-key-belongs-iam-user' })
  id: string;

  @ApiProperty({ example: 'irsa-gitea-role' })
  source: string;

  @ApiProperty({ example: 'hap-customer-data-s3' })
  target: string;

  @ApiProperty({ example: 'HAS_PERMISSION' })
  relation: string;

  @ApiPropertyOptional({ example: 0.8 })
  weight?: number;

  @ApiPropertyOptional()
  properties?: Record<string, unknown>;
}

export class EdgeDto {
  @ApiProperty({ type: EdgeData })
  data: EdgeData;
}
