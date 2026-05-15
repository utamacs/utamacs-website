export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const VALID_MODES = ['cash', 'upi', 'cheque', 'neft', 'rtgs', 'online', 'bank_transfer'] as const;
const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

type ReconcileEntry = {
  unit_number: string;
  amount: number;
  payment_date: string;   // YYYY-MM-DD
  payment_mode: string;
  reference_no?: string;
  billing_period_name?: string;  // optional — match most recent pending due if omitted
};

// POST /api/v1/finance/payments/bulk-reconcile
// Body: { entries: ReconcileEntry[], dry_run?: boolean }
// Phase 1 (dry_run=true) : match and preview without writing
// Phase 2 (dry_run=false): commit all matched rows
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json() as { entries?: unknown; dry_run?: boolean };
    const dryRun  = body.dry_run === true;
    const entries = body.entries;

    if (!Array.isArray(entries) || entries.length === 0) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'entries array is required and must not be empty' }, { status: 400 });
    }
    if (entries.length > 200) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Maximum 200 entries per batch' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    // Load all units for this society once — keyed by unit_number (lower)
    const { data: units } = await sb
      .from('units')
      .select('id, unit_number, block')
      .eq('society_id', SOCIETY_ID);

    const unitMap = new Map<string, { id: string; unit_number: string; block: string }>();
    for (const u of units ?? []) {
      unitMap.set(u.unit_number.toLowerCase(), u);
    }

    // Load all pending/partial dues for matching
    const { data: allDues } = await sb
      .from('maintenance_dues')
      .select('id, unit_id, total_amount, amount_paid, status, due_date, billing_period_id, billing_periods(name)')
      .eq('society_id', SOCIETY_ID)
      .in('status', ['pending', 'partially_paid'])
      .order('due_date', { ascending: true });

    // Group dues by unit_id → list (ascending due_date, i.e. oldest first)
    const duesByUnit = new Map<string, typeof allDues>();
    for (const d of allDues ?? []) {
      const list = duesByUnit.get(d.unit_id) ?? [];
      list.push(d);
      duesByUnit.set(d.unit_id, list);
    }

    type RowResult = {
      row_index: number;
      unit_number: string;
      amount: number;
      payment_date: string;
      payment_mode: string;
      reference_no: string | null;
      status: 'matched' | 'skipped' | 'failed';
      matched_due_id: string | null;
      billing_period: string | null;
      error_message: string | null;
    };

    const results: RowResult[] = [];

    for (let i = 0; i < entries.length; i++) {
      const raw = entries[i] as ReconcileEntry;
      const rowBase = {
        row_index: i,
        unit_number: String(raw.unit_number ?? ''),
        amount: Number(raw.amount),
        payment_date: String(raw.payment_date ?? ''),
        payment_mode: String(raw.payment_mode ?? ''),
        reference_no: raw.reference_no ? String(raw.reference_no).slice(0, 100) : null,
      };

      // Validate row
      if (!rowBase.unit_number) {
        results.push({ ...rowBase, status: 'failed', matched_due_id: null, billing_period: null, error_message: 'unit_number is required' });
        continue;
      }
      if (!rowBase.amount || rowBase.amount <= 0 || isNaN(rowBase.amount)) {
        results.push({ ...rowBase, status: 'failed', matched_due_id: null, billing_period: null, error_message: 'amount must be a positive number' });
        continue;
      }
      if (!DATE_RE.test(rowBase.payment_date)) {
        results.push({ ...rowBase, status: 'failed', matched_due_id: null, billing_period: null, error_message: 'payment_date must be YYYY-MM-DD' });
        continue;
      }
      if (!VALID_MODES.includes(rowBase.payment_mode as typeof VALID_MODES[number])) {
        results.push({ ...rowBase, status: 'failed', matched_due_id: null, billing_period: null, error_message: `payment_mode must be one of: ${VALID_MODES.join(', ')}` });
        continue;
      }

      // Find unit
      const unit = unitMap.get(rowBase.unit_number.toLowerCase());
      if (!unit) {
        results.push({ ...rowBase, status: 'failed', matched_due_id: null, billing_period: null, error_message: `Unit '${rowBase.unit_number}' not found` });
        continue;
      }

      // Find matching due
      const unitDues = duesByUnit.get(unit.id) ?? [];
      let matchedDue: (typeof allDues)[number] | null = null;

      if (raw.billing_period_name) {
        const bpLower = raw.billing_period_name.toLowerCase();
        matchedDue = unitDues.find(d =>
          ((d.billing_periods as { name: string } | null)?.name ?? '').toLowerCase() === bpLower
        ) ?? null;
      } else {
        // Match oldest pending due for this unit
        matchedDue = unitDues[0] ?? null;
      }

      if (!matchedDue) {
        results.push({ ...rowBase, status: 'skipped', matched_due_id: null, billing_period: null, error_message: 'No pending due found for this unit' });
        continue;
      }

      const bpName = (matchedDue.billing_periods as { name: string } | null)?.name ?? null;
      results.push({ ...rowBase, status: 'matched', matched_due_id: matchedDue.id, billing_period: bpName, error_message: null });
    }

    if (dryRun) {
      const summary = {
        total: results.length,
        matched: results.filter(r => r.status === 'matched').length,
        skipped: results.filter(r => r.status === 'skipped').length,
        failed:  results.filter(r => r.status === 'failed').length,
      };
      return Response.json({ dry_run: true, summary, rows: results });
    }

    // Commit phase — create batch header
    const { data: batch, error: batchErr } = await sb
      .from('payment_reconcile_batches')
      .insert({
        society_id:   SOCIETY_ID,
        imported_by:  user.id,
        total_rows:   results.length,
        matched_rows: results.filter(r => r.status === 'matched').length,
        skipped_rows: results.filter(r => r.status === 'skipped').length,
        failed_rows:  results.filter(r => r.status === 'failed').length,
        status:       'processing',
      })
      .select('id')
      .single();

    if (batchErr || !batch) throw Object.assign(new Error(batchErr?.message ?? 'batch insert failed'), { status: 500 });

    // Insert batch rows
    const batchRowInserts = results.map((r, idx) => ({
      batch_id:          batch.id,
      society_id:        SOCIETY_ID,
      row_index:         r.row_index,
      unit_number:       r.unit_number,
      amount:            r.amount,
      payment_date:      DATE_RE.test(r.payment_date) ? r.payment_date : null,
      reference_no:      r.reference_no,
      raw_row:           (entries[idx] as object),
      status:            r.status,
      matched_due_id:    r.matched_due_id,
      error_message:     r.error_message,
    }));

    await sb.from('payment_reconcile_rows').insert(batchRowInserts);

    // Process matched rows
    let committed = 0;
    let commitFailed = 0;

    for (const r of results.filter(row => row.status === 'matched')) {
      const due = (allDues ?? []).find(d => d.id === r.matched_due_id)!;
      const totalDue    = Number(due.total_amount);
      const alreadyPaid = Number(due.amount_paid ?? 0);
      const outstanding = Math.max(0, totalDue - alreadyPaid);
      const paidNow     = Math.min(r.amount, outstanding + 0.005);
      const newAmountPaid = alreadyPaid + paidNow;
      const newStatus   = newAmountPaid >= totalDue - 0.005 ? 'paid' : 'partially_paid';
      const paidAt      = new Date(r.payment_date + 'T00:00:00').toISOString();

      const { data: payment, error: payErr } = await sb
        .from('payments')
        .insert({
          society_id:      SOCIETY_ID,
          dues_id:         r.matched_due_id,
          user_id:         due.unit_id,
          amount:          paidNow,
          payment_mode:    r.payment_mode,
          transaction_ref: r.reference_no ?? null,
          paid_at:         paidAt,
          status:          'completed',
          recorded_by:     user.id,
        })
        .select('id')
        .single();

      if (payErr || !payment) { commitFailed++; continue; }

      await sb
        .from('maintenance_dues')
        .update({ amount_paid: newAmountPaid, status: newStatus, paid_at: paidAt })
        .eq('id', r.matched_due_id)
        .eq('society_id', SOCIETY_ID);

      // Update reconcile row with payment id
      await sb
        .from('payment_reconcile_rows')
        .update({ matched_payment_id: payment.id })
        .eq('batch_id', batch.id)
        .eq('row_index', r.row_index);

      committed++;
    }

    // Finalize batch status
    await sb
      .from('payment_reconcile_batches')
      .update({ status: commitFailed === 0 ? 'completed' : 'failed' })
      .eq('id', batch.id);

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'PAYMENT', resourceType: 'payment_reconcile_batches', resourceId: batch.id,
      ip: extractClientIP(request),
      newValues: { committed, commit_failed: commitFailed, batch_id: batch.id },
    });

    return Response.json({
      dry_run: false,
      batch_id: batch.id,
      summary: {
        total:         results.length,
        matched:       results.filter(r => r.status === 'matched').length,
        committed,
        commit_failed: commitFailed,
        skipped:       results.filter(r => r.status === 'skipped').length,
        failed:        results.filter(r => r.status === 'failed').length,
      },
      rows: results,
    }, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
