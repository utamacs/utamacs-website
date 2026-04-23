export const prerender = false;
import type { APIRoute } from 'astro';
import { createServerClient, parseCookieHeader, serializeCookieHeader, type CookieOptions } from '@supabase/ssr';

export const POST: APIRoute = async ({ request }) => {
  const { password } = await request.json() as { password?: string };

  if (!password || password.length < 8) {
    return new Response(JSON.stringify({ error: 'Password must be at least 8 characters.' }), { status: 400 });
  }

  const headers = new Headers({ 'Content-Type': 'application/json' });

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

  const { error } = await supabase.auth.updateUser({ password });

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 400, headers });
  }

  return new Response(JSON.stringify({ ok: true }), { status: 200, headers });
};
