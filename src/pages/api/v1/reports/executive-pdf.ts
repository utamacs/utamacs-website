export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleInt, ruleBool } from '@lib/utils/getRules';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import PdfPrinter from 'pdfmake';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const BRAND = '#1E3A8A';
const GREEN  = '#10B981';
const RED    = '#EF4444';
const AMBER  = '#F59E0B';
const GRAY   = '#6B7280';
const LGRAY  = '#E5E7EB';

function requireExec(user: { isAdmin: boolean; portalRole?: string | null; role?: string | null }) {
  return user.isAdmin ||
    ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') ||
    ['executive', 'admin'].includes(user.role ?? '');
}

const fmt2 = (n: number) => n.toLocaleString('en-IN', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
const fmtPct = (n: number) => `${n}%`;

// GET /api/v1/reports/executive-pdf?months=N
// Returns a pdfmake executive summary report covering:
//   - Society KPIs, occupancy, collection rate, complaints, expenses
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, [
      'ANALYTICS_PDF_ENABLED', 'ANALYTICS_TREND_MONTHS', 'ANALYTICS_EXPENSE_TOP_N',
    ]);
    if (!ruleBool(rules, 'ANALYTICS_PDF_ENABLED', true)) {
      return Response.json({ error: 'FORBIDDEN', message: 'PDF export is disabled' }, { status: 403 });
    }
    const trendMonths = ruleInt(rules, 'ANALYTICS_TREND_MONTHS', 12);
    const topN        = ruleInt(rules, 'ANALYTICS_EXPENSE_TOP_N', 8);

    const since = new Date();
    since.setMonth(since.getMonth() - trendMonths);
    since.setDate(1); since.setHours(0, 0, 0, 0);
    const sinceStr = since.toISOString();

    // Fetch all data in parallel
    const [
      societyRes, unitsRes, profilesRes,
      duesRes, paymentsRes, expensesRes,
      complaintsRes, periodsRes,
    ] = await Promise.all([
      sb.from('societies').select('name, address, city, state, registration_no, gstin').eq('id', SOCIETY_ID).single(),
      sb.from('units').select('id, block').eq('society_id', SOCIETY_ID),
      sb.from('profiles').select('unit_id, residency_type, is_active').eq('society_id', SOCIETY_ID).eq('is_active', true),
      sb.from('maintenance_dues').select('status, total_amount, billing_period_id').eq('society_id', SOCIETY_ID).gte('created_at', sinceStr),
      sb.from('payments').select('amount, paid_at').eq('society_id', SOCIETY_ID).gte('paid_at', sinceStr),
      sb.from('expenses').select('net_payable, amount, payment_date, expense_categories(name)').eq('society_id', SOCIETY_ID).gte('payment_date', sinceStr.slice(0, 10)),
      sb.from('complaints').select('status, priority, created_at, resolved_at').eq('society_id', SOCIETY_ID).gte('created_at', sinceStr),
      sb.from('billing_periods').select('id, name, due_date').eq('society_id', SOCIETY_ID).order('due_date', { ascending: false }).limit(trendMonths),
    ]);

    const soc       = (societyRes.data ?? {}) as any;
    const allUnits  = unitsRes.data ?? [];
    const profiles  = profilesRes.data ?? [];
    const dues      = duesRes.data ?? [];
    const payments  = paymentsRes.data ?? [];
    const expenses  = expensesRes.data ?? [];
    const complaints = complaintsRes.data ?? [];
    const periods   = (periodsRes.data ?? []).reverse();

    // Occupancy
    const occupiedIds = new Set(profiles.map((p: any) => p.unit_id));
    const totalUnits  = allUnits.length;
    const ownerUnits  = profiles.filter((p: any) => p.residency_type !== 'tenant').length;
    const tenantUnits = profiles.filter((p: any) => p.residency_type === 'tenant').length;
    const vacantUnits = totalUnits - occupiedIds.size;

    // Collection summary
    const totalDemand    = dues.reduce((s, d) => s + Number((d as any).total_amount ?? 0), 0);
    const totalPaid      = dues.filter((d: any) => d.status === 'paid').reduce((s, d) => s + Number((d as any).total_amount ?? 0), 0);
    const collectionRate = totalDemand > 0 ? Math.round((totalPaid / totalDemand) * 100) : 0;
    const overdueDues    = dues.filter((d: any) => d.status === 'pending' || d.status === 'partially_paid').length;

    // Income vs Expense
    const totalIncome   = payments.reduce((s, p) => s + Number((p as any).amount ?? 0), 0);
    const totalExpenses = expenses.reduce((s, e) => s + Number((e as any).net_payable ?? (e as any).amount ?? 0), 0);

    // Expense by category
    const catMap: Record<string, number> = {};
    for (const e of expenses) {
      const cat = ((e as any).expense_categories?.name) ?? 'Uncategorised';
      catMap[cat] = (catMap[cat] ?? 0) + Number((e as any).net_payable ?? (e as any).amount ?? 0);
    }
    const sortedCats = Object.entries(catMap).sort(([, a], [, b]) => b - a);
    const topCats    = sortedCats.slice(0, topN);
    const otherAmt   = sortedCats.slice(topN).reduce((s, [, v]) => s + v, 0);
    if (otherAmt > 0) topCats.push(['Other', otherAmt]);

    // Complaints
    const openComplaints     = complaints.filter((c: any) => !['resolved', 'closed'].includes(c.status)).length;
    const resolvedComplaints = complaints.filter((c: any) => ['resolved', 'closed'].includes(c.status)).length;
    const highPriorityOpen   = complaints.filter((c: any) => c.priority === 'high' && !['resolved', 'closed'].includes(c.status)).length;

    // Collection per billing period
    const periodDueMap: Record<string, { name: string; total: number; paid: number }> = {};
    for (const d of dues) {
      const pid = (d as any).billing_period_id;
      if (!pid) continue;
      if (!periodDueMap[pid]) {
        const p = periods.find((pp: any) => pp.id === pid);
        periodDueMap[pid] = { name: p?.name ?? pid, total: 0, paid: 0 };
      }
      periodDueMap[pid].total++;
      if ((d as any).status === 'paid') periodDueMap[pid].paid++;
    }
    const collectionTrend = Object.values(periodDueMap).slice(-6).map(p => ({
      period: p.name,
      rate:   p.total > 0 ? Math.round((p.paid / p.total) * 100) : 0,
    }));

    const generatedAt = new Date().toLocaleDateString('en-IN', { day: 'numeric', month: 'long', year: 'numeric' });

    // ── Build PDF ──────────────────────────────────────────────────────────
    function kpiTable(items: Array<{ label: string; value: string; sub?: string; color?: string }>): object {
      return {
        table: {
          widths: Array(items.length).fill('*'),
          body: [[
            ...items.map(k => ({
              stack: [
                { text: k.value, fontSize: 18, bold: true, color: k.color ?? BRAND, margin: [0, 0, 0, 2] },
                { text: k.label, fontSize: 9, color: GRAY },
                ...(k.sub ? [{ text: k.sub, fontSize: 8, color: k.color ?? GREEN }] : []),
              ],
              alignment: 'center',
              border: [false, false, false, false],
              fillColor: '#F8FAFC',
              margin: [8, 8, 8, 8],
            })),
          ]],
        },
        layout: {
          hLineColor: () => LGRAY,
          vLineColor: () => LGRAY,
        },
        margin: [0, 0, 0, 12],
      };
    }

    function sectionHeader(title: string): object {
      return {
        stack: [
          { canvas: [{ type: 'rect', x: 0, y: 0, w: 4, h: 14, color: BRAND }] },
          { text: title, fontSize: 12, bold: true, color: BRAND, margin: [10, -14, 0, 6], relativePosition: { x: 6, y: 0 } },
        ],
        margin: [0, 14, 0, 8],
      };
    }

    // Inline bar chart for collection rate trend (div-style via canvas)
    const barMaxWidth = 360;
    const collectionBars = collectionTrend.map(p => ({
      columns: [
        { text: p.period.slice(0, 12), fontSize: 8, color: GRAY, width: 80, noWrap: true },
        {
          canvas: [{
            type: 'rect',
            x: 0, y: 2,
            w: Math.max(2, Math.round((p.rate / 100) * barMaxWidth * 0.6)),
            h: 10,
            color: p.rate >= 80 ? GREEN : p.rate >= 50 ? AMBER : RED,
          }],
          width: barMaxWidth * 0.6 + 4,
        },
        { text: `${p.rate}%`, fontSize: 8, bold: true, color: p.rate >= 80 ? GREEN : p.rate >= 50 ? AMBER : RED, width: 35, alignment: 'right' },
      ],
      margin: [0, 2, 0, 2],
    }));

    // Expense category bars
    const expMax = topCats[0]?.[1] ?? 1;
    const expBars = topCats.map(([name, amt]) => ({
      columns: [
        { text: String(name).slice(0, 18), fontSize: 8, color: GRAY, width: 100, noWrap: true },
        {
          canvas: [{
            type: 'rect', x: 0, y: 2,
            w: Math.max(2, Math.round((Number(amt) / Number(expMax)) * 200)),
            h: 10, color: BRAND,
          }],
          width: 210,
        },
        { text: `₹${fmt2(Number(amt))}`, fontSize: 8, bold: true, color: BRAND, width: 70, alignment: 'right' },
      ],
      margin: [0, 2, 0, 2],
    }));

    const docDefinition: object = {
      pageSize: 'A4',
      pageMargins: [40, 60, 40, 60],
      footer: (currentPage: number, pageCount: number) => ({
        columns: [
          { text: `${soc.name ?? 'UTA MACS'} — Executive Summary — ${generatedAt}`, fontSize: 8, color: GRAY, margin: [40, 0, 0, 0] },
          { text: `Page ${currentPage} of ${pageCount}`, fontSize: 8, color: GRAY, alignment: 'right', margin: [0, 0, 40, 0] },
        ],
        margin: [0, 10, 0, 0],
      }),
      styles: {
        heading: { fontSize: 18, bold: true, color: BRAND },
        sub:     { fontSize: 10, color: GRAY },
        label:   { fontSize: 9, bold: true, color: '#374151' },
        value:   { fontSize: 9, color: '#111827' },
      },
      content: [
        // Header
        {
          columns: [
            {
              stack: [
                { text: soc.name ?? 'UTA MACS', style: 'heading' },
                { text: [soc.address, soc.city, soc.state].filter(Boolean).join(', '), style: 'sub' },
                { text: `Reg No: ${soc.registration_no ?? 'N/A'}  |  GSTIN: ${soc.gstin ?? 'N/A'}`, style: 'sub', margin: [0, 2, 0, 0] },
              ],
            },
            {
              stack: [
                { text: 'Executive Summary', fontSize: 13, bold: true, color: BRAND, alignment: 'right' },
                { text: `As of ${generatedAt}`, fontSize: 9, color: GRAY, alignment: 'right' },
                { text: `Period: Last ${trendMonths} months`, fontSize: 9, color: GRAY, alignment: 'right' },
              ],
              width: 180,
            },
          ],
          margin: [0, 0, 0, 16],
        },
        { canvas: [{ type: 'line', x1: 0, y1: 0, x2: 515, y2: 0, lineWidth: 1.5, lineColor: BRAND }], margin: [0, 0, 0, 14] },

        // ── Occupancy KPIs
        sectionHeader('Occupancy & Membership'),
        kpiTable([
          { label: 'Total Units',   value: String(totalUnits) },
          { label: 'Owner-Occupied', value: String(ownerUnits), sub: fmtPct(totalUnits > 0 ? Math.round((ownerUnits / totalUnits) * 100) : 0) },
          { label: 'Tenant-Occupied', value: String(tenantUnits), sub: fmtPct(totalUnits > 0 ? Math.round((tenantUnits / totalUnits) * 100) : 0) },
          { label: 'Vacant',        value: String(vacantUnits), color: vacantUnits > 0 ? AMBER : GREEN, sub: fmtPct(totalUnits > 0 ? Math.round((vacantUnits / totalUnits) * 100) : 0) },
        ]),

        // ── Finance KPIs
        sectionHeader('Finance Summary'),
        kpiTable([
          { label: 'Total Demand',    value: `₹${fmt2(totalDemand)}` },
          { label: 'Total Collected', value: `₹${fmt2(totalIncome)}`,   color: GREEN },
          { label: 'Total Expenses',  value: `₹${fmt2(totalExpenses)}`, color: RED   },
          { label: 'Net Surplus',     value: `₹${fmt2(totalIncome - totalExpenses)}`, color: totalIncome >= totalExpenses ? GREEN : RED },
        ]),
        kpiTable([
          { label: 'Collection Rate', value: fmtPct(collectionRate), color: collectionRate >= 80 ? GREEN : collectionRate >= 50 ? AMBER : RED },
          { label: 'Overdue Units',   value: String(overdueDues), color: overdueDues > 0 ? AMBER : GREEN },
          { label: 'Open Complaints', value: String(openComplaints), color: openComplaints > 0 ? AMBER : GREEN },
          { label: 'High Priority',   value: String(highPriorityOpen), color: highPriorityOpen > 0 ? RED : GREEN },
        ]),

        // ── Collection Rate Trend
        sectionHeader('Collection Rate by Billing Period'),
        collectionTrend.length > 0
          ? { stack: collectionBars }
          : { text: 'No billing period data available.', fontSize: 9, color: GRAY },

        // ── Expense Breakdown
        { text: '', pageBreak: 'before' }, // page 2
        sectionHeader('Expense Breakdown by Category'),
        topCats.length > 0
          ? {
              columns: [
                { stack: expBars, width: '*' },
                {
                  stack: [
                    { text: 'Total Expenses', fontSize: 9, color: GRAY, margin: [0, 0, 0, 2] },
                    { text: `₹${fmt2(totalExpenses)}`, fontSize: 16, bold: true, color: RED, margin: [0, 0, 0, 10] },
                    ...topCats.map(([name, amt]) => ({
                      text: `${String(name).slice(0, 18)}: ${Math.round((Number(amt) / totalExpenses) * 100)}%`,
                      fontSize: 8, color: GRAY, margin: [0, 1, 0, 1],
                    })),
                  ],
                  width: 120,
                },
              ],
            }
          : { text: 'No expense data available.', fontSize: 9, color: GRAY },

        // ── Complaints
        sectionHeader('Complaints Summary'),
        kpiTable([
          { label: 'Total Raised',   value: String(complaints.length) },
          { label: 'Resolved',       value: String(resolvedComplaints), color: GREEN },
          { label: 'Still Open',     value: String(openComplaints), color: openComplaints > 0 ? AMBER : GREEN },
          { label: 'High Priority Open', value: String(highPriorityOpen), color: highPriorityOpen > 0 ? RED : GREEN },
        ]),

        // Footer note
        { canvas: [{ type: 'line', x1: 0, y1: 0, x2: 515, y2: 0, lineWidth: 0.5, lineColor: LGRAY }], margin: [0, 20, 0, 8] },
        { text: 'This report is auto-generated from portal data. For queries, contact the society treasurer or secretary.', fontSize: 8, color: GRAY, alignment: 'center' },
      ],
    };

    const fonts = {
      Helvetica: {
        normal: 'Helvetica', bold: 'Helvetica-Bold',
        italics: 'Helvetica-Oblique', bolditalics: 'Helvetica-BoldOblique',
      },
    };

    const printer = new PdfPrinter(fonts);
    const pdfDoc  = printer.createPdfKitDocument(docDefinition as any);
    const chunks: Buffer[] = [];

    await new Promise<void>((resolve, reject) => {
      pdfDoc.on('data', (c: Buffer) => chunks.push(c));
      pdfDoc.on('end', resolve);
      pdfDoc.on('error', reject);
      pdfDoc.end();
    });

    const pdfBuffer = Buffer.concat(chunks);

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'EXPORT', resourceType: 'executive_report', resourceId: SOCIETY_ID,
      ip: extractClientIP(request),
      newValues: { trend_months: trendMonths, generated_at: new Date().toISOString() },
    });

    const filename = `Executive-Summary-${new Date().toISOString().slice(0, 10)}.pdf`;
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
