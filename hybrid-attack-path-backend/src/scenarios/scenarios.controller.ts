import { Controller, Get, Param, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiParam, ApiResponse, ApiTags } from '@nestjs/swagger';
import { ScenariosService } from './scenarios.service';
import { ScenarioResponseDto } from './dto/scenario-response.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';

@ApiTags('scenarios')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller({ path: 'scenarios', version: '1' })
export class ScenariosController {
  constructor(private readonly scenariosService: ScenariosService) {}

  @Get()
  @Roles(Role.VIEWER, Role.ANALYST, Role.ADMIN)
  @ApiOperation({ summary: '공격 시나리오 목록 조회', description: '사전 정의된 공격 시나리오 목록 조회 (발표 시연 시 시나리오 선택 UI에 사용)' })
  @ApiResponse({ status: 200, description: '조회 성공', type: [ScenarioResponseDto] })
  @ApiResponse({ status: 401, description: '인증 실패' })
  findAll() {
    return this.scenariosService.findAll();
  }

  @Get(':id')
  @Roles(Role.VIEWER, Role.ANALYST, Role.ADMIN)
  @ApiParam({ name: 'id', example: 'scn-irsa-s3' })
  @ApiOperation({ summary: '공격 시나리오 상세 조회', description: '시나리오 상세 설명 및 연결된 그래프 조회용 graphId 제공' })
  @ApiResponse({ status: 200, description: '조회 성공', type: ScenarioResponseDto })
  @ApiResponse({ status: 401, description: '인증 실패' })
  @ApiResponse({ status: 404, description: '존재하지 않는 시나리오 ID' })
  findOne(@Param('id') id: string) {
    return this.scenariosService.findOne(id);
  }
}
