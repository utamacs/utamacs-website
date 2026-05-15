export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { commitDocument, getDocumentDownloadUrl } from '@lib/utils/githubDocStore';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';
import PdfPrinter from 'pdfmake';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/finance/ledger/statement?member_id=<uuid>&from=YYYY-MM-DD&to=YYYY-MM-DD
// Generates a PDF statement of account for a member.
// Members generate their own; exec can generate for any member_id.
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isExec = user.isAdmin ||
      ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') ||
      ['executive', 'admin'].includes(user.role ?? '');

    const requestedMemberId = url.searchParams.get('member_id') ?? user.id;
    if (!UUID_RE.test(requestedMemberId)) {
      return Response.json({ error: 'VALIDATION', message: 'invalid member_id' }, { status: 400 });
    }
    if (!isExec && requestedMemberId !== user.id) {
      return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
    }

    const fromDate = url.searchParams.get('from') ?? '';
    const toDate   = url.searchParams.get('to') ?? '';

    const sb = getSupabaseServiceClient();

    // Fetch member profile + unit
    const { data: profile } = await sb
      .from('profiles')
      .select('id, full_name, unit_id, units(unit_number, block, floor)')
      .eq('id', requestedMemberId)
      .eq('society_id', SOCIETY_ID)
      .single();

    const prof = (profile ?? {}) as any;

    // Fetch dues
    let duesQ = sb
      .from('maintenance_dues')
      .select('id, total_amount, base_amount, penalty_amount, gst_amount, amount_paid, status, due_date, paid_at, billing_periods(name)')
      .eq('user_id', requestedMemberId)
      .eq('society_id', SOCIETY_ID)
      .order('due_date', { ascending: true });
    if (fromDate) duesQ = duesQ.gte('due_date', fromDate);
    if (toDate)   duesQ = duesQ.lte('due_date', toDate);

    // Fetch payments
    let pmtsQ = sb
      .from('payments')
      .select('id, amount, payment_mode, transaction_ref, receipt_number, paid_at')
      .eq('user_id', requestedMemberId)
      .eq('society_id', SOCIETY_ID)
      .order('paid_at', { ascending: true });
    if (fromDate) pmtsQ = pmtsQ.gte('paid_at', fromDate);
    if (toDate)   pmtsQ = pmtsQ.lte('paid_at', toDate + 'T23:59:59');

    const [{ data: dues }, { data: payments }, { data: society }] = await Promise.all([
      duesQ,
      pmtsQ,
      sb.from('societies').select('name, address, city, state, pincode').eq('id', SOCIETY_ID).single(),
    ]);

    const soc = (society ?? {}) as any;

    // Build merged chronological timeline
    type LedgerEntry = {
      date: string; type: 'debit' | 'credit'; label: string;
      amount: number; reference: string; running_balance: number;
    };

    const raw = [
      ...(dues ?? []).map((d: any) => ({
        date: d.due_date, type: 'debit' as const,
        label: `Maintenance — ${(d.billing_periods as any)?.name ?? d.due_date}`,
        amount: Number(d.total_amount),
        reference: `Status: ${String(d.status).replace('_', ' ')}`,
      })),
      ...(payments ?? []).map((p: any) => ({
        date: p.paid_at?.slice(0, 10) ?? '',
        type: 'credit' as const,
        label: `Payment — ${String(p.payment_mode).toUpperCase()}`,
        amount: Number(p.amount),
        reference: p.receipt_number ?? p.transaction_ref ?? '',
      })),
    ].sort((a, b) => a.date.localeCompare(b.date));

    let balance = 0;
    const entries: LedgerEntry[] = raw.map((e) => {
      balance = e.type === 'debit' ? balance + e.amount : balance - e.amount;
      return { ...e, running_balance: balance };
    });

    const totalDues    = (dues ?? []).reduce((s: number, d: any) => s + Number(d.total_amount), 0);
    const totalPaid    = (payments ?? []).reduce((s: number, p: any) => s + Number(p.amount), 0);
    const outstanding  = totalDues - totalPaid;

    const fmt = (n: number) => `₹${Math.abs(n).toLocaleString('en-IN', { minimumFractionDigits: 2 })}`;
    const dateLabel = fromDate || toDate
      ? `${fromDate || 'All time'} to ${toDate || 'present'}`
      : 'All time';
    const generatedOn = new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });

    // Build ledger table rows
    const tableBody: any[] = [
      [
        { text: 'Date', style: 'th' },
        { text: 'Description', style: 'th' },
        { text: 'Reference', style: 'th' },
        { text: 'Debit (₹)', style: 'th', alignment: 'right' },
        { text: 'Credit (₹)', style: 'th', alignment: 'right' },
        { text: 'Balance (₹)', style: 'th', alignment: 'right' },
      ],
      ...entries.map((e) => [
        { text: e.date, fontSize: 8, color: '#6B7280' },
        { text: e.label, fontSize: 9 },
        { text: e.reference, fontSize: 8, color: '#6B7280' },
        { text: e.type === 'debit'  ? fmt(e.amount) : '—', fontSize: 9, alignment: 'right', color: e.type === 'debit'  ? '#DC2626' : '#9CA3AF' },
        { text: e.type === 'credit' ? fmt(e.amount) : '—', fontSize: 9, alignment: 'right', color: e.type === 'credit' ? '#16A34A' : '#9CA3AF' },
        {
          text: fmt(e.running_balance),
          fontSize: 9, alignment: 'right', bold: true,
          color: e.running_balance > 0 ? '#DC2626' : e.running_balance < 0 ? '#16A34A' : '#374151',
        },
      ]),
    ];

    const docDefinition: any = {
      pageSize: 'A4',
      pageMargins: [36, 50, 36, 50],
      styles: {
        heading:  { fontSize: 16, bold: true, color: '#1E3A8A' },
        subtext:  { fontSize: 9, color: '#6B7280' },
        label:    { fontSize: 8, bold: true, color: '#9CA3AF', characterSpacing: 0.5 },
        value:    { fontSize: 10, bold: true, color: '#111827' },
        th:       { bold: true, fillColor: '#EFF6FF', color: '#1E3A8A', fontSize: 9 },
        footer:   { fontSize: 8, color: '#9CA3AF', italics: true },
        statVal:  { fontSize: 13, bold: true },
      },
      content: [
        // Header
        {
          columns: [
            {
              stack: [
                { text: soc.name ?? 'UTA MACS', style: 'heading' },
                { text: [soc.address, soc.city, soc.state, soc.pincode].filter(Boolean).join(', '), style: 'subtext' },
              ],
            },
            {
              stack: [
                { text: 'STATEMENT OF ACCOUNT', fontSize: 13, bold: true, color: '#1E3A8A', alignment: 'right' },
                { text: `Generated: ${generatedOn}`, style: 'subtext', alignment: 'right', marginTop: 4 },
              ],
            },
          ],
          marginBottom: 10,
        },
        { canvas: [{ type: 'line', x1: 0, y1: 0, x2: 523, y2: 0, lineWidth: 1.5, lineColor: '#1E3A8A' }], marginBottom: 10 },

        // Member + period
        {
          columns: [
            {
              stack: [
                { text: 'MEMBER', style: 'label', marginBottom: 3 },
                { text: prof.full_name ?? '—', style: 'value' },
                { text: `Unit: ${prof.units?.block ?? ''}${prof.units?.unit_number ?? '—'}, Floor ${prof.units?.floor ?? 0}`, fontSize: 9, color: '#4B5563' },
              ],
              width: '48%',
            },
            { width: '4%', text: '' },
            {
              stack: [
                { text: 'PERIOD', style: 'label', marginBottom: 3 },
                { text: dateLabel, style: 'value' },
              ],
              width: '48%',
            },
          ],
          marginBottom: 12,
        },

        // Summary boxes
        {
          columns: [
            {
              stack: [
                { text: 'TOTAL BILLED', style: 'label', marginBottom: 2 },
                { text: fmt(totalDues), fontSize: 13, bold: true, color: '#111827' },
              ],
              width: '33%', alignment: 'center',
              fillColor: '#F9FAFB',
            },
            {
              stack: [
                { text: 'TOTAL PAID', style: 'label', marginBottom: 2 },
                { text: fmt(totalPaid), fontSize: 13, bold: true, color: '#16A34A' },
              ],
              width: '33%', alignment: 'center',
            },
            {
              stack: [
                { text: outstanding > 0 ? 'OUTSTANDING' : 'ADVANCE CREDIT', style: 'label', marginBottom: 2 },
                { text: fmt(outstanding), fontSize: 13, bold: true, color: outstanding > 0 ? '#DC2626' : '#16A34A' },
              ],
              width: '33%', alignment: 'center',
            },
          ],
          marginBottom: 16,
        },

        // Ledger table
        entries.length > 0 ? {
          table: {
            headerRows: 1,
            widths: [48, '*', 70, 60, 60, 65],
            body: tableBody,
          },
          layout: {
            hLineWidth: (i: number) => i === 0 || i === 1 ? 1 : 0.3,
            vLineWidth: () => 0,
            hLineColor: () => '#E5E7EB',
            paddingLeft: () => 5, paddingRight: () => 5, paddingTop: () => 4, paddingBottom: () => 4,
          },
          marginBottom: 12,
        } : { text: 'No transactions in this period.', fontSize: 10, color: '#6B7280', marginBottom: 12 },

        // Footer
        { canvas: [{ type: 'line', x1: 0, y1: 0, x2: 523, y2: 0, lineWidth: 0.5, lineColor: '#E5E7EB' }], marginBottom: 6 },
        {
          columns: [
            { text: 'This is a computer-generated statement. No signature required.', style: 'footer' },
            { text: outstanding > 0 ? `Amount due: ${fmt(outstanding)}` : 'Account clear', style: 'footer', alignment: 'right', color: outstanding > 0 ? '#DC2626' : '#16A34A' },
          ],
        },
      ],
    };

    const printer = new PdfPrinter({
      Roboto: { normal: Buffer.from([]), bold: Buffer.from([]), italics: Buffer.from([]), bolditalics: Buffer.from([]) },
    });
    const doc = printer.createPdfKitDocument(docDefinition, {
      fonts: { Roboto: { normal: 'Helvetica', bold: 'Helvetica-Bold', italics: 'Helvetica-Oblique', bolditalics: 'Helvetica-BoldOblique' } },
    });
    const chunks: Buffer[] = [];
    await new Promise<void>((resolve, reject) => {
      doc.on('data', (c: Buffer) => chunks.push(c));
      doc.on('end', resolve);
      doc.on('error', reject);
      doc.end();
    });

    const pdfBuffer = Buffer.concat(chunks);
    const ts = Date.now();
    const githubPath = `finance/statements/${requestedMemberId.slice(0, 8)}/${ts}.pdf`;
    const result = await commitDocument(githubPath, pdfBuffer, `docs: account statement for member ${requestedMemberId.slice(0, 8)}`);
    const download_url = await getDocumentDownloadUrl(result.githubPath);

    await writeAuditLog({
      societyId: SOCIETY_ID,
      userId:    user.id,
      action:    'EXPORT',
      resourceType: 'maintenance_dues',
      resourceId:   requestedMemberId,
      ip:        extractClientIP(request),
      newValues: { statement_for: requestedMemberId, period: dateLabel },
    });

    return Response.json({ download_url, expires_in: 3600, period: dateLabel, summary: { total_dues: totalDues, total_paid: totalPaid, outstanding } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
