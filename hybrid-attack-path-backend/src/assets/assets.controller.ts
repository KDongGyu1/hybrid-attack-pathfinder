import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam, ApiResponse, ApiTags } from '@nestjs/swagger';
import { AssetsService } from './assets.service';
import { AssetQueryDto } from './dto/asset-query.dto';
import { AssetResponseDto } from './dto/asset-response.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';

@ApiTags('assets')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller({ path: 'assets', version: '1' })
export class AssetsController {
  constructor(private readonly assetsService: AssetsService) {}

  @Get()
  @Roles(Role.VIEWER, Role.ANALYST, Role.ADMIN)
  @ApiOperation({ summary: '자산 목록 조회', description: '환경/유형/민감도 등급으로 필터링된 자산 목록을 페이지네이션하여 조회' })
  @ApiResponse({ status: 200, description: '조회 성공' })
  @ApiResponse({ status: 400, description: '쿼리 파라미터 검증 실패' })
  @ApiResponse({ status: 401, description: '인증 실패' })
  findAll(@Query() query: AssetQueryDto) {
    return this.assetsService.findAll(query);
  }

  @Get(':id')
  @Roles(Role.VIEWER, Role.ANALYST, Role.ADMIN)
  @ApiParam({ name: 'id', example: 'asset-rds-01' })
  @ApiOperation({ summary: '자산 상세 조회', description: '특정 자산의 상세 정보 및 연관된 그래프 요약(연결된 엣지 수 등) 조회' })
  @ApiResponse({ status: 200, description: '조회 성공', type: AssetResponseDto })
  @ApiResponse({ status: 401, description: '인증 실패' })
  @ApiResponse({ status: 404, description: '존재하지 않는 자산 ID' })
  findOne(@Param('id') id: string) {
    return this.assetsService.findOne(id);
  }
}
