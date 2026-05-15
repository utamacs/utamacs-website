export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getRules, ruleStr } from '@lib/utils/getRules';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// POST /api/v1/finance/expenses/:id/decision
// Body: { decision: 'approved' | 'rejected', notes?: string }
// Applies an approval or rejection to an expense, enforcing amount-tier rules.
export const POST: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isExec = user.isAdmin ||
      ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') ||
      ['executive', 'admin'].includes(user.role ?? '');
    if (!isExec) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const expenseId = params.id ?? '';
    if (!UUID_RE.test(expenseId)) return Response.json({ error: 'VALIDATION', message: 'invalid expense id' }, { status: 400 });

    const body = await request.json() as { decision?: string; notes?: string };
    if (!['approved', 'rejected'].includes(body.decision ?? '')) {
      return Response.json({ error: 'VALIDATION', message: 'decision must be approved or rejected' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: expense, error: expErr } = await sb
      .from('expenses')
      .select('id, amount, approval_status, approval_tier, description, created_by')
      .eq('id', expenseId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (expErr || !expense) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });
    if (expense.approval_status !== 'pending') {
      return Response.json({ error: 'CONFLICT', message: `Expense already ${expense.approval_status}` }, { status: 409 });
    }

    // Enforce amount-tier access control
    const rules = await getRules(sb, SOCIETY_ID, [
      'EXPENSE_APPROVAL_CHAIN_10K',
      'EXPENSE_APPROVAL_CHAIN_20K',
      'EXPENSE_APPROVAL_CHAIN_50K',
    ]);
    const role10k = ruleStr(rules, 'EXPENSE_APPROVAL_CHAIN_10K', 'secretary');
    const role20k = ruleStr(rules, 'EXPENSE_APPROVAL_CHAIN_20K', 'president');
    const role50k = ruleStr(rules, 'EXPENSE_APPROVAL_CHAIN_50K', 'president');

    const amt = Number(expense.amount);
    const portalRole = user.portalRole ?? '';
    let tier = 1;
    let requiredRole: string;

    if (amt < 10_000)       { requiredRole = 'executive'; tier = 1; }
    else if (amt < 20_000)  { requiredRole = role10k;      tier = 2; }
    else if (amt < 50_000)  { requiredRole = role20k;      tier = 3; }
    else                    { requiredRole = role50k;      tier = 4; }

    // Check if current user has sufficient role
    const roleHierarchy: Record<string, number> = {
      executive: 1, secretary: 2, president: 3,
    };
    const userLevel   = roleHierarchy[portalRole] ?? (user.isAdmin ? 99 : 0);
    const neededLevel = roleHierarchy[requiredRole] ?? 1;

    if (!user.isAdmin && userLevel < neededLevel) {
      return Response.json({
        error: 'FORBIDDEN',
        message: `Expenses ≥ ₹${amt < 20_000 ? '10,000' : amt < 50_000 ? '20,000' : '50,000'} require ${requiredRole} role`,
      }, { status: 403 });
    }

    const decision = body.decision as 'approved' | 'rejected';
    const notes    = String(body.notes ?? '').trim() || null;

    // Write approval record (immutable audit trail)
    await sb.from('expense_approvals').insert({
      society_id:  SOCIETY_ID,
      expense_id:  expenseId,
      approver_id: user.id,
      decision,
      tier,
      notes,
    });

    // Update expense status
    const updatePayload: Record<string, unknown> = {
      approval_status: decision,
      approval_tier:   tier,
      approved_by:     user.id,
    };
    if (decision === 'rejected') updatePayload.rejection_notes = notes;

    await sb.from('expenses')
      .update(updatePayload)
      .eq('id', expenseId)
      .eq('society_id', SOCIETY_ID);

    // Notify the submitter (non-fatal)
    if (expense.created_by) {
      // fire-and-forget, non-fatal
      void sb.from('notifications').insert({
        society_id:      SOCIETY_ID,
        user_id:         expense.created_by,
        title:           `Expense ${decision}`,
        body:            `Your expense "${expense.description}" (₹${amt.toLocaleString('en-IN')}) has been ${decision}${notes ? `: ${notes}` : '.'}`,
        type:            'finance',
        reference_table: 'expenses',
        reference_id:    expenseId,
        is_read:         false,
      });
    }

    await writeAuditLog({
      societyId:    SOCIETY_ID,
      userId:       user.id,
      action:       decision === 'approved' ? 'APPROVE' : 'REJECT',
      resourceType: 'expenses',
      resourceId:   expenseId,
      ip:           extractClientIP(request),
      newValues:    { decision, tier, notes, amount: amt },
    });

    return Response.json({ ok: true, decision, tier, expense_id: expenseId });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
