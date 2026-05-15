export const prerender = false;
// Master daily cron — replaces all per-feature cron endpoints.
// Vercel Hobby allows max 2 crons at daily-minimum intervals.
// This single endpoint runs everything at 07:00 IST (01:30 UTC) daily.
// Each task is time-boxed: skip and continue on any individual failure.
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { loadRules, r, RULE } from '@lib/rules';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { fanoutNotification } from '@lib/notifications';

const SOCIETY_ID    = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const CRON_SECRET   = import.meta.env.CRON_SECRET;
const GITHUB_REPO   = import.meta.env.GITHUB_HOTO_REPO ?? '';
const GITHUB_TOKEN  = import.meta.env.GITHUB_HOTO_TOKEN ?? import.meta.env.GITHUB_LETTERS_TOKEN ?? '';
const RESEND_API_KEY = import.meta.env.RESEND_API_KEY ?? '';
const SENDER_NAME   = 'UTA MACS Society';
const SENDER_EMAIL  = import.meta.env.SOCIETY_SENDER_EMAIL ?? 'no-reply@utamacs.org';

export const GET: APIRoute = async ({ request }) => {
  const t0 = Date.now();
  if (CRON_SECRET && request.headers.get('authorization') !== `Bearer ${CRON_SECRET}`) {
    return Response.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const sb = getSupabaseServiceClient();
  const now = new Date();
  const nowIso = now.toISOString();
  const todayStr = nowIso.slice(0, 10);
  const results: Record<string, unknown> = {};

  // ── 1. Supabase ping (keep-alive: free tier pauses after 7 days) ──────────
  try {
    await sb.from('profiles').select('id', { count: 'exact', head: true });
    results.supabase_ping = 'OK';
  } catch { results.supabase_ping = 'ERROR'; }

  // ── 2. GitHub health check + circuit breaker ──────────────────────────────
  try {
    results.github_health = await runGitHubHealth(sb, nowIso);
  } catch (err) {
    results.github_health = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── 3. Upload queue cleanup (mark permanently failed, alert admins) ────────
  try {
    results.upload_queue = await runUploadQueueCleanup(sb, nowIso);
  } catch (err) {
    results.upload_queue = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── 4. Builder SLA escalation (overdue hoto_items) ────────────────────────
  try {
    results.sla_escalation = await runSlaEscalation(sb, now, todayStr);
  } catch (err) {
    results.sla_escalation = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── 5. Weekly digest (Monday only) ────────────────────────────────────────
  if (now.getDay() === 1) { // 1 = Monday
    try {
      results.weekly_digest = await runWeeklyDigest(sb, now, todayStr);
    } catch (err) {
      results.weekly_digest = { error: err instanceof Error ? err.message : String(err) };
    }
  } else {
    results.weekly_digest = 'SKIPPED_NOT_MONDAY';
  }

  // ── 6. Payment reminders (overdue maintenance dues) ───────────────────────
  try {
    results.payment_reminders = await runPaymentReminders(sb, todayStr);
  } catch (err) {
    results.payment_reminders = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── 7. Expire marketplace listings + visitor pre-approvals ────────────────
  try {
    const [listings, preapprovals] = await Promise.all([
      sb.from('marketplace_listings').update({ status: 'expired' })
        .eq('society_id', SOCIETY_ID).eq('status', 'active').lt('expires_at', nowIso).select('id'),
      sb.from('visitor_pre_approvals').update({ status: 'expired' })
        .eq('society_id', SOCIETY_ID).in('status', ['pending', 'approved']).lt('expires_at', nowIso).select('id'),
    ]);
    results.expirations = { listings: listings.data?.length ?? 0, preapprovals: preapprovals.data?.length ?? 0 };
  } catch (err) {
    results.expirations = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── 8. Auto-send Tier 1 email drafts (operational alerts, no manual review needed) ──
  try {
    results.auto_send = await runAutoSendTier1(sb);
  } catch (err) {
    results.auto_send = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── 9. Publish scheduled notices whose scheduled_at has passed ─────────────
  try {
    results.scheduled_notices = await runScheduledNotices(sb, nowIso);
  } catch (err) {
    results.scheduled_notices = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── 10. Complaint SLA escalation ─────────────────────────────────────────
  try {
    results.complaint_sla = await runComplaintSlaEscalation(sb, now, nowIso);
  } catch (err) {
    results.complaint_sla = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── 11. Event reminder notifications ──────────────────────────────────────
  try {
    results.event_reminders = await runEventReminders(sb, now, nowIso);
  } catch (err) {
    results.event_reminders = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── 12. Feedback SLA escalation (exec response overdue > 7 days) ──────────
  try {
    results.feedback_sla = await runFeedbackSlaEscalation(sb, now, nowIso);
  } catch (err) {
    results.feedback_sla = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── 13. AMC renewal reminders (30 days before end_date) ──────────────────
  try {
    results.amc_reminders = await runAmcRenewalReminders(sb, now, nowIso);
  } catch (err) {
    results.amc_reminders = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── 14. Daily notification digest emails ───────────────────────────────────
  try {
    results.digest_emails = await runDailyDigest(sb, now, nowIso);
  } catch (err) {
    results.digest_emails = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── 15. Late fee application ───────────────────────────────────────────────
  try {
    results.late_fees = await runLateFeeApplication(sb, now, todayStr);
  } catch (err) {
    results.late_fees = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── 16. Notice acknowledgement reminders ──────────────────────────────────
  try {
    results.notice_ack_reminders = await runNoticeAckReminders(sb, nowIso, todayStr);
  } catch (err) {
    results.notice_ack_reminders = { error: err instanceof Error ? err.message : String(err) };
  }

  // ── Write master heartbeat ─────────────────────────────────────────────────
  try {
    await sb.from('cron_heartbeats').insert({
      cron_name: 'master', status: 'OK', items_processed: 1, items_failed: 0,
      duration_ms: Date.now() - t0, error_message: null,
    });
  } catch { /* non-fatal */ }

  return Response.json({ status: 'OK', duration_ms: Date.now() - t0, tasks: results });
};

// ── Task implementations ────────────────────────────────────────────────────

async function runGitHubHealth(sb: ReturnType<typeof getSupabaseServiceClient>, nowIso: string) {
  if (!GITHUB_REPO || !GITHUB_TOKEN) return 'SKIPPED_NOT_CONFIGURED';

  const [{ data: cbRow }, { data: failRow }] = await Promise.all([
    sb.from('system_config').select('value').eq('key', 'github_circuit_breaker').single(),
    sb.from('system_config').select('value').eq('key', 'github_consecutive_failures').single(),
  ]);
  const wasOpen = (cbRow?.value as string) === 'OPEN';
  const prevFailures = (failRow?.value as number) ?? 0;

  let ok = false;
  let errMsg = '';
  try {
    const res = await fetch(`https://api.github.com/repos/${GITHUB_REPO}`, {
      headers: { Authorization: `Bearer ${GITHUB_TOKEN}`, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' },
      signal: AbortSignal.timeout(5_000),
    });
    ok = res.ok;
    if (!res.ok) errMsg = `HTTP ${res.status}`;
  } catch (e) { errMsg = e instanceof Error ? e.message.slice(0, 100) : String(e); }

  if (ok) {
    await Promise.all([
      sb.from('system_config').update({ value: 0, updated_at: nowIso }).eq('key', 'github_consecutive_failures'),
      sb.from('system_config').update({ value: 'CLOSED', updated_at: nowIso }).eq('key', 'github_circuit_breaker'),
    ]);
    if (wasOpen) await alertCommittee(sb, '[RESOLVED] GitHub storage back online', 'The GitHub document storage circuit breaker has been closed. Uploads will resume on next attempt.');
    return { circuit: 'CLOSED', was_open: wasOpen };
  }

  const newFailures = prevFailures + 1;
  await sb.from('system_config').update({ value: newFailures, updated_at: nowIso }).eq('key', 'github_consecutive_failures');
  if (newFailures >= 3 && !wasOpen) {
    await sb.from('system_config').update({ value: 'OPEN', updated_at: nowIso }).eq('key', 'github_circuit_breaker');
    await alertCommittee(sb, '[ALERT] GitHub document storage unavailable',
      `GitHub has been unreachable for ${newFailures} consecutive checks. Document uploads are paused. Error: ${errMsg}`);
  }
  return { circuit: newFailures >= 3 ? 'OPEN' : 'CLOSED', failures: newFailures, error: errMsg };
}

async function runUploadQueueCleanup(sb: ReturnType<typeof getSupabaseServiceClient>, nowIso: string) {
  const { data: items } = await sb
    .from('upload_queue').select('id, attempts, file_name, target_github_path, item_type, item_id, error_message')
    .eq('society_id', SOCIETY_ID).in('status', ['PENDING', 'FAILED'])
    .or(`backoff_until.is.null,backoff_until.lte.${nowIso}`)
    .order('created_at', { ascending: true }).limit(5);

  let processed = 0;
  for (const q of items ?? []) {
    const row = q as any;
    if ((row.attempts ?? 0) >= 3) {
      await sb.from('upload_queue').update({ status: 'PERMANENTLY_FAILED', last_attempt_at: nowIso,
        error_message: 'Max retries exceeded — please re-upload.' }).eq('id', row.id);
      try {
        await sb.from('email_drafts').insert({
          society_id: SOCIETY_ID, tier: 1, triggered_by: 'cron:master:upload-cleanup',
          trigger_resource_type: 'upload_queue', trigger_resource_id: row.id,
          recipient_type: 'ADMIN',
          subject: `[ACTION REQUIRED] Document upload failed permanently: ${row.file_name}`,
          body_html: `<p>File <strong>${row.file_name}</strong> could not be uploaded after 3 attempts. Please ask the member to re-upload.</p><ul><li>Path: ${row.target_github_path}</li><li>Item: ${row.item_type}/${row.item_id}</li></ul>`,
          body_text: `Document upload failed permanently: ${row.file_name}\nPath: ${row.target_github_path}\nItem: ${row.item_type}/${row.item_id}\n\nPlease re-upload manually.`,
          suggested_sender_name: SENDER_NAME, suggested_sender_email: SENDER_EMAIL, status: 'DRAFT',
        });
      } catch { /* non-fatal */ }
      processed++;
    }
  }
  return { processed };
}

async function runSlaEscalation(sb: ReturnType<typeof getSupabaseServiceClient>, now: Date, todayStr: string) {
  const rules = await loadRules(SOCIETY_ID);
  const escalationDays = r<number[]>(rules, RULE.HOTO_SLA_ESCALATION_DAYS, [7, 14, 30]);
  const [d7, d14, d30] = [escalationDays[0] ?? 7, escalationDays[1] ?? 14, escalationDays[2] ?? 30];

  const { data: items } = await sb
    .from('hoto_items').select('id, title, hoto_category, builder_sla_date, priority, status')
    .eq('society_id', SOCIETY_ID).not('builder_sla_date', 'is', null)
    .not('status', 'in', '("CLOSED","REJECTED")').lt('builder_sla_date', todayStr).limit(5);

  let escalated = 0;
  const today = new Date(now); today.setHours(0, 0, 0, 0);

  for (const item of items ?? []) {
    const it = item as any;
    const daysOverdue = Math.floor((today.getTime() - new Date(it.builder_sla_date).getTime()) / 86_400_000);
    let tier: number, triggerKey: string;
    if (daysOverdue >= d30) { tier = 3; triggerKey = `sla_${d30}d`; }
    else if (daysOverdue >= d14) { tier = 2; triggerKey = `sla_${d14}d`; }
    else if (daysOverdue >= d7) { tier = 2; triggerKey = `sla_${d7}d`; }
    else continue;

    const { count } = await sb.from('email_drafts').select('id', { count: 'exact', head: true })
      .eq('triggered_by', `cron:sla-escalation:${triggerKey}`).eq('trigger_resource_id', it.id)
      .gte('created_at', `${todayStr}T00:00:00.000Z`);
    if (count && count > 0) continue;

    const subject = tier === 3
      ? `[URGENT] Builder SLA ${daysOverdue}d overdue — legal notice required: ${it.title}`
      : `[ESCALATION] Builder SLA ${daysOverdue}d overdue: ${it.title}`;
    const committee = await getCommitteeEmails(sb);
    for (const person of committee) {
      try {
        await sb.from('email_drafts').insert({
          society_id: SOCIETY_ID, tier,
          triggered_by: `cron:sla-escalation:${triggerKey}`,
          trigger_resource_type: 'hoto_item', trigger_resource_id: it.id,
          recipient_type: 'COMMITTEE', recipient_email: person.email, recipient_name: person.name,
          subject,
          body_html: `<p>HOTO item <strong>${it.title}</strong> (${it.hoto_category}) has an overdue builder SLA commitment.</p><ul><li>SLA Date: ${it.builder_sla_date}</li><li>Days Overdue: ${daysOverdue}</li><li>Priority: ${it.priority}</li><li>Status: ${it.status}</li></ul>${tier === 3 ? '<p style="color:red"><strong>Consider formal legal notice to the builder.</strong></p>' : ''}`,
          body_text: `${subject}\n\nSLA Date: ${it.builder_sla_date}\nDays Overdue: ${daysOverdue}\nPriority: ${it.priority}\nStatus: ${it.status}`,
          suggested_sender_name: SENDER_NAME, suggested_sender_email: SENDER_EMAIL, status: 'DRAFT',
        });
      } catch { /* non-fatal */ }
    }
    escalated++;
  }
  return { escalated };
}

async function runWeeklyDigest(sb: ReturnType<typeof getSupabaseServiceClient>, now: Date, todayStr: string) {
  const rules = await loadRules(SOCIETY_ID);
  if (!r<boolean>(rules, RULE.WEEKLY_DIGEST_ENABLED, true)) return 'DISABLED';

  const monday = new Date(now);
  monday.setDate(now.getDate() - ((now.getDay() + 6) % 7));
  monday.setHours(0, 0, 0, 0);

  const { count: existing } = await sb.from('email_drafts').select('id', { count: 'exact', head: true })
    .eq('triggered_by', 'cron:weekly-digest').gte('created_at', monday.toISOString());
  if (existing && existing > 0) return 'ALREADY_RAN';

  const [{ count: hotoOpen }, { count: snagsOpen }, { count: vendorActive }, { count: pendingUploads }] = await Promise.all([
    sb.from('hoto_items').select('id', { count: 'exact', head: true }).eq('society_id', SOCIETY_ID).not('status', 'in', '("CLOSED","REJECTED")'),
    sb.from('snag_items').select('id', { count: 'exact', head: true }).eq('society_id', SOCIETY_ID).in('status', ['OPEN', 'REOPENED', 'IN_PROGRESS']).eq('deleted', false),
    sb.from('vendor_requirements').select('id', { count: 'exact', head: true }).eq('society_id', SOCIETY_ID).not('status', 'in', '("CANCELLED","CONTRACT_SIGNED")'),
    sb.from('upload_queue').select('id', { count: 'exact', head: true }).eq('society_id', SOCIETY_ID).in('status', ['PENDING', 'FAILED']),
  ]);

  const weekLabel = `Week of ${monday.toISOString().slice(0, 10)}`;
  const subject = `HOTO Weekly Digest — ${weekLabel}`;
  const bodyHtml = `<h2 style="color:#1E3A8A">UTA MACS HOTO — Weekly Status Digest</h2><p>${weekLabel}</p><table border="0" cellpadding="4"><tr><td>HOTO Items (active):</td><td><strong>${hotoOpen ?? 0}</strong></td></tr><tr><td>Snag Items (open/in-progress):</td><td><strong>${snagsOpen ?? 0}</strong></td></tr><tr><td>Vendor Requirements (active):</td><td><strong>${vendorActive ?? 0}</strong></td></tr>${(pendingUploads ?? 0) > 0 ? `<tr><td style="color:#B45309">Pending Uploads:</td><td><strong>${pendingUploads}</strong></td></tr>` : ''}</table><p><a href="https://portal.utamacs.org">View full dashboard →</a></p>`;
  const bodyText = `HOTO Weekly Digest (${weekLabel})\n\nHOTO active: ${hotoOpen ?? 0}\nSnags open: ${snagsOpen ?? 0}\nVendors active: ${vendorActive ?? 0}${(pendingUploads ?? 0) > 0 ? `\nPending uploads: ${pendingUploads}` : ''}\n\nhttps://portal.utamacs.org`;

  const committee = await getCommitteeEmails(sb);
  for (const person of committee) {
    try {
      await sb.from('email_drafts').insert({
        society_id: SOCIETY_ID, tier: 2, triggered_by: 'cron:weekly-digest',
        trigger_resource_type: 'digest', trigger_resource_id: todayStr,
        recipient_type: 'COMMITTEE', recipient_email: person.email, recipient_name: person.name,
        subject, body_html: bodyHtml, body_text: bodyText,
        suggested_sender_name: SENDER_NAME, suggested_sender_email: SENDER_EMAIL, status: 'DRAFT',
      });
    } catch { /* non-fatal */ }
  }
  return { sent_to: committee.length };
}

async function runPaymentReminders(sb: ReturnType<typeof getSupabaseServiceClient>, todayStr: string) {
  const { data: overdue } = await sb.from('maintenance_dues').select('id, user_id, total_amount, due_date')
    .eq('society_id', SOCIETY_ID).in('status', ['pending', 'partially_paid', 'overdue']).lt('due_date', todayStr).limit(20);
  if (!overdue?.length) return { reminded: 0 };
  await sb.from('maintenance_dues').update({ status: 'overdue' })
    .in('id', overdue.map((d: any) => d.id)).eq('society_id', SOCIETY_ID);
  try {
    await sb.from('notifications').insert(overdue.map((d: any) => ({
      society_id: SOCIETY_ID, user_id: d.user_id,
      title: 'Maintenance Overdue', type: 'payment',
      body: `Your maintenance of ₹${Number(d.total_amount).toLocaleString('en-IN')} was due on ${d.due_date}.`,
      reference_table: 'maintenance_dues', reference_id: d.id, channel: 'in_app', status: 'sent',
    })));
  } catch { /* non-fatal */ }
  return { reminded: overdue.length };
}

async function runAutoSendTier1(sb: ReturnType<typeof getSupabaseServiceClient>) {
  // Auto-send Tier 1 drafts (operational alerts) that have a recipient email
  if (!RESEND_API_KEY) return 'SKIPPED_NO_RESEND_KEY';

  const { data: drafts } = await sb.from('email_drafts').select('id, recipient_email, recipient_name, subject, body_html, body_text, suggested_sender_name, suggested_sender_email')
    .eq('society_id', SOCIETY_ID).eq('status', 'DRAFT').eq('tier', 1)
    .not('recipient_email', 'is', null).order('created_at', { ascending: true }).limit(3);

  let sent = 0;
  for (const draft of drafts ?? []) {
    const d = draft as any;
    try {
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${RESEND_API_KEY}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ from: `${d.suggested_sender_name} <${d.suggested_sender_email}>`, to: [d.recipient_email], subject: d.subject, html: d.body_html, text: d.body_text }),
        signal: AbortSignal.timeout(5_000),
      });
      if (res.ok) {
        const { id: resendId } = await res.json() as { id?: string };
        await sb.from('email_drafts').update({ status: 'SENT', sent_at: new Date().toISOString(), resend_message_id: resendId ?? null }).eq('id', d.id);
        sent++;
      }
    } catch { /* skip and retry tomorrow */ }
  }
  return { sent };
}

async function runScheduledNotices(sb: ReturnType<typeof getSupabaseServiceClient>, nowIso: string) {
  const { data: due } = await sb
    .from('notices')
    .select('id, title, category')
    .eq('society_id', SOCIETY_ID)
    .eq('status', 'scheduled')
    .lte('scheduled_at', nowIso)
    .limit(20);

  if (!due?.length) return { published: 0 };

  const ids = due.map((n: any) => n.id);
  await sb
    .from('notices')
    .update({ status: 'published', is_published: true, published_at: nowIso })
    .in('id', ids)
    .eq('society_id', SOCIETY_ID);

  for (const notice of due) {
    const n = notice as any;
    fanoutNotification({
      societyId: SOCIETY_ID,
      preferenceKey: 'notices',
      title: `Notice: ${n.title}`,
      body: n.category,
      type: 'notice',
      referenceTable: 'notices',
      referenceId: n.id,
    });
  }

  return { published: ids.length };
}

async function runComplaintSlaEscalation(sb: ReturnType<typeof getSupabaseServiceClient>, now: Date, nowIso: string) {
  // Escalate complaints that have been Open or Assigned for more than 48 hours
  // without a status change. Sends an in-app notification to executive members.
  const cutoff48h = new Date(now.getTime() - 48 * 3_600_000).toISOString();

  const { data: stale } = await sb
    .from('complaints')
    .select('id, title, status, raised_by, created_at')
    .eq('society_id', SOCIETY_ID)
    .in('status', ['Open', 'Assigned'])
    .lt('created_at', cutoff48h)
    .limit(20);

  if (!stale?.length) return { escalated: 0 };

  // Get exec members to notify
  const { data: execs } = await sb
    .from('profiles')
    .select('id')
    .eq('society_id', SOCIETY_ID)
    .eq('is_active', true)
    .in('portal_role', ['executive', 'secretary', 'president']);

  const execIds = (execs ?? []).map((e: any) => e.id);
  if (!execIds.length) return { escalated: 0 };

  let escalated = 0;
  for (const complaint of stale) {
    const c = complaint as any;
    // Dedup: skip if already escalated today
    const { count } = await sb
      .from('notifications')
      .select('id', { count: 'exact', head: true })
      .eq('society_id', SOCIETY_ID)
      .eq('reference_id', c.id)
      .eq('reference_table', 'complaints')
      .eq('title', 'Complaint SLA overdue')
      .gte('created_at', nowIso.slice(0, 10) + 'T00:00:00.000Z');
    if (count && count > 0) continue;

    const hoursOpen = Math.round((now.getTime() - new Date(c.created_at).getTime()) / 3_600_000);
    try {
      await sb.from('notifications').insert(
        execIds.map((uid: string) => ({
          society_id: SOCIETY_ID,
          user_id: uid,
          title: 'Complaint SLA overdue',
          body: `"${c.title}" has been ${c.status} for ${hoursOpen}h with no update.`,
          type: 'complaint',
          reference_table: 'complaints',
          reference_id: c.id,
          is_read: false,
        })),
      );
      escalated++;
    } catch { /* non-fatal */ }
  }

  return { escalated };
}

async function runEventReminders(sb: ReturnType<typeof getSupabaseServiceClient>, now: Date, nowIso: string) {
  // Daily cron fires at 07:00 IST. We send two reminder types:
  //   "Tomorrow" reminder — events starting in the next 20–32h window
  //   "Today"    reminder — events starting in the next 0–20h window (same day)
  const windowStart = new Date(now);
  const windowTomorrow = new Date(now.getTime() + 20 * 3_600_000);
  const windowEnd     = new Date(now.getTime() + 32 * 3_600_000);

  const [{ data: todayEvents }, { data: tomorrowEvents }] = await Promise.all([
    sb.from('events')
      .select('id, title, starts_at')
      .eq('society_id', SOCIETY_ID)
      .eq('is_published', true)
      .gte('starts_at', nowIso)
      .lt('starts_at', windowTomorrow.toISOString())
      .limit(20),
    sb.from('events')
      .select('id, title, starts_at')
      .eq('society_id', SOCIETY_ID)
      .eq('is_published', true)
      .gte('starts_at', windowTomorrow.toISOString())
      .lte('starts_at', windowEnd.toISOString())
      .limit(20),
  ]);

  let reminders = 0;

  const sendEventReminder = async (event: any, label: string) => {
    // Dedup: skip if we already sent a reminder for this event today
    const { count } = await sb.from('notifications')
      .select('id', { count: 'exact', head: true })
      .eq('society_id', SOCIETY_ID)
      .eq('reference_id', event.id)
      .eq('reference_table', 'events')
      .eq('type', 'event')
      .gte('created_at', windowStart.toISOString().slice(0, 10) + 'T00:00:00.000Z');
    if (count && count > 0) return; // already reminded today

    // Get all registered users for this event
    const { data: regs } = await sb.from('event_registrations')
      .select('user_id')
      .eq('event_id', event.id)
      .in('status', ['registered', 'waitlisted']);

    if (!regs?.length) return;

    const startsAt = new Date(event.starts_at);
    const timeStr = startsAt.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Kolkata' });

    try {
      await sb.from('notifications').insert(
        regs.map((r: any) => ({
          society_id: SOCIETY_ID,
          user_id: r.user_id,
          title: `Reminder: ${event.title}`,
          body: `${label} at ${timeStr} IST. Don't forget to attend!`,
          type: 'event',
          reference_table: 'events',
          reference_id: event.id,
          is_read: false,
        })),
      );
      reminders += regs.length;
    } catch { /* non-fatal */ }
  };

  for (const e of todayEvents ?? []) await sendEventReminder(e as any, 'Today');
  for (const e of tomorrowEvents ?? []) await sendEventReminder(e as any, 'Tomorrow');

  return { reminders };
}

async function runDailyDigest(sb: ReturnType<typeof getSupabaseServiceClient>, now: Date, nowIso: string) {
  // Send one daily digest email per member if they have unread notifications from the past 24h
  // and have email_digest_enabled = true in notification_preferences.
  if (!RESEND_API_KEY) return 'SKIPPED_NO_RESEND_KEY';

  const since24h = new Date(now.getTime() - 24 * 3_600_000).toISOString();
  const todayPrefix = nowIso.slice(0, 10);

  // Members with email digest opted in
  const { data: prefs } = await sb
    .from('notification_preferences')
    .select('user_id')
    .eq('email_enabled', true)
    .eq('email_digest_enabled', true)
    .limit(200);

  if (!prefs?.length) return { sent: 0 };

  let sent = 0;
  for (const pref of prefs) {
    try {
      // Dedup: already sent a digest to this user today?
      const { count: alreadySent } = await sb
        .from('email_drafts')
        .select('id', { count: 'exact', head: true })
        .eq('recipient_type', 'MEMBER')
        .eq('triggered_by', 'cron:master:daily-digest')
        .like('subject', '%Daily Summary%')
        .gte('created_at', `${todayPrefix}T00:00:00.000Z`);
      if (alreadySent && alreadySent > 0) continue;

      // Fetch this user's unread notifications from past 24h
      const { data: notifs } = await sb
        .from('notifications')
        .select('type, title')
        .eq('user_id', pref.user_id)
        .eq('is_read', false)
        .gte('created_at', since24h)
        .eq('society_id', SOCIETY_ID)
        .limit(50);

      if (!notifs?.length) continue;

      // Group by type
      const grouped: Record<string, number> = {};
      for (const n of notifs) {
        const t = n.type ?? 'other';
        grouped[t] = (grouped[t] ?? 0) + 1;
      }

      // Get user email
      const { data: authUser } = await (sb as any).auth.admin.getUserById(pref.user_id);
      const email = authUser?.user?.email;
      const name = authUser?.user?.user_metadata?.full_name ?? 'Resident';
      if (!email) continue;

      const rows = Object.entries(grouped)
        .map(([type, count]) => `<tr><td style="padding:4px 8px;text-transform:capitalize">${type.replace(/_/g,' ')}</td><td style="padding:4px 8px;font-weight:600">${count}</td></tr>`)
        .join('');

      const bodyHtml = `
        <p>Hi ${name},</p>
        <p>You have <strong>${notifs.length} unread notification${notifs.length > 1 ? 's' : ''}</strong> from the last 24 hours:</p>
        <table border="0" cellpadding="0" cellspacing="0" style="border-collapse:collapse;margin:12px 0">
          <thead><tr style="background:#F3F4F6"><th style="padding:4px 8px;text-align:left">Type</th><th style="padding:4px 8px;text-align:left">Count</th></tr></thead>
          <tbody>${rows}</tbody>
        </table>
        <p><a href="https://portal.utamacs.org/portal/notifications" style="color:#1E3A8A">View all notifications →</a></p>
        <p style="color:#6B7280;font-size:12px">To stop receiving digest emails, update your notification preferences in the portal.</p>`;

      await sb.from('email_drafts').insert({
        society_id: SOCIETY_ID, tier: 1, status: 'DRAFT',
        triggered_by: 'cron:master:daily-digest',
        trigger_resource_type: 'notifications', trigger_resource_id: pref.user_id,
        recipient_type: 'MEMBER', recipient_email: email, recipient_name: name,
        subject: `UTA MACS Daily Summary — ${notifs.length} notification${notifs.length > 1 ? 's' : ''}`,
        body_html: bodyHtml,
        body_text: `You have ${notifs.length} unread notifications. Visit https://portal.utamacs.org/portal/notifications to view them.`,
        suggested_sender_name: SENDER_NAME, suggested_sender_email: SENDER_EMAIL,
      });
      sent++;
    } catch { /* non-fatal per user */ }
  }

  return { sent };
}

async function runAmcRenewalReminders(sb: ReturnType<typeof getSupabaseServiceClient>, now: Date, nowIso: string) {
  // Send exec notifications for AMC contracts expiring within 30 days.
  // One reminder per contract per day (dedup on reference_id).
  const in30Days = new Date(now);
  in30Days.setDate(in30Days.getDate() + 30);

  const { data: expiring } = await sb
    .from('amc_contracts')
    .select('id, equipment_name, end_date')
    .eq('society_id', SOCIETY_ID)
    .eq('is_active', true)
    .gte('end_date', now.toISOString().slice(0, 10))   // not yet expired
    .lte('end_date', in30Days.toISOString().slice(0, 10))
    .limit(20);

  if (!expiring?.length) return { reminded: 0 };

  const { data: execProfiles } = await sb
    .from('profiles')
    .select('id')
    .eq('society_id', SOCIETY_ID)
    .in('portal_role', ['executive', 'secretary', 'president'])
    .eq('is_active', true);

  const execIds = (execProfiles ?? []).map((p: any) => p.id);
  if (!execIds.length) return { reminded: 0 };

  let reminded = 0;
  for (const contract of expiring) {
    // Dedup: skip if already reminded today
    const { count } = await sb
      .from('notifications')
      .select('id', { count: 'exact', head: true })
      .eq('society_id', SOCIETY_ID)
      .eq('reference_id', contract.id)
      .eq('type', 'amc')
      .eq('title', 'AMC renewal due')
      .gte('created_at', nowIso.slice(0, 10) + 'T00:00:00.000Z');
    if (count && count > 0) continue;

    const daysLeft = Math.ceil((new Date(contract.end_date).getTime() - now.getTime()) / 86400000);
    try {
      await sb.from('notifications').insert(
        execIds.map((uid: string) => ({
          society_id: SOCIETY_ID,
          user_id: uid,
          title: 'AMC renewal due',
          body: `"${contract.equipment_name}" AMC expires in ${daysLeft} day${daysLeft !== 1 ? 's' : ''} (${contract.end_date}). Renew to avoid service gap.`,
          type: 'amc',
          reference_table: 'amc_contracts',
          reference_id: contract.id,
          is_read: false,
        })),
      );
      reminded++;
    } catch { /* non-fatal */ }
  }

  return { reminded };
}

async function runFeedbackSlaEscalation(sb: ReturnType<typeof getSupabaseServiceClient>, now: Date, nowIso: string) {
  // Escalate feedback items that have had no exec response for >7 days.
  // Feedback table: id, title, status, is_anonymous, submitted_by, created_at, response_at (nullable)
  const SLA_HOURS = 7 * 24; // 7 days
  const cutoff = new Date(now.getTime() - SLA_HOURS * 3_600_000).toISOString();

  const { data: stale } = await sb
    .from('feedbacks')
    .select('id, subject, status')
    .eq('society_id', SOCIETY_ID)
    .in('status', ['open', 'acknowledged', 'in_progress'])
    .lt('created_at', cutoff)
    .is('responded_at', null)
    .limit(30);

  if (!stale?.length) return { escalated: 0 };

  // Get exec/secretary/president IDs for notification
  const { data: execProfiles } = await sb
    .from('profiles')
    .select('id')
    .eq('society_id', SOCIETY_ID)
    .in('portal_role', ['executive', 'secretary', 'president'])
    .eq('is_active', true);

  const execIds = (execProfiles ?? []).map((p: any) => p.id);
  if (!execIds.length) return { escalated: 0 };

  let escalated = 0;
  for (const f of stale) {
    // Dedup: only escalate once per feedback item per day
    const { count } = await sb
      .from('notifications')
      .select('id', { count: 'exact', head: true })
      .eq('society_id', SOCIETY_ID)
      .eq('reference_id', f.id)
      .eq('type', 'feedback')
      .eq('title', 'Feedback awaiting response')
      .gte('created_at', nowIso.slice(0, 10) + 'T00:00:00.000Z');
    if (count && count > 0) continue;

    try {
      await sb.from('notifications').insert(
        execIds.map((uid: string) => ({
          society_id: SOCIETY_ID,
          user_id: uid,
          title: 'Feedback awaiting response',
          body: `Resident feedback "${f.subject ?? 'Untitled'}" has had no response for over 7 days.`,
          type: 'feedback',
          reference_table: 'feedback',
          reference_id: f.id,
          is_read: false,
        })),
      );
      escalated++;
    } catch { /* non-fatal */ }
  }

  return { escalated };
}

// ── Shared helpers ───────────────────────────────────────────────────────────

async function getCommitteeEmails(sb: ReturnType<typeof getSupabaseServiceClient>) {
  const { data: members } = await sb.from('profiles').select('id, full_name')
    .eq('society_id', SOCIETY_ID).in('portal_role', ['secretary', 'president']).eq('is_active', true);
  const result: { id: string; name: string; email: string }[] = [];
  for (const m of members ?? []) {
    const { data: auth } = await (sb as any).auth.admin.getUserById(m.id);
    if (auth?.user?.email) result.push({ id: m.id, name: m.full_name, email: auth.user.email });
  }
  return result;
}

async function alertCommittee(sb: ReturnType<typeof getSupabaseServiceClient>, subject: string, body: string) {
  const committee = await getCommitteeEmails(sb);
  for (const person of committee) {
    try {
      await sb.from('email_drafts').insert({
        society_id: SOCIETY_ID, tier: 1, triggered_by: 'cron:master:system-alert',
        trigger_resource_type: 'system_config', trigger_resource_id: 'github_circuit_breaker',
        recipient_type: 'COMMITTEE', recipient_email: person.email, recipient_name: person.name,
        subject, body_html: `<p>${body}</p>`, body_text: body,
        suggested_sender_name: SENDER_NAME, suggested_sender_email: SENDER_EMAIL, status: 'DRAFT',
      });
    } catch { /* non-fatal */ }
  }
}

// ── Task 15: Late Fee Application ─────────────────────────────────────────────
// Applies daily late fee charges to overdue dues past the grace period.
// Reads LATE_FEE_CRON_ENABLED, LATE_FEE_GRACE_PERIOD_DAYS, LATE_FEE_DEFAULT_RATE_PCT,
// LATE_FEE_MAX_CAP_AMOUNT from rules. Idempotent per dues per day via unique(dues_id, charge_date).
async function runLateFeeApplication(
  sb: ReturnType<typeof getSupabaseServiceClient>,
  now: Date,
  todayStr: string,
) {
  const rules = await loadRules(SOCIETY_ID);
  if (!r<boolean>(rules, 'LATE_FEE_CRON_ENABLED', true)) return { skipped: 'disabled' };

  const graceDays  = r<number>(rules, 'LATE_FEE_GRACE_PERIOD_DAYS', 5);
  const ratePct    = r<number>(rules, 'LATE_FEE_DEFAULT_RATE_PCT', 18);
  const maxCap     = r<number>(rules, 'LATE_FEE_MAX_CAP_AMOUNT', 5000);

  const cutoff = new Date(now);
  cutoff.setDate(cutoff.getDate() - graceDays);
  const cutoffStr = cutoff.toISOString().slice(0, 10);

  const { data: overdueDues } = await sb
    .from('maintenance_dues')
    .select('id, total_amount, penalty_amount')
    .eq('society_id', SOCIETY_ID)
    .in('status', ['pending', 'partially_paid', 'overdue'])
    .lt('due_date', cutoffStr)
    .limit(50);

  if (!overdueDues?.length) return { applied: 0, skipped: 0 };

  let applied = 0;
  let skipped = 0;

  for (const due of overdueDues) {
    const totalDue      = Number(due.total_amount);
    const existingPenalty = Number(due.penalty_amount ?? 0);

    if (existingPenalty >= maxCap) { skipped++; continue; }

    // Daily rate = annual rate / 365
    const dailyRate  = ratePct / 100 / 365;
    const feeAmount  = Math.min(
      Math.round(totalDue * dailyRate * 100) / 100,
      maxCap - existingPenalty,
    );

    if (feeAmount <= 0) { skipped++; continue; }

    const { error: insertErr } = await sb.from('late_fee_charges').insert({
      society_id:   SOCIETY_ID,
      dues_id:      due.id,
      charge_date:  todayStr,
      fee_amount:   feeAmount,
      fee_type:     'percentage',
      rate_applied: dailyRate,
    });

    if (insertErr?.code === '23505') { skipped++; continue; } // already charged today
    if (insertErr) { skipped++; continue; }

    await sb.from('maintenance_dues')
      .update({ penalty_amount: existingPenalty + feeAmount })
      .eq('id', due.id)
      .eq('society_id', SOCIETY_ID);

    applied++;
  }

  return { applied, skipped };
}

// ── Task 16: Notice Acknowledgement Reminders ─────────────────────────────────
// For notices with requires_acknowledgement=true published >= NOTICE_ACK_REMINDER_DAYS days ago,
// sends an in-app notification to every active member who has not yet acknowledged.
// Rate-limited: only sends once per member per notice via a unique notification check.
async function runNoticeAckReminders(
  sb: ReturnType<typeof getSupabaseServiceClient>,
  nowIso: string,
  todayStr: string,
) {
  const rules = await loadRules(SOCIETY_ID);
  const reminderDays = r<number>(rules, 'NOTICE_ACK_REMINDER_DAYS', 3);

  const cutoff = new Date(nowIso);
  cutoff.setDate(cutoff.getDate() - reminderDays);
  const cutoffIso = cutoff.toISOString();

  // Notices that require ack, published at least reminderDays ago, not expired
  const { data: notices } = await sb
    .from('notices')
    .select('id, title')
    .eq('society_id', SOCIETY_ID)
    .eq('requires_acknowledgement', true)
    .eq('is_published', true)
    .lte('published_at', cutoffIso)
    .or(`expires_at.is.null,expires_at.gt.${nowIso}`)
    .limit(10);

  if (!notices?.length) return { reminded: 0 };

  let reminded = 0;

  for (const notice of notices) {
    // Get all active members
    const { data: members } = await sb
      .from('profiles')
      .select('id')
      .eq('society_id', SOCIETY_ID)
      .eq('is_active', true);

    // Get who already acked
    const { data: acks } = await sb
      .from('notice_acknowledgements')
      .select('user_id')
      .eq('notice_id', notice.id);

    const ackedSet = new Set((acks ?? []).map((a: any) => a.user_id));

    // Get who already received a reminder notification for this notice
    const { data: existingNotifs } = await sb
      .from('notifications')
      .select('user_id')
      .eq('society_id', SOCIETY_ID)
      .eq('reference_table', 'notices')
      .eq('reference_id', notice.id)
      .eq('type', 'notice')
      .ilike('title', '%reminder%');

    const alreadyRemindedSet = new Set((existingNotifs ?? []).map((n: any) => n.user_id));

    const pending = (members ?? []).filter(
      (m: any) => !ackedSet.has(m.id) && !alreadyRemindedSet.has(m.id),
    );

    if (!pending.length) continue;

    // Batch insert notifications (up to 50 per notice per run)
    const notifBatch = pending.slice(0, 50).map((m: any) => ({
      society_id:      SOCIETY_ID,
      user_id:         m.id,
      title:           `Reminder: Please acknowledge notice`,
      body:            `"${notice.title}" requires your acknowledgement. Please open the notice and confirm you have read it.`,
      type:            'notice',
      reference_table: 'notices',
      reference_id:    notice.id,
      is_read:         false,
      channel:         'in_app',
      status:          'sent',
    }));

    try {
      await sb.from('notifications').insert(notifBatch);
      reminded += notifBatch.length;
    } catch { /* non-fatal */ }
  }

  return { reminded, notices_processed: notices.length };
}
