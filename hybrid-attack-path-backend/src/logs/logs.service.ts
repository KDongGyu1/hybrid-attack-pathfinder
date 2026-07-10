import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Between, Repository } from 'typeorm';
import { LogQueryDto } from './dto/log-query.dto';
import { PaginatedResponseDto } from '../common/dto/paginated-response.dto';
import { LogResponseDto } from './dto/log-response.dto';
import { LogEntry } from './entities/log-entry.entity';

@Injectable()
export class LogsService {
  constructor(@InjectRepository(LogEntry) private readonly logRepo: Repository<LogEntry>) {}

  private toResponse(log: LogEntry): LogResponseDto {
    return {
      id: log.id,
      userId: log.userId,
      userEmail: log.userEmail,
      action: log.action,
      targetResource: log.targetResource,
      ipAddress: log.ipAddress,
      createdAt: log.createdAt.toISOString(),
    };
  }

  async findAll(query: LogQueryDto): Promise<PaginatedResponseDto<LogResponseDto>> {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    const where: Record<string, unknown> = {};
    if (query.userId) where.userId = query.userId;
    if (query.action) where.action = query.action;
    if (query.dateFrom && query.dateTo) {
      where.createdAt = Between(new Date(query.dateFrom), new Date(query.dateTo));
    }

    const [items, totalItems] = await this.logRepo.findAndCount({
      where,
      skip: (page - 1) * limit,
      take: limit,
      order: { createdAt: 'DESC' },
    });

    return {
      items: items.map((log) => this.toResponse(log)),
      meta: {
        page,
        limit,
        totalItems,
        totalPages: Math.max(1, Math.ceil(totalItems / limit)),
      },
    };
  }

  // 인증/조회 시점에 감사 로그를 남기기 위한 헬퍼 (AuthController, GraphController 등에서 호출)
  async record(entry: {
    userId: string;
    userEmail: string;
    action: LogEntry['action'];
    targetResource: string;
    ipAddress: string;
  }): Promise<void> {
    await this.logRepo.save(this.logRepo.create(entry));
  }
}
