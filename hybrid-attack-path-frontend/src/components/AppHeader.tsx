'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useAuth } from '@/lib/auth-context';

const NAV_ITEMS = [
  { href: '/dashboard', label: '대시보드' },
  { href: '/assets', label: '자산 목록' },
  { href: '/logs', label: '감사 로그' },
];

interface AppHeaderProps {
  title: string;
}

export default function AppHeader({ title }: AppHeaderProps) {
  const { user, logout } = useAuth();
  const router = useRouter();
  const pathname = usePathname();

  return (
    <header className="mb-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-lg font-semibold text-neutral-900">{title}</h1>
          {user && (
            <p className="text-sm text-neutral-500">
              {user.email} · <span className="font-medium">{user.role}</span>
            </p>
          )}
        </div>
        <button
          onClick={() => {
            logout();
            router.replace('/login');
          }}
          className="rounded-md border border-neutral-300 px-3 py-1.5 text-sm text-neutral-700 hover:bg-neutral-100"
        >
          로그아웃
        </button>
      </div>

      <nav className="mt-4 flex gap-1 border-b border-neutral-200">
        {NAV_ITEMS.map((item) => {
          const active = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`px-3 py-2 text-sm font-medium ${
                active
                  ? 'border-b-2 border-neutral-900 text-neutral-900'
                  : 'text-neutral-500 hover:text-neutral-800'
              }`}
            >
              {item.label}
            </Link>
          );
        })}
      </nav>
    </header>
  );
}
