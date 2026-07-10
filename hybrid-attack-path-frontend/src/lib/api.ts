import axios from 'axios';

// 백엔드 API base URL. .env.local의 NEXT_PUBLIC_API_BASE_URL로 덮어쓸 수 있음.
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:3000/api/v1';

export const api = axios.create({
  baseURL: API_BASE_URL,
});

// 요청마다 accessToken을 Authorization 헤더에 부착 (auth-context가 세팅해줌)
let accessToken: string | null = null;

export function setAccessToken(token: string | null) {
  accessToken = token;
}

api.interceptors.request.use((config) => {
  if (accessToken) {
    config.headers.Authorization = `Bearer ${accessToken}`;
  }
  return config;
});
