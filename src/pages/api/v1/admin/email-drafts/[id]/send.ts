export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID    = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const RESEND_API_KEY = import.meta.env.RESEND_API_KEY ?? '';

// POST — send a draft email via Resend (secretary+ or admin)
// Marks status → SENT and records resend_message_id, sent_by, sent_at
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });

    const canSend = ['secretary','president'].includes(user.portalRole) || user.isAdmin;
    if (!canSend) return Response.json({ error: 'FORBIDDEN', message: 'Secretary or admin required' }, { status: 403 });

    const sb = getSupabaseServiceClient();

    const { data: draft } = await sb
      .from('email_drafts')
      .select('*')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!draft) return Response.json({ error: 'NOT_FOUND', message: 'Draft not found' }, { status: 404 });

    const d = draft as any;
    if (!['DRAFT','REVIEWED'].includes(d.status)) {
      return Response.json({ error: 'CONFLICT', message: `Cannot send a draft with status: ${d.status}` }, { status: 409 });
    }

    if (!d.recipient_email) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Draft has no recipient email' }, { status: 400 });
    }

    let resendMessageId: string | null = null;

    if (RESEND_API_KEY) {
      const resendRes = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${RESEND_API_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          from: `${d.suggested_sender_name} <${d.suggested_sender_email}>`,
          to: [d.recipient_email],
          subject: d.subject,
          html: d.body_html,
          text: d.body_text,
        }),
      });

      if (!resendRes.ok) {
        const errText = await resendRes.text();
        return Response.json({
          error: 'EMAIL_SEND_FAILED',
          message: `Resend API error (${resendRes.status}): ${errText.slice(0, 200)}`,
        }, { status: 502 });
      }

      const resendData = await resendRes.json() as { id?: string };
      resendMessageId = resendData.id ?? null;
    }

    const { data: updated, error } = await sb
      .from('email_drafts')
      .update({
        status: 'SENT',
        sent_by: user.id,
        sent_at: new Date().toISOString(),
        resend_message_id: resendMessageId,
      })
      .eq('id', params.id!)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'email_drafts', resourceId: params.id!,
      ip: extractClientIP(request),
      newValues: {
        status: 'SENT',
        recipient_email: d.recipient_email,
        resend_message_id: resendMessageId,
        resend_configured: !!RESEND_API_KEY,
      },
    });

    return Response.json({
      ...updated,
      resend_configured: !!RESEND_API_KEY,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
