/**
 * SMS provider stub — requires TRAI DLT entity + template registration before activation.
 * Feature flag: notifications.sms_trai_dlt must be enabled by admin before use.
 * When real integration is ready, implement sendSms() against your DLT-registered provider
 * (e.g. MSG91, Textlocal, Kaleyra) by setting SMS_PROVIDER_API_KEY and SMS_SENDER_ID env vars.
 */

export interface SmsMessage {
  to: string;       // E.164 format: +91XXXXXXXXXX
  templateId: string; // TRAI DLT registered template ID
  params: string[];   // Template variable substitutions in order
}

export async function sendSms(message: SmsMessage): Promise<void> {
  const apiKey = import.meta.env.SMS_PROVIDER_API_KEY;
  const senderId = import.meta.env.SMS_SENDER_ID;

  if (!apiKey || !senderId) {
    // Stub: log and return — no network call
    console.info('[SMS stub] Would send SMS to', message.to, 'template:', message.templateId);
    return;
  }

  // Real implementation: uncomment and fill in your DLT-compliant provider's API
  // const res = await fetch('https://api.your-sms-provider.com/send', {
  //   method: 'POST',
  //   headers: { 'Authorization': `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
  //   body: JSON.stringify({
  //     sender: senderId,
  //     to: message.to,
  //     template_id: message.templateId,
  //     variables: message.params,
  //   }),
  // });
  // if (!res.ok) throw new Error(`SMS send failed: ${res.status}`);
  throw new Error('SMS provider not yet configured. Set SMS_PROVIDER_API_KEY and SMS_SENDER_ID.');
}
