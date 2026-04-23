import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { featureFlagService } from '@lib/services/index';
import { sendSms } from '@lib/services/providers/messaging/SmsService';
import { sendWhatsApp } from '@lib/services/providers/messaging/WhatsAppService';

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
}

/**
 * Dispatches a notification across all enabled channels for the given user.
 * Channels are gated by feature flags (sms_trai_dlt, whatsapp_trai_dlt).
 * Always sends in-app; SMS/WhatsApp only if flags enabled and phone provided.
 */
export async function dispatchNotification(payload: DispatchPayload): Promise<void> {
  const sb = getSupabaseServiceClient();

  // Always send in-app
  await sb.from('notifications').insert({
    society_id: payload.societyId,
    user_id: payload.userId,
    title: payload.title,
    body: payload.body,
    type: payload.type,
    reference_table: payload.referenceTable ?? null,
    reference_id: payload.referenceId ?? null,
    channel: 'in_app',
    status: 'sent',
  });

  if (!payload.phoneE164) return;

  // Check feature flags before sending SMS / WhatsApp
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
        languageCode: 'en',
        components: [
          {
            type: 'body',
            parameters: [
              { type: 'text', text: payload.title },
              { type: 'text', text: payload.body.slice(0, 200) },
            ],
          },
        ],
      });
    } catch (err) {
      console.error('[NotificationDispatcher] WhatsApp failed:', err);
    }
  }
}
