export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list expenses (finance.view feature required)
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'finance.view');

    const sb = getSupabaseServiceClient();

    const from    = url.searchParams.get('from') ?? '';
    const to      = url.searchParams.get('to') ?? '';
    const catId   = url.searchParams.get('category_id') ?? '';
    const limit   = Math.min(parseInt(url.searchParams.get('limit') ?? '50'), 100);
    const offset  = Math.max(0, parseInt(url.searchParams.get('offset') ?? '0'));

    let query = sb
      .from('expenses')
      .select(`
        id, description, amount, gst_amount, tds_deducted, net_payable,
        bill_number, bill_date, payment_date, receipt_storage_key, created_at,
        expense_categories(id, name),
        vendors(id, name, pan)
      `)
      .eq('society_id', SOCIETY_ID)
      .order('payment_date', { ascending: false })
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    if (from) query = query.gte('payment_date', from);
    if (to)   query = query.lte('payment_date', to);
    if (catId && UUID_RE.test(catId)) query = query.eq('category_id', catId);

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — record a new expense (finance.enter feature required)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'finance.enter');

    const body = await request.json() as Record<string, unknown>;
    const {
      description, amount, gst_amount, tds_deducted,
      bill_number, bill_date, payment_date,
      category_id, vendor_id,
    } = body;

    if (!description || typeof description !== 'string' || !description.trim()) {
      return Response.json({ error: 'VALIDATION', message: 'description is required' }, { status: 400 });
    }
    const parsedAmount = parseFloat(String(amount));
    if (isNaN(parsedAmount) || parsedAmount <= 0) {
      return Response.json({ error: 'VALIDATION', message: 'amount must be a positive number' }, { status: 400 });
    }
    if (category_id && !UUID_RE.test(String(category_id))) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid category_id' }, { status: 400 });
    }
    if (vendor_id && !UUID_RE.test(String(vendor_id))) {
      return Response.json({ error: 'VALIDATION', message: 'Invalid vendor_id' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('expenses')
      .insert({
        society_id:    SOCIETY_ID,
        description:   sanitizePlainText(String(description)).trim().slice(0, 500),
        amount:        parsedAmount,
        gst_amount:    parseFloat(String(gst_amount ?? 0)) || 0,
        tds_deducted:  parseFloat(String(tds_deducted ?? 0)) || 0,
        bill_number:   bill_number ? sanitizePlainText(String(bill_number)).trim().slice(0, 100) : null,
        bill_date:     bill_date ? String(bill_date) : null,
        payment_date:  payment_date ? String(payment_date) : null,
        category_id:   category_id ? String(category_id) : null,
        vendor_id:     vendor_id ? String(vendor_id) : null,
        created_by:    user.id,
      })
      .select(`
        id, description, amount, gst_amount, tds_deducted, net_payable,
        bill_number, bill_date, payment_date, created_at,
        expense_categories(id, name),
        vendors(id, name)
      `)
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'expense', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { description: String(description), amount: parsedAmount, payment_date },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// PATCH — update an expense (finance.enter feature required)
export const PATCH: APIRoute = async ({ request, url }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    requireFeature(user, 'finance.enter');

    const id = url.searchParams.get('id') ?? '';
    if (!UUID_RE.test(id)) {
      return Response.json({ error: 'VALIDATION', message: 'Valid expense id required' }, { status: 400 });
    }

    const body = await request.json() as Record<string, unknown>;
    const sb = getSupabaseServiceClient();

    const { data: existing } = await sb
      .from('expenses')
      .select('id, amount')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!existing) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const updates: Record<string, unknown> = {};
    if (body.description !== undefined) updates.description = sanitizePlainText(String(body.description)).trim().slice(0, 500);
    if (body.amount !== undefined) updates.amount = parseFloat(String(body.amount));
    if (body.gst_amount !== undefined) updates.gst_amount = parseFloat(String(body.gst_amount)) || 0;
    if (body.tds_deducted !== undefined) updates.tds_deducted = parseFloat(String(body.tds_deducted)) || 0;
    if (body.bill_number !== undefined) updates.bill_number = body.bill_number ? sanitizePlainText(String(body.bill_number)).trim().slice(0, 100) : null;
    if (body.bill_date !== undefined) updates.bill_date = body.bill_date || null;
    if (body.payment_date !== undefined) updates.payment_date = body.payment_date || null;
    if (body.category_id !== undefined) updates.category_id = body.category_id && UUID_RE.test(String(body.category_id)) ? String(body.category_id) : null;
    if (body.vendor_id !== undefined) updates.vendor_id = body.vendor_id && UUID_RE.test(String(body.vendor_id)) ? String(body.vendor_id) : null;

    if (!Object.keys(updates).length) {
      return Response.json({ error: 'VALIDATION', message: 'No valid fields to update' }, { status: 400 });
    }

    const { data, error } = await sb
      .from('expenses')
      .update(updates)
      .eq('id', id)
      .select('id, description, amount, gst_amount, tds_deducted, net_payable, bill_number, payment_date')
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: 'expense', resourceId: id,
      ip: extractClientIP(request),
      oldValues: { amount: existing.amount },
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
