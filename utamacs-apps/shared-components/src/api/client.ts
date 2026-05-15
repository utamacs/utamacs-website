import axios, { type AxiosInstance, type AxiosRequestConfig, type AxiosResponse } from 'axios';

// Platform-injectable token provider — implemented per-platform (expo-secure-store)
export interface TokenProvider {
  getAccessToken(): Promise<string | null>;
  getRefreshToken(): Promise<string | null>;
  storeTokens(access: string, refresh: string): Promise<void>;
  clearTokens(): Promise<void>;
}

// Platform-injectable connectivity checker
export interface ConnectivityProvider {
  isOnline(): boolean;
}

export interface ApiClientConfig {
  baseUrl: string;
  tokenProvider: TokenProvider;
  connectivityProvider: ConnectivityProvider;
  onUnauthorized?: () => void;
  onTokenRefreshed?: (tokens: { access: string; refresh: string }) => void;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

let _correlationId = 0;
const nextCorrelationId = () => `mob-${++_correlationId}-${Date.now()}`;

export function createApiClient(config: ApiClientConfig): AxiosInstance {
  const instance = axios.create({
    baseURL: config.baseUrl,
    timeout: 30_000,
    headers: {
      'Content-Type': 'application/json',
      'X-API-Version': '1',
      'X-Platform': 'mobile',
    },
  });

  // Request interceptor — attach Bearer token + correlation ID
  instance.interceptors.request.use(async (req) => {
    const token = await config.tokenProvider.getAccessToken();
    if (token) {
      req.headers['Authorization'] = `Bearer ${token}`;
    }
    req.headers['X-Request-ID'] = nextCorrelationId();
    return req;
  });

  // Response interceptor — handle 401 (token refresh) + error normalization
  let isRefreshing = false;
  let refreshQueue: Array<(token: string | null) => void> = [];

  const processQueue = (token: string | null) => {
    refreshQueue.forEach((resolve) => resolve(token));
    refreshQueue = [];
  };

  instance.interceptors.response.use(
    (response: AxiosResponse) => response,
    async (error) => {
      const originalRequest = error.config as AxiosRequestConfig & { _retry?: boolean };

      if (error.response?.status === 401 && !originalRequest._retry) {
        if (isRefreshing) {
          return new Promise((resolve, reject) => {
            refreshQueue.push((token) => {
              if (!token) return reject(error);
              originalRequest.headers = { ...originalRequest.headers, Authorization: `Bearer ${token}` };
              resolve(instance(originalRequest));
            });
          });
        }

        originalRequest._retry = true;
        isRefreshing = true;

        try {
          const refreshToken = await config.tokenProvider.getRefreshToken();
          if (!refreshToken) throw new Error('No refresh token');

          const { data } = await axios.post(`${config.baseUrl}/auth/refresh`, { refresh_token: refreshToken });
          const newAccess: string = data.access_token;
          const newRefresh: string = data.refresh_token ?? refreshToken;

          await config.tokenProvider.storeTokens(newAccess, newRefresh);
          config.onTokenRefreshed?.({ access: newAccess, refresh: newRefresh });
          processQueue(newAccess);

          originalRequest.headers = { ...originalRequest.headers, Authorization: `Bearer ${newAccess}` };
          return instance(originalRequest);
        } catch {
          processQueue(null);
          await config.tokenProvider.clearTokens();
          config.onUnauthorized?.();
          return Promise.reject(error);
        } finally {
          isRefreshing = false;
        }
      }

      // Normalize error to RFC 7807 shape
      const apiError: ApiError = {
        code: error.response?.data?.error ?? 'NETWORK_ERROR',
        message: error.response?.data?.message ?? error.message ?? 'An unexpected error occurred',
        status: error.response?.status ?? 0,
        requestId: error.response?.headers?.['x-request-id'],
      };

      return Promise.reject(apiError);
    },
  );

  return instance;
}

export interface ApiError {
  code: string;
  message: string;
  status: number;
  requestId?: string;
}

export const isApiError = (e: unknown): e is ApiError =>
  typeof e === 'object' && e !== null && 'code' in e && 'message' in e && 'status' in e;

// Default instance — initialized by platform (android-app / ios-app) before use
let _apiClient: AxiosInstance | null = null;

export const setApiClient = (client: AxiosInstance) => {
  _apiClient = client;
};

export const apiClient = new Proxy({} as AxiosInstance, {
  get: (_, prop) => {
    if (!_apiClient) throw new Error('API client not initialized. Call setApiClient() first.');
    return (_apiClient as unknown as Record<string | symbol, unknown>)[prop];
  },
});
