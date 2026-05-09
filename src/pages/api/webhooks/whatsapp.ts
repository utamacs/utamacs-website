export const prerender = false;

/**
 * WhatsApp Cloud API Webhook
 *
 * GET  — Meta's hub.verify handshake (called once when you register the webhook URL in Meta dashboard)
 * POST — Incoming events: delivery receipts, read receipts, staff replies
 *
 * Configure in Meta Developer Console → WhatsApp → Configuration → Webhook:
 *   Callback URL:  https://portal.utamacs.org/api/webhooks/whatsapp
 *   Verify token:  value of WHATSAPP_WEBHOOK_VERIFY_TOKEN env var
 *   Subscribed fields: messages, message_deliveries, message_reads
 */

import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { sendWhatsAppText } from '@lib/services/providers/messaging/WhatsAppService';

const VERIFY_TOKEN = import.meta.env.WHATSAPP_WEBHOOK_VERIFY_TOKEN ?? '';
const SOCIETY_ID   = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// ── GET: Meta webhook verification handshake ───────────────────────────────────
export const GET: APIRoute = async ({ request }) => {
  const url    = new URL(request.url);
  const mode   = url.searchParams.get('hub.mode');
  const token  = url.searchParams.get('hub.verify_token');
  const challenge = url.searchParams.get('hub.challenge');

  if (mode === 'subscribe' && token === VERIFY_TOKEN) {
    return new Response(challenge, { status: 200 });
  }
  return new Response('Forbidden', { status: 403 });
};

// ── POST: Incoming webhook events ─────────────────────────────────────────────
export const POST: APIRoute = async ({ request }) => {
  // Always return 200 immediately so Meta doesn't retry
  const body = await request.json().catch(() => null);
  if (!body) return new Response('ok', { status: 200 });

  // Process asynchronously — don't await, return 200 now
  handleWebhookEvent(body).catch(err =>
    console.error('[WhatsApp webhook] processing error:', err)
  );

  return new Response('ok', { status: 200 });
};

// ── Event handler ─────────────────────────────────────────────────────────────

interface WaWebhookEntry {
  id: string;
  changes: Array<{
    value: {
      messaging_product: string;
      metadata: { display_phone_number: string; phone_number_id: string };
      contacts?: Array<{ profile: { name: string }; wa_id: string }>;
      messages?: WaIncomingMessage[];
      statuses?: WaStatusUpdate[];
    };
    field: string;
  }>;
}

interface WaIncomingMessage {
  id: string;
  from: string;        // E.164 without leading +
  timestamp: string;
  type: 'text' | 'image' | 'document' | 'audio' | 'interactive';
  text?: { body: string };
  context?: { id: string };  // reply to a message
}

interface WaStatusUpdate {
  id: string;          // message ID
  recipient_id: string;
  status: 'sent' | 'delivered' | 'read' | 'failed';
  timestamp: string;
  errors?: Array<{ code: number; title: string }>;
}

async function handleWebhookEvent(body: { object: string; entry?: WaWebhookEntry[] }) {
  if (body.object !== 'whatsapp_business_account') return;

  for (const entry of body.entry ?? []) {
    for (const change of entry.changes ?? []) {
      if (change.field !== 'messages') continue;
      const { messages = [], statuses = [] } = change.value;

      await Promise.all([
        ...messages.map(m => handleIncomingMessage(m, change.value.metadata.phone_number_id)),
        ...statuses.map(s => handleStatusUpdate(s)),
      ]);
    }
  }
}

// ── Incoming message from a staff member ──────────────────────────────────────
// Staff members can reply to the WhatsApp number to trigger actions.
// Commands (case-insensitive, any language):
//   "HI" / "PRESENT" / "IN"   → auto check-in attempt
//   "BYE" / "OUT"              → auto check-out attempt
//   "TASKS" / "LIST"           → reply with today's task list

const CHECK_IN_KEYWORDS  = new Set(['hi', 'present', 'in', 'checkin', 'आया', 'వచ్చాను']);
const CHECK_OUT_KEYWORDS = new Set(['bye', 'out', 'checkout', 'done', 'गया', 'వెళ్ళాను']);
const TASK_KEYWORDS      = new Set(['tasks', 'list', 'काम', 'పని']);

async function handleIncomingMessage(msg: WaIncomingMessage, _phoneNumberId: string) {
  if (msg.type !== 'text' || !msg.text?.body) return;

  const phone = `+${msg.from}`;
  const text  = msg.text.body.trim().toLowerCase();
  const sb    = getSupabaseServiceClient();

  // Look up staff member by phone
  const { data: staff } = await sb
    .from('staff_members')
    .select('id, name, language_preference, qr_token, self_checkin_enabled')
    .eq('society_id', SOCIETY_ID)
    .eq('phone', phone)
    .eq('is_active', true)
    .maybeSingle();

  if (!staff) {
    // Unknown sender — silently ignore (don't leak info)
    return;
  }

  if (!staff.self_checkin_enabled) {
    await sendWhatsAppText(phone,
      'Self check-in via WhatsApp is not enabled for your account. Please contact your supervisor.'
    );
    return;
  }

  if (CHECK_IN_KEYWORDS.has(text)) {
    await handleWhatsAppCheckIn(phone, staff, sb);
  } else if (CHECK_OUT_KEYWORDS.has(text)) {
    await handleWhatsAppCheckOut(phone, staff, sb);
  } else if (TASK_KEYWORDS.has(text)) {
    await handleWhatsAppTaskList(phone, staff, sb);
  } else {
    // Echo help menu
    const help = staff.language_preference === 'hi'
      ? 'कमांड:\nIN - हाजिरी दर्ज करें\nOUT - बाहर जाएं\nTASKS - आज के काम देखें'
      : staff.language_preference === 'te'
      ? 'కమాండ్లు:\nIN - హాజరు నమోదు\nOUT - నిష్క్రమించు\nTASKS - నేటి పనులు చూడండి'
      : 'Commands:\nIN - Check in\nOUT - Check out\nTASKS - View today\'s tasks';
    await sendWhatsAppText(phone, help);
  }
}

async function handleWhatsAppCheckIn(
  phone: string,
  staff: { id: string; name: string; language_preference: string },
  sb: ReturnType<typeof getSupabaseServiceClient>,
) {
  const now = new Date();
  const today = now.toISOString().slice(0, 10);

  // Upsert attendance — do nothing if already checked in today
  const { error } = await sb.from('staff_attendance').upsert({
    society_id: SOCIETY_ID,
    staff_id: staff.id,
    date: today,
    check_in: now.toISOString(),
    check_in_method: 'whatsapp',
    status: 'present',
  }, { onConflict: 'staff_id,date', ignoreDuplicates: true });

  const timeStr = now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });

  if (error) {
    await sendWhatsAppText(phone, 'Could not record check-in. Please contact your supervisor.');
    return;
  }

  const confirm = staff.language_preference === 'hi'
    ? `✅ ${timeStr} पर हाजिरी दर्ज हो गई। - UTAMACS`
    : staff.language_preference === 'te'
    ? `✅ ${timeStr} కి హాజరు నమోదైంది. - UTAMACS`
    : `✅ Checked in at ${timeStr}. - UTAMACS`;

  await sendWhatsAppText(phone, confirm);
}

async function handleWhatsAppCheckOut(
  phone: string,
  staff: { id: string; name: string; language_preference: string },
  sb: ReturnType<typeof getSupabaseServiceClient>,
) {
  const now = new Date();
  const today = now.toISOString().slice(0, 10);

  const { error } = await sb.from('staff_attendance')
    .update({ check_out: now.toISOString(), check_out_method: 'whatsapp' })
    .eq('staff_id', staff.id)
    .eq('date', today)
    .is('check_out', null);

  const timeStr = now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' });

  if (error) {
    await sendWhatsAppText(phone, 'Could not record check-out. Please contact your supervisor.');
    return;
  }

  const confirm = staff.language_preference === 'hi'
    ? `👋 ${timeStr} पर बाहर जाना दर्ज हुआ। शुभ दिन! - UTAMACS`
    : staff.language_preference === 'te'
    ? `👋 ${timeStr} కి నిష్క్రమణ నమోదైంది. శుభదినం! - UTAMACS`
    : `👋 Checked out at ${timeStr}. Have a good day! - UTAMACS`;

  await sendWhatsAppText(phone, confirm);
}

async function handleWhatsAppTaskList(
  phone: string,
  staff: { id: string; name: string; language_preference: string },
  sb: ReturnType<typeof getSupabaseServiceClient>,
) {
  const today = new Date().toISOString().slice(0, 10);
  const lang  = staff.language_preference ?? 'en';

  const { data: tasks } = await sb
    .from('staff_activity_assignments')
    .select('title, title_hi, title_te, status, due_time')
    .eq('staff_id', staff.id)
    .eq('assigned_date', today)
    .order('due_time', { ascending: true });

  if (!tasks?.length) {
    const none = lang === 'hi' ? 'आज कोई काम नहीं सौंपा गया।'
               : lang === 'te' ? 'నేడు పనులు లేవు.'
               : 'No tasks assigned for today.';
    await sendWhatsAppText(phone, none);
    return;
  }

  const statusIcon = (s: string) =>
    s === 'completed' ? '✅' : s === 'overdue' ? '🔴' : s === 'in_progress' ? '🔄' : '○';

  const lines = tasks.map(t => {
    const title = (lang === 'hi' ? t.title_hi : lang === 'te' ? t.title_te : null) ?? t.title;
    const time  = t.due_time ? ` (${t.due_time.slice(0, 5)})` : '';
    return `${statusIcon(t.status)} ${title}${time}`;
  });

  const header = lang === 'hi' ? 'आज के काम:\n' : lang === 'te' ? 'నేటి పనులు:\n' : "Today's tasks:\n";
  await sendWhatsAppText(phone, header + lines.join('\n'));
}

// ── Delivery / read status update ─────────────────────────────────────────────
async function handleStatusUpdate(status: WaStatusUpdate) {
  // Log delivery failures for observability
  if (status.status === 'failed') {
    console.warn('[WhatsApp webhook] delivery failed:', {
      messageId: status.id,
      recipient: status.recipient_id,
      errors: status.errors,
    });
  }
  // Future: update a whatsapp_message_log table to track delivery rates
}
