/**
 * WhatsApp Business Cloud API — Meta Graph API v19.0
 *
 * Setup checklist (one-time):
 *   1. Create a Meta Business Manager account → business.facebook.com
 *   2. Create a WhatsApp Business Account (WABA) and add a dedicated phone number
 *      (the number must NOT be registered on personal WhatsApp)
 *   3. Enable Cloud API in Meta Developer console → get PHONE_NUMBER_ID + WABA_ID
 *   4. Generate a permanent System User access token in Business Manager
 *   5. Register as principal entity on TRAI DLT portal (Vodafone/JIO/Airtel)
 *      — mandatory for bulk messages to Indian numbers (takes 7–14 days)
 *   6. Register each message template on DLT portal, then submit to Meta for approval
 *      — Meta approval takes 24–48 hours per template
 *
 * While awaiting DLT registration:
 *   — Staff who reply to the WhatsApp number open a 24-hour "user-initiated" session
 *     during which you can send free-form messages without template approval.
 *
 * Feature flag: notifications.whatsapp_trai_dlt must be enabled by admin before use.
 * Set env vars: WHATSAPP_API_URL, WHATSAPP_ACCESS_TOKEN, WHATSAPP_PHONE_NUMBER_ID,
 *               WHATSAPP_WEBHOOK_VERIFY_TOKEN, WHATSAPP_BUSINESS_ACCOUNT_ID
 */

// ── Template name registry ─────────────────────────────────────────────────────
// Each constant maps to a Meta-approved + TRAI DLT-registered template.
// Register all templates in Meta's Template Manager before going live.
export const WA_TEMPLATES = {
  // Staff self-service
  STAFF_TASK_ASSIGNED:     'utamacs_staff_task_assigned',
  STAFF_CHECKIN_CONFIRM:   'utamacs_staff_checkin_confirm',
  STAFF_CHECKOUT_CONFIRM:  'utamacs_staff_checkout_confirm',
  STAFF_TASK_OVERDUE:      'utamacs_staff_task_overdue',
  STAFF_TASK_REMINDER:     'utamacs_staff_task_reminder',

  // Supervisor / AFM operational alerts
  LATE_CHECKIN_ALERT:      'utamacs_late_checkin_alert',
  ABSENT_ALERT:            'utamacs_absent_alert',
  PROPOSAL_APPROVED:       'utamacs_proposal_approved',
  PROPOSAL_REJECTED:       'utamacs_proposal_rejected',

  // Compliance
  COMPLIANCE_OVERDUE:      'utamacs_compliance_overdue',
  AGENCY_LICENSE_EXPIRING: 'utamacs_agency_license_expiring',

  // Executive / admin
  MONTHLY_STAFF_REPORT:    'utamacs_monthly_staff_report',

  // General portal notifications
  GENERAL_NOTIFICATION:    'utamacs_general_notification',
} as const;

export type WaTemplateName = typeof WA_TEMPLATES[keyof typeof WA_TEMPLATES];

// Language codes supported by Meta for Indian languages
export type WaLangCode = 'en' | 'en_IN' | 'hi' | 'te' | 'kn' | 'ta';

// Mapping from staff language_preference → Meta language code
export const LANG_MAP: Record<string, WaLangCode> = {
  en: 'en_IN',
  hi: 'hi',
  te: 'te',
};

// ── Core types ─────────────────────────────────────────────────────────────────

export interface WaTextParam { type: 'text'; text: string }
export interface WaComponent {
  type: 'header' | 'body' | 'button';
  parameters: WaTextParam[];
  sub_type?: 'quick_reply' | 'url';
  index?: number;
}

export interface WhatsAppMessage {
  to: string;            // E.164: +91XXXXXXXXXX
  templateName: WaTemplateName;
  languageCode: WaLangCode;
  components?: WaComponent[];
}

export interface WhatsAppResult {
  messageId: string | null;
  status: 'sent' | 'failed' | 'stub';
  error?: string;
}

// ── Internal helpers ───────────────────────────────────────────────────────────

function isConfigured(): boolean {
  return !!(
    import.meta.env.WHATSAPP_API_URL &&
    import.meta.env.WHATSAPP_ACCESS_TOKEN &&
    import.meta.env.WHATSAPP_PHONE_NUMBER_ID
  );
}

function buildPayload(message: WhatsAppMessage) {
  return {
    messaging_product: 'whatsapp',
    recipient_type: 'individual',
    to: message.to,
    type: 'template',
    template: {
      name: message.templateName,
      language: { code: message.languageCode },
      components: message.components ?? [],
    },
  };
}

// ── Single send ────────────────────────────────────────────────────────────────

export async function sendWhatsApp(message: WhatsAppMessage): Promise<WhatsAppResult> {
  if (!isConfigured()) {
    console.info('[WhatsApp stub] Would send to', message.to, '|', message.templateName);
    return { messageId: null, status: 'stub' };
  }

  const url = `${import.meta.env.WHATSAPP_API_URL}/${import.meta.env.WHATSAPP_PHONE_NUMBER_ID}/messages`;

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${import.meta.env.WHATSAPP_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(buildPayload(message)),
    });

    const body = await res.json().catch(() => ({}));

    if (!res.ok) {
      const errMsg = body?.error?.message ?? `HTTP ${res.status}`;
      console.error('[WhatsApp] send failed:', errMsg);
      return { messageId: null, status: 'failed', error: errMsg };
    }

    const messageId: string = body?.messages?.[0]?.id ?? null;
    return { messageId, status: 'sent' };
  } catch (err) {
    const error = err instanceof Error ? err.message : String(err);
    console.error('[WhatsApp] network error:', error);
    return { messageId: null, status: 'failed', error };
  }
}

// ── Bulk send ──────────────────────────────────────────────────────────────────
// Sends to a list of recipients sequentially with a 100 ms gap to avoid rate-limiting.
// Meta Cloud API rate limit: 250 messages/second per WABA — well within this pace.

export interface BulkRecipient {
  phone: string;       // E.164
  langCode?: WaLangCode;
  components?: WaComponent[];
}

export interface BulkResult {
  phone: string;
  result: WhatsAppResult;
}

export async function sendWhatsAppBulk(
  templateName: WaTemplateName,
  recipients: BulkRecipient[],
  defaultLangCode: WaLangCode = 'en_IN',
): Promise<BulkResult[]> {
  const results: BulkResult[] = [];

  for (const r of recipients) {
    const result = await sendWhatsApp({
      to: r.phone,
      templateName,
      languageCode: r.langCode ?? defaultLangCode,
      components: r.components,
    });
    results.push({ phone: r.phone, result });
    if (isConfigured()) await new Promise(res => setTimeout(res, 100));
  }

  return results;
}

// ── Free-form text message (user-initiated session only) ───────────────────────
// Can only be used within 24 hours of the staff member messaging the society number.
// No DLT registration required for this type.

export async function sendWhatsAppText(to: string, text: string): Promise<WhatsAppResult> {
  if (!isConfigured()) {
    console.info('[WhatsApp stub] Would send text to', to);
    return { messageId: null, status: 'stub' };
  }

  const url = `${import.meta.env.WHATSAPP_API_URL}/${import.meta.env.WHATSAPP_PHONE_NUMBER_ID}/messages`;

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${import.meta.env.WHATSAPP_ACCESS_TOKEN}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        messaging_product: 'whatsapp',
        recipient_type: 'individual',
        to,
        type: 'text',
        text: { preview_url: false, body: text },
      }),
    });

    const body = await res.json().catch(() => ({}));
    if (!res.ok) {
      return { messageId: null, status: 'failed', error: body?.error?.message };
    }
    return { messageId: body?.messages?.[0]?.id ?? null, status: 'sent' };
  } catch (err) {
    return { messageId: null, status: 'failed', error: String(err) };
  }
}
