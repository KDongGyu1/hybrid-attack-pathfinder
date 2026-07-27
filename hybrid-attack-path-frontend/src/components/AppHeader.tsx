'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';

const NAV_ITEMS = [
  { href: '/dashboard', label: '대시보드' },
  { href: '/assets', label: '자산 목록' },
  { href: '/logs', label: '감사 로그' },
];

const ROLE_STYLE: Record<string, string> = {
  ADMIN: 'bg-rose-500/15 text-rose-300 ring-1 ring-inset ring-rose-500/30',
  ANALYST: 'bg-indigo-500/15 text-indigo-300 ring-1 ring-inset ring-indigo-500/30',
  VIEWER: 'bg-slate-500/15 text-slate-300 ring-1 ring-inset ring-slate-500/30',
};

interface AppHeaderProps {
  title: string;
}

export default function AppHeader({ title }: AppHeaderProps) {
  const { user, logout } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  return (
    <header className="mb-6 border-b border-slate-800/80 bg-slate-950/40 px-6 pt-5 -mx-6 -mt-6">
      <div className="flex items-center justify-between pb-4">
        <div className="flex items-center gap-3">
          <div className="flex h-8 w-8 items-center justify-center rounded-md bg-gradient-to-br from-indigo-500 to-cyan-400 text-xs font-bold text-slate-950">
            HAP
          </div>
          <div>
            <h1 className="text-base font-semibold tracking-tight text-slate-100">{title}</h1>
            {user && (
              <p className="text-xs text-slate-500">
                {user.email}{' '}
                <span
                  className={`ml-1 rounded-full px-2 py-0.5 text-[10px] font-semibold ${
                    ROLE_STYLE[user.role] ?? ROLE_STYLE.VIEWER
                  }`}
                >
                  {user.role}
                </span>
              </p>
            )}
          </div>
        </div>
        <button
          onClick={() => {
            logout();
            router.replace('/login');
          }}
          className="rounded-md border border-slate-700 px-3 py-1.5 text-xs font-medium text-slate-300 transition hover:border-slate-600 hover:bg-slate-800/60 hover:text-slate-100"
        >
          로그아웃
        </button>
      </div>

      <nav className="flex gap-1">
        {NAV_ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`relative px-3 py-2 text-sm font-medium transition ${
                active ? 'text-slate-50' : 'text-slate-500 hover:text-slate-300'
              }`}
            >
              {item.label}
              {active && (
                <span className="absolute inset-x-2 -bottom-px h-0.5 rounded-full bg-gradient-to-r from-indigo-500 to-cyan-400" />
              )}
            </Link>
          );
        })}
      </nav>
    </header>
  );
}
