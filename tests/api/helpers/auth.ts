// Fetches Supabase tokens directly — no Playwright dependency.
// Reads credentials from env vars set in .env.test (never committed).

const SUPABASE_URL  = process.env.SUPABASE_URL  ?? '';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY ?? '';
export const PORTAL = process.env.PORTAL_URL ?? 'http://localhost:4321';
export const API    = `${PORTAL}/api/v1`;

export interface TokenSet {
  accessToken: string;
  cookieHeader: string; // ready-to-use cookie string
}

const tokenCache = new Map<string, TokenSet>();

export async function getTokens(role: 'member' | 'exec' | 'admin' | 'guard'): Promise<TokenSet> {
  if (tokenCache.has(role)) return tokenCache.get(role)!;

  const emailVar = `TEST_${role.toUpperCase()}_EMAIL`;
  const passVar  = `TEST_${role.toUpperCase()}_PASS`;
  const email    = process.env[emailVar] ?? '';
  const password = process.env[passVar]  ?? '';

  if (!email || !password) {
    throw new Error(`Missing ${emailVar} / ${passVar} env vars. Create a .env.test file.`);
  }
  if (!SUPABASE_URL || !SUPABASE_ANON) {
    throw new Error('Missing SUPABASE_URL / SUPABASE_ANON_KEY env vars.');
  }

  const res = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: SUPABASE_ANON, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Supabase auth failed for ${role}: ${res.status} ${body}`);
  }

  const json = await res.json() as any;
  const accessToken = json.access_token as string;
  const tokenSet: TokenSet = {
    accessToken,
    cookieHeader: `sb-access-token=${encodeURIComponent(accessToken)}`,
  };
  tokenCache.set(role, tokenSet);
  return tokenSet;
}

// Helper: make authenticated fetch call to the portal API
export async function apiFetch(
  path: string,
  options: RequestInit & { role?: 'member' | 'exec' | 'admin' | 'guard' | 'none' } = {},
): Promise<Response> {
  const { role = 'member', ...fetchOpts } = options;
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
    ...(fetchOpts.headers as Record<string, string> ?? {}),
  };

  if (role !== 'none') {
    const { cookieHeader } = await getTokens(role);
    headers['cookie'] = cookieHeader;
  }

  return fetch(`${API}${path}`, { ...fetchOpts, headers });
}
