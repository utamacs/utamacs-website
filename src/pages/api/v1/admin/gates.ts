export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { sanitizePlainText } from '@lib/utils/sanitize';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

const VALID_GATE_TYPES = ['main_entry', 'exit', 'emergency', 'pedestrian'] as const;
type GateType = typeof VALID_GATE_TYPES[number];

// POST (exec only) — create a new gate
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role) && !user.isAdmin) {
      return Response.json({ error: 'FORBIDDEN', message: 'Exec access required.' }, { status: 403 });
    }

    const body = await request.json() as {
      gate_name?: string;
      gate_code?: string;
      gate_type?: string;
      notes?: string;
    };

    if (!body.gate_name?.trim()) {
      return Response.json({ error: 'MISSING_FIELD', message: 'gate_name is required.' }, { status: 400 });
    }

    if (body.gate_type && !VALID_GATE_TYPES.includes(body.gate_type as GateType)) {
      return Response.json(
        { error: 'INVALID_GATE_TYPE', message: `gate_type must be one of: ${VALID_GATE_TYPES.join(', ')}` },
        { status: 400 },
      );
    }

    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('gates')
      .insert({
        society_id: SOCIETY_ID,
        name: sanitizePlainText(body.gate_name).slice(0, 100),
        gate_code: body.gate_code ? sanitizePlainText(body.gate_code).slice(0, 20) : null,
        description: body.notes ? sanitizePlainText(body.notes).slice(0, 300) : null,
        is_active: true,
      })
      .select()
      .single();

    if (error) {
      if (error.code === '23505') {
        return Response.json({ error: 'DUPLICATE', message: 'A gate with this name already exists.' }, { status: 409 });
      }
      throw Object.assign(new Error(error.message), { status: 500 });
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'gates', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { name: data.name, gate_code: data.gate_code },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH (exec only) — update an existing gate
export const PATCH: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role) && !user.isAdmin) {
      return Response.json({ error: 'FORBIDDEN', message: 'Exec access required.' }, { status: 403 });
    }

    const body = await request.json() as {
      id?: string;
      gate_name?: string;
      is_active?: boolean;
      notes?: string;
    };

    if (!body.id || !UUID_RE.test(body.id)) {
      return Response.json({ error: 'INVALID_ID', message: 'A valid gate id is required.' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: existing } = await sb
      .from('gates')
      .select('id, name, is_active, description')
      .eq('id', body.id)
      .eq('society_id', SOCIETY_ID)
      .maybeSingle();

    if (!existing) {
      return Response.json({ error: 'NOT_FOUND', message: 'Gate not found.' }, { status: 404 });
    }

    const updates: Record<string, unknown> = {};
    if (body.gate_name !== undefined) updates.name = sanitizePlainText(body.gate_name).slice(0, 100);
    if (body.is_active !== undefined) updates.is_active = Boolean(body.is_active);
    if (body.notes !== undefined) updates.description = sanitizePlainText(body.notes).slice(0, 300);

    if (Object.keys(updates).length === 0) {
      return Response.json({ error: 'NO_CHANGES', message: 'No updatable fields provided.' }, { status: 400 });
    }

    const { data, error } = await sb
      .from('gates')
      .update(updates)
      .eq('id', body.id)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'gates', resourceId: body.id,
      ip: extractClientIP(request),
      oldValues: { name: existing.name, is_active: existing.is_active, description: existing.description },
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
