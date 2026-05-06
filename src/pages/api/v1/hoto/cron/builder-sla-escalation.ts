export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { loadRules, r, RULE } from '@lib/rules';

const SOCIETY_ID   = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const CRON_SECRET  = import.meta.env.CRON_SECRET;
const SENDER_NAME  = 'UTA MACS Society';
const SENDER_EMAIL = import.meta.env.SOCIETY_SENDER_EMAIL ?? 'no-reply@utamacs.org';

// GET — scan hoto_items with overdue builder_sla_date; create escalation email drafts.
// Uses the HOTO_SLA_ESCALATION_DAYS rule to determine thresholds.
// Idempotent: skips items that already have a draft for today's escalation level.
export const GET: APIRoute = async ({ request }) => {
  const t0 = Date.now();
  try {
    if (CRON_SECRET && request.headers.get('authorization') !== `Bearer ${CRON_SECRET}`) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const sb = getSupabaseServiceClient();
    const rules = await loadRules(SOCIETY_ID);

    // Thresholds: default [7, 14, 30] days
    const escalationDays = r<number[]>(rules, RULE.HOTO_SLA_ESCALATION_DAYS, [7, 14, 30]);
    const [day7, day14, day30] = [escalationDays[0] ?? 7, escalationDays[1] ?? 14, escalationDays[2] ?? 30];

    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayStr = today.toISOString().slice(0, 10);

    // Items that are overdue (sla_date set, not yet closed/rejected)
    const { data: items } = await sb
      .from('hoto_items')
      .select('id, title, ascenza_category, builder_sla_date, priority, status')
      .eq('society_id', SOCIETY_ID)
      .not('builder_sla_date', 'is', null)
      .not('status', 'in', '("CLOSED","REJECTED")')
      .lt('builder_sla_date', todayStr);

    if (!items?.length) {
      await heartbeat(sb, 'builder-sla-escalation', 'OK', 0, 0, Date.now() - t0);
      return Response.json({ status: 'OK', escalated: 0 });
    }

    const committee = await getCommitteeEmails(sb);

    let escalated = 0;
    let skipped = 0;

    for (const item of items) {
      const it = item as any;
      const slaDate = new Date(it.builder_sla_date);
      const daysOverdue = Math.floor((today.getTime() - slaDate.getTime()) / 86_400_000);

      // Determine escalation tier for today
      let tier: number;
      let level: string;
      let triggerKey: string;

      if (daysOverdue >= day30) {
        tier = 3;
        level = `${day30}d`;
        triggerKey = `sla_${day30}d`;
      } else if (daysOverdue >= day14) {
        tier = 2;
        level = `${day14}d`;
        triggerKey = `sla_${day14}d`;
      } else if (daysOverdue >= day7) {
        tier = 2;
        level = `${day7}d`;
        triggerKey = `sla_${day7}d`;
      } else {
        continue; // Less than day7 threshold — no escalation yet
      }

      // Idempotency: skip if we already created this escalation level today for this item
      const { count } = await sb
        .from('email_drafts')
        .select('id', { count: 'exact', head: true })
        .eq('triggered_by', `cron:sla-escalation:${triggerKey}`)
        .eq('trigger_resource_id', it.id)
        .gte('created_at', `${todayStr}T00:00:00.000Z`);

      if (count && count > 0) {
        skipped++;
        continue;
      }

      const subject = tier === 3
        ? `[URGENT] Builder SLA overdue ${daysOverdue} days — legal notice required: ${it.title}`
        : `[ESCALATION] Builder SLA overdue ${daysOverdue} days: ${it.title}`;

      const urgencyNote = tier === 3
        ? '<p style="color:red"><strong>⚠ This item is more than 30 days overdue. A formal legal notice to the builder should be considered urgently.</strong></p>'
        : daysOverdue >= day14
          ? '<p><strong>This item requires urgent follow-up.</strong></p>'
          : '';

      const bodyHtml = `${urgencyNote}
<p>The following HOTO item has an overdue builder SLA commitment:</p>
<table border="0" cellpadding="4">
  <tr><td><strong>Item:</strong></td><td>${it.title}</td></tr>
  <tr><td><strong>Category:</strong></td><td>${it.ascenza_category}</td></tr>
  <tr><td><strong>Priority:</strong></td><td>${it.priority}</td></tr>
  <tr><td><strong>SLA Date:</strong></td><td>${it.builder_sla_date}</td></tr>
  <tr><td><strong>Days Overdue:</strong></td><td>${daysOverdue}</td></tr>
  <tr><td><strong>Status:</strong></td><td>${it.status}</td></tr>
</table>
<p>Please follow up with the builder immediately. Update the item status in the portal once resolved.</p>`;

      const bodyText = `${subject}\n\nItem: ${it.title}\nCategory: ${it.ascenza_category}\nPriority: ${it.priority}\nSLA Date: ${it.builder_sla_date}\nDays Overdue: ${daysOverdue}\nStatus: ${it.status}\n\nPlease follow up with the builder immediately.`;

      // Create draft for each committee member
      for (const person of committee) {
        await sb.from('email_drafts').insert({
          society_id: SOCIETY_ID,
          tier,
          triggered_by: `cron:sla-escalation:${triggerKey}`,
          trigger_resource_type: 'hoto_item',
          trigger_resource_id: it.id,
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

      escalated++;
    }

    await heartbeat(sb, 'builder-sla-escalation', 'OK', escalated, 0, Date.now() - t0,
      skipped > 0 ? `${skipped} items already escalated today` : undefined);
    return Response.json({ status: 'OK', escalated, skipped, total_overdue: items.length });
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
