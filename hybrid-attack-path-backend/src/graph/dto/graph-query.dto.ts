import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { SensitivityLevel } from '../../common/enums/sensitivity-level.enum';

export class GraphQueryDto {
  @ApiPropertyOptional({ example: 'scn-iam-privesc' })
  @IsOptional()
  @IsString()
  scenarioId?: string;

  @ApiPropertyOptional({ example: 'hap-gitea-db' })
  @IsOptional()
  @IsString()
  assetId?: string;

  @ApiPropertyOptional({ example: 5, minimum: 1, maximum: 10 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10)
  @Type(() => Number)
  maxDepth?: number;

  // 자산 인벤토리 문서의 분류 기준(Public < Internal < Confidential < Restricted)을 그대로 따른다
  @ApiPropertyOptional({ enum: SensitivityLevel })
  @IsOptional()
  @IsEnum(SensitivityLevel)
  sensitivityLevel?: SensitivityLevel;
}
