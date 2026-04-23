export const prerender = false;
import type { APIRoute } from 'astro';
import { createServerClient } from '@supabase/ssr';

export const GET: APIRoute = async ({ request, cookies, redirect }) => {
  const url = new URL(request.url);
  const code = url.searchParams.get('code');
  const type = url.searchParams.get('type');
  const next = url.searchParams.get('next') ?? '/portal';

  if (code) {
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

    const { error } = await supabase.auth.exchangeCodeForSession(code);
    if (!error) {
      if (type === 'recovery') {
        return redirect('/portal/reset-password');
      }
      return redirect(next);
    }
  }

  return redirect('/portal/login?error=auth_callback_failed');
};
