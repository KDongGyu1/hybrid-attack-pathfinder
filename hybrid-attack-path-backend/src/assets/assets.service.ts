import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { AssetQueryDto } from './dto/asset-query.dto';
import { PaginatedResponseDto } from '../common/dto/paginated-response.dto';
import { AssetResponseDto } from './dto/asset-response.dto';
import { Asset } from './entities/asset.entity';

@Injectable()
export class AssetsService {
  constructor(@InjectRepository(Asset) private readonly assetRepo: Repository<Asset>) {}

  private toResponse(asset: Asset): AssetResponseDto {
    return {
      id: asset.id,
      name: asset.name,
      type: asset.type,
      environment: asset.environment,
      sensitivityLevel: asset.sensitivityLevel,
      tags: asset.tags,
      properties: asset.properties,
      relatedScenarioIds: asset.relatedScenarioIds,
      // relatedEdgeCount는 Backend 1(Neo4j) 그래프 연동 후 채워질 필드 (TODO)
    };
  }

  async findAll(query: AssetQueryDto): Promise<PaginatedResponseDto<AssetResponseDto>> {
    const page = query.page ?? 1;
    const limit = query.limit ?? 20;

    const where: Record<string, unknown> = {};
    if (query.type) where.type = query.type;
    if (query.environment) where.environment = query.environment;
    if (query.sensitivityLevel) where.sensitivityLevel = query.sensitivityLevel;

    const [items, totalItems] = await this.assetRepo.findAndCount({
      where,
      skip: (page - 1) * limit,
      take: limit,
      order: { id: 'ASC' },
    });

    return {
      items: items.map((asset) => this.toResponse(asset)),
      meta: {
        page,
        limit,
        totalItems,
        totalPages: Math.max(1, Math.ceil(totalItems / limit)),
      },
    };
  }

  async findOne(id: string): Promise<AssetResponseDto> {
    const asset = await this.assetRepo.findOne({ where: { id } });
    if (!asset) {
      throw new NotFoundException(`자산을 찾을 수 없습니다: ${id}`);
    }
    return this.toResponse(asset);
  }
}
