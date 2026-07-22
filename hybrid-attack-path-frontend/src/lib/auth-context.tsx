'use client';

import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { api, setAccessToken, setRefreshToken, setAuthHandlers } from './api';

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

interface StoredSession {
  accessToken: string;
  refreshToken: string;
  user: User;
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [token, setToken] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  // 새로고침 시 sessionStorage에서 세션 복구
  useEffect(() => {
    const raw = sessionStorage.getItem(STORAGE_KEY);
    if (raw) {
      try {
        const parsed = JSON.parse(raw) as StoredSession;
        setUser(parsed.user);
        setToken(parsed.accessToken);
        setAccessToken(parsed.accessToken);
        setRefreshToken(parsed.refreshToken);
      } catch {
        sessionStorage.removeItem(STORAGE_KEY);
      }
    }
    setLoading(false);
  }, []);

  // Access Token이 만료(15분)돼 401이 나면 api.ts 인터셉터가 refreshToken으로 자동 갱신한다.
  // 갱신 성공/실패 시 리액트 상태·세션 저장소를 이 콜백으로 동기화한다.
  useEffect(() => {
    setAuthHandlers({
      onTokenRefreshed: (newAccessToken) => {
        setToken(newAccessToken);
        const raw = sessionStorage.getItem(STORAGE_KEY);
        if (raw) {
          try {
            const parsed = JSON.parse(raw) as StoredSession;
            sessionStorage.setItem(
              STORAGE_KEY,
              JSON.stringify({ ...parsed, accessToken: newAccessToken }),
            );
          } catch {
            sessionStorage.removeItem(STORAGE_KEY);
          }
        }
      },
      onAuthFailure: () => {
        // refreshToken마저 만료/무효하면 세션을 정리한다 (재로그인 필요).
        setAccessToken(null);
        setRefreshToken(null);
        setToken(null);
        setUser(null);
        sessionStorage.removeItem(STORAGE_KEY);
      },
    });
  }, []);

  async function login(email: string, password: string) {
    const res = await api.post('/auth/login', { email, password });
    const { accessToken, refreshToken, user } = res.data;
    setAccessToken(accessToken);
    setRefreshToken(refreshToken);
    setToken(accessToken);
    setUser(user);
    sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ accessToken, refreshToken, user }));
  }

  function logout() {
    setAccessToken(null);
    setRefreshToken(null);
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
