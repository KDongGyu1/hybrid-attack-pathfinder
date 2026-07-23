import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class ScenarioResponseDto {
  @ApiProperty({ example: 'S1-A' })
  id: string;

  @ApiProperty({ example: 'dev-01 Access Key 탈취 후 고객 S3 직접 접근' })
  name: string;

  @ApiProperty({
    example: '탈취된 dev-01 IAM Access Key로 hap-dev-01-user 인증 후, S3에 직접 연결된 정책을 통해 고객 데이터 S3 Bucket에 접근 가능한 경로',
  })
  description: string;

  @ApiProperty({ example: 'HIGH', enum: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'] })
  severity: string;

  @ApiPropertyOptional({ example: 'S1-A' })
  graphId?: string;

  @ApiPropertyOptional({ type: [String] })
  mitreTactics?: string[];
}
