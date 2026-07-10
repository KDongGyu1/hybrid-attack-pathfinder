import { ApiProperty } from '@nestjs/swagger';

export class LogResponseDto {
  @ApiProperty({ example: 'log-88213' })
  id: string;

  @ApiProperty({ example: 'user-uuid-1234' })
  userId: string;

  @ApiProperty({ example: 'analyst@company.com' })
  userEmail: string;

  @ApiProperty({ example: 'SEARCH_PATH' })
  action: string;

  @ApiProperty({ example: 'asset-onprem-web-01 -> asset-rds-01' })
  targetResource: string;

  @ApiProperty({ example: '10.0.4.21' })
  ipAddress: string;

  @ApiProperty({ example: '2026-07-02T08:40:11.000Z' })
  createdAt: string;
}
