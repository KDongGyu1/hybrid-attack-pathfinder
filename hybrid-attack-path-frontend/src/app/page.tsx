'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';

export default function Home() {
  const { user, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;
    router.replace(user ? '/dashboard' : '/login');
  }, [loading, user, router]);

  return (
    <main className="flex min-h-screen items-center justify-center bg-slate-950">
      <p className="text-sm text-slate-500">불러오는 중...</p>
    </main>
  );
}
