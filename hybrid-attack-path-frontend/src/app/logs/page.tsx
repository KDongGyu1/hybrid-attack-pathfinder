'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';
import { api } from '@/lib/api';
import AppHeader from '@/components/AppHeader';

const ACTIONS = ['LOGIN', 'VIEW_GRAPH', 'VIEW_SCENARIO', 'SEARCH_PATH'] as const;

interface LogEntry {
  id: string;
  userId: string;
  userEmail: string;
  action: string;
  targetResource: string;
  ipAddress: string;
  createdAt: string;
}

interface PaginatedLogs {
  items: LogEntry[];
  meta: { page: number; limit: number; totalItems: number; totalPages: number };
}

function getErrorInfo(err: unknown): { status?: number; message: string } {
  if (err && typeof err === 'object' && 'response' in err) {
    const response = (err as { response?: { status?: number; data?: { message?: string } } })
      .response;
    return {
      status: response?.status,
      message: response?.data?.message ?? '감사 로그를 불러오지 못했습니다.',
    };
  }
  return { message: '감사 로그를 불러오지 못했습니다. (네트워크 오류)' };
}

export default function LogsPage() {
  const { user, loading } = useAuth();
  const router = useRouter();

  const [action, setAction] = useState('');
  const [userId, setUserId] = useState('');
  const [page, setPage] = useState(1);

  const [data, setData] = useState<PaginatedLogs | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [forbidden, setForbidden] = useState(false);

  useEffect(() => {
    if (!loading && !user) router.replace('/login');
  }, [loading, user, router]);

  useEffect(() => {
    if (!user) return;
    setError(null);
    setForbidden(false);
    api
      .get<PaginatedLogs>('/logs', {
        params: {
          action: action || undefined,
          userId: userId || undefined,
          page,
          limit: 20,
        },
      })
      .then((res) => setData(res.data))
      .catch((err) => {
        setData(null);
        const { status, message } = getErrorInfo(err);
        if (status === 403) setForbidden(true);
        setError(message);
      });
  }, [user, action, userId, page]);

  if (loading || !user) return null;

  return (
    <main className="min-h-screen bg-slate-950 p-6 text-slate-100">
      <AppHeader title="감사 로그" />

      {forbidden ? (
        <div className="flex flex-col items-center justify-center rounded-xl border border-slate-800 bg-slate-900/40 px-6 py-20 text-center">
          <div className="mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-slate-800/80 text-slate-400">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth={1.5}
              className="h-6 w-6"
            >
              <rect x="4.5" y="10.5" width="15" height="9" rx="1.5" />
              <path d="M8 10.5V7a4 4 0 0 1 8 0v3.5" />
            </svg>
          </div>
          <h2 className="text-base font-semibold text-slate-200">접근 권한이 없습니다</h2>
          <p className="mt-2 max-w-sm text-sm text-slate-500">
            감사 로그는 관리자 권한 계정만 조회할 수 있습니다. 현재 계정 권한: {user.role}
          </p>
        </div>
      ) : (
        <>
          <div className="mb-4 flex flex-wrap items-center gap-3">
            <select
              value={action}
              onChange={(e) => {
                setPage(1);
                setAction(e.target.value);
              }}
              className="rounded-md border border-slate-700 bg-slate-900/60 px-3 py-1.5 text-sm text-slate-200"
            >
              <option value="">전체 액션</option>
              {ACTIONS.map((a) => (
                <option key={a} value={a}>
                  {a}
                </option>
              ))}
            </select>

            <input
              type="text"
              placeholder="사용자 ID로 검색"
              value={userId}
              onChange={(e) => {
                setPage(1);
                setUserId(e.target.value);
              }}
              className="rounded-md border border-slate-700 bg-slate-900/60 px-3 py-1.5 text-sm text-slate-200 placeholder:text-slate-600"
            />

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
                  <th className="px-4 py-2 font-medium">시각</th>
                  <th className="px-4 py-2 font-medium">사용자</th>
                  <th className="px-4 py-2 font-medium">액션</th>
                  <th className="px-4 py-2 font-medium">대상 리소스</th>
                  <th className="px-4 py-2 font-medium">IP</th>
                </tr>
              </thead>
              <tbody>
                {data?.items.map((log) => (
                  <tr key={log.id} className="border-t border-slate-800/80 hover:bg-slate-800/30">
                    <td className="px-4 py-2 text-xs text-slate-500">
                      {new Date(log.createdAt).toLocaleString('ko-KR')}
                    </td>
                    <td className="px-4 py-2 text-slate-200">{log.userEmail}</td>
                    <td className="px-4 py-2 text-slate-300">{log.action}</td>
                    <td className="px-4 py-2 text-xs text-slate-400">{log.targetResource}</td>
                    <td className="px-4 py-2 font-mono text-xs text-slate-400">{log.ipAddress}</td>
                  </tr>
                ))}
                {data && data.items.length === 0 && (
                  <tr>
                    <td colSpan={5} className="px-4 py-6 text-center text-slate-600">
                      조건에 맞는 로그가 없습니다.
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
        </>
      )}
    </main>
  );
}
