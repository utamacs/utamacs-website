export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const CURRENT_POLICY_VERSION = parseInt(import.meta.env.PRIVACY_POLICY_VERSION ?? '1');

// GET — return current consent state and whether re-consent is needed
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data: profile } = await sb
      .from('profiles')
      .select('consent_version, consent_at')
      .eq('id', user.id)
      .eq('society_id', SOCIETY_ID)
      .single();

    const needsConsent = !profile?.consent_version || profile.consent_version < CURRENT_POLICY_VERSION;

    return new Response(JSON.stringify({
      current_policy_version: CURRENT_POLICY_VERSION,
      accepted_version: profile?.consent_version ?? null,
      accepted_at: profile?.consent_at ?? null,
      needs_consent: needsConsent,
    }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — record consent acceptance for the current policy version
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const body = await request.json().catch(() => ({})) as { version?: number };

    const version = body.version ?? CURRENT_POLICY_VERSION;
    if (version > CURRENT_POLICY_VERSION) {
      return new Response(JSON.stringify({ error: 'Invalid policy version' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const now = new Date().toISOString();

    const { error } = await sb
      .from('profiles')
      .update({ consent_version: version, consent_at: now })
      .eq('id', user.id)
      .eq('society_id', SOCIETY_ID);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'profiles', resourceId: user.id,
      ip: extractClientIP(request),
      newValues: { consent_version: version, consent_at: now },
    });

    return new Response(JSON.stringify({
      ok: true, consent_version: version, consent_at: now,
    }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
