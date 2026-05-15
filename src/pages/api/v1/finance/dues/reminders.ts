export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleInt } from '@lib/utils/getRules';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// POST /api/v1/finance/dues/reminders — send bulk overdue payment reminders
// Body: { dry_run?: boolean }  — dry_run=true returns eligible list without sending
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json() as { dry_run?: boolean };
    const dryRun = body.dry_run === true;

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['DUES_REMINDER_COOLDOWN_DAYS', 'DUES_REMINDER_MAX_SENDS']);
    const cooldownDays = ruleInt(rules, 'DUES_REMINDER_COOLDOWN_DAYS', 3);
    const maxSends     = ruleInt(rules, 'DUES_REMINDER_MAX_SENDS', 3);

    const todayStr = new Date().toISOString().split('T')[0];
    const cooldownCutoff = new Date(Date.now() - cooldownDays * 86_400_000).toISOString();

    // Fetch all overdue dues eligible for reminders
    const { data: dues, error } = await sb
      .from('maintenance_dues')
      .select(`
        id, unit_id, user_id, total_amount, amount_paid, due_date,
        reminder_sent_count, last_reminder_sent_at,
        units(unit_number, block),
        billing_periods(name)
      `)
      .eq('society_id', SOCIETY_ID)
      .in('status', ['pending', 'partially_paid'])
      .lt('due_date', todayStr)
      .order('due_date', { ascending: true });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const eligible: Array<{
      due_id: string;
      user_id: string;
      unit_number: string;
      block: string;
      billing_period: string;
      outstanding: number;
      due_date: string;
      reminder_sent_count: number;
    }> = [];
    const skipped: Array<{ due_id: string; reason: string }> = [];

    for (const d of dues ?? []) {
      const sentCount = d.reminder_sent_count ?? 0;
      const lastSent  = d.last_reminder_sent_at;

      if (sentCount >= maxSends) {
        skipped.push({ due_id: d.id, reason: `max_sends reached (${sentCount}/${maxSends})` });
        continue;
      }
      if (lastSent && lastSent > cooldownCutoff) {
        skipped.push({ due_id: d.id, reason: `cooldown active (last sent ${lastSent})` });
        continue;
      }
      if (!d.user_id) {
        skipped.push({ due_id: d.id, reason: 'no user linked to unit' });
        continue;
      }

      eligible.push({
        due_id: d.id,
        user_id: d.user_id,
        unit_number: (d.units as any)?.unit_number ?? '',
        block: (d.units as any)?.block ?? '',
        billing_period: (d.billing_periods as any)?.name ?? '',
        outstanding: (d.total_amount ?? 0) - (d.amount_paid ?? 0),
        due_date: d.due_date,
        reminder_sent_count: sentCount,
      });
    }

    if (dryRun) {
      return Response.json({
        dry_run: true,
        eligible_count: eligible.length,
        skipped_count: skipped.length,
        eligible,
        skipped,
      });
    }

    // Send notifications and update counters
    const now = new Date().toISOString();
    let sent = 0;
    let failed = 0;

    for (const e of eligible) {
      const outstanding = Number(e.outstanding).toLocaleString('en-IN');
      const notif = {
        society_id:      SOCIETY_ID,
        user_id:         e.user_id,
        title:           'Maintenance Due Reminder',
        body:            `Your maintenance due of ₹${outstanding} for ${e.billing_period} (Unit ${e.unit_number}) is overdue. Please clear the balance to avoid penalties.`,
        type:            'payment',
        reference_table: 'maintenance_dues',
        reference_id:    e.due_id,
        is_read:         false,
        channel:         'in_app',
        status:          'sent',
      };

      const { error: notifErr } = await sb.from('notifications').insert(notif);
      if (notifErr) { failed++; continue; }

      await sb
        .from('maintenance_dues')
        .update({
          reminder_sent_count:   e.reminder_sent_count + 1,
          last_reminder_sent_at: now,
        })
        .eq('id', e.due_id)
        .eq('society_id', SOCIETY_ID);

      sent++;
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'dues_reminders', resourceId: SOCIETY_ID,
      ip: extractClientIP(request),
      newValues: { sent, failed, skipped_count: skipped.length, triggered_at: now },
    });

    return Response.json({
      dry_run: false,
      eligible_count: eligible.length,
      sent,
      failed,
      skipped_count: skipped.length,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
