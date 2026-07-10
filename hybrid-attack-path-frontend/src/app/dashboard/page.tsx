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

export default function DashboardPage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  const [scenarios, setScenarios] = useState<Scenario[]>([]);
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [graph, setGraph] = useState<GraphResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

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
    if (!selectedId) return;
    setError(null);
    api
      .get<GraphResponse>(`/graph/${selectedId}`)
      .then((res) => setGraph(res.data))
      .catch(() => {
        setGraph(null);
        setError('이 시나리오의 그래프를 불러오지 못했습니다. (Backend 1 엔진 연동 전에는 scn-irsa-s3만 목업으로 제공됩니다)');
      });
  }, [selectedId]);

  if (loading || !user) return null;

  const elements = graph ? [...graph.nodes, ...graph.edges] : [];

  return (
    <main className="min-h-screen bg-neutral-50 p-6">
      <AppHeader title="공격 경로 대시보드" />

      <div className="mb-4 flex items-center gap-3">
        <label className="text-sm font-medium text-neutral-700">시나리오</label>
        <select
          value={selectedId ?? ''}
          onChange={(e) => setSelectedId(e.target.value)}
          className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm"
        >
          {scenarios.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name} ({s.severity})
            </option>
          ))}
        </select>
        {graph && (
          <span className="text-xs text-neutral-500">
            노드 {graph.meta.nodeCount} · 엣지 {graph.meta.edgeCount} · 최고 위험도{' '}
            <span className="font-semibold text-red-600">{graph.meta.maxRiskLevel}</span> (
            {graph.meta.maxRiskScore})
          </span>
        )}
      </div>

      {error && <p className="mb-3 text-sm text-amber-600">{error}</p>}

      <GraphView elements={elements} />
    </main>
  );
}
