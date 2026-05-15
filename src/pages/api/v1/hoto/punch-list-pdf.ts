export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleBool } from '@lib/utils/getRules';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import PdfPrinter from 'pdfmake';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const BRAND = '#1E3A8A';
const GREEN  = '#10B981';
const RED    = '#EF4444';
const AMBER  = '#F59E0B';
const GRAY   = '#6B7280';
const LGRAY  = '#E5E7EB';

function requireExec(user: { isAdmin: boolean; portalRole?: string | null }) {
  return user.isAdmin || ['executive', 'secretary', 'president'].includes(user.portalRole ?? '');
}

function fmtDate(d: string | null | undefined) {
  return d ? new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';
}

const CLOSED_STATUSES  = new Set(['APPROVED', 'CLOSED']);
const OPEN_STATUSES    = new Set(['NOT_STARTED', 'IN_PROGRESS', 'UNDER_REVIEW', 'PENDING_PRESIDENT', 'PENDING_SECRETARY']);

const STATUS_LABEL: Record<string, string> = {
  NOT_STARTED:        'Not Started',
  IN_PROGRESS:        'In Progress',
  UNDER_REVIEW:       'Under Review',
  PENDING_SECRETARY:  'Pending Secretary',
  PENDING_PRESIDENT:  'Pending President',
  APPROVED:           'Approved',
  REJECTED:           'Rejected',
  CLOSED:             'Closed',
};

const PRIORITY_COLOR: Record<string, string> = {
  CRITICAL: RED, HIGH: AMBER, MEDIUM: BRAND, LOW: GRAY,
};

// GET /api/v1/hoto/punch-list-pdf?category=
// Generates a formal RERA-ready punch list PDF covering all HOTO items and their linked snags.
// Optional ?category= filter. Exec/admin only.
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['HOTO_PUNCH_LIST_ENABLED']);
    if (!ruleBool(rules, 'HOTO_PUNCH_LIST_ENABLED', true)) {
      return Response.json({ error: 'FORBIDDEN', message: 'Punch list PDF is disabled' }, { status: 403 });
    }

    const categoryFilter = url.searchParams.get('category')?.trim() ?? '';

    // ── Fetch data ────────────────────────────────────────────────────────────
    const [societyRes, itemsRes, snagLinksRes, snagSummaryRes] = await Promise.all([
      sb.from('societies').select('name, address, city, state, registration_no').eq('id', SOCIETY_ID).single(),
      (() => {
        let q = sb
          .from('hoto_items')
          .select(`
            id, hoto_category, title, priority, status, deadline,
            builder_sla_date, days_overdue, responsible_role,
            president_approved_at, secretary_approved_at,
            rera_escalation_eligible, notice_sent, created_at
          `)
          .eq('society_id', SOCIETY_ID)
          .order('hoto_category')
          .order('priority', { ascending: false });
        if (categoryFilter) q = (q as any).eq('hoto_category', categoryFilter);
        return q;
      })(),
      sb.from('snag_hoto_links').select('hoto_item_id, snag_item_id'),
      sb.from('snag_items')
        .select('id, status, severity, category')
        .eq('society_id', SOCIETY_ID)
        .eq('deleted', false),
    ]);

    const soc   = (societyRes.data ?? {}) as any;
    const items = (itemsRes.data ?? []) as any[];
    const snagLinks = (snagLinksRes.data ?? []) as any[];
    const allSnags  = (snagSummaryRes.data ?? []) as any[];

    // Map snag counts per HOTO item
    const snagsByItem: Record<string, { total: number; open: number; closed: number }> = {};
    const snagIdMap: Record<string, any> = {};
    for (const s of allSnags) snagIdMap[s.id] = s;
    for (const link of snagLinks) {
      if (!snagsByItem[link.hoto_item_id]) snagsByItem[link.hoto_item_id] = { total: 0, open: 0, closed: 0 };
      snagsByItem[link.hoto_item_id].total++;
      const snag = snagIdMap[link.snag_item_id];
      if (snag && CLOSED_STATUSES.has(snag.status)) snagsByItem[link.hoto_item_id].closed++;
      else snagsByItem[link.hoto_item_id].open++;
    }

    // Summary counters
    const totalItems  = items.length;
    const closedItems = items.filter(i => CLOSED_STATUSES.has(i.status)).length;
    const openItems   = items.filter(i => OPEN_STATUSES.has(i.status)).length;
    const overdueItems = items.filter(i => (i.days_overdue ?? 0) > 0 && !CLOSED_STATUSES.has(i.status)).length;
    const totalSnags  = allSnags.filter(s => !categoryFilter || s.snag_category === categoryFilter).length;
    const openSnags   = allSnags.filter(s => (!categoryFilter || s.snag_category === categoryFilter) && !CLOSED_STATUSES.has(s.status)).length;

    // Group items by category
    const byCategory: Record<string, any[]> = {};
    for (const item of items) {
      const cat = item.hoto_category ?? 'Uncategorised';
      if (!byCategory[cat]) byCategory[cat] = [];
      byCategory[cat].push(item);
    }

    // ── PDF structure ─────────────────────────────────────────────────────────
    const printer = new PdfPrinter({
      Helvetica: { normal: 'Helvetica', bold: 'Helvetica-Bold', italics: 'Helvetica-Oblique', bolditalics: 'Helvetica-BoldOblique' },
    });

    const reportDate   = new Date().toLocaleDateString('en-IN', { day: '2-digit', month: 'long', year: 'numeric' });
    const completionPct = totalItems > 0 ? Math.round((closedItems / totalItems) * 100) : 0;

    const kpiTable = {
      table: {
        widths: ['*', '*', '*', '*'],
        body: [[
          { text: [{ text: String(totalItems) + '\n', style: 'kpiVal' }, { text: 'Total Items', style: 'kpiLbl' }], alignment: 'center' },
          { text: [{ text: String(closedItems) + '\n', style: 'kpiValGreen' }, { text: 'Approved/Closed', style: 'kpiLbl' }], alignment: 'center' },
          { text: [{ text: String(openItems) + '\n', style: 'kpiValAmber' }, { text: 'Open', style: 'kpiLbl' }], alignment: 'center' },
          { text: [{ text: String(overdueItems) + '\n', style: 'kpiValRed' }, { text: 'Overdue', style: 'kpiLbl' }], alignment: 'center' },
        ]],
      },
      layout: {
        hLineColor: () => LGRAY,
        vLineColor: () => LGRAY,
        paddingTop: () => 8,
        paddingBottom: () => 8,
      },
    };

    const snagKpiTable = {
      table: {
        widths: ['*', '*', '*'],
        body: [[
          { text: [{ text: String(totalSnags) + '\n', style: 'kpiVal' }, { text: 'Total Snags', style: 'kpiLbl' }], alignment: 'center' },
          { text: [{ text: String(totalSnags - openSnags) + '\n', style: 'kpiValGreen' }, { text: 'Resolved', style: 'kpiLbl' }], alignment: 'center' },
          { text: [{ text: String(openSnags) + '\n', style: 'kpiValRed' }, { text: 'Open', style: 'kpiLbl' }], alignment: 'center' },
        ]],
      },
      layout: {
        hLineColor: () => LGRAY,
        vLineColor: () => LGRAY,
        paddingTop: () => 8,
        paddingBottom: () => 8,
      },
    };

    // Progress bar canvas
    const pctWidth = Math.max(1, Math.round(completionPct * 4.8)); // max ~480pt
    const progressBar = {
      canvas: [
        { type: 'rect', x: 0, y: 4, w: 480, h: 10, r: 5, color: LGRAY },
        { type: 'rect', x: 0, y: 4, w: pctWidth, h: 10, r: 5, color: completionPct >= 80 ? GREEN : completionPct >= 50 ? AMBER : RED },
      ],
    };

    // Category sections
    const categorySections: any[] = [];
    for (const [cat, catItems] of Object.entries(byCategory)) {
      const catClosed = catItems.filter(i => CLOSED_STATUSES.has(i.status)).length;
      const catPct    = catItems.length > 0 ? Math.round((catClosed / catItems.length) * 100) : 0;
      const catColor  = catPct >= 80 ? GREEN : catPct >= 50 ? AMBER : RED;

      categorySections.push(
        { text: cat, style: 'catHeading', pageBreak: categorySections.length === 0 ? undefined : 'before' as const },
        {
          columns: [
            { text: `${catClosed}/${catItems.length} items completed`, style: 'catMeta' },
            { text: `${catPct}%`, style: 'catMeta', alignment: 'right', color: catColor, bold: true },
          ],
          marginBottom: 4,
        },
        {
          canvas: [
            { type: 'rect', x: 0, y: 2, w: 480, h: 6, r: 3, color: LGRAY },
            { type: 'rect', x: 0, y: 2, w: Math.max(1, Math.round(catPct * 4.8)), h: 6, r: 3, color: catColor },
          ],
          marginBottom: 10,
        },
      );

      // Item table for this category
      const tableRows: any[][] = [
        [
          { text: '#',           style: 'thdr' },
          { text: 'Title',       style: 'thdr' },
          { text: 'Priority',    style: 'thdr' },
          { text: 'Status',      style: 'thdr' },
          { text: 'SLA Date',    style: 'thdr' },
          { text: 'Overdue',     style: 'thdr' },
          { text: 'Snags',       style: 'thdr' },
          { text: 'Sec. ✓',      style: 'thdr' },
          { text: 'Pres. ✓',     style: 'thdr' },
        ],
      ];

      catItems.forEach((item, idx) => {
        const snags   = snagsByItem[item.id];
        const overdue = (item.days_overdue ?? 0) > 0 && !CLOSED_STATUSES.has(item.status);
        const rowFill = CLOSED_STATUSES.has(item.status) ? '#F0FDF4' : overdue ? '#FFF7ED' : '#FFFFFF';
        const statusColor = CLOSED_STATUSES.has(item.status) ? GREEN : overdue ? RED : BRAND;

        tableRows.push([
          { text: String(idx + 1), style: 'td', fillColor: rowFill, alignment: 'center' },
          { text: item.title ?? '—', style: 'td', fillColor: rowFill },
          { text: item.priority ?? '—', style: 'tdSm', fillColor: rowFill, color: PRIORITY_COLOR[item.priority] ?? GRAY },
          { text: STATUS_LABEL[item.status] ?? item.status, style: 'tdSm', fillColor: rowFill, color: statusColor },
          { text: fmtDate(item.builder_sla_date), style: 'tdSm', fillColor: rowFill },
          { text: overdue ? `${item.days_overdue}d` : '—', style: 'tdSm', fillColor: rowFill, color: overdue ? RED : GRAY },
          { text: snags ? `${snags.closed}/${snags.total}` : '—', style: 'tdSm', fillColor: rowFill, alignment: 'center' },
          { text: item.secretary_approved_at ? '✓' : '—', style: 'tdSm', fillColor: rowFill, color: item.secretary_approved_at ? GREEN : GRAY, alignment: 'center' },
          { text: item.president_approved_at ? '✓' : '—', style: 'tdSm', fillColor: rowFill, color: item.president_approved_at ? GREEN : GRAY, alignment: 'center' },
        ]);
      });

      categorySections.push({
        table: {
          headerRows: 1,
          widths: ['auto', '*', 'auto', 'auto', 'auto', 'auto', 'auto', 'auto', 'auto'],
          body: tableRows,
        },
        layout: {
          hLineColor: () => LGRAY,
          vLineColor: () => LGRAY,
          fillColor: (rowIdx: number) => rowIdx === 0 ? BRAND : null,
          paddingTop: () => 4,
          paddingBottom: () => 4,
        },
        marginBottom: 6,
      });
    }

    // Signature block
    const signatureBlock = {
      marginTop: 30,
      columns: [
        {
          width: '33%',
          stack: [
            { canvas: [{ type: 'line', x1: 0, y1: 0, x2: 130, y2: 0, lineWidth: 1, lineColor: GRAY }] },
            { text: 'Secretary', style: 'sigLbl' },
            { text: 'Date: ________________', style: 'sigDate' },
          ],
        },
        { width: '5%', text: '' },
        {
          width: '33%',
          stack: [
            { canvas: [{ type: 'line', x1: 0, y1: 0, x2: 130, y2: 0, lineWidth: 1, lineColor: GRAY }] },
            { text: 'President', style: 'sigLbl' },
            { text: 'Date: ________________', style: 'sigDate' },
          ],
        },
        { width: '5%', text: '' },
        {
          width: '24%',
          stack: [
            { canvas: [{ type: 'line', x1: 0, y1: 0, x2: 100, y2: 0, lineWidth: 1, lineColor: GRAY }] },
            { text: 'Builder Representative', style: 'sigLbl' },
            { text: 'Date: ________________', style: 'sigDate' },
          ],
        },
      ],
    };

    const docDef: any = {
      pageSize:    'A4',
      pageMargins: [40, 60, 40, 50],
      defaultStyle: { font: 'Helvetica', fontSize: 9, color: '#111827' },

      header: (_: number, pageCount: number) => ({
        columns: [
          { text: soc.name ?? 'HOTO Punch List', fontSize: 8, color: BRAND, bold: true, marginLeft: 40, marginTop: 20 },
          { text: `CONFIDENTIAL — Page ${_} of ${pageCount}`, fontSize: 7, color: GRAY, alignment: 'right', marginRight: 40, marginTop: 20 },
        ],
      }),
      footer: () => ({
        text: `Generated on ${reportDate} | Urban Trilla Apartment Owners Mutually Aided Cooperative Maintenance Society Limited`,
        fontSize: 7, color: GRAY, alignment: 'center', marginBottom: 20,
      }),

      content: [
        // Cover section
        { text: soc.name ?? 'Society', style: 'heading', marginBottom: 2 },
        { text: [soc.address, soc.city, soc.state].filter(Boolean).join(', '), style: 'subheading', marginBottom: 2 },
        soc.registration_no ? { text: `Reg. No.: ${soc.registration_no}`, style: 'meta' } : {},
        { text: 'HOTO Punch List Report', fontSize: 16, bold: true, color: BRAND, marginTop: 18, marginBottom: 2 },
        categoryFilter
          ? { text: `Category: ${categoryFilter}`, fontSize: 10, color: GRAY, marginBottom: 4 }
          : { text: 'All Categories', fontSize: 10, color: GRAY, marginBottom: 4 },
        { text: `Report Date: ${reportDate}`, fontSize: 9, color: GRAY, marginBottom: 16 },

        // Summary KPIs
        { text: 'Handover Items', style: 'sectionHeading' },
        kpiTable,
        { text: '\n', fontSize: 4 },

        // Progress bar
        { columns: [
            { text: 'Overall Completion', fontSize: 9, color: GRAY, width: '*' },
            { text: `${completionPct}%`, fontSize: 9, bold: true, color: completionPct >= 80 ? GREEN : completionPct >= 50 ? AMBER : RED, alignment: 'right', width: 'auto' },
          ], marginBottom: 4 },
        progressBar,
        { text: '\n', fontSize: 8 },

        // Snag KPIs
        { text: 'Linked Snags / Defects', style: 'sectionHeading' },
        snagKpiTable,
        { text: '\n', fontSize: 8 },

        // Category detail sections
        ...categorySections,

        // Signature block
        { text: 'Sign-off', style: 'sectionHeading', marginTop: 20 },
        { text: 'By signing below, the parties confirm that the handover items listed in this report are accurate as of the report date.', fontSize: 8, color: GRAY, marginBottom: 8 },
        signatureBlock,
      ],

      styles: {
        heading:        { fontSize: 14, bold: true, color: BRAND },
        subheading:     { fontSize: 9, color: GRAY },
        meta:           { fontSize: 8, color: GRAY },
        sectionHeading: { fontSize: 11, bold: true, color: BRAND, marginBottom: 6, marginTop: 8 },
        catHeading:     { fontSize: 10, bold: true, color: BRAND, marginBottom: 4, marginTop: 12 },
        catMeta:        { fontSize: 8, color: GRAY },
        kpiVal:         { fontSize: 18, bold: true, color: BRAND },
        kpiValGreen:    { fontSize: 18, bold: true, color: GREEN },
        kpiValAmber:    { fontSize: 18, bold: true, color: AMBER },
        kpiValRed:      { fontSize: 18, bold: true, color: RED },
        kpiLbl:         { fontSize: 8, color: GRAY },
        thdr:           { fontSize: 8, bold: true, color: '#FFFFFF', marginLeft: 4, marginRight: 4 },
        td:             { fontSize: 8, marginLeft: 4, marginRight: 4 },
        tdSm:           { fontSize: 7.5, marginLeft: 4, marginRight: 4 },
        sigLbl:         { fontSize: 8, color: GRAY, marginTop: 4 },
        sigDate:        { fontSize: 8, color: GRAY, marginTop: 8 },
      },
    };

    const pdfDoc = printer.createPdfKitDocument(docDef);
    const chunks: Buffer[] = [];
    await new Promise<void>((resolve, reject) => {
      pdfDoc.on('data', (c: Buffer) => chunks.push(c));
      pdfDoc.on('end', resolve);
      pdfDoc.on('error', reject);
      pdfDoc.end();
    });
    const pdfBuffer = Buffer.concat(chunks);

    // Audit log + record in hoto_completion_reports
    await Promise.all([
      writeAuditLog({
        societyId:    SOCIETY_ID,
        userId:       user.id,
        action:       'EXPORT',
        resourceType: 'hoto_punch_list_pdf',
        resourceId:   SOCIETY_ID,
        newValues:    { total_items: totalItems, closed_items: closedItems, open_snags: openSnags, category_filter: categoryFilter || null },
        ip:           extractClientIP(request),
      }),
      sb.from('hoto_completion_reports').insert({
        society_id:      SOCIETY_ID,
        generated_by:    user.id,
        total_items:     totalItems,
        closed_items:    closedItems,
        open_snags:      openSnags,
        category_filter: categoryFilter || null,
      }),
    ]);

    const filename = categoryFilter
      ? `hoto-punch-list-${categoryFilter.toLowerCase().replace(/\s+/g, '-')}-${new Date().toISOString().slice(0, 10)}.pdf`
      : `hoto-punch-list-${new Date().toISOString().slice(0, 10)}.pdf`;

    return new Response(pdfBuffer, {
      headers: {
        'Content-Type':        'application/pdf',
        'Content-Disposition': `attachment; filename="${filename}"`,
        'Content-Length':      String(pdfBuffer.length),
      },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
