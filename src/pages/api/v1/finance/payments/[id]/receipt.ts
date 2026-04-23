export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    const { data: payment, error } = await sb
      .from('payments')
      .select(`
        id, amount, payment_mode, transaction_ref, receipt_number,
        gst_invoice_no, tds_deducted, paid_at, created_at,
        user_id,
        maintenance_dues(
          base_amount, gst_amount, penalty_amount, total_amount, due_date,
          units(unit_number, block),
          billing_periods(name, start_date, end_date)
        )
      `)
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error || !payment) {
      return new Response(JSON.stringify({ error: 'Payment not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Members can only access their own receipts; exec/admin can access all
    if (user.role === 'member' && (payment as any).user_id !== user.id) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const { data: profile } = await sb
      .from('profiles')
      .select('full_name')
      .eq('id', (payment as any).user_id)
      .single();

    const { data: society } = await sb
      .from('societies')
      .select('name, address, gstin')
      .eq('id', SOCIETY_ID)
      .single();

    const p = payment as any;
    const due = p.maintenance_dues ?? {};
    const unit = due.units ?? {};
    const period = due.billing_periods ?? {};

    // Build a structured receipt object (could be rendered to PDF in future)
    const receipt = {
      receipt_number: p.receipt_number ?? `RCP-${p.id.slice(0, 8).toUpperCase()}`,
      payment_id: p.id,
      society: {
        name: society?.name ?? 'UTA MACS',
        address: society?.address ?? '',
        gstin: society?.gstin ?? '',
      },
      resident: {
        name: profile?.full_name ?? 'Resident',
        unit: unit.unit_number ?? '',
        block: unit.block ?? '',
      },
      billing_period: period.name ?? '',
      payment_details: {
        amount: p.amount,
        payment_mode: p.payment_mode,
        transaction_ref: p.transaction_ref ?? null,
        paid_at: p.paid_at,
        gst_invoice_no: p.gst_invoice_no ?? null,
        tds_deducted: p.tds_deducted ?? 0,
      },
      due_breakdown: {
        base_amount: due.base_amount,
        gst_amount: due.gst_amount,
        penalty_amount: due.penalty_amount,
        total_amount: due.total_amount,
        due_date: due.due_date,
      },
      generated_at: new Date().toISOString(),
    };

    // Check if client wants HTML (for print/download) or JSON
    const accept = request.headers.get('accept') ?? '';
    if (accept.includes('text/html')) {
      const html = buildReceiptHtml(receipt);
      return new Response(html, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
    }

    return new Response(JSON.stringify(receipt), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

function buildReceiptHtml(r: ReturnType<typeof Object.create>): string {
  const fmt = (n: number) => `₹${Number(n ?? 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}`;
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>Receipt ${r.receipt_number}</title>
  <style>
    body { font-family: Arial, sans-serif; max-width: 600px; margin: 40px auto; color: #111; font-size: 14px; }
    h1 { color: #1E3A8A; margin-bottom: 4px; }
    .subtitle { color: #6B7280; font-size: 12px; margin-bottom: 24px; }
    .row { display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid #E5E7EB; }
    .row:last-child { border-bottom: none; }
    .label { color: #6B7280; }
    .total { font-weight: bold; font-size: 16px; color: #1E3A8A; }
    .stamp { text-align: center; margin-top: 32px; padding: 16px; border: 2px dashed #10B981; border-radius: 8px; color: #10B981; font-weight: bold; }
    @media print { .no-print { display: none; } }
  </style>
</head>
<body>
  <button class="no-print" onclick="window.print()" style="margin-bottom:16px;padding:8px 16px;background:#1E3A8A;color:white;border:none;border-radius:6px;cursor:pointer;">Print / Save PDF</button>
  <h1>${r.society.name}</h1>
  <p class="subtitle">${r.society.address}${r.society.gstin ? ` | GSTIN: ${r.society.gstin}` : ''}</p>
  <hr style="border-color:#E5E7EB;margin-bottom:16px;" />
  <div class="row"><span class="label">Receipt No.</span><span><strong>${r.receipt_number}</strong></span></div>
  <div class="row"><span class="label">Resident</span><span>${r.resident.name}</span></div>
  <div class="row"><span class="label">Unit</span><span>${r.resident.unit}${r.resident.block ? ` · Block ${r.resident.block}` : ''}</span></div>
  <div class="row"><span class="label">Billing Period</span><span>${r.billing_period}</span></div>
  <div class="row"><span class="label">Due Date</span><span>${r.due_breakdown.due_date ?? '—'}</span></div>
  <br />
  <div class="row"><span class="label">Base Amount</span><span>${fmt(r.due_breakdown.base_amount)}</span></div>
  ${r.due_breakdown.gst_amount > 0 ? `<div class="row"><span class="label">GST</span><span>${fmt(r.due_breakdown.gst_amount)}</span></div>` : ''}
  ${r.due_breakdown.penalty_amount > 0 ? `<div class="row"><span class="label">Penalty</span><span>${fmt(r.due_breakdown.penalty_amount)}</span></div>` : ''}
  <div class="row total"><span>Amount Paid</span><span>${fmt(r.payment_details.amount)}</span></div>
  <div class="row"><span class="label">Payment Mode</span><span>${r.payment_details.payment_mode?.toUpperCase() ?? '—'}</span></div>
  ${r.payment_details.transaction_ref ? `<div class="row"><span class="label">Transaction Ref</span><span>${r.payment_details.transaction_ref}</span></div>` : ''}
  ${r.payment_details.gst_invoice_no ? `<div class="row"><span class="label">GST Invoice No.</span><span>${r.payment_details.gst_invoice_no}</span></div>` : ''}
  <div class="row"><span class="label">Paid On</span><span>${new Date(r.payment_details.paid_at).toLocaleString('en-IN', { day: 'numeric', month: 'long', year: 'numeric', hour: '2-digit', minute: '2-digit' })}</span></div>
  <div class="stamp">✓ PAYMENT RECEIVED</div>
  <p style="font-size:11px;color:#9CA3AF;text-align:center;margin-top:16px;">Generated on ${new Date(r.generated_at).toLocaleString('en-IN')} · ${r.society.name}</p>
</body>
</html>`;
}
