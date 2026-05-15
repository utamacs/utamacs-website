export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { commitDocument, getDocumentDownloadUrl, docPath } from '@lib/utils/githubDocStore';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';
import PdfPrinter from 'pdfmake';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/finance/invoices/:id/pdf
// Generates (or returns cached) a GST invoice PDF for a dues record.
// Members can only access their own; exec can access any.
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const duesId = params.id ?? '';
    if (!UUID_RE.test(duesId)) return Response.json({ error: 'VALIDATION', message: 'invalid dues id' }, { status: 400 });

    const sb = getSupabaseServiceClient();

    const { data: due, error: dueErr } = await sb
      .from('maintenance_dues')
      .select(`
        id, invoice_number, invoice_pdf_key,
        base_amount, penalty_amount, gst_amount, total_amount, amount_paid, status, due_date,
        user_id,
        billing_periods(id, name, start_date, end_date, due_date),
        units(unit_number, block, floor),
        profiles(id, full_name)
      `)
      .eq('id', duesId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (dueErr || !due) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const d = due as any;
    const isExec = user.isAdmin ||
      ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') ||
      ['executive', 'admin'].includes(user.role ?? '');

    if (!isExec && d.user_id !== user.id) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    // Return cached PDF if it exists
    if (d.invoice_pdf_key) {
      try {
        const cached_url = await getDocumentDownloadUrl(d.invoice_pdf_key);
        return Response.json({ url: cached_url, invoice_number: d.invoice_number, cached: true, expires_in: 3600 });
      } catch { /* cache miss — regenerate */ }
    }

    // Fetch most recent payment for this dues record
    const { data: payments } = await sb
      .from('payments')
      .select('id, amount, payment_mode, transaction_ref, receipt_number, tds_deducted, paid_at')
      .eq('dues_id', duesId)
      .order('paid_at', { ascending: false })
      .limit(5);

    // Fetch society info
    const { data: society } = await sb
      .from('societies')
      .select('name, address, city, state, pincode, gstin, pan, registration_no')
      .eq('id', SOCIETY_ID)
      .single();

    const soc = (society ?? {}) as any;
    const period = d.billing_periods as any;
    const unit = d.units as any;
    const member = d.profiles as any;

    // Ensure invoice number exists
    let invoiceNo: string = d.invoice_number ?? '';
    if (!invoiceNo) {
      const now = new Date();
      const fy = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1;
      const { data: seqRow } = await sb.rpc('generate_invoice_number', {
        p_society_id: SOCIETY_ID,
        p_dues_id: duesId,
      });
      invoiceNo = seqRow ?? `INV/${fy}/${duesId.slice(-6).toUpperCase()}`;
      await sb.from('maintenance_dues').update({ invoice_number: invoiceNo }).eq('id', duesId);
    }

    const invoiceDateStr = new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
    const baseAmt   = Number(d.base_amount ?? 0);
    const penaltyAmt = Number(d.penalty_amount ?? 0);
    const gstAmt    = Number(d.gst_amount ?? 0);
    const totalAmt  = Number(d.total_amount ?? 0);
    const paidAmt   = Number(d.amount_paid ?? 0);
    const outstanding = Math.max(0, totalAmt - paidAmt);
    const gstRate   = baseAmt > 0 ? `${((gstAmt / baseAmt) * 100).toFixed(0)}%` : '0%';
    const fmt2 = (n: number) => n.toFixed(2);

    const statusColor = d.status === 'paid' ? '#16a34a' : d.status === 'overdue' ? '#dc2626' : '#B45309';
    const statusLabel = String(d.status).replace('_', ' ').toUpperCase();

    // Build payment rows for the PDF
    const pmtRows: any[] = (payments ?? []).map((pmt: any, i: number) => [
      { text: String(i + 1), fontSize: 9 },
      { text: new Date(pmt.paid_at).toLocaleDateString('en-IN'), fontSize: 9 },
      { text: String(pmt.payment_mode ?? '').replace('_', ' ').toUpperCase(), fontSize: 9 },
      { text: pmt.transaction_ref ?? '—', fontSize: 9 },
      { text: pmt.receipt_number ?? '—', fontSize: 9 },
      { text: `₹${fmt2(Number(pmt.amount))}`, alignment: 'right', fontSize: 9 },
    ]);

    const lineRows: any[] = [
      [
        { text: '1', fontSize: 9 },
        { text: `Maintenance Charges\n${period?.name ?? '—'} (${period?.start_date ? new Date(period.start_date).toLocaleDateString('en-IN') : '—'} – ${period?.end_date ? new Date(period.end_date).toLocaleDateString('en-IN') : '—'})`, fontSize: 9 },
        { text: '9972', fontSize: 9, alignment: 'center' },
        { text: gstRate, fontSize: 9, alignment: 'center' },
        { text: `₹${fmt2(baseAmt)}`, alignment: 'right', fontSize: 9 },
      ],
    ];
    if (penaltyAmt > 0) {
      lineRows.push([
        { text: '2', fontSize: 9 },
        { text: 'Late Payment Penalty', fontSize: 9 },
        { text: '9972', fontSize: 9, alignment: 'center' },
        { text: 'Nil', fontSize: 9, alignment: 'center' },
        { text: `₹${fmt2(penaltyAmt)}`, alignment: 'right', fontSize: 9 },
      ]);
    }

    const docDefinition: any = {
      pageSize: 'A4',
      pageMargins: [40, 60, 40, 60],
      styles: {
        heading:      { fontSize: 18, bold: true, color: '#1E3A8A' },
        subtext:      { fontSize: 9, color: '#6B7280' },
        label:        { fontSize: 8, bold: true, color: '#9CA3AF', characterSpacing: 0.5 },
        value:        { fontSize: 10, bold: true, color: '#111827' },
        tableHeader:  { bold: true, fillColor: '#EFF6FF', color: '#1E3A8A', fontSize: 9 },
        totalRow:     { bold: true, fillColor: '#F9FAFB', fontSize: 10 },
        grandTotal:   { bold: true, color: '#1E3A8A', fontSize: 11 },
        footer:       { fontSize: 8, color: '#9CA3AF', italics: true },
      },
      content: [
        // Header
        {
          columns: [
            {
              stack: [
                { text: soc.name ?? 'UTA MACS', style: 'heading' },
                { text: [soc.address, soc.city, soc.state, soc.pincode].filter(Boolean).join(', '), style: 'subtext', marginBottom: 2 },
                ...(soc.gstin ? [{ text: `GSTIN: ${soc.gstin}`, style: 'subtext' }] : []),
                ...(soc.registration_no ? [{ text: `Reg. No.: ${soc.registration_no}`, style: 'subtext' }] : []),
              ],
            },
            {
              stack: [
                { text: 'TAX INVOICE', fontSize: 16, bold: true, color: '#1E3A8A', alignment: 'right' },
                { text: invoiceNo, fontSize: 10, color: '#374151', alignment: 'right', marginTop: 4 },
                { text: invoiceDateStr, style: 'subtext', alignment: 'right', marginTop: 2 },
              ],
            },
          ],
          marginBottom: 12,
        },

        // Horizontal rule
        { canvas: [{ type: 'line', x1: 0, y1: 0, x2: 515, y2: 0, lineWidth: 1.5, lineColor: '#1E3A8A' }], marginBottom: 12 },

        // Parties (supplier + recipient)
        {
          columns: [
            {
              stack: [
                { text: 'SUPPLIER', style: 'label', marginBottom: 4 },
                { text: soc.name ?? 'UTA MACS', fontSize: 10, bold: true },
                { text: [soc.address, soc.city].filter(Boolean).join(', '), fontSize: 9, color: '#4B5563' },
                ...(soc.gstin ? [{ text: `GSTIN: ${soc.gstin}`, fontSize: 9, color: '#4B5563' }] : []),
              ],
              width: '48%',
            },
            { width: '4%', text: '' },
            {
              stack: [
                { text: 'RECIPIENT', style: 'label', marginBottom: 4 },
                { text: member?.full_name ?? '—', fontSize: 10, bold: true },
                { text: `Unit: ${unit?.block ?? ''}${unit?.unit_number ?? '—'}, Floor ${unit?.floor ?? 0}`, fontSize: 9, color: '#4B5563' },
                { text: soc.city ?? '', fontSize: 9, color: '#4B5563' },
              ],
              width: '48%',
            },
          ],
          marginBottom: 12,
        },

        // Meta row
        {
          table: {
            widths: ['25%', '25%', '25%', '25%'],
            body: [
              [
                { text: 'Invoice No.', style: 'label' }, { text: 'Invoice Date', style: 'label' },
                { text: 'Billing Period', style: 'label' }, { text: 'Due Date', style: 'label' },
              ],
              [
                { text: invoiceNo, style: 'value' },
                { text: invoiceDateStr, style: 'value' },
                { text: period?.name ?? '—', style: 'value' },
                { text: d.due_date ? new Date(d.due_date).toLocaleDateString('en-IN') : '—', style: 'value' },
              ],
            ],
          },
          layout: {
            hLineWidth: (i: number) => i === 0 || i === 2 ? 0.5 : 0,
            vLineWidth: (i: number) => i > 0 && i < 4 ? 0.5 : 0,
            hLineColor: () => '#E5E7EB',
            vLineColor: () => '#E5E7EB',
            paddingLeft: () => 6, paddingRight: () => 6, paddingTop: () => 5, paddingBottom: () => 5,
          },
          marginBottom: 16,
        },

        // Line items
        { text: 'Charges', fontSize: 10, bold: true, color: '#111827', marginBottom: 6 },
        {
          table: {
            headerRows: 1,
            widths: [20, '*', 50, 50, 70],
            body: [
              [
                { text: '#', style: 'tableHeader', alignment: 'center' },
                { text: 'Description', style: 'tableHeader' },
                { text: 'HSN/SAC', style: 'tableHeader', alignment: 'center' },
                { text: 'GST', style: 'tableHeader', alignment: 'center' },
                { text: 'Amount (₹)', style: 'tableHeader', alignment: 'right' },
              ],
              ...lineRows,
              [
                { text: '', fontSize: 9 }, { text: 'Sub-Total', fontSize: 9, alignment: 'right', bold: true },
                { text: '' }, { text: '' },
                { text: `₹${fmt2(baseAmt + penaltyAmt)}`, alignment: 'right', fontSize: 9, bold: true },
              ],
              [
                { text: '', fontSize: 9 }, { text: `GST @ ${gstRate}`, fontSize: 9, alignment: 'right' },
                { text: '' }, { text: '' },
                { text: `₹${fmt2(gstAmt)}`, alignment: 'right', fontSize: 9 },
              ],
              [
                { text: '', style: 'totalRow' }, { text: 'Total Invoice Amount', style: 'totalRow', alignment: 'right' },
                { text: '', style: 'totalRow' }, { text: '', style: 'totalRow' },
                { text: `₹${fmt2(totalAmt)}`, alignment: 'right', style: 'grandTotal' },
              ],
            ],
          },
          layout: {
            hLineWidth: (i: number) => i === 0 || i === 1 ? 1 : 0.5,
            vLineWidth: () => 0,
            hLineColor: () => '#E5E7EB',
            paddingLeft: () => 6, paddingRight: () => 6, paddingTop: () => 5, paddingBottom: () => 5,
          },
          marginBottom: 12,
        },

        // Payment summary
        {
          columns: [
            {
              stack: [
                { text: 'PAYMENT SUMMARY', style: 'label', marginBottom: 4 },
                { text: `Total Billed: ₹${fmt2(totalAmt)}`, fontSize: 9 },
                { text: `Amount Paid: ₹${fmt2(paidAmt)}`, fontSize: 9, color: '#16a34a' },
                outstanding > 0 ? { text: `Outstanding: ₹${fmt2(outstanding)}`, fontSize: 9, color: '#dc2626' } : { text: '' },
              ],
              width: '50%',
            },
            {
              stack: [
                { text: 'STATUS', style: 'label', marginBottom: 4 },
                {
                  text: statusLabel,
                  fontSize: 18, bold: true, color: statusColor,
                  decoration: d.status === 'paid' ? 'underline' : undefined,
                },
              ],
              width: '50%',
              alignment: 'right',
            },
          ],
          marginBottom: pmtRows.length > 0 ? 12 : 0,
        },

        // Payment history table
        ...(pmtRows.length > 0 ? [
          { text: 'Payments Received', fontSize: 10, bold: true, color: '#111827', marginBottom: 6 },
          {
            table: {
              headerRows: 1,
              widths: [16, 55, 50, '*', 80, 60],
              body: [
                [
                  { text: '#', style: 'tableHeader', alignment: 'center' },
                  { text: 'Date', style: 'tableHeader' },
                  { text: 'Mode', style: 'tableHeader' },
                  { text: 'Reference', style: 'tableHeader' },
                  { text: 'Receipt No.', style: 'tableHeader' },
                  { text: 'Amount', style: 'tableHeader', alignment: 'right' },
                ],
                ...pmtRows,
              ],
            },
            layout: {
              hLineWidth: (i: number) => i === 0 || i === 1 ? 1 : 0.5,
              vLineWidth: () => 0,
              hLineColor: () => '#E5E7EB',
              paddingLeft: () => 6, paddingRight: () => 6, paddingTop: () => 4, paddingBottom: () => 4,
            },
            marginBottom: 12,
          },
        ] : []),

        // Footer
        { canvas: [{ type: 'line', x1: 0, y1: 0, x2: 515, y2: 0, lineWidth: 0.5, lineColor: '#E5E7EB' }], marginBottom: 8 },
        {
          columns: [
            { text: 'This is a computer-generated document. No signature required.', style: 'footer' },
            { text: `Generated: ${invoiceDateStr}`, style: 'footer', alignment: 'right' },
          ],
        },
      ],
    };

    const printer = new PdfPrinter({
      Roboto: {
        normal: Buffer.from([]),
        bold: Buffer.from([]),
        italics: Buffer.from([]),
        bolditalics: Buffer.from([]),
      },
    });

    const doc = printer.createPdfKitDocument(docDefinition, {
      fonts: {
        Roboto: {
          normal: 'Helvetica',
          bold: 'Helvetica-Bold',
          italics: 'Helvetica-Oblique',
          bolditalics: 'Helvetica-BoldOblique',
        },
      },
    });

    const chunks: Buffer[] = [];
    await new Promise<void>((resolve, reject) => {
      doc.on('data', (chunk: Buffer) => chunks.push(chunk));
      doc.on('end', resolve);
      doc.on('error', reject);
      doc.end();
    });

    const pdfBuffer = Buffer.concat(chunks);
    const githubPath = docPath.financeInvoice(duesId, 'pdf');
    const result = await commitDocument(githubPath, pdfBuffer, `docs: invoice ${invoiceNo} generated`);

    // Cache the PDF key on the dues record
    await sb.from('maintenance_dues')
      .update({ invoice_pdf_key: result.githubPath })
      .eq('id', duesId);

    const url = await getDocumentDownloadUrl(result.githubPath);

    await writeAuditLog({
      societyId: SOCIETY_ID,
      userId: user.id,
      action: 'EXPORT',
      resourceType: 'maintenance_dues',
      resourceId: duesId,
      ip: extractClientIP(request),
      newValues: { invoice_number: invoiceNo, pdf_key: result.githubPath },
    });

    return Response.json({ url, invoice_number: invoiceNo, cached: false, expires_in: 3600 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
