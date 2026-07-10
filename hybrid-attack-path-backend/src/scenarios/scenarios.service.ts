import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ScenarioResponseDto } from './dto/scenario-response.dto';
import { Scenario } from './entities/scenario.entity';

@Injectable()
export class ScenariosService {
  constructor(@InjectRepository(Scenario) private readonly scenarioRepo: Repository<Scenario>) {}

  private toResponse(scenario: Scenario): ScenarioResponseDto {
    return {
      id: scenario.id,
      name: scenario.name,
      description: scenario.description,
      severity: scenario.severity,
      graphId: scenario.graphId,
      mitreTactics: scenario.mitreTactics,
    };
  }

  async findAll(): Promise<ScenarioResponseDto[]> {
    const scenarios = await this.scenarioRepo.find({ order: { id: 'ASC' } });
    return scenarios.map((scenario) => this.toResponse(scenario));
  }

  async findOne(id: string): Promise<ScenarioResponseDto> {
    const scenario = await this.scenarioRepo.findOne({ where: { id } });
    if (!scenario) {
      throw new NotFoundException(`시나리오를 찾을 수 없습니다: ${id}`);
    }
    return this.toResponse(scenario);
  }
}
