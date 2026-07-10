import { ApiProperty } from '@nestjs/swagger';

export class PathDto {
  @ApiProperty({ example: 'path-01' })
  pathId: string;

  @ApiProperty({ example: 5 })
  hopCount: number;

  @ApiProperty({ example: 8.7 })
  riskScore: number;

  @ApiProperty({ example: 'CRITICAL', enum: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'] })
  riskLevel: string;

  @ApiProperty({ type: [String] })
  nodeIds: string[];

  @ApiProperty({ type: [String] })
  edgeIds: string[];

  // Backend 1 PathResponse 형식(v1.1)을 따르는 자연어 요약
  @ApiProperty({ example: '온프레미스 웹 서버(WordPress)에 저장된 AWS IAM 액세스 키 탈취 후, 해당 키로 S3ReadOnlyRole을 이용해 S3(고객데이터 버킷)에 접근 가능한 경로' })
  summary: string;
}

export class PathResponseDto {
  @ApiProperty({ example: 'asset-onprem-web-01' })
  sourceAssetId: string;

  @ApiProperty({ example: 'asset-s3-01' })
  targetAssetId: string;

  @ApiProperty({ type: [PathDto] })
  paths: PathDto[];
}
