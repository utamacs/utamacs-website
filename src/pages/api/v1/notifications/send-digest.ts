export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleInt, ruleBool } from '@lib/utils/getRules';
import { renderDigestEmail } from '@lib/utils/emailTemplates';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// POST /api/v1/notifications/send-digest
// Enqueues daily digest emails for all users with email_digest_enabled=true
// who have unread notifications within the digest window.
// Exec/admin only — call once per day via scheduled task or admin action.
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
      'NOTIFICATION_DIGEST_WINDOW_HRS',
    ]);

    const emailEnabled   = ruleBool(rules, 'NOTIFICATION_EMAIL_ENABLED', false);
    const windowHrs      = ruleInt(rules, 'NOTIFICATION_DIGEST_WINDOW_HRS', 24);
    const maxRetries     = ruleInt(rules, 'NOTIFICATION_EMAIL_MAX_RETRIES', 3);

    if (!emailEnabled) {
      return Response.json({ skipped: true, reason: 'NOTIFICATION_EMAIL_ENABLED rule is false' });
    }

    const windowCutoff = new Date(Date.now() - windowHrs * 3600_000).toISOString();
    const now = new Date().toISOString();

    // Find all users eligible for digest:
    // - email_digest_enabled = true
    // - last_digest_sent_at is null OR older than window
    const { data: prefs, error: prefsErr } = await sb
      .from('notification_preferences')
      .select('user_id, last_digest_sent_at')
      .eq('email_digest_enabled', true)
      .or(`last_digest_sent_at.is.null,last_digest_sent_at.lt.${windowCutoff}`);

    if (prefsErr) throw Object.assign(new Error(prefsErr.message), { status: 500 });

    const eligibleUserIds = (prefs ?? []).map(p => p.user_id);
    if (!eligibleUserIds.length) {
      return Response.json({ enqueued: 0, skipped_no_prefs: true });
    }

    // Fetch user emails
    const { data: profiles } = await sb
      .from('profiles')
      .select('id, email, full_name')
      .in('id', eligibleUserIds)
      .not('email', 'is', null);

    const emailByUser = new Map<string, string>();
    for (const p of profiles ?? []) {
      if ((p as { email?: string }).email) emailByUser.set(p.id, (p as { email: string }).email);
    }

    // Fetch society name
    const { data: society } = await sb
      .from('societies')
      .select('name')
      .eq('id', SOCIETY_ID)
      .single();
    const societyName = (society as { name?: string } | null)?.name ?? 'UTA MACS';

    let enqueued = 0;
    let skipped_no_notifs = 0;
    let skipped_no_email = 0;

    for (const pref of prefs ?? []) {
      const toEmail = emailByUser.get(pref.user_id);
      if (!toEmail) { skipped_no_email++; continue; }

      // Fetch unread notifications for this user within window
      const { data: notifs } = await sb
        .from('notifications')
        .select('title, body, type, created_at, reference_id')
        .eq('society_id', SOCIETY_ID)
        .eq('user_id', pref.user_id)
        .eq('is_read', false)
        .gte('created_at', windowCutoff)
        .order('created_at', { ascending: false })
        .limit(50);

      if (!notifs?.length) { skipped_no_notifs++; continue; }

      const { subject, html } = renderDigestEmail(notifs, societyName);

      await sb.from('email_queue').insert({
        society_id:   SOCIETY_ID,
        user_id:      pref.user_id,
        to_email:     toEmail,
        subject,
        html_body:    html,
        status:       'pending',
        max_retries:  maxRetries,
        scheduled_for: now,
      });

      // Update last_digest_sent_at
      await sb
        .from('notification_preferences')
        .update({ last_digest_sent_at: now })
        .eq('user_id', pref.user_id);

      enqueued++;
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'digest_emails', resourceId: SOCIETY_ID,
      ip: extractClientIP(request),
      newValues: { enqueued, skipped_no_notifs, skipped_no_email, ran_at: now },
    });

    return Response.json({ enqueued, skipped_no_notifs, skipped_no_email });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
