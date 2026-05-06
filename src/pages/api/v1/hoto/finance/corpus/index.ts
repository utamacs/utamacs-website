export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list corpus fund records + current balance (auth: finance.view)
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'finance.view');

    const url = new URL(request.url);
    const transactionType = url.searchParams.get('transaction_type') ?? '';
    const limit = Math.min(Number(url.searchParams.get('limit') ?? '100'), 500);

    const sb = getSupabaseServiceClient();

    let query = sb
      .from('corpus_fund_records')
      .select('*')
      .eq('society_id', SOCIETY_ID)
      .order('date', { ascending: false })
      .limit(limit);

    if (transactionType) query = query.eq('transaction_type', transactionType);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Calculate balance from records (mirrors get_corpus_balance DB function)
    const balance = (data ?? []).reduce((sum, r) => {
      const amt = Number(r.amount);
      return r.transaction_type === 'APPROVED_USE' ? sum - amt : sum + amt;
    }, 0);

    return Response.json({ balance, records: data ?? [] });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — add a corpus fund record (auth: finance.enter)
// Treasurer (or finance.enter) can add RECEIVED_FROM_BUILDER and INTEREST_EARNED.
// APPROVED_USE is created by the board vote flow (finance/expenses), never directly here.
// Body: { transaction_type, amount, description?, date, payment_mode?, reference_number? }
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'finance.enter');

    const body = await request.json() as {
      transaction_type?: string;
      amount?: number;
      description?: string;
      date?: string;
      payment_mode?: string;
      reference_number?: string;
    };

    const ALLOWED_TYPES = ['RECEIVED_FROM_BUILDER', 'INTEREST_EARNED'];

    if (!body.transaction_type || !ALLOWED_TYPES.includes(body.transaction_type)) {
      return Response.json({
        error: 'VALIDATION_ERROR',
        message: `transaction_type must be one of: ${ALLOWED_TYPES.join(', ')}. APPROVED_USE is created via the expense approval flow.`,
      }, { status: 400 });
    }
    if (!body.amount || body.amount <= 0) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'amount must be a positive number' }, { status: 400 });
    }
    if (!body.date) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'date is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data, error } = await sb.from('corpus_fund_records').insert({
      society_id: SOCIETY_ID,
      transaction_type: body.transaction_type,
      amount: body.amount,
      description: body.description?.trim() ?? null,
      date: body.date,
      payment_mode: body.payment_mode?.trim() ?? null,
      reference_number: body.reference_number?.trim() ?? null,
      approved_by: user.id,
    }).select().single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await Promise.all([
      sb.from('hoto_audit_log').insert({
        society_id: SOCIETY_ID,
        actor_id: user.id,
        action: 'CREATE',
        resource_type: 'corpus_fund_records',
        resource_id: (data as any).id,
        new_values: { transaction_type: body.transaction_type, amount: body.amount, date: body.date },
      }),
      writeAuditLog({
        societyId: SOCIETY_ID, userId: user.id,
        action: 'CREATE', resourceType: 'corpus_fund_records', resourceId: (data as any).id,
        ip: extractClientIP(request),
        newValues: { transaction_type: body.transaction_type, amount: body.amount },
      }),
    ]);

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
