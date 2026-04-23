export const prerender = false;
import type { APIRoute } from 'astro';
import { authService } from '@lib/services/index';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

export const POST: APIRoute = async ({ request }) => {
  const { password } = await request.json() as { password?: string };

  if (!password || password.length < 8) {
    return new Response(JSON.stringify({ error: 'Password must be at least 8 characters.' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // Read the sb-access-token cookie set by login.astro or callback.ts
  const cookieHeader = request.headers.get('Cookie') ?? '';
  const match = cookieHeader.match(/sb-access-token=([^;]+)/);
  if (!match?.[1]) {
    return new Response(JSON.stringify({ error: 'Session expired. Please start the password reset again.' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let userId: string;
  try {
    const user = await authService.validateToken(match[1]);
    userId = user.id;
  } catch {
    return new Response(JSON.stringify({ error: 'Session expired. Please start the password reset again.' }), {
      status: 401,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const { error } = await getSupabaseServiceClient().auth.admin.updateUserById(userId, { password });

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
};
