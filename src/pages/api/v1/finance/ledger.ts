export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

/** GET /api/v1/finance/ledger — chronological dues + payments for the logged-in member with running balance. */
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const [{ data: dues }, { data: payments }] = await Promise.all([
      sb
        .from('maintenance_dues')
        .select('id, total_amount, base_amount, penalty_amount, gst_amount, status, due_date, paid_at, created_at, billing_periods(name)')
        .eq('user_id', user.id)
        .eq('society_id', SOCIETY_ID)
        .order('due_date', { ascending: true }),

      sb
        .from('payments')
        .select('id, amount, payment_mode, transaction_ref, receipt_number, paid_at, created_at')
        .eq('user_id', user.id)
        .eq('society_id', SOCIETY_ID)
        .order('paid_at', { ascending: true }),
    ]);

    // Merge into a single ledger timeline
    type Entry = {
      date: string;
      type: 'debit' | 'credit';
      label: string;
      amount: number;
      status?: string;
      reference?: string;
      running_balance: number;
    };

    const entries: Omit<Entry, 'running_balance'>[] = [
      ...(dues ?? []).map((d: any) => ({
        date: d.due_date,
        type: 'debit' as const,
        label: `Maintenance due — ${(d.billing_periods as any)?.name ?? d.due_date}`,
        amount: Number(d.total_amount),
        status: d.status,
        reference: d.id,
      })),
      ...(payments ?? []).map((p: any) => ({
        date: p.paid_at?.slice(0, 10) ?? p.created_at.slice(0, 10),
        type: 'credit' as const,
        label: `Payment received — ${p.payment_mode.toUpperCase()}${p.transaction_ref ? ` (${p.transaction_ref})` : ''}`,
        amount: Number(p.amount),
        reference: p.receipt_number,
      })),
    ].sort((a, b) => a.date.localeCompare(b.date));

    // Compute running balance (positive = owed by member)
    let balance = 0;
    const ledger: Entry[] = entries.map((e) => {
      balance = e.type === 'debit' ? balance + e.amount : balance - e.amount;
      return { ...e, running_balance: balance };
    });

    const totalDues    = (dues ?? []).reduce((s: number, d: any) => s + Number(d.total_amount), 0);
    const totalPaid    = (payments ?? []).reduce((s: number, p: any) => s + Number(p.amount), 0);
    const outstanding  = totalDues - totalPaid;

    return new Response(JSON.stringify({ ledger, summary: { total_dues: totalDues, total_paid: totalPaid, outstanding } }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
