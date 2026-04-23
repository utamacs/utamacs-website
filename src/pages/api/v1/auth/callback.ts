export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseAnonClient } from '@lib/services/providers/supabase/SupabaseDB';

export const GET: APIRoute = async ({ request, redirect, cookies }) => {
  const url = new URL(request.url);
  const code = url.searchParams.get('code');
  const type = url.searchParams.get('type');
  const next = url.searchParams.get('next') ?? '/portal';

  if (!code) {
    return redirect('/portal/login?error=auth_callback_failed');
  }

  const supabase = getSupabaseAnonClient();
  const { data, error } = await supabase.auth.exchangeCodeForSession(code);

  if (error || !data.session) {
    return redirect('/portal/login?error=auth_callback_failed');
  }

  // Use Astro's cookies API — same approach as login.astro
  cookies.set('sb-access-token', data.session.access_token, {
    path: '/',
    httpOnly: true,
    secure: true,
    sameSite: 'lax',
    maxAge: 15 * 60,
  });

  cookies.set('sb-refresh-token', data.session.refresh_token, {
    path: '/api/v1/auth/refresh',
    httpOnly: true,
    secure: true,
    sameSite: 'lax',
    maxAge: 7 * 24 * 60 * 60,
  });

  return redirect(type === 'recovery' ? '/portal/reset-password' : next);
};
