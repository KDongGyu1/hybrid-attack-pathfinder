import { Controller, Get, Param, Query, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiParam,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { GraphService } from './graph.service';
import { GraphQueryDto } from './dto/graph-query.dto';
import { PathQueryDto } from './dto/path-query.dto';
import { GraphResponseDto } from './dto/graph-response.dto';
import { PathResponseDto } from './dto/path-response.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';

@ApiTags('graph')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller({ path: 'graph', version: '1' })
export class GraphController {
  constructor(private readonly graphService: GraphService) {}

  @Get()
  @Roles(Role.VIEWER, Role.ANALYST, Role.ADMIN)
  @ApiOperation({
    summary: '전체/조건별 공격 경로 그래프 조회',
    description: '조건(자산, 민감도 등급 등)에 맞는 공격 경로 그래프를 nodes/edges 형태로 조회',
  })
  @ApiResponse({ status: 200, description: '조회 성공 (결과 없으면 빈 nodes/edges 배열 반환)', type: GraphResponseDto })
  @ApiResponse({ status: 400, description: '쿼리 파라미터 검증 실패' })
  @ApiResponse({ status: 401, description: '인증 실패' })
  @ApiResponse({ status: 403, description: '권한 부족' })
  findGraph(@Query() query: GraphQueryDto): Promise<GraphResponseDto> {
    return this.graphService.findGraph(query);
  }

  // 주의: NestJS는 라우트를 선언 순서대로 매칭한다. 'paths'가 ':scenarioId'보다
  // 반드시 먼저 와야 GET /graph/paths 요청이 scenarioId="paths"로 잘못 매칭되지 않는다.
  @Get('paths')
  @Roles(Role.ANALYST, Role.ADMIN)
  @ApiOperation({
    summary: '두 자산 간 공격 경로 탐색',
    description: '출발 자산에서 목표 자산까지의 가능한 공격 경로들을 Backend 1 Cypher 엔진에 위임하여 탐색',
  })
  @ApiResponse({ status: 200, description: '탐색 성공 (경로가 없으면 paths: [] 반환)', type: PathResponseDto })
  @ApiResponse({ status: 400, description: 'sourceAssetId/targetAssetId 누락 또는 형식 오류' })
  @ApiResponse({ status: 401, description: '인증 실패' })
  @ApiResponse({ status: 403, description: '권한 부족' })
  @ApiResponse({ status: 404, description: 'sourceAssetId 또는 targetAssetId에 해당하는 자산 없음' })
  findPaths(@Query() query: PathQueryDto): Promise<PathResponseDto> {
    return this.graphService.findPaths(query);
  }

  @Get(':scenarioId')
  @Roles(Role.VIEWER, Role.ANALYST, Role.ADMIN)
  @ApiParam({ name: 'scenarioId', example: 'scn-irsa-s3' })
  @ApiOperation({
    summary: '시나리오별 공격 경로 그래프 조회',
    description: '특정 공격 시나리오 ID에 해당하는 그래프 전체 조회',
  })
  @ApiResponse({ status: 200, description: '조회 성공', type: GraphResponseDto })
  @ApiResponse({ status: 401, description: '인증 실패' })
  @ApiResponse({ status: 403, description: '권한 부족' })
  @ApiResponse({ status: 404, description: '존재하지 않는 시나리오 ID' })
  findGraphByScenario(@Param('scenarioId') scenarioId: string): Promise<GraphResponseDto> {
    return this.graphService.findGraphByScenario(scenarioId);
  }
}
