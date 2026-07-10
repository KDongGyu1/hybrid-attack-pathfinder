import {
  HttpException,
  Injectable,
  InternalServerErrorException,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios, { AxiosInstance } from 'axios';
import { GraphQueryDto } from './dto/graph-query.dto';
import { PathQueryDto } from './dto/path-query.dto';
import { GraphResponseDto } from './dto/graph-response.dto';
import { PathResponseDto } from './dto/path-response.dto';
import { NodeData } from './dto/node.dto';
import { EdgeData } from './dto/edge.dto';
import { Environment } from '../common/enums/environment.enum';
import { SensitivityLevel } from '../common/enums/sensitivity-level.enum';

// GraphService: Backend 1(Neo4j/Cypher) 탐색 결과를 REST DTO로 변환하는 어댑터.
// Neo4j 스키마/Cypher 쿼리가 바뀌어도 이 서비스 내부만 수정하면 Controller와
// 프론트엔드 계약(DTO)에는 영향이 없도록 한다. (설계 원칙 2.4, 2.8, 8.7)
//
// 2026-07-10: 상범님의 FastAPI 엔진(hybrid-attack-pathfinder, feature/backend1-neo4j-engine
// 브랜치 app/api_server.py + app/path_finder.py)에 실제로 연동함. 목업 반환은 제거됨.
// 엔진 주소는 GRAPH_ENGINE_BASE_URL 환경변수로 설정 (.env.example 참고).

// Backend 1 FastAPI가 실제로 반환하는 원본 노드/엣지 형태.
// 우리 DTO와 필드명이 다른 부분(엣지 type -> relation 등)을 이 서비스에서 변환한다.
interface EngineNode {
  id: string;
  label: string;
  type: string;
  environment?: string;
  assetRole?: string;
  sensitivityLevel?: string;
  riskLevel?: string;
}

interface EngineEdge {
  id: string;
  source: string;
  target: string;
  type: string;
  action?: string | null;
}

interface EnginePath {
  pathId: string;
  hopCount: number;
  riskScore: number;
  riskLevel: string;
  nodeIds: string[];
  edgeIds: string[];
  summary: string;
}

interface EngineScenarioResult {
  scenarioId: string;
  scenarioName: string;
  sourceAssetId: string;
  targetAssetId: string | null;
  riskScore: number;
  riskLevel: string;
  pathCount: number;
  nodes: EngineNode[];
  edges: EngineEdge[];
  paths: EnginePath[];
  summary: string;
}

interface EngineScenarioSummary {
  scenarioId: string;
  scenarioName: string;
  sourceAssetId: string;
  targetAssetId: string | null;
  summary: string;
}

@Injectable()
export class GraphService {
  private readonly logger = new Logger(GraphService.name);
  private readonly client: AxiosInstance;

  constructor(private readonly config: ConfigService) {
    this.client = axios.create({
      baseURL: this.config.get<string>('GRAPH_ENGINE_BASE_URL') ?? 'http://localhost:8000',
      timeout: 5000,
    });
  }

  // Backend 1의 environment 값(ON_PREM/PROD)은 우리 Environment enum과 1:1로 안 맞는다.
  // node type으로 EKS 계열인지 구분해서 최대한 정확히 매핑한다 (완전한 매핑은 아님 - 임시 처리).
  private mapEnvironment(raw?: string, nodeType?: string): Environment | undefined {
    if (!raw) return undefined;
    if (raw === 'ON_PREM') return Environment.ON_PREM;
    if (raw === 'PROD') {
      if (nodeType === 'EKS_POD' || nodeType === 'SERVICE_ACCOUNT') return Environment.AWS_EKS;
      return Environment.AWS;
    }
    return undefined;
  }

  private mapNode(node: EngineNode): NodeData {
    return {
      id: node.id,
      label: node.label,
      type: node.type,
      environment: this.mapEnvironment(node.environment, node.type),
      sensitivityLevel: node.sensitivityLevel as SensitivityLevel | undefined,
      properties: {
        ...(node.assetRole ? { assetRole: node.assetRole } : {}),
        ...(node.riskLevel ? { riskLevel: node.riskLevel } : {}),
      },
    };
  }

  private mapEdge(edge: EngineEdge): EdgeData {
    return {
      id: edge.id,
      source: edge.source,
      target: edge.target,
      relation: edge.type,
      properties: edge.action ? { action: edge.action } : undefined,
    };
  }

  // Backend 1 엔진 호출 실패를 우리 API의 표준 에러 응답으로 변환한다.
  // (404 = 존재하지 않는 시나리오, 그 외 = 엔진 서버 자체에 연결 불가/오류)
  private toEngineException(err: unknown, scenarioId?: string): HttpException {
    if (axios.isAxiosError(err)) {
      if (err.response?.status === 404) {
        return new NotFoundException(`시나리오를 찾을 수 없습니다: ${scenarioId}`);
      }
      this.logger.error(
        `Backend 1 엔진 호출 실패${scenarioId ? ` (scenarioId=${scenarioId})` : ''}: ${err.message}`,
      );
      return new ServiceUnavailableException(
        'Backend 1(Neo4j 탐색 엔진) 서버에 연결할 수 없습니다. 엔진이 실행 중인지 확인하세요.',
      );
    }
    this.logger.error(`예상치 못한 오류: ${err instanceof Error ? err.stack : String(err)}`);
    return new InternalServerErrorException();
  }

  private async fetchScenario(scenarioId: string): Promise<EngineScenarioResult> {
    try {
      const res = await this.client.get<EngineScenarioResult>(`/attack-paths/${scenarioId}`);
      return res.data;
    } catch (err) {
      throw this.toEngineException(err, scenarioId);
    }
  }

  private toGraphResponse(result: EngineScenarioResult): GraphResponseDto {
    return {
      graphId: result.scenarioId,
      scenarioId: result.scenarioId,
      generatedAt: new Date().toISOString(),
      nodes: result.nodes.map((n) => ({ data: this.mapNode(n) })),
      edges: result.edges.map((e) => ({ data: this.mapEdge(e) })),
      meta: {
        nodeCount: result.nodes.length,
        edgeCount: result.edges.length,
        maxRiskScore: result.riskScore,
        maxRiskLevel: result.riskLevel,
      },
    };
  }

  async findGraph(query: GraphQueryDto): Promise<GraphResponseDto> {
    if (query.scenarioId) {
      return this.findGraphByScenario(query.scenarioId);
    }

    // 시나리오 지정이 없으면 전체 시나리오의 그래프를 하나로 합쳐서 반환한다.
    let allResults: EngineScenarioResult[];
    try {
      const res = await this.client.get<{ results: EngineScenarioResult[] }>('/attack-paths');
      allResults = res.data.results;
    } catch (err) {
      throw this.toEngineException(err);
    }

    const nodeMap = new Map<string, EngineNode>();
    const edgeMap = new Map<string, EngineEdge>();
    let maxRiskScore = 0;
    let maxRiskLevel = 'LOW';

    for (const result of allResults) {
      for (const node of result.nodes) nodeMap.set(node.id, node);
      for (const edge of result.edges) edgeMap.set(edge.id, edge);
      if (result.riskScore > maxRiskScore) {
        maxRiskScore = result.riskScore;
        maxRiskLevel = result.riskLevel;
      }
    }

    let nodes = Array.from(nodeMap.values());
    let edges = Array.from(edgeMap.values());

    // assetId/sensitivityLevel 필터는 엔진이 모르는 우리 쪽 계약이라 응답을 받은 뒤 후처리한다.
    if (query.sensitivityLevel) {
      nodes = nodes.filter((n) => n.sensitivityLevel === query.sensitivityLevel);
      const remainingIds = new Set(nodes.map((n) => n.id));
      edges = edges.filter((e) => remainingIds.has(e.source) && remainingIds.has(e.target));
    }
    if (query.assetId) {
      const targetId = query.assetId;
      edges = edges.filter((e) => e.source === targetId || e.target === targetId);
      const connectedIds = new Set<string>([targetId, ...edges.flatMap((e) => [e.source, e.target])]);
      nodes = nodes.filter((n) => connectedIds.has(n.id));
    }

    return {
      graphId: 'all-scenarios',
      scenarioId: 'all-scenarios',
      generatedAt: new Date().toISOString(),
      nodes: nodes.map((n) => ({ data: this.mapNode(n) })),
      edges: edges.map((e) => ({ data: this.mapEdge(e) })),
      meta: {
        nodeCount: nodes.length,
        edgeCount: edges.length,
        maxRiskScore,
        maxRiskLevel,
      },
    };
  }

  async findGraphByScenario(scenarioId: string): Promise<GraphResponseDto> {
    const result = await this.fetchScenario(scenarioId);
    return this.toGraphResponse(result);
  }

  async findPaths(query: PathQueryDto): Promise<PathResponseDto> {
    // 주의: Backend 1 엔진은 임의의 source/target 쌍을 탐색하는 범용 기능이 없고,
    // 미리 정의된 시나리오(고정 source/target)만 조회 가능하다. 쿼리와 source/target이
    // 일치하는 시나리오를 찾아 위임하고, 없으면 빈 paths를 반환한다. (엔진 쪽 제약사항)
    let scenarios: EngineScenarioSummary[];
    try {
      const res = await this.client.get<{ scenarios: EngineScenarioSummary[] }>('/scenarios');
      scenarios = res.data.scenarios;
    } catch (err) {
      throw this.toEngineException(err);
    }

    const matched = scenarios.find(
      (s) => s.sourceAssetId === query.sourceAssetId && s.targetAssetId === query.targetAssetId,
    );

    if (!matched) {
      return { sourceAssetId: query.sourceAssetId, targetAssetId: query.targetAssetId, paths: [] };
    }

    const result = await this.fetchScenario(matched.scenarioId);
    const maxHops = query.maxHops;

    return {
      sourceAssetId: query.sourceAssetId,
      targetAssetId: query.targetAssetId,
      paths: result.paths
        .filter((p) => (maxHops ? p.hopCount <= maxHops : true))
        .map((p) => ({
          pathId: p.pathId,
          hopCount: p.hopCount,
          riskScore: p.riskScore,
          riskLevel: p.riskLevel,
          nodeIds: p.nodeIds,
          edgeIds: p.edgeIds,
          summary: p.summary,
        })),
    };
  }
}
