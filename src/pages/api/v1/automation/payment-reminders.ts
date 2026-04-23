export const prerender = false;
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
    const today = new Date().toISOString().slice(0, 10);

    // Find overdue dues (past due_date, not yet paid)
    const { data: overdueDues, error } = await sb
      .from('maintenance_dues')
      .select('id, user_id, unit_id, total_amount, due_date')
      .eq('society_id', SOCIETY_ID)
      .in('status', ['pending', 'partially_paid', 'overdue'])
      .lt('due_date', today);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    if (!overdueDues || overdueDues.length === 0) {
      return new Response(JSON.stringify({ reminded: 0 }), {
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Mark dues as overdue and send notifications
    const dueIds = overdueDues.map((d: any) => d.id);
    await sb
      .from('maintenance_dues')
      .update({ status: 'overdue' })
      .in('id', dueIds)
      .eq('society_id', SOCIETY_ID);

    const notifications = overdueDues.map((due: any) => ({
      society_id: SOCIETY_ID,
      user_id: due.user_id,
      title: 'Maintenance Due Overdue',
      body: `Your maintenance due of ₹${Number(due.total_amount).toLocaleString('en-IN')} was due on ${due.due_date}. Please pay at the earliest to avoid additional penalties.`,
      type: 'payment',
      reference_table: 'maintenance_dues',
      reference_id: due.id,
      channel: 'in_app',
      status: 'sent',
    }));

    await sb.from('notifications').insert(notifications);

    return new Response(JSON.stringify({ reminded: overdueDues.length }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
