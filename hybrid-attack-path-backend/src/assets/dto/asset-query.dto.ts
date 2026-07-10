import { ApiPropertyOptional } from '@nestjs/swagger';
import { IsEnum, IsInt, IsOptional, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';
import { AssetType } from '../../common/enums/asset-type.enum';
import { Environment } from '../../common/enums/environment.enum';
import { SensitivityLevel } from '../../common/enums/sensitivity-level.enum';

export class AssetQueryDto {
  // 자산 인벤토리 문서의 시스템 영역(7~20번) 14종과 1:1 매핑
  @ApiPropertyOptional({ enum: AssetType })
  @IsOptional()
  @IsEnum(AssetType)
  type?: AssetType;

  @ApiPropertyOptional({ enum: Environment })
  @IsOptional()
  @IsEnum(Environment)
  environment?: Environment;

  // 자산 인벤토리 문서 2장 분류 기준(Public < Internal < Confidential < Restricted)
  @ApiPropertyOptional({ enum: SensitivityLevel })
  @IsOptional()
  @IsEnum(SensitivityLevel)
  sensitivityLevel?: SensitivityLevel;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Type(() => Number)
  page?: number = 1;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  @Type(() => Number)
  limit?: number = 20;
}
