import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { featureFlagService } from '@lib/services/index';
import { sendSms } from '@lib/services/providers/messaging/SmsService';
import { sendWhatsApp } from '@lib/services/providers/messaging/WhatsAppService';
import { renderNotificationEmail } from '@lib/utils/emailTemplates';
import { getRules, ruleBool, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export interface DispatchPayload {
  societyId: string;
  userId: string;
  title: string;
  body: string;
  type: string;
  referenceTable?: string;
  referenceId?: string;
  phoneE164?: string; // only needed for SMS/WhatsApp channels
  ctaUrl?: string;    // optional CTA link for email
}

/**
 * Dispatches a notification across all enabled channels for the given user.
 * Always sends in-app. Email is enqueued if:
 *   - NOTIFICATION_EMAIL_ENABLED rule is true
 *   - user's notification_preferences.email_enabled is true
 *   - user has a non-null email address in profiles
 * SMS/WhatsApp gated by TRAI DLT feature flags (disabled by default).
 */
export async function dispatchNotification(payload: DispatchPayload): Promise<void> {
  const sb = getSupabaseServiceClient();

  // Always send in-app notification
  const { data: notif } = await sb.from('notifications').insert({
    society_id:      payload.societyId,
    user_id:         payload.userId,
    title:           payload.title,
    body:            payload.body,
    type:            payload.type,
    reference_table: payload.referenceTable ?? null,
    reference_id:    payload.referenceId ?? null,
    channel:         'in_app',
    status:          'sent',
  }).select('id').single();

  // ── Email channel ──────────────────────────────────────────────────────────
  try {
    const [rules, prefs, profile] = await Promise.all([
      getRules(sb, payload.societyId, ['NOTIFICATION_EMAIL_ENABLED', 'NOTIFICATION_EMAIL_MAX_RETRIES']),
      sb.from('notification_preferences')
        .select('email_enabled, quiet_hours_start, quiet_hours_end')
        .eq('user_id', payload.userId)
        .maybeSingle(),
      sb.from('profiles')
        .select('email')
        .eq('id', payload.userId)
        .single(),
    ]);

    const emailMasterEnabled = ruleBool(rules, 'NOTIFICATION_EMAIL_ENABLED', false);
    const maxRetries = ruleInt(rules, 'NOTIFICATION_EMAIL_MAX_RETRIES', 3);
    const userEmailEnabled = prefs.data?.email_enabled !== false; // default opt-in
    const toEmail = (profile.data as { email?: string } | null)?.email;

    if (emailMasterEnabled && userEmailEnabled && toEmail) {
      // Respect quiet hours (IST offset +05:30)
      const quietStart = prefs.data?.quiet_hours_start as string | null;
      const quietEnd   = prefs.data?.quiet_hours_end   as string | null;
      const scheduledFor = resolveScheduledFor(quietStart, quietEnd);

      const { subject, html } = renderNotificationEmail({
        type:     payload.type,
        title:    payload.title,
        body:     payload.body,
        ctaUrl:   payload.ctaUrl,
      });

      await sb.from('email_queue').insert({
        society_id:      payload.societyId,
        user_id:         payload.userId,
        to_email:        toEmail,
        subject,
        html_body:       html,
        notification_id: notif?.id ?? null,
        status:          'pending',
        max_retries:     maxRetries,
        scheduled_for:   scheduledFor,
      });
    }
  } catch (err) {
    // Email enqueue failure is non-fatal — in-app was already sent
    console.error('[NotificationDispatcher] Email enqueue failed:', err);
  }

  // ── SMS / WhatsApp ─────────────────────────────────────────────────────────
  if (!payload.phoneE164) return;

  const [smsEnabled, waEnabled] = await Promise.all([
    featureFlagService.isEnabled(payload.societyId, 'notifications', 'sms_trai_dlt').catch(() => false),
    featureFlagService.isEnabled(payload.societyId, 'notifications', 'whatsapp_trai_dlt').catch(() => false),
  ]);

  if (smsEnabled) {
    try {
      await sendSms({
        to: payload.phoneE164,
        templateId: 'utamacs_general_notification',
        params: [payload.title, payload.body.slice(0, 100)],
      });
    } catch (err) {
      console.error('[NotificationDispatcher] SMS failed:', err);
    }
  }

  if (waEnabled) {
    try {
      await sendWhatsApp({
        to: payload.phoneE164,
        templateName: 'utamacs_general_notification',
        languageCode: 'en_IN',
        components: [{
          type: 'body',
          parameters: [
            { type: 'text', text: payload.title },
            { type: 'text', text: payload.body.slice(0, 200) },
          ],
        }],
      });
    } catch (err) {
      console.error('[NotificationDispatcher] WhatsApp failed:', err);
    }
  }
}

/** If user has quiet hours, schedule email delivery for after the quiet window ends. */
function resolveScheduledFor(quietStart: string | null, quietEnd: string | null): string {
  const now = new Date();
  if (!quietStart || !quietEnd) return now.toISOString();

  const [startH, startM] = quietStart.split(':').map(Number);
  const [endH,   endM]   = quietEnd.split(':').map(Number);
  const startMins = startH * 60 + startM;
  const endMins   = endH   * 60 + endM;
  const nowMins   = now.getUTCHours() * 60 + now.getUTCMinutes() + 330; // +5:30 IST offset

  const nowIstMins = nowMins % (24 * 60);

  // Check if currently in quiet period
  const inQuiet = startMins <= endMins
    ? nowIstMins >= startMins && nowIstMins < endMins
    : nowIstMins >= startMins || nowIstMins < endMins;

  if (!inQuiet) return now.toISOString();

  // Schedule for end of quiet period today (or tomorrow if it wraps)
  const targetDate = new Date(now);
  targetDate.setUTCHours(endH);
  targetDate.setUTCMinutes(endM - 330); // convert back from IST
  targetDate.setUTCSeconds(0);
  if (targetDate <= now) targetDate.setUTCDate(targetDate.getUTCDate() + 1);
  return targetDate.toISOString();
}
