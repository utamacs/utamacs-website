import { test as setup, expect, request } from '@playwright/test';
import { TEST_USERS } from '../../fixtures/env';

// Uses Supabase's REST API directly (bypasses the portal's rate-limited login endpoint).
// Injects the access + refresh tokens as HttpOnly-equivalent cookies so the portal
// middleware sees an authenticated session — identical to what a real browser login produces.

const SUPABASE_URL  = process.env.SUPABASE_URL ?? '';
const SUPABASE_ANON = process.env.SUPABASE_ANON_KEY ?? '';

async function getSupabaseTokens(email: string, password: string) {
  const ctx = await request.newContext();
  const res = await ctx.post(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
    headers: {
      apikey: SUPABASE_ANON,
      'Content-Type': 'application/json',
    },
    data: { email, password },
  });

  if (!res.ok()) {
    const body = await res.text();
    throw new Error(`Supabase login failed for ${email}: ${res.status()} ${body}`);
  }

  const json = await res.json();
  return { accessToken: json.access_token as string, refreshToken: json.refresh_token as string };
}

function cookieFor(name: string, value: string, path: string, domain: string) {
  return {
    name,
    value: encodeURIComponent(value),
    domain,
    path,
    httpOnly: true,
    secure: true,
    sameSite: 'Lax' as const,
    expires: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 7, // 7 days
  };
}

for (const [role, creds] of Object.entries(TEST_USERS)) {
  setup(`authenticate as ${role}`, async ({ browser }) => {
    if (!creds.email || !creds.password) {
      throw new Error(`Missing credentials for role "${role}".`);
    }
    if (!SUPABASE_URL || !SUPABASE_ANON) {
      throw new Error('SUPABASE_URL and SUPABASE_ANON_KEY must be set in env.');
    }

    const { accessToken, refreshToken } = await getSupabaseTokens(creds.email, creds.password);

    const portalHost = new URL(process.env.PORTAL_URL ?? 'http://localhost:4321').hostname;

    const context = await browser.newContext();
    await context.addCookies([
      cookieFor('sb-access-token',  accessToken,  '/',                       portalHost),
      cookieFor('sb-refresh-token', refreshToken, '/api/v1/auth/refresh',    portalHost),
    ]);

    // Verify the session works by visiting /portal
    const page = await context.newPage();
    await page.goto(process.env.PORTAL_URL + '/portal');
    await expect(page).toHaveURL(/\/portal(?!\/login)/, { timeout: 15000 });

    await context.storageState({ path: creds.authFile });
    await context.close();
  });
}
