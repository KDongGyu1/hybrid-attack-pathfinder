import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsNotEmpty, IsOptional, IsString, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class PathQueryDto {
  @ApiProperty({ example: 'asset-onprem-web-01' })
  @IsString()
  @IsNotEmpty()
  sourceAssetId: string;

  @ApiProperty({ example: 'asset-s3-01' })
  @IsString()
  @IsNotEmpty()
  targetAssetId: string;

  @ApiPropertyOptional({ example: 6, default: 6 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(10)
  @Type(() => Number)
  maxHops?: number = 6;
}
