export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function pad2(n: number) { return String(n).padStart(2, '0'); }

function buildGstInvoiceHtml(data: {
  invoiceNo: string; invoiceDate: string;
  society: any; member: any; unit: any;
  due: any; payment: any; period: any;
}): string {
  const { invoiceNo, invoiceDate, society, member, unit, due, payment, period } = data;
  const baseAmount = Number(due.base_amount ?? 0).toFixed(2);
  const penaltyAmount = Number(due.penalty_amount ?? 0).toFixed(2);
  const gstAmount = Number(due.gst_amount ?? 0).toFixed(2);
  const totalAmount = Number(due.total_amount ?? payment.amount ?? 0).toFixed(2);
  const paidAmount = Number(payment.amount ?? 0).toFixed(2);
  const tdsDeducted = Number(payment.tds_deducted ?? 0).toFixed(2);
  const netPayable = (Number(payment.amount ?? 0) - Number(payment.tds_deducted ?? 0)).toFixed(2);
  const gstRate = due.base_amount > 0 ? ((Number(due.gst_amount ?? 0) / Number(due.base_amount)) * 100).toFixed(0) + '%' : '0%';

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>GST Invoice ${invoiceNo}</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: Arial, sans-serif; font-size: 12px; color: #111; background: #fff; padding: 20px; }
  .page { max-width: 800px; margin: 0 auto; border: 2px solid #1E3A8A; }
  .header { background: #1E3A8A; color: white; padding: 20px 24px; display: flex; justify-content: space-between; align-items: flex-start; }
  .header h1 { font-size: 20px; font-weight: bold; }
  .header .subtitle { font-size: 11px; opacity: 0.85; margin-top: 4px; }
  .invoice-tag { background: white; color: #1E3A8A; padding: 6px 16px; border-radius: 4px; font-size: 14px; font-weight: bold; }
  .parties { display: flex; gap: 0; border-bottom: 1px solid #e5e7eb; }
  .party { flex: 1; padding: 16px 24px; }
  .party + .party { border-left: 1px solid #e5e7eb; }
  .party-label { font-size: 10px; font-weight: bold; text-transform: uppercase; color: #6b7280; margin-bottom: 8px; letter-spacing: 0.5px; }
  .party h3 { font-size: 14px; font-weight: bold; margin-bottom: 4px; }
  .party p { color: #4b5563; margin-bottom: 2px; line-height: 1.5; }
  .invoice-meta { display: flex; gap: 0; border-bottom: 1px solid #e5e7eb; background: #f9fafb; }
  .meta-item { flex: 1; padding: 10px 24px; border-right: 1px solid #e5e7eb; }
  .meta-item:last-child { border-right: none; }
  .meta-label { font-size: 10px; font-weight: bold; color: #6b7280; text-transform: uppercase; letter-spacing: 0.5px; }
  .meta-value { font-size: 13px; font-weight: bold; margin-top: 2px; }
  table { width: 100%; border-collapse: collapse; }
  th { background: #f3f4f6; text-align: left; padding: 10px 24px; font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px; color: #6b7280; font-weight: bold; }
  td { padding: 10px 24px; border-bottom: 1px solid #e5e7eb; }
  .amount-col { text-align: right; }
  .total-row td { font-weight: bold; background: #f9fafb; font-size: 13px; }
  .grand-total td { font-weight: bold; font-size: 14px; color: #1E3A8A; border-top: 2px solid #1E3A8A; }
  .footer { padding: 16px 24px; border-top: 2px solid #1E3A8A; display: flex; justify-content: space-between; align-items: center; }
  .paid-stamp { border: 3px solid #16a34a; border-radius: 8px; padding: 8px 20px; color: #16a34a; font-size: 20px; font-weight: bold; transform: rotate(-5deg); display: inline-block; }
  .note { font-size: 10px; color: #6b7280; }
  @media print { .no-print { display: none; } body { padding: 0; } }
</style>
</head>
<body>
<div class="page">
  <div class="header">
    <div>
      <h1>${society?.name ?? 'UTA MACS'}</h1>
      <div class="subtitle">${society?.address ?? ''}, ${society?.city ?? ''} – ${society?.pincode ?? ''}</div>
      ${society?.gstin ? `<div class="subtitle">GSTIN: ${society.gstin}</div>` : ''}
      ${society?.pan ? `<div class="subtitle">PAN: ${society.pan}</div>` : ''}
      <div class="subtitle">Reg. No.: ${society?.registration_no ?? 'TS MACS'}</div>
    </div>
    <div style="text-align:right">
      <div class="invoice-tag">TAX INVOICE</div>
    </div>
  </div>

  <div class="invoice-meta">
    <div class="meta-item"><div class="meta-label">Invoice No.</div><div class="meta-value">${invoiceNo}</div></div>
    <div class="meta-item"><div class="meta-label">Invoice Date</div><div class="meta-value">${invoiceDate}</div></div>
    <div class="meta-item"><div class="meta-label">Billing Period</div><div class="meta-value">${period?.name ?? '—'}</div></div>
    <div class="meta-item"><div class="meta-label">Due Date</div><div class="meta-value">${period?.due_date ? new Date(period.due_date).toLocaleDateString('en-IN') : '—'}</div></div>
  </div>

  <div class="parties">
    <div class="party">
      <div class="party-label">Supplier (Society)</div>
      <h3>${society?.name ?? 'UTA MACS'}</h3>
      <p>${society?.address ?? ''}</p>
      <p>${society?.city ?? ''}, ${society?.state ?? 'Telangana'} – ${society?.pincode ?? ''}</p>
      ${society?.gstin ? `<p>GSTIN: ${society.gstin}</p>` : ''}
    </div>
    <div class="party">
      <div class="party-label">Recipient (Member)</div>
      <h3>${member?.full_name ?? '—'}</h3>
      <p>Unit: ${unit?.block ?? ''}${unit?.unit_number ?? '—'}, Floor ${unit?.floor ?? 0}</p>
      <p>${society?.name ?? ''}</p>
      <p>${society?.city ?? ''}, ${society?.state ?? 'Telangana'}</p>
    </div>
  </div>

  <table>
    <thead>
      <tr>
        <th style="width:40px">#</th>
        <th>Description</th>
        <th>HSN/SAC</th>
        <th>GST Rate</th>
        <th class="amount-col">Amount (₹)</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>1</td>
        <td>
          <strong>Maintenance Charges</strong><br />
          <span style="color:#6b7280; font-size:11px">Period: ${period?.name ?? '—'} (${period?.start_date ? new Date(period.start_date).toLocaleDateString('en-IN') : '—'} to ${period?.end_date ? new Date(period.end_date).toLocaleDateString('en-IN') : '—'})</span>
        </td>
        <td>9972</td>
        <td>${gstRate}</td>
        <td class="amount-col">${baseAmount}</td>
      </tr>
      ${Number(due.penalty_amount ?? 0) > 0 ? `
      <tr>
        <td>2</td>
        <td><strong>Late Payment Penalty</strong></td>
        <td>9972</td>
        <td>Nil</td>
        <td class="amount-col">${penaltyAmount}</td>
      </tr>` : ''}
      <tr>
        <td></td>
        <td colspan="3" style="text-align:right; padding-right:8px">Sub-Total</td>
        <td class="amount-col">${(Number(baseAmount) + Number(penaltyAmount)).toFixed(2)}</td>
      </tr>
      <tr>
        <td></td>
        <td colspan="3" style="text-align:right; padding-right:8px">GST @ ${gstRate}</td>
        <td class="amount-col">${gstAmount}</td>
      </tr>
      <tr class="total-row">
        <td></td>
        <td colspan="3" style="text-align:right; padding-right:8px; font-size:13px">Total Invoice Amount</td>
        <td class="amount-col" style="font-size:13px">₹${totalAmount}</td>
      </tr>
    </tbody>
  </table>

  <table style="margin-top:0">
    <thead>
      <tr>
        <th colspan="4">Payment Details</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><strong>Mode:</strong> ${payment.payment_mode?.replace('_', ' ').toUpperCase() ?? '—'}</td>
        <td><strong>Ref:</strong> ${payment.transaction_ref ?? '—'}</td>
        <td><strong>Date:</strong> ${payment.paid_at ? new Date(payment.paid_at).toLocaleDateString('en-IN') : '—'}</td>
        <td class="amount-col"><strong>Paid: ₹${paidAmount}</strong></td>
      </tr>
      ${Number(payment.tds_deducted ?? 0) > 0 ? `
      <tr>
        <td colspan="3">TDS Deducted (u/s 194C)</td>
        <td class="amount-col">-₹${tdsDeducted}</td>
      </tr>` : ''}
      <tr class="grand-total">
        <td colspan="3" style="text-align:right; padding-right:8px">Net Amount Received</td>
        <td class="amount-col">₹${netPayable}</td>
      </tr>
    </tbody>
  </table>

  <div class="footer">
    <div>
      <p style="font-weight:bold; margin-bottom:4px">Receipt No.: ${payment.receipt_number ?? '—'}</p>
      <p class="note">This is a computer-generated invoice. No signature required.</p>
      <p class="note">For support: management@utamacs.org</p>
    </div>
    <div class="paid-stamp">✓ PAID</div>
  </div>
</div>
<div class="no-print" style="text-align:center; margin-top:16px">
  <button onclick="window.print()" style="background:#1E3A8A; color:white; border:none; padding:10px 28px; border-radius:8px; cursor:pointer; font-size:14px">
    Print / Save PDF
  </button>
</div>
</body>
</html>`;
}

// POST — generate a GST invoice for a specific payment
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const body = await request.json() as { payment_id?: string };
    if (!body.payment_id) {
      return new Response(JSON.stringify({ error: 'payment_id is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    const { data: payment } = await sb
      .from('payments')
      .select(`
        id, amount, payment_mode, transaction_ref, receipt_number,
        tds_deducted, paid_at, gst_invoice_no,
        maintenance_dues(
          id, base_amount, penalty_amount, gst_amount, total_amount,
          billing_periods(name, start_date, end_date, due_date),
          units(unit_number, block, floor),
          profiles(full_name)
        )
      `)
      .eq('id', body.payment_id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!payment) {
      return new Response(JSON.stringify({ error: 'Payment not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Members can only access their own invoices
    const p = payment as any;
    if (user.role === 'member' && p.maintenance_dues?.profiles && p.maintenance_dues.profiles.id !== user.id) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    // Fetch society info
    const { data: society } = await sb
      .from('societies')
      .select('name, address, city, state, pincode, gstin, pan, registration_no')
      .eq('id', SOCIETY_ID)
      .single();

    // Generate or reuse invoice number
    let invoiceNo = p.gst_invoice_no;
    if (!invoiceNo) {
      const now = new Date();
      const fy = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1;
      const seq = String(body.payment_id).slice(-6).toUpperCase();
      invoiceNo = `INV/${fy}-${String(fy + 1).slice(-2)}/${seq}`;

      // Store the invoice number on the payment
      await sb.from('payments').update({ gst_invoice_no: invoiceNo }).eq('id', body.payment_id);
    }

    const invoiceDate = new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });

    const html = buildGstInvoiceHtml({
      invoiceNo,
      invoiceDate,
      society: society as any,
      member: p.maintenance_dues?.profiles,
      unit: p.maintenance_dues?.units,
      due: p.maintenance_dues,
      payment: p,
      period: p.maintenance_dues?.billing_periods,
    });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'EXPORT', resourceType: 'payments', resourceId: body.payment_id,
      ip: extractClientIP(request),
      newValues: { invoice_no: invoiceNo },
    });

    const accept = request.headers.get('accept') ?? '';
    if (accept.includes('text/html')) {
      return new Response(html, { headers: { 'Content-Type': 'text/html; charset=utf-8' } });
    }

    return new Response(JSON.stringify({ invoice_no: invoiceNo, html }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// GET — list all invoices for the society (exec/admin) or own invoices (member)
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    const sb = getSupabaseServiceClient();

    let query = sb
      .from('payments')
      .select(`
        id, amount, payment_mode, receipt_number, gst_invoice_no,
        tds_deducted, paid_at,
        maintenance_dues(
          base_amount, gst_amount, total_amount,
          billing_periods(name),
          units(unit_number, block),
          profiles(full_name)
        )
      `)
      .eq('society_id', SOCIETY_ID)
      .not('gst_invoice_no', 'is', null)
      .order('paid_at', { ascending: false });

    if (user.role === 'member') {
      query = query.eq('user_id', user.id);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data ?? []), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
