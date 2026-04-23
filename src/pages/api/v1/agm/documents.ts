export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_DOC_TYPES = ['minutes', 'financial_statement', 'audit_report', 'resolution', 'notice', 'proxy_form', 'other'] as const;

// GET — list AGM documents
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const sessionId = url.searchParams.get('session_id');
    const status = url.searchParams.get('status');

    let query = sb
      .from('agm_documents')
      .select(`
        id, agm_session_id, document_type, title, description,
        file_name, mime_type, file_size_bytes, version, parent_id,
        status, submitted_by, submitted_at,
        reviewed_by, reviewed_at, review_comment,
        secondary_approver_id, secondary_approved_at,
        effective_date, is_public, created_by, created_at, updated_at,
        agm_sessions(agm_year, agm_type, meeting_date),
        profiles!agm_documents_submitted_by_fkey(full_name),
        reviewer:profiles!agm_documents_reviewed_by_fkey(full_name)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false });

    if (sessionId) query = query.eq('agm_session_id', sessionId);
    if (status) query = query.eq('status', status);

    // Members only see approved+public docs
    if (user.role === 'member') {
      query = query.eq('status', 'approved').eq('is_public', true);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data ?? []), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — create/submit AGM document (exec/admin only)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Only executives and admins can create AGM documents' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as {
      agm_session_id?: string; document_type?: string; title?: string;
      description?: string; storage_key?: string; file_name?: string;
      mime_type?: string; file_size_bytes?: number; effective_date?: string;
      is_public?: boolean; submit?: boolean;
    };

    if (!body.title?.trim()) {
      return new Response(JSON.stringify({ error: 'title is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (body.document_type && !VALID_DOC_TYPES.includes(body.document_type as typeof VALID_DOC_TYPES[number])) {
      return new Response(JSON.stringify({ error: `document_type must be one of: ${VALID_DOC_TYPES.join(', ')}` }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const isSubmitting = body.submit === true;
    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('agm_documents')
      .insert({
        society_id: SOCIETY_ID,
        agm_session_id: body.agm_session_id ?? null,
        document_type: body.document_type ?? 'other',
        title: sanitizePlainText(body.title.trim()),
        description: body.description ? sanitizePlainText(body.description) : null,
        storage_key: body.storage_key ?? null,
        file_name: body.file_name ?? null,
        mime_type: body.mime_type ?? null,
        file_size_bytes: body.file_size_bytes ?? null,
        effective_date: body.effective_date ?? null,
        is_public: body.is_public ?? false,
        status: isSubmitting ? 'submitted' : 'draft',
        submitted_by: isSubmitting ? user.id : null,
        submitted_at: isSubmitting ? new Date().toISOString() : null,
        created_by: user.id,
        version: 1,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Insert workflow history
    await sb.from('agm_workflow_history').insert({
      agm_document_id: (data as any).id,
      society_id: SOCIETY_ID,
      old_status: null,
      new_status: isSubmitting ? 'submitted' : 'draft',
      action: isSubmitting ? 'SUBMITTED' : 'DRAFT_CREATED',
      actor_id: user.id,
    });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'agm_documents', resourceId: (data as any).id,
      ip: extractClientIP(request),
      newValues: { title: body.title, document_type: body.document_type, status: (data as any).status },
    });

    return new Response(JSON.stringify(data), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
