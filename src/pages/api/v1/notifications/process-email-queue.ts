export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleInt, ruleBool } from '@lib/utils/getRules';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// POST /api/v1/notifications/process-email-queue
// Processes pending emails from email_queue and sends via Resend.
// Exec/admin only — intended to be called by a scheduled task or admin.
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, [
      'NOTIFICATION_EMAIL_ENABLED',
      'NOTIFICATION_EMAIL_MAX_RETRIES',
      'NOTIFICATION_BATCH_SIZE',
    ]);

    const emailEnabled  = ruleBool(rules, 'NOTIFICATION_EMAIL_ENABLED', false);
    const maxRetries    = ruleInt(rules, 'NOTIFICATION_EMAIL_MAX_RETRIES', 3);
    const batchSize     = ruleInt(rules, 'NOTIFICATION_BATCH_SIZE', 50);

    if (!emailEnabled) {
      return Response.json({ skipped: true, reason: 'NOTIFICATION_EMAIL_ENABLED rule is false' });
    }

    const resendKey = import.meta.env.RESEND_API_KEY;
    if (!resendKey) {
      return Response.json({ error: 'CONFIG_ERROR', message: 'RESEND_API_KEY not configured' }, { status: 503 });
    }

    const now = new Date().toISOString();

    // Fetch pending emails due for sending
    const { data: pending, error: fetchErr } = await sb
      .from('email_queue')
      .select('id, to_email, subject, html_body, retry_count, max_retries')
      .eq('society_id', SOCIETY_ID)
      .eq('status', 'pending')
      .lte('scheduled_for', now)
      .order('created_at', { ascending: true })
      .limit(batchSize);

    if (fetchErr) throw Object.assign(new Error(fetchErr.message), { status: 500 });

    const rows = pending ?? [];
    let sent = 0;
    let failed = 0;
    let permanent_failed = 0;

    for (const row of rows) {
      try {
        const res = await fetch('https://api.resend.com/emails', {
          method: 'POST',
          headers: {
            Authorization:  `Bearer ${resendKey}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            from:    'UTA MACS <no-reply@utamacs.org>',
            to:      [row.to_email],
            subject: row.subject,
            html:    row.html_body,
          }),
        });

        if (res.ok) {
          await sb
            .from('email_queue')
            .update({ status: 'sent', sent_at: new Date().toISOString() })
            .eq('id', row.id);
          sent++;
        } else {
          const errText = await res.text().catch(() => res.statusText);
          const newRetryCount = (row.retry_count ?? 0) + 1;
          const isPermanentFail = newRetryCount >= (row.max_retries ?? maxRetries);
          await sb
            .from('email_queue')
            .update({
              status:      isPermanentFail ? 'failed' : 'pending',
              retry_count: newRetryCount,
              last_error:  errText.slice(0, 500),
              scheduled_for: isPermanentFail ? now : new Date(Date.now() + newRetryCount * 300_000).toISOString(),
            })
            .eq('id', row.id);
          isPermanentFail ? permanent_failed++ : failed++;
        }
      } catch (sendErr) {
        const newRetryCount = (row.retry_count ?? 0) + 1;
        const isPermanentFail = newRetryCount >= (row.max_retries ?? maxRetries);
        await sb
          .from('email_queue')
          .update({
            status:       isPermanentFail ? 'failed' : 'pending',
            retry_count:  newRetryCount,
            last_error:   String(sendErr).slice(0, 500),
            scheduled_for: isPermanentFail ? now : new Date(Date.now() + newRetryCount * 300_000).toISOString(),
          })
          .eq('id', row.id);
        isPermanentFail ? permanent_failed++ : failed++;
      }
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'email_queue', resourceId: SOCIETY_ID,
      ip: extractClientIP(request),
      newValues: { processed: rows.length, sent, failed, permanent_failed, ran_at: now },
    });

    return Response.json({
      processed: rows.length,
      sent,
      transient_failed: failed,
      permanent_failed,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
