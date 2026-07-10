import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Environment } from '../../common/enums/environment.enum';
import { SensitivityLevel } from '../../common/enums/sensitivity-level.enum';

// 주의: type은 AssetType(14종)에 한정되지 않는다. Backend 1 Neo4j 스키마의
// GraphNodeType(INTERNET, IAM_USER, IAM_ROLE, IAM_POLICY, VPC, SUBNET,
// SECURITY_GROUP, ON_PREM_SERVER, EKS_POD, S3_BUCKET, FINDING 등)을 그대로 통과시킨다.
export class NodeData {
  @ApiProperty({ example: 'irsa-gitea-role' })
  id: string;

  @ApiProperty({ example: 'irsa-gitea-role (IRSA)' })
  label: string;

  @ApiProperty({ example: 'IAM_ACCOUNT', description: 'GraphNodeType - Backend 1 스키마 그대로 통과' })
  type: string;

  @ApiPropertyOptional({ enum: Environment })
  environment?: Environment;

  @ApiPropertyOptional({ enum: SensitivityLevel })
  sensitivityLevel?: SensitivityLevel;

  @ApiPropertyOptional()
  properties?: Record<string, unknown>;
}

export class NodeDto {
  @ApiProperty({ type: NodeData })
  data: NodeData;
}
