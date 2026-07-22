'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';
import { api } from '@/lib/api';
import AppHeader from '@/components/AppHeader';

// 2026-07-14: VPN Gateway/Bastion/Management Server는 v2 아키텍처에서 제거된 구성이라 목록에서도 삭제.
const ASSET_TYPES = [
  'WEB_SERVER',
  'DB_SERVER',
  'ALB',
  'APP_SERVER',
  'APP_POD',
  'RDS',
  'S3',
  'IAM_ACCOUNT',
  'NAT_GATEWAY',
  'NETWORK_CONFIG',
  'SERVICE_ACCOUNT',
] as const;

const ENVIRONMENTS = ['AWS', 'AWS_EKS', 'ON_PREM', 'HYBRID', 'EXTERNAL'] as const;
const SENSITIVITY_LEVELS = ['PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'] as const;

interface Asset {
  id: string;
  name: string;
  type: string;
  environment: string;
  sensitivityLevel: string;
  tags?: string[];
  relatedEdgeCount?: number;
}

interface PaginatedAssets {
  items: Asset[];
  meta: { page: number; limit: number; totalItems: number; totalPages: number };
}

function extractErrorMessage(err: unknown): string {
  if (err && typeof err === 'object' && 'response' in err) {
    const message = (err as { response?: { data?: { message?: string } } }).response?.data
      ?.message;
    if (message) return message;
  }
  return '자산 목록을 불러오지 못했습니다.';
}

export default function AssetsPage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  const [type, setType] = useState('');
  const [environment, setEnvironment] = useState('');
  const [sensitivityLevel, setSensitivityLevel] = useState('');
  const [page, setPage] = useState(1);

  const [data, setData] = useState<PaginatedAssets | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!loading && !user) router.replace('/login');
  }, [loading, user, router]);

  useEffect(() => {
    if (!user) return;
    setError(null);
    api
      .get<PaginatedAssets>('/assets', {
        params: {
          type: type || undefined,
          environment: environment || undefined,
          sensitivityLevel: sensitivityLevel || undefined,
          page,
          limit: 20,
        },
      })
      .then((res) => setData(res.data))
      .catch((err) => {
        setData(null);
        setError(extractErrorMessage(err));
      });
  }, [user, type, environment, sensitivityLevel, page]);

  if (loading || !user) return null;

  const sensitivityStyle: Record<string, string> = {
    PUBLIC: 'bg-slate-500/15 text-slate-300',
    INTERNAL: 'bg-sky-500/15 text-sky-300',
    CONFIDENTIAL: 'bg-amber-500/15 text-amber-300',
    RESTRICTED: 'bg-rose-500/15 text-rose-300',
  };

  return (
    <main className="min-h-screen bg-slate-950 p-6 text-slate-100">
      <AppHeader title="자산 목록" />

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <select
          value={type}
          onChange={(e) => {
            setPage(1);
            setType(e.target.value);
          }}
          className="rounded-md border border-slate-700 bg-slate-900/60 px-3 py-1.5 text-sm text-slate-200"
        >
          <option value="">전체 유형</option>
          {ASSET_TYPES.map((t) => (
            <option key={t} value={t}>
              {t}
            </option>
          ))}
        </select>

        <select
          value={environment}
          onChange={(e) => {
            setPage(1);
            setEnvironment(e.target.value);
          }}
          className="rounded-md border border-slate-700 bg-slate-900/60 px-3 py-1.5 text-sm text-slate-200"
        >
          <option value="">전체 환경</option>
          {ENVIRONMENTS.map((e) => (
            <option key={e} value={e}>
              {e}
            </option>
          ))}
        </select>

        <select
          value={sensitivityLevel}
          onChange={(e) => {
            setPage(1);
            setSensitivityLevel(e.target.value);
          }}
          className="rounded-md border border-slate-700 bg-slate-900/60 px-3 py-1.5 text-sm text-slate-200"
        >
          <option value="">전체 민감도</option>
          {SENSITIVITY_LEVELS.map((s) => (
            <option key={s} value={s}>
              {s}
            </option>
          ))}
        </select>

        {data && (
          <span className="text-xs text-slate-500">
            총 {data.meta.totalItems}건 · {data.meta.page}/{data.meta.totalPages} 페이지
          </span>
        )}
      </div>

      {error && (
        <p className="mb-3 rounded-lg border border-amber-500/30 bg-amber-500/10 px-3 py-2 text-sm text-amber-300">
          {error}
        </p>
      )}

      <div className="overflow-hidden rounded-xl border border-slate-800 bg-slate-900/40">
        <table className="w-full text-left text-sm">
          <thead className="bg-slate-900/80 text-slate-400">
            <tr>
              <th className="px-4 py-2 font-medium">ID</th>
              <th className="px-4 py-2 font-medium">이름</th>
              <th className="px-4 py-2 font-medium">유형</th>
              <th className="px-4 py-2 font-medium">환경</th>
              <th className="px-4 py-2 font-medium">민감도</th>
              <th className="px-4 py-2 font-medium">태그</th>
            </tr>
          </thead>
          <tbody>
            {data?.items.map((asset) => (
              <tr key={asset.id} className="border-t border-slate-800/80 hover:bg-slate-800/30">
                <td className="px-4 py-2 font-mono text-xs text-slate-400">{asset.id}</td>
                <td className="px-4 py-2 text-slate-200">{asset.name}</td>
                <td className="px-4 py-2 text-slate-300">{asset.type}</td>
                <td className="px-4 py-2 text-slate-300">{asset.environment}</td>
                <td className="px-4 py-2">
                  <span
                    className={`rounded-full px-2 py-0.5 text-[11px] font-medium ${
                      sensitivityStyle[asset.sensitivityLevel] ?? sensitivityStyle.PUBLIC
                    }`}
                  >
                    {asset.sensitivityLevel}
                  </span>
                </td>
                <td className="px-4 py-2 text-xs text-slate-500">
                  {asset.tags?.join(', ') ?? '-'}
                </td>
              </tr>
            ))}
            {data && data.items.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-6 text-center text-slate-600">
                  조건에 맞는 자산이 없습니다.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {data && data.meta.totalPages > 1 && (
        <div className="mt-4 flex items-center gap-2">
          <button
            disabled={page <= 1}
            onClick={() => setPage((p) => Math.max(1, p - 1))}
            className="rounded-md border border-slate-700 px-3 py-1 text-sm text-slate-300 disabled:opacity-40"
          >
            이전
          </button>
          <span className="text-sm text-slate-500">
            {data.meta.page} / {data.meta.totalPages}
          </span>
          <button
            disabled={page >= data.meta.totalPages}
            onClick={() => setPage((p) => p + 1)}
            className="rounded-md border border-slate-700 px-3 py-1 text-sm text-slate-300 disabled:opacity-40"
          >
            다음
          </button>
        </div>
      )}
    </main>
  );
}
