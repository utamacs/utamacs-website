/**
 * WhatsApp Business API stub — requires TRAI DLT entity + template registration before activation.
 * Feature flag: notifications.whatsapp_trai_dlt must be enabled by admin before use.
 * When ready: obtain WhatsApp Business API access (Meta), register TRAI DLT templates,
 * then set WHATSAPP_API_URL, WHATSAPP_ACCESS_TOKEN, and WHATSAPP_PHONE_NUMBER_ID env vars.
 */

export interface WhatsAppMessage {
  to: string;           // E.164 format: +91XXXXXXXXXX
  templateName: string; // Meta-approved + TRAI DLT registered template name
  languageCode: string; // e.g. 'en' or 'te'
  components?: Array<{
    type: 'body' | 'header' | 'button';
    parameters: Array<{ type: 'text'; text: string }>;
  }>;
}

export async function sendWhatsApp(message: WhatsAppMessage): Promise<void> {
  const apiUrl = import.meta.env.WHATSAPP_API_URL;
  const token = import.meta.env.WHATSAPP_ACCESS_TOKEN;
  const phoneNumberId = import.meta.env.WHATSAPP_PHONE_NUMBER_ID;

  if (!apiUrl || !token || !phoneNumberId) {
    // Stub: log and return — no network call
    console.info('[WhatsApp stub] Would send to', message.to, 'template:', message.templateName);
    return;
  }

  // Real implementation (Meta Cloud API):
  const res = await fetch(`${apiUrl}/${phoneNumberId}/messages`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      recipient_type: 'individual',
      to: message.to,
      type: 'template',
      template: {
        name: message.templateName,
        language: { code: message.languageCode },
        components: message.components ?? [],
      },
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`WhatsApp send failed: ${res.status} — ${err}`);
  }
}
