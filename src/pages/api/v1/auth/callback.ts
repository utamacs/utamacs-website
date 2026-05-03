export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseAnonClient } from '@lib/services/providers/supabase/SupabaseDB';

const setCookie = (name: string, value: string, maxAge: number, path: string) =>
  `${name}=${encodeURIComponent(value)}; Path=${path}; HttpOnly; Secure; SameSite=Lax; Max-Age=${maxAge}`;

export const GET: APIRoute = async ({ request }) => {
  const url = new URL(request.url);
  const code = url.searchParams.get('code');
  const type = url.searchParams.get('type');
  const next = url.searchParams.get('next') ?? '/portal';

  if (!code) {
    return new Response(null, { status: 302, headers: { Location: '/portal/login?error=auth_callback_failed' } });
  }

  const supabase = getSupabaseAnonClient();
  const { data, error } = await supabase.auth.exchangeCodeForSession(code);

  if (error || !data.session) {
    console.error('[callback] exchangeCodeForSession failed:', error?.message);
    return new Response(null, { status: 302, headers: { Location: '/portal/login?error=auth_callback_failed' } });
  }

  const destination = type === 'recovery' ? '/portal/reset-password' : next;
  const r = new Response(null, {
    status: 303,
    headers: { Location: destination, 'Cache-Control': 'no-store' },
  });
  r.headers.append('Set-Cookie', setCookie('sb-access-token', data.session.access_token, 15 * 60, '/'));
  r.headers.append('Set-Cookie', setCookie('sb-refresh-token', data.session.refresh_token, 7 * 24 * 60 * 60, '/api/v1/auth/refresh'));
  return r;
};
