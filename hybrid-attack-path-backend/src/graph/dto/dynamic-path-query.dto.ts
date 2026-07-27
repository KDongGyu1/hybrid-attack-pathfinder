import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsNumber, IsOptional, IsString, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

// Backend 1 엔진의 GET /dynamic-attack-paths 쿼리 파라미터를 그대로 통과시킨다.
// (2026-07-23 상범님이 신규 추가한 동적 탐색 엔드포인트 — Neo4j 전체 그래프 기준으로
// 고정 시나리오 없이 실시간으로 공격 경로를 계산한다.)
export class DynamicPathQueryDto {
  @ApiPropertyOptional({ example: 8, minimum: 1, maximum: 15, default: 8 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(15)
  @Type(() => Number)
  maxDepth?: number;

  @ApiPropertyOptional({ example: 20, minimum: 1, maximum: 200, default: 20 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(200)
  @Type(() => Number)
  limit?: number;

  @ApiPropertyOptional({ example: 0, minimum: 0 })
  @IsOptional()
  @IsNumber()
  @Min(0)
  @Type(() => Number)
  minRiskScore?: number;

  @ApiPropertyOptional({ example: 'internet' })
  @IsOptional()
  @IsString()
  sourceId?: string;

  @ApiPropertyOptional({ example: 'hap-customer-data-s3' })
  @IsOptional()
  @IsString()
  targetId?: string;
}
