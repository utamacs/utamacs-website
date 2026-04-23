import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      return new Response(JSON.stringify({ error: 'Forbidden' }), {
        status: 403, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();

    const [
      complaintsRes,
      duesRes,
      eventsRes,
      visitorsRes,
      membersRes,
      pollsRes,
    ] = await Promise.all([
      sb.from('complaints').select('status, priority, created_at').eq('society_id', SOCIETY_ID),
      sb.from('maintenance_dues').select('status, total_amount, base_amount').eq('society_id', SOCIETY_ID),
      sb.from('events').select('id, title, starts_at, is_published').eq('society_id', SOCIETY_ID).eq('is_published', true).order('starts_at', { ascending: false }).limit(10),
      sb.from('visitor_logs').select('entry_type, entry_time, exit_time').eq('society_id', SOCIETY_ID).gte('entry_time', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString()),
      sb.from('profiles').select('residency_type, is_active').eq('society_id', SOCIETY_ID).eq('is_active', true),
      sb.from('polls').select('id, status, ends_at').eq('society_id', SOCIETY_ID),
    ]);

    const complaints = complaintsRes.data ?? [];
    const dues = duesRes.data ?? [];
    const visitors = visitorsRes.data ?? [];
    const members = membersRes.data ?? [];

    // Complaint breakdown by status
    const complaintsByStatus = complaints.reduce((acc: Record<string, number>, c: any) => {
      acc[c.status] = (acc[c.status] ?? 0) + 1;
      return acc;
    }, {});

    // Complaint aging by priority
    const now = Date.now();
    const aging = complaints
      .filter((c: any) => !['Resolved', 'Closed'].includes(c.status))
      .reduce((acc: Record<string, number>, c: any) => {
        const days = Math.floor((now - new Date(c.created_at).getTime()) / 86400000);
        const bucket = days <= 3 ? '0-3d' : days <= 7 ? '4-7d' : days <= 14 ? '8-14d' : '14d+';
        acc[c.priority] = acc[c.priority] ?? 0;
        acc[`${bucket}_${c.priority}`] = (acc[`${bucket}_${c.priority}`] ?? 0) + 1;
        return acc;
      }, {});

    // Finance summary
    const totalDues = dues.reduce((s: number, d: any) => s + (d.total_amount ?? d.base_amount ?? 0), 0);
    const paidDues = dues.filter((d: any) => d.status === 'paid').reduce((s: number, d: any) => s + (d.total_amount ?? d.base_amount ?? 0), 0);
    const pendingDues = dues.filter((d: any) => ['pending', 'overdue'].includes(d.status)).reduce((s: number, d: any) => s + (d.total_amount ?? d.base_amount ?? 0), 0);
    const collectionRate = totalDues > 0 ? Math.round((paidDues / totalDues) * 100) : 0;

    // Visitor stats (last 30 days)
    const visitorsByType = visitors.reduce((acc: Record<string, number>, v: any) => {
      acc[v.entry_type] = (acc[v.entry_type] ?? 0) + 1;
      return acc;
    }, {});

    // Daily visitor trend (last 14 days)
    const visitorTrend: Record<string, number> = {};
    for (let i = 13; i >= 0; i--) {
      const d = new Date(Date.now() - i * 86400000).toISOString().split('T')[0];
      visitorTrend[d] = 0;
    }
    visitors.forEach((v: any) => {
      const d = new Date(v.entry_time).toISOString().split('T')[0];
      if (d in visitorTrend) visitorTrend[d]++;
    });

    return new Response(JSON.stringify({
      complaints: {
        total: complaints.length,
        open: complaints.filter((c: any) => !['Resolved', 'Closed'].includes(c.status)).length,
        by_status: complaintsByStatus,
        aging,
      },
      finance: {
        total_dues: Math.round(totalDues),
        paid: Math.round(paidDues),
        pending: Math.round(pendingDues),
        collection_rate: collectionRate,
        by_status: dues.reduce((acc: Record<string, number>, d: any) => {
          acc[d.status] = (acc[d.status] ?? 0) + 1;
          return acc;
        }, {}),
      },
      visitors: {
        last_30d: visitors.length,
        by_type: visitorsByType,
        daily_trend: Object.entries(visitorTrend).map(([date, count]) => ({ date, count })),
      },
      members: {
        total: members.length,
        owners: members.filter((m: any) => m.residency_type === 'owner').length,
        tenants: members.filter((m: any) => m.residency_type === 'tenant').length,
      },
    }), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
