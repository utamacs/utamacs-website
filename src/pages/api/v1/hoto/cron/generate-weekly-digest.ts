export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { loadRules, r, RULE } from '@lib/rules';

const SOCIETY_ID   = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const CRON_SECRET  = import.meta.env.CRON_SECRET;
const SENDER_NAME  = 'UTA MACS Society';
const SENDER_EMAIL = import.meta.env.SOCIETY_SENDER_EMAIL ?? 'no-reply@utamacs.org';

// GET — generate weekly HOTO status digest for the committee.
// Runs every Monday at 7 AM (configurable via WEEKLY_DIGEST_DAY / WEEKLY_DIGEST_HOUR rules).
// Idempotent: no-ops if a digest was already created in the current calendar week.
export const GET: APIRoute = async ({ request }) => {
  const t0 = Date.now();
  try {
    if (CRON_SECRET && request.headers.get('authorization') !== `Bearer ${CRON_SECRET}`) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const sb = getSupabaseServiceClient();
    const rules = await loadRules(SOCIETY_ID);

    const enabled = r<boolean>(rules, RULE.WEEKLY_DIGEST_ENABLED, true);
    if (!enabled) {
      await heartbeat(sb, 'generate-weekly-digest', 'OK', 0, 0, Date.now() - t0, 'Digest disabled via rule');
      return Response.json({ status: 'SKIPPED', reason: 'WEEKLY_DIGEST_ENABLED is false' });
    }

    // Idempotency: one digest per calendar week (Mon–Sun)
    const now = new Date();
    const dayOfWeek = now.getDay(); // 0=Sun, 1=Mon...
    const monday = new Date(now);
    monday.setDate(now.getDate() - ((dayOfWeek + 6) % 7)); // Roll back to Monday
    monday.setHours(0, 0, 0, 0);
    const weekKey = monday.toISOString().slice(0, 10); // e.g. "2026-05-04"

    const { count: existingCount } = await sb
      .from('email_drafts')
      .select('id', { count: 'exact', head: true })
      .eq('triggered_by', 'cron:weekly-digest')
      .gte('created_at', monday.toISOString());

    if (existingCount && existingCount > 0) {
      await heartbeat(sb, 'generate-weekly-digest', 'OK', 0, 0, Date.now() - t0, `Already ran for week ${weekKey}`);
      return Response.json({ status: 'ALREADY_RAN', week: weekKey });
    }

    // Gather HOTO stats in parallel
    const [
      { data: hotoItems },
      { data: snagItems },
      { data: vendorReqs },
      { data: pendingUploads },
    ] = await Promise.all([
      sb.from('hoto_items')
        .select('id, status, priority, builder_sla_date')
        .eq('society_id', SOCIETY_ID)
        .not('status', 'in', '("CLOSED","REJECTED")'),

      sb.from('snag_items')
        .select('id, status, severity')
        .eq('society_id', SOCIETY_ID)
        .eq('deleted', false),

      sb.from('vendor_requirements')
        .select('id, status')
        .eq('society_id', SOCIETY_ID)
        .not('status', 'in', '("CANCELLED","CONTRACT_SIGNED")'),

      sb.from('upload_queue')
        .select('id, status')
        .eq('society_id', SOCIETY_ID)
        .in('status', ['PENDING', 'FAILED']),
    ]);

    // Compute HOTO summary
    const hotoByStatus: Record<string, number> = {};
    let overdueItems = 0;
    const todayStr = now.toISOString().slice(0, 10);
    for (const item of hotoItems ?? []) {
      const i = item as any;
      hotoByStatus[i.status] = (hotoByStatus[i.status] ?? 0) + 1;
      if (i.builder_sla_date && i.builder_sla_date < todayStr) overdueItems++;
    }

    // Compute snag summary
    const snagByStatus: Record<string, number> = {};
    for (const snag of snagItems ?? []) {
      const s = snag as any;
      snagByStatus[s.status] = (snagByStatus[s.status] ?? 0) + 1;
    }

    const openSnags    = (snagByStatus['OPEN'] ?? 0) + (snagByStatus['REOPENED'] ?? 0);
    const activeSnags  = snagByStatus['IN_PROGRESS'] ?? 0;
    const resolvedSnags = snagByStatus['RESOLVED'] ?? 0;

    // Vendor summary
    const vendorByStatus: Record<string, number> = {};
    for (const vr of vendorReqs ?? []) {
      const v = vr as any;
      vendorByStatus[v.status] = (vendorByStatus[v.status] ?? 0) + 1;
    }

    const hotoTotal   = hotoItems?.length ?? 0;
    const hotoInProg  = (hotoByStatus['IN_PROGRESS'] ?? 0) + (hotoByStatus['UNDER_REVIEW'] ?? 0);
    const hotoPending = (hotoByStatus['PENDING_PRESIDENT'] ?? 0) + (hotoByStatus['PENDING_SECRETARY'] ?? 0);
    const pendingUploadCount = pendingUploads?.length ?? 0;
    const weekLabel   = `Week of ${weekKey}`;

    const bodyHtml = `
<h2 style="color:#1E3A8A">UTA MACS HOTO — Weekly Status Digest</h2>
<p style="color:#4B5563">${weekLabel}</p>

<h3>HOTO Items (${hotoTotal} active)</h3>
<table border="0" cellpadding="4" style="border-collapse:collapse">
  <tr><td>🔵 In Progress / Under Review</td><td><strong>${hotoInProg}</strong></td></tr>
  <tr><td>⏳ Pending Approval</td><td><strong>${hotoPending}</strong></td></tr>
  <tr><td>⚠️ Overdue SLA</td><td><strong style="color:${overdueItems > 0 ? '#B91C1C' : 'inherit'}">${overdueItems}</strong></td></tr>
</table>

<h3>Snag Items (${(snagItems?.length ?? 0)} total)</h3>
<table border="0" cellpadding="4" style="border-collapse:collapse">
  <tr><td>🔴 Open / Reopened</td><td><strong>${openSnags}</strong></td></tr>
  <tr><td>🔵 In Progress</td><td><strong>${activeSnags}</strong></td></tr>
  <tr><td>🟡 Resolved (awaiting verification)</td><td><strong>${resolvedSnags}</strong></td></tr>
</table>

${vendorReqs?.length ? `
<h3>Vendor Requirements (${vendorReqs.length} active)</h3>
<table border="0" cellpadding="4" style="border-collapse:collapse">
  ${Object.entries(vendorByStatus).map(([s, c]) => `<tr><td>${s}</td><td><strong>${c}</strong></td></tr>`).join('')}
</table>` : ''}

${pendingUploadCount > 0 ? `<p style="color:#B45309">⚠️ ${pendingUploadCount} document upload(s) pending in the upload queue.</p>` : ''}

<p style="color:#4B5563;font-size:12px">This digest is generated automatically every Monday. View the full dashboard at <a href="https://portal.utamacs.org">portal.utamacs.org</a>.</p>`;

    const bodyText = `UTA MACS HOTO — Weekly Status Digest (${weekLabel})\n\nHOTO Items: ${hotoTotal} active, ${overdueItems} overdue SLA, ${hotoPending} pending approval\nSnag Items: ${openSnags} open, ${activeSnags} in progress, ${resolvedSnags} resolved\nVendor Requirements: ${vendorReqs?.length ?? 0} active${pendingUploadCount > 0 ? `\n⚠️ ${pendingUploadCount} upload(s) pending` : ''}\n\nFull dashboard: https://portal.utamacs.org`;

    const subject = `HOTO Weekly Digest — ${weekLabel}${overdueItems > 0 ? ` (${overdueItems} SLA overdue)` : ''}`;

    // Send to committee members
    const committee = await getCommitteeEmails(sb);
    for (const person of committee) {
      await sb.from('email_drafts').insert({
        society_id: SOCIETY_ID,
        tier: 2,
        triggered_by: 'cron:weekly-digest',
        trigger_resource_type: 'digest',
        trigger_resource_id: weekKey,
        recipient_type: 'COMMITTEE',
        recipient_email: person.email,
        recipient_name: person.name,
        subject,
        body_html: bodyHtml,
        body_text: bodyText,
        suggested_sender_name: SENDER_NAME,
        suggested_sender_email: SENDER_EMAIL,
        status: 'DRAFT',
      });
    }

    await heartbeat(sb, 'generate-weekly-digest', 'OK', committee.length, 0, Date.now() - t0);
    return Response.json({ status: 'OK', week: weekKey, drafts_created: committee.length, stats: {
      hoto_total: hotoTotal, hoto_overdue: overdueItems, hoto_pending: hotoPending,
      snag_open: openSnags, snag_in_progress: activeSnags, snag_resolved: resolvedSnags,
      vendor_active: vendorReqs?.length ?? 0, pending_uploads: pendingUploadCount,
    }});
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

async function getCommitteeEmails(sb: ReturnType<typeof getSupabaseServiceClient>) {
  const { data: members } = await sb
    .from('profiles')
    .select('id, full_name, portal_role')
    .eq('society_id', SOCIETY_ID)
    .in('portal_role', ['secretary', 'president'])
    .eq('is_active', true);

  const result: { id: string; name: string; email: string }[] = [];
  for (const m of members ?? []) {
    const { data: auth } = await (sb as any).auth.admin.getUserById(m.id);
    if (auth?.user?.email) result.push({ id: m.id, name: m.full_name, email: auth.user.email });
  }
  return result;
}

async function heartbeat(
  sb: ReturnType<typeof getSupabaseServiceClient>,
  cronName: string,
  status: string,
  itemsProcessed: number,
  itemsFailed: number,
  durationMs: number,
  errorMessage?: string,
) {
  await sb.from('cron_heartbeats').insert({
    cron_name: cronName,
    status,
    items_processed: itemsProcessed,
    items_failed: itemsFailed,
    duration_ms: durationMs,
    error_message: errorMessage ?? null,
  });
}
