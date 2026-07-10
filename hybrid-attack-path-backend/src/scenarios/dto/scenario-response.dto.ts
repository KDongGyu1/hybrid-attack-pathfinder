import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class ScenarioResponseDto {
  @ApiProperty({ example: 'scn-irsa-s3' })
  id: string;

  @ApiProperty({ example: 'Pod 침해 -> IRSA -> S3/RDS 접근' })
  name: string;

  @ApiProperty({ example: 'Pod 침해로 ServiceAccount 토큰 탈취 후 IRSA를 통한 S3/RDS 접근' })
  description: string;

  @ApiProperty({ example: 'CRITICAL', enum: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'] })
  severity: string;

  @ApiPropertyOptional({ example: 'scn-irsa-s3' })
  graphId?: string;

  @ApiPropertyOptional({ type: [String] })
  mitreTactics?: string[];
}
