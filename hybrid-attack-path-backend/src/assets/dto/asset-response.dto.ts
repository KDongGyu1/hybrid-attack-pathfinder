import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { AssetType } from '../../common/enums/asset-type.enum';
import { Environment } from '../../common/enums/environment.enum';
import { SensitivityLevel } from '../../common/enums/sensitivity-level.enum';

export class AssetResponseDto {
  @ApiProperty({ example: 'hap-gitea-db' })
  id: string;

  @ApiProperty({ example: 'RDS (Gitea DB)' })
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
