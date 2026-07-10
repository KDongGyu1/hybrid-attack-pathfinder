import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { AssetType } from '../../common/enums/asset-type.enum';
import { Environment } from '../../common/enums/environment.enum';
import { SensitivityLevel } from '../../common/enums/sensitivity-level.enum';

export class AssetResponseDto {
  @ApiProperty({ example: 'asset-rds-01' })
  id: string;

  @ApiProperty({ example: 'prod-rds-postgres' })
  name: string;

  @ApiProperty({ enum: AssetType })
  type: AssetType;

  @ApiProperty({ enum: Environment })
  environment: Environment;

  @ApiProperty({ enum: SensitivityLevel })
  sensitivityLevel: SensitivityLevel;

  @ApiPropertyOptional({ type: [String] })
  tags?: string[];

  @ApiPropertyOptional()
  properties?: Record<string, unknown>;

  @ApiPropertyOptional({ example: 5 })
  relatedEdgeCount?: number;

  @ApiPropertyOptional({ type: [String] })
  relatedScenarioIds?: string[];
}
