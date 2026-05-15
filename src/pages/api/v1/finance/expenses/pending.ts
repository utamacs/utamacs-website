export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleStr } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

function requireExec(user: any) {
  return user.isAdmin ||
    ['executive', 'secretary', 'president'].includes(user.portalRole ?? '') ||
    ['executive', 'admin'].includes(user.role ?? '');
}

// GET /api/v1/finance/expenses/pending
// Returns pending-approval expenses the requesting exec is authorised to approve
// based on the EXPENSE_APPROVAL_CHAIN_* rules and their portal role.
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!requireExec(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, [
      'EXPENSE_APPROVAL_CHAIN_10K',
      'EXPENSE_APPROVAL_CHAIN_20K',
      'EXPENSE_APPROVAL_CHAIN_50K',
    ]);

    const role10k = ruleStr(rules, 'EXPENSE_APPROVAL_CHAIN_10K', 'secretary');
    const role20k = ruleStr(rules, 'EXPENSE_APPROVAL_CHAIN_20K', 'president');
    const role50k = ruleStr(rules, 'EXPENSE_APPROVAL_CHAIN_50K', 'president');

    const portalRole = user.portalRole ?? '';

    // Determine which amount bands this user can approve
    const canApprove10k = [role10k, role20k, role50k].includes(portalRole) || user.isAdmin;
    const canApprove20k = [role20k, role50k].includes(portalRole) || user.isAdmin;
    const canApprove50k = [role50k].includes(portalRole) || user.isAdmin;

    // Build a condition for amounts this user can approve
    // All execs can at least see pending expenses (for awareness); approval gated client-side
    const { data, error } = await sb
      .from('expenses')
      .select(`
        id, description, amount, gst_amount, tds_deducted, net_payable,
        bill_number, bill_date, payment_date, approval_status, approval_tier,
        created_at, created_by,
        expense_categories(id, name),
        vendors(id, name)
      `)
      .eq('society_id', SOCIETY_ID)
      .eq('approval_status', 'pending')
      .order('created_at', { ascending: true });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Tag each expense with whether this user is authorised to action it
    const expenses = (data ?? []).map((e: any) => {
      const amt = Number(e.amount);
      let canAction = false;
      if (amt < 10_000) canAction = true; // any exec can approve small expenses
      else if (amt < 20_000) canAction = canApprove10k;
      else if (amt < 50_000) canAction = canApprove20k;
      else canAction = canApprove50k;
      return { ...e, can_action: canAction };
    });

    return Response.json({
      expenses,
      approval_roles: { role_10k: role10k, role_20k: role20k, role_50k: role50k },
      user_role: portalRole,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
