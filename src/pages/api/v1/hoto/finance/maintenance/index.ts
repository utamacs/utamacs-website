export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list maintenance records (auth: finance.view)
// Query: flat_number, period_year, period_month, limit (default 200)
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'finance.view');

    const url = new URL(request.url);
    const flatNumber  = url.searchParams.get('flat_number')   ?? '';
    const periodYear  = url.searchParams.get('period_year')   ?? '';
    const periodMonth = url.searchParams.get('period_month')  ?? '';
    const limit       = Math.min(Number(url.searchParams.get('limit') ?? '200'), 1000);

    const sb = getSupabaseServiceClient();

    let query = sb
      .from('maintenance_records')
      .select('*')
      .eq('society_id', SOCIETY_ID)
      .order('period_year', { ascending: false })
      .order('period_month', { ascending: false })
      .limit(limit);

    if (flatNumber)  query = query.eq('flat_number', flatNumber);
    if (periodYear)  query = query.eq('period_year', Number(periodYear));
    if (periodMonth) query = query.eq('period_month', Number(periodMonth));

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — enter a maintenance record (auth: finance.enter)
// Body: { flat_number, amount, period_month, period_year, paid_date?, payment_mode?, reference_number? }
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'finance.enter');

    const body = await request.json() as {
      flat_number?: string;
      amount?: number;
      period_month?: number;
      period_year?: number;
      paid_date?: string;
      payment_mode?: string;
      reference_number?: string;
    };

    if (!body.flat_number?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'flat_number is required' }, { status: 400 });
    }
    if (!body.amount || body.amount <= 0) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'amount must be a positive number' }, { status: 400 });
    }
    if (!body.period_month || body.period_month < 1 || body.period_month > 12) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'period_month must be 1–12' }, { status: 400 });
    }
    if (!body.period_year || body.period_year < 2000) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'period_year is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data, error } = await sb.from('maintenance_records').insert({
      society_id: SOCIETY_ID,
      flat_number: body.flat_number.trim(),
      amount: body.amount,
      period_month: body.period_month,
      period_year: body.period_year,
      paid_date: body.paid_date ?? null,
      payment_mode: body.payment_mode?.trim() ?? null,
      reference_number: body.reference_number?.trim() ?? null,
      recorded_by: user.id,
    }).select().single();

    if (error) {
      if (error.code === '23505') {
        return Response.json({
          error: 'CONFLICT',
          message: `Maintenance record already exists for flat ${body.flat_number} — ${body.period_month}/${body.period_year}`,
        }, { status: 409 });
      }
      throw Object.assign(new Error(error.message), { status: 500 });
    }

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'maintenance_records', resourceId: (data as any).id,
      ip: extractClientIP(request),
      newValues: { flat_number: body.flat_number, period_year: body.period_year, period_month: body.period_month, amount: body.amount },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
