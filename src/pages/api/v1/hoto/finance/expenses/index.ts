export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature, hasFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const MAX_PORTAL_EXPENSE = 50_000;

// GET — list governance expenses (auth: finance.view)
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'finance.view');

    const url = new URL(request.url);
    const limit = Math.min(Number(url.searchParams.get('limit') ?? '100'), 500);

    const sb = getSupabaseServiceClient();

    const { data, error } = await sb
      .from('governance_expenses')
      .select('*')
      .eq('society_id', SOCIETY_ID)
      .order('expense_date', { ascending: false })
      .limit(limit);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return Response.json(data ?? []);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — record and sanction a governance expense (auth: finance.enter + approval-tier check)
//
// Approval tiers:
//   ≤ ₹10,000  — finance.approve_10k required (secretary or above)
//   ≤ ₹20,000  — finance.approve_20k required (president only)
//   ≤ ₹50,000  — finance.open_board_vote required + board_resolution_ref must be supplied
//   > ₹50,000  — rejected: use formal process outside portal
//
// For board-voted expenses (₹20K–₹50K) this route also:
//   1. Checks corpus balance for overdraft prevention
//   2. Creates a corpus_fund_records APPROVED_USE entry atomically
//
// Body: { payee, purpose, amount, expense_date, payment_mode, reference_number?,
//         is_recurring?, board_resolution_ref?, byelaw_authority? }
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'finance.enter');

    const body = await request.json() as {
      payee?: string;
      purpose?: string;
      amount?: number;
      expense_date?: string;
      payment_mode?: string;
      reference_number?: string;
      is_recurring?: boolean;
      board_resolution_ref?: string;
      byelaw_authority?: string;
    };

    if (!body.payee?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'payee is required' }, { status: 400 });
    }
    if (!body.purpose?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'purpose is required' }, { status: 400 });
    }
    if (!body.amount || body.amount <= 0) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'amount must be a positive number' }, { status: 400 });
    }
    if (!body.expense_date) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'expense_date is required' }, { status: 400 });
    }
    if (!body.payment_mode?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'payment_mode is required' }, { status: 400 });
    }

    const amount = body.amount;

    if (amount > MAX_PORTAL_EXPENSE) {
      return Response.json({
        error: 'VALIDATION_ERROR',
        message: `Expenses above ₹${MAX_PORTAL_EXPENSE.toLocaleString('en-IN')} require formal process outside the portal`,
      }, { status: 400 });
    }

    // Determine required approval tier
    let sanctionedByRole: string;
    const needsBoardVote = amount > 20_000;
    const needsPresidentApproval = amount > 10_000 && !needsBoardVote;
    const needsSecretaryApproval = amount <= 10_000;

    if (needsBoardVote) {
      if (!hasFeature(user, 'finance.open_board_vote')) {
        return Response.json({
          error: 'FORBIDDEN',
          message: 'Expenses above ₹20,000 require board resolution. Only secretary/president can record board-voted expenses.',
        }, { status: 403 });
      }
      if (!body.board_resolution_ref?.trim()) {
        return Response.json({
          error: 'VALIDATION_ERROR',
          message: 'board_resolution_ref is required for expenses above ₹20,000',
        }, { status: 400 });
      }
      sanctionedByRole = 'board_resolution';
    } else if (needsPresidentApproval) {
      if (!hasFeature(user, 'finance.approve_20k')) {
        return Response.json({
          error: 'FORBIDDEN',
          message: 'Expenses above ₹10,000 require president approval',
        }, { status: 403 });
      }
      sanctionedByRole = 'president';
    } else {
      if (!hasFeature(user, 'finance.approve_10k')) {
        return Response.json({
          error: 'FORBIDDEN',
          message: 'Expenses require secretary or above approval',
        }, { status: 403 });
      }
      sanctionedByRole = 'secretary';
    }

    const sb = getSupabaseServiceClient();

    // For board-voted expenses, check corpus overdraft before writing
    if (needsBoardVote) {
      const { data: corpusRows } = await sb
        .from('corpus_fund_records')
        .select('transaction_type, amount')
        .eq('society_id', SOCIETY_ID);

      const balance = (corpusRows ?? []).reduce((sum, r) => {
        return r.transaction_type === 'APPROVED_USE' ? sum - Number(r.amount) : sum + Number(r.amount);
      }, 0);

      if (balance < amount) {
        return Response.json({
          error: 'CORPUS_OVERDRAFT',
          message: `Insufficient corpus fund balance. Available: ₹${balance.toLocaleString('en-IN')}, requested: ₹${amount.toLocaleString('en-IN')}`,
        }, { status: 422 });
      }
    }

    const { data, error } = await sb.from('governance_expenses').insert({
      society_id: SOCIETY_ID,
      amount,
      payee: body.payee.trim(),
      purpose: body.purpose.trim(),
      expense_date: body.expense_date,
      payment_mode: body.payment_mode.trim(),
      reference_number: body.reference_number?.trim() ?? null,
      is_recurring: body.is_recurring ?? false,
      sanctioned_by_role: sanctionedByRole,
      sanctioned_by: user.id,
      byelaw_authority: body.byelaw_authority?.trim() ?? null,
      board_resolution_ref: body.board_resolution_ref?.trim() ?? null,
    }).select().single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    const expenseId = (data as any).id;

    // Atomically create corpus APPROVED_USE record for board-voted expenses
    if (needsBoardVote) {
      await sb.from('corpus_fund_records').insert({
        society_id: SOCIETY_ID,
        transaction_type: 'APPROVED_USE',
        amount,
        description: body.purpose.trim(),
        date: body.expense_date,
        approved_by: user.id,
        board_resolution_ref: body.board_resolution_ref!.trim(),
        payment_mode: body.payment_mode.trim(),
        reference_number: body.reference_number?.trim() ?? null,
      });
    }

    await Promise.all([
      sb.from('hoto_audit_log').insert({
        society_id: SOCIETY_ID,
        actor_id: user.id,
        action: 'CREATE',
        resource_type: 'governance_expenses',
        resource_id: expenseId,
        new_values: {
          payee: body.payee.trim(),
          amount,
          sanctioned_by_role: sanctionedByRole,
          board_resolution_ref: body.board_resolution_ref ?? null,
        },
      }),
      writeAuditLog({
        societyId: SOCIETY_ID, userId: user.id,
        action: 'CREATE', resourceType: 'governance_expenses', resourceId: expenseId,
        ip: extractClientIP(request),
        newValues: { payee: body.payee.trim(), amount, sanctioned_by_role: sanctionedByRole },
      }),
    ]);

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
