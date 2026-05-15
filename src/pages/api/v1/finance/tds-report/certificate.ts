export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';
import PdfPrinter from 'pdfmake';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const FY_RE = /^\d{4}$/;  // "2025" → FY2025-26 (Apr 2025 – Mar 2026)

// GET /api/v1/finance/tds-report/certificate?vendor_id=<uuid>&fy=<yyyy>
// Returns a PDF Form-16A-style TDS certificate for a vendor for a financial year.
// Exec/admin only — access logged in audit_logs.
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const vendorId = url.searchParams.get('vendor_id') ?? '';
    const fy       = url.searchParams.get('fy') ?? '';

    if (!UUID_RE.test(vendorId)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'valid vendor_id is required' }, { status: 400 });
    }
    if (!FY_RE.test(fy)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'fy must be a 4-digit year, e.g. 2025 for FY2025-26' }, { status: 400 });
    }

    const fyYear   = parseInt(fy, 10);
    const fromDate = `${fyYear}-04-01`;
    const toDate   = `${fyYear + 1}-03-31`;

    const sb = getSupabaseServiceClient();

    // Fetch vendor details
    const { data: vendor, error: vendorErr } = await sb
      .from('vendors')
      .select('id, name, pan, gstin, address, email, phone')
      .eq('id', vendorId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (vendorErr || !vendor) {
      return Response.json({ error: 'NOT_FOUND', message: 'Vendor not found' }, { status: 404 });
    }

    // Fetch society info
    const { data: society } = await sb
      .from('societies')
      .select('name, address, city, state, pincode, gstin, pan, registration_no, tan')
      .eq('id', SOCIETY_ID)
      .single();

    // Fetch all expenses with TDS for this vendor in the FY
    const { data: expenses, error: expErr } = await sb
      .from('expenses')
      .select('id, amount, tds_deducted, payment_date, bill_number, description, expense_categories(name)')
      .eq('society_id', SOCIETY_ID)
      .eq('vendor_id', vendorId)
      .gt('tds_deducted', 0)
      .gte('payment_date', fromDate)
      .lte('payment_date', toDate)
      .order('payment_date', { ascending: true });

    if (expErr) throw Object.assign(new Error(expErr.message), { status: 500 });

    const rows = expenses ?? [];
    const totalAmount = rows.reduce((s, e) => s + Number(e.amount ?? 0), 0);
    const totalTds    = rows.reduce((s, e) => s + Number(e.tds_deducted ?? 0), 0);

    const soc = (society ?? {}) as Record<string, string | null>;
    const v   = vendor as Record<string, string | null>;
    const fmt2 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

    const fyLabel = `${fyYear}-${String(fyYear + 1).slice(2)}`;
    const generatedDate = new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'long', year: 'numeric' });

    // Build expense table rows
    const expenseTableRows: object[] = [
      [
        { text: 'Date', bold: true, fontSize: 9, fillColor: '#EFF6FF' },
        { text: 'Description / Bill No.', bold: true, fontSize: 9, fillColor: '#EFF6FF' },
        { text: 'Category', bold: true, fontSize: 9, fillColor: '#EFF6FF' },
        { text: 'Amount (₹)', bold: true, fontSize: 9, alignment: 'right', fillColor: '#EFF6FF' },
        { text: 'TDS Deducted (₹)', bold: true, fontSize: 9, alignment: 'right', fillColor: '#EFF6FF' },
      ],
      ...rows.map(e => [
        { text: new Date(e.payment_date).toLocaleDateString('en-IN'), fontSize: 9 },
        { text: `${e.description ?? '—'}\n${e.bill_number ? `Bill: ${e.bill_number}` : ''}`, fontSize: 9 },
        { text: (e.expense_categories as { name: string } | null)?.name ?? '—', fontSize: 9 },
        { text: fmt2(Number(e.amount ?? 0)), alignment: 'right', fontSize: 9 },
        { text: fmt2(Number(e.tds_deducted ?? 0)), alignment: 'right', fontSize: 9 },
      ]),
      [
        { text: 'TOTAL', bold: true, fontSize: 9, colSpan: 3, alignment: 'right', fillColor: '#F0FDF4' },
        {},
        {},
        { text: fmt2(totalAmount), bold: true, fontSize: 9, alignment: 'right', fillColor: '#F0FDF4' },
        { text: fmt2(totalTds), bold: true, fontSize: 9, alignment: 'right', fillColor: '#F0FDF4' },
      ],
    ];

    const docDefinition: object = {
      pageSize: 'A4',
      pageMargins: [40, 60, 40, 60],
      styles: {
        heading:   { fontSize: 16, bold: true, color: '#1E3A8A' },
        subtext:   { fontSize: 9,  color: '#6B7280' },
        label:     { fontSize: 9,  bold: true, color: '#374151' },
        value:     { fontSize: 9,  color: '#111827' },
        section:   { fontSize: 11, bold: true, color: '#1E3A8A', margin: [0, 12, 0, 6] },
        certText:  { fontSize: 9,  color: '#374151', lineHeight: 1.4 },
      },
      content: [
        // Header
        {
          columns: [
            {
              stack: [
                { text: soc.name ?? 'UTA MACS', style: 'heading' },
                { text: [soc.address, soc.city, soc.state, soc.pincode].filter(Boolean).join(', '), style: 'subtext' },
                { text: `PAN: ${soc.pan ?? 'N/A'}   |   TAN: ${(soc as any).tan ?? 'N/A'}   |   GSTIN: ${soc.gstin ?? 'N/A'}`, style: 'subtext', margin: [0, 4, 0, 0] },
              ],
              width: '*',
            },
            {
              stack: [
                { text: 'CERTIFICATE OF TAX', fontSize: 10, bold: true, color: '#1E3A8A', alignment: 'right' },
                { text: 'DEDUCTED AT SOURCE', fontSize: 10, bold: true, color: '#1E3A8A', alignment: 'right' },
                { text: `(Form 16A — FY ${fyLabel})`, fontSize: 9, color: '#6B7280', alignment: 'right' },
                { text: `Generated: ${generatedDate}`, style: 'subtext', alignment: 'right', margin: [0, 4, 0, 0] },
              ],
              width: 180,
            },
          ],
          margin: [0, 0, 0, 16],
        },
        { canvas: [{ type: 'line', x1: 0, y1: 0, x2: 515, y2: 0, lineWidth: 1, lineColor: '#1E3A8A' }] },

        // Deductee (vendor) details
        { text: 'Deductee Details', style: 'section' },
        {
          columns: [
            {
              stack: [
                { text: 'Name of Deductee', style: 'label' },
                { text: v.name ?? '—', style: 'value' },
                { text: 'Address', style: 'label', margin: [0, 6, 0, 0] },
                { text: v.address ?? '—', style: 'value' },
              ],
              width: '*',
            },
            {
              stack: [
                { text: 'PAN of Deductee', style: 'label' },
                { text: v.pan ?? '⚠ NOT PROVIDED', style: 'value', color: v.pan ? '#111827' : '#DC2626' },
                { text: 'GSTIN', style: 'label', margin: [0, 6, 0, 0] },
                { text: v.gstin ?? 'N/A', style: 'value' },
                { text: 'Financial Year', style: 'label', margin: [0, 6, 0, 0] },
                { text: fyLabel, style: 'value' },
              ],
              width: 200,
            },
          ],
          margin: [0, 0, 0, 4],
        },

        // Deductor (society) details
        { text: 'Deductor Details', style: 'section' },
        {
          columns: [
            {
              stack: [
                { text: 'Name of Deductor', style: 'label' },
                { text: soc.name ?? '—', style: 'value' },
              ],
              width: '*',
            },
            {
              stack: [
                { text: 'PAN of Deductor', style: 'label' },
                { text: soc.pan ?? 'N/A', style: 'value' },
                { text: 'TAN of Deductor', style: 'label', margin: [0, 6, 0, 0] },
                { text: (soc as any).tan ?? 'N/A', style: 'value' },
              ],
              width: 200,
            },
          ],
          margin: [0, 0, 0, 4],
        },

        // TDS summary
        { text: `TDS Transactions — FY ${fyLabel}`, style: 'section' },
        rows.length > 0
          ? {
              table: {
                headerRows: 1,
                widths: [60, '*', 80, 70, 80],
                body: expenseTableRows,
              },
              layout: {
                hLineColor: () => '#E5E7EB',
                vLineColor: () => '#E5E7EB',
              },
            }
          : { text: 'No TDS transactions found for this vendor in the selected financial year.', style: 'certText', color: '#6B7280' },

        // Summary box
        rows.length > 0
          ? {
              table: {
                widths: ['*', 120],
                body: [
                  [
                    { text: 'Total Amount Paid / Credited', style: 'label', margin: [0, 2, 0, 2] },
                    { text: `₹ ${fmt2(totalAmount)}`, bold: true, fontSize: 10, alignment: 'right', margin: [0, 2, 0, 2] },
                  ],
                  [
                    { text: 'Total TDS Deducted & Deposited', style: 'label', margin: [0, 2, 0, 2] },
                    { text: `₹ ${fmt2(totalTds)}`, bold: true, fontSize: 10, alignment: 'right', color: '#1E3A8A', margin: [0, 2, 0, 2] },
                  ],
                ],
              },
              layout: 'noBorders',
              margin: [0, 8, 0, 0],
            }
          : '',

        // Certificate text
        { text: 'Certificate', style: 'section' },
        {
          text: `This is to certify that the tax deducted at source from the payments made / credited to ${v.name ?? 'the deductee'} (PAN: ${v.pan ?? 'N/A'}) during FY ${fyLabel} amounts to ₹ ${fmt2(totalTds)}, which has been deducted at the applicable rate and deposited with the Central Government as required under the provisions of the Income Tax Act, 1961.`,
          style: 'certText',
        },

        // Signature block
        {
          columns: [
            { text: '', width: '*' },
            {
              stack: [
                { canvas: [{ type: 'line', x1: 0, y1: 0, x2: 180, y2: 0, lineWidth: 1, lineColor: '#9CA3AF' }], margin: [0, 40, 0, 4] },
                { text: 'Authorised Signatory', style: 'label', alignment: 'center' },
                { text: soc.name ?? '', style: 'subtext', alignment: 'center' },
                { text: `Date: ${generatedDate}`, style: 'subtext', alignment: 'center', margin: [0, 2, 0, 0] },
              ],
              width: 180,
            },
          ],
          margin: [0, 24, 0, 0],
        },

        // Footer notice
        { canvas: [{ type: 'line', x1: 0, y1: 0, x2: 515, y2: 0, lineWidth: 0.5, lineColor: '#E5E7EB' }], margin: [0, 16, 0, 8] },
        {
          text: 'This is a computer-generated certificate. No physical signature is required. For queries, contact the society treasurer.',
          style: 'subtext',
          alignment: 'center',
        },
        ...(!v.pan ? [{
          text: '⚠ WARNING: PAN not available for this vendor. TDS rate may be higher and Form 16A cannot be issued as per Section 206AA.',
          fontSize: 9, color: '#DC2626', bold: true, margin: [0, 8, 0, 0],
        }] : []),
      ],
    };

    const fonts = {
      Helvetica: {
        normal:      'Helvetica',
        bold:        'Helvetica-Bold',
        italics:     'Helvetica-Oblique',
        bolditalics: 'Helvetica-BoldOblique',
      },
    };

    const printer = new PdfPrinter(fonts);
    const pdfDoc  = printer.createPdfKitDocument(docDefinition as any);
    const chunks: Buffer[] = [];

    await new Promise<void>((resolve, reject) => {
      pdfDoc.on('data', (chunk: Buffer) => chunks.push(chunk));
      pdfDoc.on('end', resolve);
      pdfDoc.on('error', reject);
      pdfDoc.end();
    });

    const pdfBuffer = Buffer.concat(chunks);

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'READ', resourceType: 'tds_certificate', resourceId: vendorId,
      ip: extractClientIP(request),
      newValues: { vendor_id: vendorId, fy: fyLabel, total_tds: totalTds },
    });

    const filename = `TDS-Certificate-${(v.name ?? vendorId).replace(/\s+/g, '-')}-FY${fyLabel}.pdf`;
    return new Response(pdfBuffer, {
      headers: {
        'Content-Type':        'application/pdf',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Content-Length':      String(pdfBuffer.length),
        'Cache-Control':       'no-store',
      },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
