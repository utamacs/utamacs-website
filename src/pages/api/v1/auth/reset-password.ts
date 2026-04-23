export const prerender = false;
import type { APIRoute } from 'astro';
import { createServerClient } from '@supabase/ssr';

export const POST: APIRoute = async ({ request, cookies }) => {
  const { password } = await request.json();

  if (!password || password.length < 8) {
    return new Response(JSON.stringify({ error: 'Password must be at least 8 characters.' }), { status: 400 });
  }

  const supabase = createServerClient(
    import.meta.env.PUBLIC_SUPABASE_URL,
    import.meta.env.PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll: () => cookies.getAll(),
        setAll: (cookiesToSet) => {
          cookiesToSet.forEach(({ name, value, options }) =>
            cookies.set(name, value, options)
          );
        },
      },
    }
  );

  const { error } = await supabase.auth.updateUser({ password });

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 400 });
  }

  return new Response(JSON.stringify({ ok: true }), { status: 200 });
};
