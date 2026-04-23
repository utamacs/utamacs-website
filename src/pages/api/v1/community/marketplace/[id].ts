import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const VALID_STATUSES = ['active', 'sold', 'expired', 'removed'] as const;

export const GET: APIRoute = async ({ request, params }) => {
  try {
    await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('marketplace_listings')
      .select('id, title, description, category, price, status, contact_preference, created_at, expires_at, seller_id, profiles(full_name), units(unit_number)')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error || !data) {
      return new Response(JSON.stringify({ error: 'Listing not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const PUT: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data: listing } = await sb
      .from('marketplace_listings')
      .select('seller_id, status')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!listing) {
      return new Response(JSON.stringify({ error: 'Listing not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    const isOwner = (listing as any).seller_id === user.id;
    const isMod = ['executive', 'admin'].includes(user.role);
    if (!isOwner && !isMod) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as { status?: string; price?: number; description?: string };

    if (body.status && !VALID_STATUSES.includes(body.status as typeof VALID_STATUSES[number])) {
      return new Response(JSON.stringify({ error: `status must be one of: ${VALID_STATUSES.join(', ')}` }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const updates: Record<string, unknown> = {};
    if (body.status) updates['status'] = body.status;
    if (body.price !== undefined) updates['price'] = body.price;
    if (body.description !== undefined) updates['description'] = body.description;

    const { data, error } = await sb
      .from('marketplace_listings')
      .update(updates)
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'marketplace_listings', resourceId: params.id!,
      ip: extractClientIP(request), newValues: updates,
    });

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data: listing } = await sb
      .from('marketplace_listings')
      .select('seller_id')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!listing) {
      return new Response(JSON.stringify({ error: 'Listing not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    const isOwner = (listing as any).seller_id === user.id;
    const isMod = ['executive', 'admin'].includes(user.role);
    if (!isOwner && !isMod) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    await sb
      .from('marketplace_listings')
      .update({ status: 'removed' })
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID);

    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
