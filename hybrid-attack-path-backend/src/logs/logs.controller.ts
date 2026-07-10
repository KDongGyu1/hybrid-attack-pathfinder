import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { LogsService } from './logs.service';
import { LogQueryDto } from './dto/log-query.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../common/decorators/roles.decorator';
import { Role } from '../common/enums/role.enum';

@ApiTags('logs')
@ApiBearerAuth('access-token')
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller({ path: 'logs', version: '1' })
export class LogsController {
  constructor(private readonly logsService: LogsService) {}

  @Get()
  @Roles(Role.ADMIN)
  @ApiOperation({ summary: '감사 로그 조회', description: 'API 접근 이력(사용자, 액션, 대상 리소스, 시각) 조회' })
  @ApiResponse({ status: 200, description: '조회 성공' })
  @ApiResponse({ status: 401, description: '인증 실패' })
  @ApiResponse({ status: 403, description: 'ADMIN이 아닌 사용자의 접근 (인가 실패 — 시연 포인트)' })
  findAll(@Query() query: LogQueryDto) {
    return this.logsService.findAll(query);
  }
}
