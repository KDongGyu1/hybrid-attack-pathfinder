import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Request, Response } from 'express';

// 2.3 일관된 응답 포맷 (에러) - 9.1 공통 에러 응답 포맷 참고
@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('ExceptionFilter');

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    const message =
      exception instanceof HttpException
        ? exception.getResponse()
        : 'Internal server error';

    // HttpException이 아닌 예상 못한 에러(DB 쿼리 실패 등)는 콘솔에 스택트레이스를 남긴다.
    // 원래 이 로그가 없어서 500 에러가 터져도 터미널에 아무 흔적이 안 남았음.
    if (!(exception instanceof HttpException)) {
      this.logger.error(
        `${request.method} ${request.url} 처리 중 예외 발생`,
        exception instanceof Error ? exception.stack : String(exception),
      );
    }

    response.status(status).json({
      statusCode: status,
      message: (message as any)?.message ?? message,
      error: (message as any)?.error ?? HttpStatus[status],
      path: request.url,
      timestamp: new Date().toISOString(),
    });
  }
}
