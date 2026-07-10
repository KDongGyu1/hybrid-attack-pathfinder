'use client';

import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { api, setAccessToken } from './api';

interface User {
  id: string;
  email: string;
  role: 'ADMIN' | 'ANALYST' | 'VIEWER';
}

interface AuthState {
  user: User | null;
  accessToken: string | null;
  loading: boolean;
  login: (email: string, password: string) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthState | undefined>(undefined);

// 세션 저장소(짧은 수명)에 토큰을 보관한다 — 설계 문서 3.1 "짧은 수명의 저장소" 원칙.
const STORAGE_KEY = 'hap-auth-session';

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  // 새로고침 시 sessionStorage에서 세션 복구
  useEffect(() => {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    if (raw) {
      try {
        const parsed = JSON.parse(raw);
        setUser(parsed.user);
        setToken(parsed.accessToken);
        setAccessToken(parsed.accessToken);
      } catch {
        sessionStorage.removeItem(STORAGE_KEY);
      }
    }
    setLoading(false);
  }, []);

  async function login(email: string, password: string) {
    const res = await api.post('/auth/login', { email, password });
    const { accessToken, user } = res.data;
    setAccessToken(accessToken);
    setToken(accessToken);
    setUser(user);
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ accessToken, user }));
  }

  function logout() {
    setAccessToken(null);
    setToken(null);
    setUser(null);
    sessionStorage.removeItem(STORAGE_KEY);
  }

  return (
    <AuthContext.Provider value={{ user, accessToken: token, loading, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within AuthProvider');
  return ctx;
}
