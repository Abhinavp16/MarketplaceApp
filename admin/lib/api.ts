import { isMemberRole } from './role-labels'

// The API host is configured ONLY through NEXT_PUBLIC_API_BASE_URL
// (for example http://localhost:5050/api/v1). There is deliberately no
// hard-coded fallback host: a missing value is a configuration error.
export class ApiConfigError extends Error {
  constructor() {
    super("Configuration error: NEXT_PUBLIC_API_BASE_URL is not set. Copy .env.example to .env.local and restart the dev server.")
    this.name = "ApiConfigError"
  }
}

export function getApiBase(): string {
  const raw = process.env.NEXT_PUBLIC_API_BASE_URL
  if (!raw || !raw.trim()) throw new ApiConfigError()
  return raw.trim().replace(/\/+$/, "")
}

// Socket.IO root = API base without the trailing /api/v1.
export function getSocketUrl(): string {
  return getApiBase().replace(/\/api\/v1$/, "")
}

export function buildApiUrl(endpoint: string): string {
  const normalizedEndpoint = endpoint.startsWith("/") ? endpoint : `/${endpoint}`
  return `${getApiBase()}${normalizedEndpoint}`
}

interface FetchOptions extends RequestInit {
  skipAuth?: boolean
}

function createApiErrorResponse(message: string, status = 503): Response {
  return new Response(JSON.stringify({ success: false, message }), {
    status,
    headers: { "Content-Type": "application/json" },
  })
}

async function refreshAccessToken(): Promise<string | null> {
  const refreshToken = localStorage.getItem('refreshToken')
  if (!refreshToken) return null

  try {
    const res = await fetch(buildApiUrl("/auth/refresh-token"), {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ refreshToken }),
    })

    if (!res.ok) {
      // Refresh token expired - clear storage and redirect to login
      localStorage.removeItem('accessToken')
      localStorage.removeItem('refreshToken')
      localStorage.removeItem('user')
      window.location.href = '/login'
      return null
    }

    const data = await res.json()
    localStorage.setItem('accessToken', data.data.accessToken)
    if (data.data.refreshToken) {
      localStorage.setItem('refreshToken', data.data.refreshToken)
    }
    return data.data.accessToken
  } catch {
    return null
  }
}

export async function apiFetch(endpoint: string, options: FetchOptions = {}): Promise<Response> {
  const { skipAuth, ...fetchOptions } = options

  try {
    getApiBase()
  } catch (error) {
    if (error instanceof ApiConfigError) return createApiErrorResponse(error.message, 500)
    throw error
  }

  const isFormDataBody = typeof FormData !== "undefined" && fetchOptions.body instanceof FormData
  const headers: HeadersInit = {
    ...fetchOptions.headers,
  }

  if (!isFormDataBody && !(headers as Record<string, string>)["Content-Type"]) {
    ;(headers as Record<string, string>)["Content-Type"] = "application/json"
  }

  if (!skipAuth) {
    const token = localStorage.getItem('accessToken')
    if (token) {
      (headers as Record<string, string>)['Authorization'] = `Bearer ${token}`
    }
  }

  let res: Response
  try {
    res = await fetch(buildApiUrl(endpoint), {
      ...fetchOptions,
      headers,
    })
  } catch (error) {
    if (error instanceof TypeError) {
      return createApiErrorResponse(`Unable to reach the API. Check backend server and NEXT_PUBLIC_API_BASE_URL.`)
    }
    throw error
  }

  // If 401 and not skipping auth, try to refresh token
  if (res.status === 401 && !skipAuth) {
    const newToken = await refreshAccessToken()
    if (newToken) {
      (headers as Record<string, string>)['Authorization'] = `Bearer ${newToken}`
      try {
        res = await fetch(buildApiUrl(endpoint), {
          ...fetchOptions,
          headers,
        })
      } catch (error) {
        if (error instanceof TypeError) {
          return createApiErrorResponse(`Unable to reach the API. Check backend server and NEXT_PUBLIC_API_BASE_URL.`)
        }
        throw error
      }
    }
  }

  return res
}

export function isAuthenticated(): boolean {
  if (typeof window === 'undefined') return false
  return !!localStorage.getItem('accessToken') && !isSessionExpired()
}

// Admin sessions are valid for 4 hours from sign-in,
// regardless of JWT refresh token lifetime.
export const SESSION_MAX_MS = 4 * 60 * 60 * 1000

export function isSessionExpired(): boolean {
  if (typeof window === 'undefined') return false
  const user = getUser()
  if (isMemberRole(user?.role)) {
    const sessionExpiresAt = localStorage.getItem('sessionExpiresAt')
    return !sessionExpiresAt || new Date(sessionExpiresAt).getTime() <= Date.now()
  }

  const loginAt = localStorage.getItem('loginAt')
  if (!loginAt) return false // legacy sessions without loginAt are left to token expiry
  return Date.now() - Number(loginAt) > SESSION_MAX_MS
}

export function getUser() {
  if (typeof window === 'undefined') return null
  const user = localStorage.getItem('user')
  return user ? JSON.parse(user) : null
}

export function logout() {
  localStorage.removeItem('accessToken')
  localStorage.removeItem('refreshToken')
  localStorage.removeItem('user')
  localStorage.removeItem('loginAt')
  localStorage.removeItem('sessionExpiresAt')
  window.location.href = '/login'
}
