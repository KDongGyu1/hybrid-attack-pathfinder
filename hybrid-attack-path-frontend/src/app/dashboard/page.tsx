'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import dynamic from 'next/dynamic';
import { useAuth } from '@/lib/auth-context';
import { api } from '@/lib/api';
import AppHeader from '@/components/AppHeader';

// Cytoscape는 DOM(window)에 의존하므로 SSR 비활성화
const GraphView = dynamic(() => import('@/components/GraphView'), { ssr: false });

interface Scenario {
  id: string;
  name: string;
  description: string;
  severity: string;
}

interface GraphResponse {
  graphId: string;
  scenarioId: string;
  nodes: { data: Record<string, unknown> }[];
  edges: { data: Record<string, unknown> }[];
  meta: { nodeCount: number; edgeCount: number; maxRiskScore: number; maxRiskLevel: string };
}

interface Finding {
  id: string;
  name: string;
  source: string;
  severity: string;
  cvssScore: number | null;
  cveId: string | null;
  findingType: string;
  status: string;
  assetId: string;
}

interface DynamicPath {
  pathId: string;
  sourceAssetId: string;
  targetAssetId: string;
  hopCount: number;
  riskScore: number;
  riskLevel: string;
  findingCount: number;
  findings: Finding[];
  summary: string;
  nodes: { data: Record<string, unknown> }[];
  edges: { data: Record<string, unknown> }[];
}

interface DynamicPathsResponse {
  pathCount: number;
  nodeCount: number;
  edgeCount: number;
  highestRiskScore: number;
  highestRiskLevel: string;
  paths: DynamicPath[];
}

const SEVERITY_STYLE: Record<string, string> = {
  CRITICAL: 'bg-rose-500/15 text-rose-300 ring-1 ring-inset ring-rose-500/30',
  HIGH: 'bg-orange-500/15 text-orange-300 ring-1 ring-inset ring-orange-500/30',
  MEDIUM: 'bg-amber-500/15 text-amber-300 ring-1 ring-inset ring-amber-500/30',
  LOW: 'bg-emerald-500/15 text-emerald-300 ring-1 ring-inset ring-emerald-500/30',
};

function SeverityBadge({ level }: { level: string }) {
  return (
    <span
      className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${
        SEVERITY_STYLE[level] ?? SEVERITY_STYLE.LOW
      }`}
    >
      {level}
    </span>
  );
}

function StatCard({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div className="rounded-xl border border-slate-800 bg-slate-900/60 px-4 py-3">
      <p className="text-[11px] uppercase tracking-wide text-slate-500">{label}</p>
      <p className="mt-1 text-xl font-semibold text-slate-100">{value}</p>
    </div>
  );
}

type TabKey = 'scenario' | 'dynamic';

export default function DashboardPage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  const [tab, setTab] = useState<TabKey>('scenario');

  // 대표 시나리오(고정 5개) 상태
  const [scenarios, setScenarios] = useState<Scenario[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [graph, setGraph] = useState<GraphResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  // 동적 경로(Neo4j 전체 그래프 실시간 탐색) 상태
  const [dynamicPaths, setDynamicPaths] = useState<DynamicPath[]>([]);
  const [dynamicLoaded, setDynamicLoaded] = useState(false);
  const [dynamicError, setDynamicError] = useState<string | null>(null);
  const [selectedPathId, setSelectedPathId] = useState<string | null>(null);

  useEffect(() => {
    if (!loading && !user) router.replace('/login');
  }, [loading, user, router]);

  useEffect(() => {
    if (!user) return;
    api
      .get<Scenario[]>('/scenarios')
      .then((res) => {
        setScenarios(res.data);
        if (res.data.length > 0) setSelectedId(res.data[0].id);
      })
      .catch(() => setError('시나리오 목록을 불러오지 못했습니다.'));
  }, [user]);

  useEffect(() => {
    if (!selectedId || tab !== 'scenario') return;
    setError(null);
    api
      .get<GraphResponse>(`/graph/${selectedId}`)
      .then((res) => setGraph(res.data))
      .catch(() => {
        setGraph(null);
        setError('이 시나리오의 그래프를 불러오지 못했습니다. Backend 1(Neo4j 탐색 엔진)이 실행 중인지 확인하세요.');
      });
  }, [selectedId, tab]);

  // 동적 경로 탭을 처음 열 때만 조회 (67개 경로 + 그래프까지 포함된 응답이라 필요할 때만 로드)
  useEffect(() => {
    if (tab !== 'dynamic' || dynamicLoaded || !user) return;
    setDynamicError(null);
    api
      .get<DynamicPathsResponse>('/graph/dynamic', { params: { limit: 100 } })
      .then((res) => {
        const sorted = [...res.data.paths].sort((a, b) => b.riskScore - a.riskScore);
        setDynamicPaths(sorted);
        setDynamicLoaded(true);
        if (sorted.length > 0) setSelectedPathId(sorted[0].pathId);
      })
      .catch(() => {
        setDynamicError('동적 경로 목록을 불러오지 못했습니다. Backend 1(Neo4j 탐색 엔진)이 실행 중인지 확인하세요.');
      });
  }, [tab, dynamicLoaded, user]);

  if (loading || !user) return null;

  const selectedScenario = scenarios.find((s) => s.id === selectedId);
  const selectedPath = dynamicPaths.find((p) => p.pathId === selectedPathId);

  const elements =
    tab === 'scenario'
      ? graph
        ? [...graph.nodes, ...graph.edges]
        : []
      : selectedPath
        ? [...selectedPath.nodes, ...selectedPath.edges]
        : [];

  return (
    <main className="min-h-screen bg-slate-950 p-6 text-slate-100">
      <AppHeader title="공격 경로 대시보드" />

      {/* 대표 시나리오 / 동적 경로 탭 */}
      <div className="mb-4 flex gap-1 border-b border-slate-800/80">
        {(
          [
            { key: 'scenario' as const, label: '대표 시나리오' },
            { key: 'dynamic' as const, label: `동적 경로${dynamicLoaded ? ` (${dynamicPaths.length})` : ''}` },
          ]
        ).map((t) => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={`relative px-3 py-2 text-sm font-medium transition ${
              tab === t.key ? 'text-slate-50' : 'text-slate-500 hover:text-slate-300'
            }`}
          >
            {t.label}
            {tab === t.key && (
              <span className="absolute inset-x-2 -bottom-px h-0.5 rounded-full bg-gradient-to-r from-indigo-500 to-cyan-400" />
            )}
          </button>
        ))}
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-[280px_1fr]">
        {tab === 'scenario' ? (
          <>
            {/* 시나리오 선택 사이드 패널 */}
            <aside className="rounded-xl border border-slate-800 bg-slate-900/40 p-3">
              <p className="mb-2 px-1 text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                공격 시나리오
              </p>
              <div className="flex flex-col gap-1.5">
                {scenarios.map((s) => {
                  const active = s.id === selectedId;
                  return (
                    <button
                      key={s.id}
                      onClick={() => setSelectedId(s.id)}
                      className={`rounded-lg border px-3 py-2 text-left text-xs transition ${
                        active
                          ? 'border-indigo-500/40 bg-indigo-500/10 text-slate-100'
                          : 'border-transparent bg-slate-900/40 text-slate-400 hover:border-slate-700 hover:bg-slate-800/50'
                      }`}
                    >
                      <div className="mb-1 flex items-center justify-between gap-2">
                        <span className="font-medium leading-snug">{s.name}</span>
                      </div>
                      <SeverityBadge level={s.severity} />
                    </button>
                  );
                })}
                {scenarios.length === 0 && !error && (
                  <p className="px-1 text-xs text-slate-500">불러오는 중...</p>
                )}
              </div>
            </aside>

            {/* 메인 영역 */}
            <div className="min-w-0">
              <div className="mb-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
                <StatCard label="노드" value={graph?.meta.nodeCount ?? '-'} />
                <StatCard label="엣지" value={graph?.meta.edgeCount ?? '-'} />
                <StatCard
                  label="최고 위험도"
                  value={graph ? <SeverityBadge level={graph.meta.maxRiskLevel} /> : '-'}
                />
                <StatCard label="리스크 점수" value={graph?.meta.maxRiskScore ?? '-'} />
              </div>

              {selectedScenario && (
                <p className="mb-3 text-xs leading-relaxed text-slate-400">{selectedScenario.description}</p>
              )}

              {error && (
                <p className="mb-3 rounded-lg border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-xs text-amber-300">
                  {error}
                </p>
              )}

              <GraphView elements={elements} />
            </div>
          </>
        ) : (
          <>
            {/* 동적 경로 목록 사이드 패널 (위험도순) */}
            <aside className="rounded-xl border border-slate-800 bg-slate-900/40 p-3">
              <p className="mb-2 px-1 text-[11px] font-semibold uppercase tracking-wide text-slate-500">
                동적 공격 경로 (위험도순)
              </p>
              <div className="flex max-h-[640px] flex-col gap-1.5 overflow-y-auto pr-1">
                {dynamicPaths.map((p) => {
                  const active = p.pathId === selectedPathId;
                  return (
                    <button
                      key={p.pathId}
                      onClick={() => setSelectedPathId(p.pathId)}
                      className={`rounded-lg border px-3 py-2 text-left text-xs transition ${
                        active
                          ? 'border-indigo-500/40 bg-indigo-500/10 text-slate-100'
                          : 'border-transparent bg-slate-900/40 text-slate-400 hover:border-slate-700 hover:bg-slate-800/50'
                      }`}
                    >
                      <div className="mb-1 flex items-center justify-between gap-2">
                        <span className="font-medium leading-snug">
                          {p.sourceAssetId} → {p.targetAssetId}
                        </span>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <SeverityBadge level={p.riskLevel} />
                        <span className="text-[10px] text-slate-500">{p.hopCount} hops</span>
                        {p.findingCount > 0 && (
                          <span className="text-[10px] text-slate-500">· 취약점 {p.findingCount}건</span>
                        )}
                      </div>
                    </button>
                  );
                })}
                {!dynamicLoaded && !dynamicError && (
                  <p className="px-1 text-xs text-slate-500">불러오는 중...</p>
                )}
                {dynamicLoaded && dynamicPaths.length === 0 && (
                  <p className="px-1 text-xs text-slate-500">조회된 동적 경로가 없습니다.</p>
                )}
              </div>
            </aside>

            {/* 메인 영역 */}
            <div className="min-w-0">
              <div className="mb-4 grid grid-cols-2 gap-3 sm:grid-cols-4">
                <StatCard label="노드" value={selectedPath?.nodes.length ?? '-'} />
                <StatCard label="엣지" value={selectedPath?.edges.length ?? '-'} />
                <StatCard
                  label="위험도"
                  value={selectedPath ? <SeverityBadge level={selectedPath.riskLevel} /> : '-'}
                />
                <StatCard label="리스크 점수" value={selectedPath?.riskScore ?? '-'} />
              </div>

              {selectedPath && (
                <p className="mb-3 text-xs leading-relaxed text-slate-400">{selectedPath.summary}</p>
              )}

              {selectedPath && selectedPath.findings.length > 0 && (
                <div className="mb-3 flex flex-wrap gap-1.5">
                  {selectedPath.findings.map((f) => (
                    <span
                      key={f.id}
                      title={`${f.findingType} · ${f.source} · ${f.status}`}
                      className="rounded-full border border-slate-700 bg-slate-900/60 px-2 py-1 text-[10px] text-slate-300"
                    >
                      {f.cveId ?? f.name} ({f.severity}
                      {f.cvssScore ? ` ${f.cvssScore}` : ''})
                    </span>
                  ))}
                </div>
              )}

              {dynamicError && (
                <p className="mb-3 rounded-lg border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-xs text-amber-300">
                  {dynamicError}
                </p>
              )}

              <GraphView elements={elements} />
            </div>
          </>
        )}
      </div>
    </main>
  );
}
