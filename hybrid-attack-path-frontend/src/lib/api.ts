import axios from 'axios';

// 백엔드 API base URL. .env.local의 NEXT_PUBLIC_API_BASE_URL로 덮어쓸 수 있음.
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:3000/api/v1';

export const api = axios.create({
  baseURL: API_BASE_URL,
});

// 요청마다 accessToken을 Authorization 헤더에 부착 (auth-context가 세팅해줌)
let accessToken: string | null = null;
let refreshToken: string | null = null;

export function setAccessToken(token: string | null) {
  accessToken = token;
}

export function setRefreshToken(token: string | null) {
  refreshToken = token;
}

interface AuthHandlers {
  onTokenRefreshed: (accessToken: string) => void;
  onAuthFailure: () => void;
}

let authHandlers: AuthHandlers | null = null;

export function setAuthHandlers(handlers: AuthHandlers) {
  authHandlers = handlers;
}

api.interceptors.request.use((config) => {
  if (accessToken) {
    config.headers.Authorization = `Bearer ${accessToken}`;
  }
  return config;
});

// Access Token 만료(15분) 대응 — 401을 받으면 refreshToken으로 재발급 받아 원 요청을 한 번 재시도한다.
let refreshPromise: Promise<string> | null = null;

async function refreshAccessToken(): Promise<string> {
  if (!refreshToken) {
    throw new Error('저장된 refreshToken이 없습니다.');
  }
  // 인터셉터 재귀 호출을 피하기 위해 api 인스턴스가 아닌 순수 axios로 호출
  const res = await axios.post<{ accessToken: string }>(`${API_BASE_URL}/auth/refresh`, {
    refreshToken,
  });
  const newAccessToken = res.data.accessToken;
  accessToken = newAccessToken;
  authHandlers?.onTokenRefreshed(newAccessToken);
  return newAccessToken;
}

api.interceptors.response.use(
  (response) => response,
  async (error) => {
    const originalRequest = error.config as (typeof error.config & { _retry?: boolean }) | undefined;
    const status = error.response?.status;
    const url: string = originalRequest?.url ?? '';
    const isAuthEndpoint = url.includes('/auth/login') || url.includes('/auth/refresh');

    if (status === 401 && originalRequest && !originalRequest._retry && !isAuthEndpoint && refreshToken) {
      originalRequest._retry = true;
      try {
        if (!refreshPromise) {
          refreshPromise = refreshAccessToken().finally(() => {
            refreshPromise = null;
          });
        }
        const newAccessToken = await refreshPromise;
        originalRequest.headers = originalRequest.headers ?? {};
        originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
        return api(originalRequest);
      } catch (refreshError) {
        authHandlers?.onAuthFailure();
        return Promise.reject(refreshError);
      }
    }

    return Promise.reject(error);
  },
);
