import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_CATEGORIES = [
  'Furniture', 'Electronics', 'Appliances', 'Books', 'Toys',
  'Clothing', 'Sports', 'Vehicles', 'Services', 'Other',
] as const;

const VALID_CONTACT = ['phone', 'message', 'both'] as const;

export const GET: APIRoute = async ({ request, url }) => {
  try {
    await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const category = url.searchParams.get('category');
    const q = url.searchParams.get('q')?.trim();
    const limit = Math.min(parseInt(url.searchParams.get('limit') ?? '20'), 50);
    const offset = parseInt(url.searchParams.get('offset') ?? '0');

    let query = sb
      .from('marketplace_listings')
      .select('id, title, description, category, price, status, contact_preference, created_at, seller_id, profiles(full_name), units(unit_number)', { count: 'exact' })
      .eq('society_id', SOCIETY_ID)
      .eq('status', 'active')
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (category && VALID_CATEGORIES.includes(category as typeof VALID_CATEGORIES[number])) {
      query = query.eq('category', category);
    }
    if (q) query = query.ilike('title', `%${q}%`);

    const { data, error, count } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify({ listings: data ?? [], total: count ?? 0 }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (['security_guard', 'vendor'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as {
      title?: string; description?: string; category?: string;
      price?: number; contact_preference?: string;
    };

    if (!body.title?.trim() || !body.category) {
      return new Response(JSON.stringify({ error: 'title and category are required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (!VALID_CATEGORIES.includes(body.category as typeof VALID_CATEGORIES[number])) {
      return new Response(JSON.stringify({ error: `category must be one of: ${VALID_CATEGORIES.join(', ')}` }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    const { data: profile } = await sb.from('profiles').select('unit_id').eq('id', user.id).single();

    // Listings expire after 30 days
    const expiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString();

    const { data, error } = await sb
      .from('marketplace_listings')
      .insert({
        society_id: SOCIETY_ID,
        seller_id: user.id,
        unit_id: (profile as any)?.unit_id ?? null,
        title: sanitizePlainText(body.title),
        description: body.description ? sanitizePlainText(body.description) : null,
        category: body.category,
        price: body.price ?? null,
        status: 'active',
        contact_preference: VALID_CONTACT.includes((body.contact_preference ?? '') as typeof VALID_CONTACT[number])
          ? body.contact_preference
          : 'message',
        expires_at: expiresAt,
        created_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'marketplace_listings', resourceId: data.id,
      ip: extractClientIP(request), newValues: { category: data.category, title: data.title },
    });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
