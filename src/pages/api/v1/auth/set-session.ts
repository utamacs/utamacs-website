export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseAnonClient } from '@lib/services/providers/supabase/SupabaseDB';

const setCookie = (name: string, value: string, maxAge: number, path: string) =>
  `${name}=${encodeURIComponent(value)}; Path=${path}; HttpOnly; Secure; SameSite=Lax; Max-Age=${maxAge}`;

export const POST: APIRoute = async ({ request }) => {
  let access_token: string | undefined;
  let refresh_token: string | undefined;

  try {
    const body = await request.json() as { access_token?: string; refresh_token?: string };
    access_token = body.access_token;
    refresh_token = body.refresh_token;
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid request body' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  if (!access_token || !refresh_token) {
    return new Response(JSON.stringify({ error: 'Missing tokens' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Validate the token with Supabase before trusting it
  const { data, error } = await getSupabaseAnonClient().auth.getUser(access_token);
  if (error || !data.user) {
    console.error('[set-session] invalid token:', error?.message);
    return new Response(JSON.stringify({ error: 'Invalid or expired session token' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const r = new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' },
  });
  r.headers.append('Set-Cookie', setCookie('sb-access-token', access_token, 15 * 60, '/'));
  r.headers.append('Set-Cookie', setCookie('sb-refresh-token', refresh_token, 7 * 24 * 60 * 60, '/api/v1/auth/refresh'));
  return r;
};
