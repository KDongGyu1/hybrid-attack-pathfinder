'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';

export default function LoginPage() {
  const { login } = useAuth();
  const router = useRouter();
  const [email, setEmail] = useState('admin@hap.com');
  const [password, setPassword] = useState('Admin1234!');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await login(email, password);
      router.replace('/dashboard');
    } catch (err) {
      const message =
        err && typeof err === 'object' && 'response' in err
          ? (err as { response?: { data?: { message?: string } } }).response?.data?.message
          : undefined;
      setError(message ?? '로그인에 실패했습니다.');
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-950 px-4">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-sm space-y-5 rounded-2xl border border-slate-800 bg-slate-900/60 p-8 shadow-2xl shadow-black/40"
      >
        <div>
          <div className="mb-3 flex h-9 w-9 items-center justify-center rounded-md bg-gradient-to-br from-indigo-500 to-cyan-400 text-xs font-bold text-slate-950">
            HAP
          </div>
          <h1 className="text-lg font-semibold text-slate-100">
            하이브리드 공격 경로 탐색 시스템
          </h1>
          <p className="mt-1 text-sm text-slate-400">로그인해서 대시보드로 이동하세요.</p>
        </div>

        <div className="space-y-1">
          <label className="text-xs font-medium text-slate-400">이메일</label>
          <input
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full rounded-md border border-slate-700 bg-slate-950/60 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-600 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
            required
          />
        </div>

        <div className="space-y-1">
          <label className="text-xs font-medium text-slate-400">비밀번호</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full rounded-md border border-slate-700 bg-slate-950/60 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-600 focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
            required
          />
        </div>

        {error && (
          <p className="rounded-md border border-rose-500/30 bg-rose-500/10 px-3 py-2 text-xs text-rose-300">
            {error}
          </p>
        )}

        <button
          type="submit"
          disabled={submitting}
          className="w-full rounded-md bg-gradient-to-r from-indigo-500 to-cyan-400 py-2 text-sm font-semibold text-slate-950 transition hover:opacity-90 disabled:opacity-50"
        >
          {submitting ? '로그인 중...' : '로그인'}
        </button>

        <p className="text-xs leading-relaxed text-slate-500">
          데모 계정: admin@hap.com / Admin1234! (ADMIN), analyst@hap.com / Analyst1234!
          (ANALYST), viewer@hap.com / Viewer1234! (VIEWER)
        </p>
      </form>
    </main>
  );
}
