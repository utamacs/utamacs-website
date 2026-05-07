export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { SupabaseStorageService } from '@lib/services/providers/supabase/SupabaseStorageService';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import PdfPrinter from 'pdfmake';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// GET /api/v1/polls/:id/export
// Returns a signed URL to a generated PDF of poll results (polls.manage feature required)
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'polls.manage');

    const pollId = params.id ?? '';
    if (!UUID_RE.test(pollId)) return Response.json({ error: 'VALIDATION', message: 'Invalid poll id' }, { status: 400 });

    const sb = getSupabaseServiceClient();

    // Fetch poll
    const { data: poll, error: pollErr } = await sb
      .from('polls')
      .select('id, title, description, poll_type, is_anonymous, one_vote_per_unit, starts_at, ends_at, is_published, created_at, poll_options(id, option_text, order_index)')
      .eq('id', pollId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (pollErr || !poll) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    // Fetch vote counts per option
    const { data: votes } = await sb
      .from('poll_votes')
      .select('option_id')
      .eq('poll_id', pollId);

    const voteTotals: Record<string, number> = {};
    for (const v of votes ?? []) {
      voteTotals[v.option_id] = (voteTotals[v.option_id] ?? 0) + 1;
    }
    const totalVotes = (votes ?? []).length;

    const options = (poll.poll_options ?? []).sort((a: any, b: any) => a.order_index - b.order_index);

    // Build PDF document definition
    const now = new Date().toLocaleString('en-IN', { dateStyle: 'long', timeStyle: 'short' });
    const endedAt = poll.ends_at
      ? new Date(poll.ends_at).toLocaleDateString('en-IN', { dateStyle: 'long' })
      : 'Ongoing';

    const tableBody: any[] = [
      [
        { text: 'Option', style: 'tableHeader' },
        { text: 'Votes', style: 'tableHeader', alignment: 'center' },
        { text: '%', style: 'tableHeader', alignment: 'center' },
      ],
      ...options.map((opt: any) => {
        const count = voteTotals[opt.id] ?? 0;
        const pct = totalVotes > 0 ? ((count / totalVotes) * 100).toFixed(1) : '0.0';
        return [
          { text: opt.option_text },
          { text: String(count), alignment: 'center' },
          { text: `${pct}%`, alignment: 'center' },
        ];
      }),
      [
        { text: 'Total', bold: true },
        { text: String(totalVotes), alignment: 'center', bold: true },
        { text: '100%', alignment: 'center', bold: true },
      ],
    ];

    const docDefinition: any = {
      pageSize: 'A4',
      pageMargins: [40, 60, 40, 60],
      styles: {
        header: { fontSize: 18, bold: true, color: '#1E3A8A', marginBottom: 6 },
        subheader: { fontSize: 12, color: '#4B5563', marginBottom: 16 },
        sectionTitle: { fontSize: 11, bold: true, color: '#111827', marginTop: 16, marginBottom: 6 },
        tableHeader: { bold: true, fillColor: '#F0F4FF', color: '#1E3A8A', fontSize: 10 },
        footer: { fontSize: 8, color: '#9CA3AF', italics: true },
      },
      content: [
        { text: 'UTAMACS Resident Portal', style: 'footer', marginBottom: 4 },
        { text: poll.title, style: 'header' },
        poll.description ? { text: poll.description, style: 'subheader' } : {},
        {
          columns: [
            { text: `Type: ${poll.poll_type.replace('_', ' ')}`, fontSize: 9, color: '#6B7280' },
            { text: `Ends: ${endedAt}`, fontSize: 9, color: '#6B7280', alignment: 'center' },
            { text: `Anonymous: ${poll.is_anonymous ? 'Yes' : 'No'}`, fontSize: 9, color: '#6B7280', alignment: 'right' },
          ],
          marginBottom: 20,
        },
        { text: 'Results', style: 'sectionTitle' },
        {
          table: {
            headerRows: 1,
            widths: ['*', 60, 60],
            body: tableBody,
          },
          layout: {
            hLineWidth: (i: number) => i === 0 || i === 1 ? 1.5 : 0.5,
            vLineWidth: () => 0,
            hLineColor: () => '#E5E7EB',
            paddingLeft: () => 8,
            paddingRight: () => 8,
            paddingTop: () => 6,
            paddingBottom: () => 6,
          },
          marginBottom: 20,
        },
        { text: `Total responses: ${totalVotes}`, fontSize: 10, color: '#374151', marginBottom: 4 },
        { text: `Exported by: ${user.portalRole} on ${now}`, style: 'footer' },
      ],
    };

    // pdfmake with built-in fonts only (no file-system font paths needed in server)
    const printer = new PdfPrinter({
      Roboto: {
        normal: Buffer.from([]),
        bold: Buffer.from([]),
        italics: Buffer.from([]),
        bolditalics: Buffer.from([]),
      },
    });

    const doc = printer.createPdfKitDocument(docDefinition, { fonts: { Roboto: { normal: 'Helvetica', bold: 'Helvetica-Bold', italics: 'Helvetica-Oblique', bolditalics: 'Helvetica-BoldOblique' } } });

    const chunks: Buffer[] = [];
    await new Promise<void>((resolve, reject) => {
      doc.on('data', (chunk: Buffer) => chunks.push(chunk));
      doc.on('end', resolve);
      doc.on('error', reject);
      doc.end();
    });

    const pdfBuffer = Buffer.concat(chunks);
    const key = `poll-exports/${SOCIETY_ID}/${pollId}/${crypto.randomUUID()}.pdf`;

    const storage = new SupabaseStorageService();
    await storage.upload('poll-exports', key, pdfBuffer, 'application/pdf');
    const signed_url = await storage.getSignedUrl('poll-exports', key, 3600);

    await writeAuditLog({
      userId: user.id, societyId: SOCIETY_ID,
      action: 'EXPORT', resourceType: 'poll_results', resourceId: pollId,
      ip: extractClientIP(request),
      newValues: { export_key: key },
    });

    return Response.json({ signed_url, total_votes: totalVotes, expires_in: 3600 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
