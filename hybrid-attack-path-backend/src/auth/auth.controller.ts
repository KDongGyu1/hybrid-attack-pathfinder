import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import {
  ApiBearerAuth,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { LoginRequestDto } from './dto/login-request.dto';
import { LoginResponseDto } from './dto/login-response.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@ApiTags('auth')
@Controller({ path: 'auth', version: '1' })
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('login')
  @ApiOperation({ summary: '로그인', description: '이메일/비밀번호 인증 후 Access/Refresh Token 발급' })
  @ApiResponse({ status: 200, description: '로그인 성공, 토큰 발급', type: LoginResponseDto })
  @ApiResponse({ status: 400, description: '요청 본문 검증 실패 (이메일 형식 오류 등)' })
  @ApiResponse({ status: 401, description: '이메일 또는 비밀번호 불일치' })
  login(@Body() dto: LoginRequestDto) {
    return this.authService.login(dto);
  }

  @Post('refresh')
  @ApiOperation({ summary: 'Access Token 재발급', description: '만료된 Access Token을 Refresh Token으로 재발급' })
  @ApiResponse({ status: 200, description: '재발급 성공' })
  @ApiResponse({ status: 401, description: 'Refresh Token 만료 또는 위변조' })
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refresh(dto.refreshToken);
  }

  @Get('me')
  @ApiBearerAuth('access-token')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: '내 정보 조회', description: '현재 로그인한 사용자 정보 조회 (인증/인가 시연용)' })
  @ApiResponse({ status: 200, description: '조회 성공' })
  @ApiResponse({ status: 401, description: '토큰 없음 또는 만료' })
  me(@Req() req: any) {
    return this.authService.me(req.user?.userId);
  }
}
