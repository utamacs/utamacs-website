export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { SupabaseStorageService } from '@lib/services/providers/supabase/SupabaseStorageService';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'gallery.view');
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('gallery_albums')
      .select('id, title, description, cover_key, event_date, photo_count, created_at')
      .eq('society_id', SOCIETY_ID)
      .order('event_date', { ascending: false, nullsFirst: false })
      .order('created_at', { ascending: false });

    if (error) throw error;

    const storage = new SupabaseStorageService();
    const albums = await Promise.all(
      ((data ?? []) as any[]).map(async (a) => {
        let cover_url: string | null = null;
        if (a.cover_key) {
          try { cover_url = await storage.getSignedUrl('gallery-photos', a.cover_key, 3600); } catch { /* non-fatal */ }
        }
        return { ...a, cover_url };
      })
    );

    return Response.json(albums);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'gallery.manage');

    const body = await request.json() as Record<string, unknown>;
    const title = String(body.title ?? '').trim();
    if (title.length < 2) {
      return Response.json({ error: 'VALIDATION', message: 'Title is required (min 2 characters).' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('gallery_albums')
      .insert({
        society_id: SOCIETY_ID,
        title: sanitizePlainText(title).slice(0, 150),
        description: body.description ? sanitizePlainText(String(body.description)).slice(0, 500) : null,
        event_date: body.event_date ? String(body.event_date) : null,
        is_public: body.is_public !== false,
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw error;

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'CREATE', resourceType: 'gallery_album',
      resourceId: (data as any).id,
      ip: extractClientIP(request),
      newValues: { title },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
