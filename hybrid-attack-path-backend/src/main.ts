import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);

  // nginx(리버스 프록시) 뒤에서 실행되므로 X-Forwarded-For를 신뢰해야 req.ip가
  // nginx 컨테이너 IP가 아닌 실제 클라이언트 IP를 반환한다 (감사 로그 ipAddress 정확성).
  app.set('trust proxy', true);

  // 프론트(localhost:3001 등)에서의 요청 허용 — CORS 미설정 시 preflight(OPTIONS)가 404로 응답됨
  app.enableCors({
    origin: true,
    credentials: true,
  });

  // 2.2 버전 관리: 모든 엔드포인트 /api/v1 프리픽스
  app.enableVersioning({
    type: VersioningType.URI,
    defaultVersion: '1',
  });
  app.setGlobalPrefix('api');

  // 2.5 DTO 기반 계약 우선 설계
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );

  // 2.3 일관된 응답 포맷 (에러)
  app.useGlobalFilters(new HttpExceptionFilter());

  // 7.1 Swagger 전역 설정
  const config = new DocumentBuilder()
    .setTitle('Hybrid Attack Path Analysis API')
    .setDescription('공격 경로 탐색 시스템 REST API 문서')
    .setVersion('1.0')
    .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'access-token')
    .addTag('auth', '인증/인가')
    .addTag('graph', '공격 경로 그래프')
    .addTag('assets', '자산')
    .addTag('scenarios', '공격 시나리오')
    .addTag('logs', '감사 로그')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);

  await app.listen(process.env.PORT ?? 3000);
}
bootstrap();
