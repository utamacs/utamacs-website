export const prerender = false;
import type { APIRoute } from 'astro';
import { createServerClient, parseCookieHeader, serializeCookieHeader, type CookieOptions } from '@supabase/ssr';

export const GET: APIRoute = async ({ request, redirect }) => {
  const url = new URL(request.url);
  const code = url.searchParams.get('code');
  const type = url.searchParams.get('type');
  const next = url.searchParams.get('next') ?? '/portal';

  if (!code) {
    return redirect('/portal/login?error=auth_callback_failed');
  }

  const headers = new Headers();

  const supabase = createServerClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll() {
          return parseCookieHeader(request.headers.get('Cookie') ?? '');
        },
        setAll(cookiesToSet: { name: string; value: string; options: CookieOptions }[]) {
          cookiesToSet.forEach(({ name, value, options }) =>
            headers.append('Set-Cookie', serializeCookieHeader(name, value, options))
          );
        },
      },
    }
  );

  const { error } = await supabase.auth.exchangeCodeForSession(code);

  if (error) {
    return redirect('/portal/login?error=auth_callback_failed');
  }

  const destination = type === 'recovery' ? '/portal/reset-password' : next;
  return new Response(null, { status: 302, headers: { ...Object.fromEntries(headers), Location: destination } });
};
