import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsInt, IsNotEmpty, IsOptional, IsString, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class PathQueryDto {
  @ApiProperty({ example: 'hap-onprem-web' })
  @IsString()
  @IsNotEmpty()
  sourceAssetId: string;

  @ApiProperty({ example: 'hap-customer-data-s3' })
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
