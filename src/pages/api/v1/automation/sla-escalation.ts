import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const CRON_SECRET = import.meta.env.CRON_SECRET;

export const GET: APIRoute = async ({ request }) => {
  try {
    if (CRON_SECRET && request.headers.get('authorization') !== `Bearer ${CRON_SECRET}`) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const now = new Date().toISOString();

    // Find complaints past SLA deadline that aren't yet closed/resolved
    const { data: breached, error } = await sb
      .from('complaints')
      .select('id, ticket_number, title, status, sla_deadline, assigned_to, raised_by')
      .eq('society_id', SOCIETY_ID)
      .not('status', 'in', '("Resolved","Closed")')
      .not('sla_deadline', 'is', null)
      .lt('sla_deadline', now);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    if (!breached || breached.length === 0) {
      return new Response(JSON.stringify({ escalated: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Fetch all exec/admin user IDs to notify
    const { data: execUsers } = await sb
      .from('user_roles')
      .select('user_id')
      .eq('society_id', SOCIETY_ID)
      .in('role', ['executive', 'admin']);

    const execIds = (execUsers ?? []).map((u: any) => u.user_id);

    let escalated = 0;

    for (const complaint of breached) {
      // Insert status history entry for SLA breach
      await sb.from('complaint_status_history').insert({
        complaint_id: complaint.id,
        old_status: complaint.status,
        new_status: complaint.status,
        note: `SLA breach: deadline was ${complaint.sla_deadline}`,
        changed_by: null,
        changed_at: now,
      });

      // Notify all execs
      if (execIds.length > 0) {
        const notifications = execIds.map((uid: string) => ({
          society_id: SOCIETY_ID,
          user_id: uid,
          title: 'SLA Breach Alert',
          body: `Complaint #${complaint.ticket_number} has breached its SLA deadline.`,
          type: 'complaint',
          reference_table: 'complaints',
          reference_id: complaint.id,
          channel: 'in_app',
          status: 'sent',
        }));
        await sb.from('notifications').insert(notifications);
      }

      escalated++;
    }

    return new Response(JSON.stringify({ escalated }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
