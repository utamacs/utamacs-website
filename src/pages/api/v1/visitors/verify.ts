export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/visitors/verify?token={pass_token}  OR  ?otp_code={6-digit}
// Public lookup — returns pass status without side effects (preview before guard admits).
export const GET: APIRoute = async ({ request }) => {
  try {
    const url = new URL(request.url);
    const token    = url.searchParams.get('token');
    const otpCode  = url.searchParams.get('otp_code');

    if (!token && !otpCode) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'token or otp_code is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const now = new Date();
    const rules = await getRules(sb, SOCIETY_ID, ['VISITOR_PASS_OTP_WINDOW_MINS']);
    const windowMins = ruleInt(rules, 'VISITOR_PASS_OTP_WINDOW_MINS', 30);

    let query = sb
      .from('visitor_pre_approvals')
      .select('id, visitor_name, purpose, expected_time_from, expected_time_to, expires_at, status, otp_code, scan_count, max_uses, guard_note, vehicle_number, units(unit_number, block), profiles!host_user_id(display_name)')
      .eq('society_id', SOCIETY_ID);

    if (token) {
      query = query.eq('pass_token', token);
    } else {
      // OTP lookup: approved, not yet expired, within time window
      query = query
        .eq('otp_code', otpCode!.trim())
        .eq('status', 'approved')
        .gte('expires_at', now.toISOString())
        .or(`expected_time_from.is.null,expected_time_from.lte.${new Date(now.getTime() + windowMins * 60000).toISOString()}`);
    }

    const { data: pass, error } = await query.single();

    if (error || !pass) {
      return Response.json({ error: 'NOT_FOUND', message: 'Pass not found or has been cancelled' }, { status: 404 });
    }

    const validUntil = new Date(pass.expires_at);
    const validFrom  = pass.expected_time_from ? new Date(pass.expected_time_from) : null;
    const isExpired  = validUntil < now;
    const notYetValid = validFrom ? validFrom > now : false;
    const maxedOut   = pass.scan_count >= pass.max_uses;

    return Response.json({
      id:           pass.id,
      visitor_name: pass.visitor_name,
      purpose:      pass.purpose,
      valid_from:   pass.expected_time_from,
      valid_until:  pass.expires_at,
      status:       pass.status,
      scan_count:   pass.scan_count,
      max_uses:     pass.max_uses,
      guard_note:   pass.guard_note,
      vehicle_number: pass.vehicle_number,
      unit:         pass.units,
      host:         pass.profiles,
      is_valid:     !isExpired && !notYetValid && !maxedOut && pass.status === 'approved',
      is_expired:   isExpired,
      not_yet_valid: notYetValid,
      maxed_out:    maxedOut,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST /api/v1/visitors/verify — guard records a successful gate entry
// Body: { pass_token?, otp_code?, action: 'entry' | 'exit' }
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const body = await request.json() as {
      pass_token?: string;
      otp_code?: string;
      action?: 'entry' | 'exit';
    };

    if (!body.pass_token && !body.otp_code) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'pass_token or otp_code is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['VISITOR_PASS_OTP_WINDOW_MINS']);
    const windowMins = ruleInt(rules, 'VISITOR_PASS_OTP_WINDOW_MINS', 30);

    // Look up by token or OTP
    let query = sb
      .from('visitor_pre_approvals')
      .select('id, visitor_name, purpose, expected_time_from, expected_time_to, expires_at, status, scan_count, max_uses, pass_token, host_unit_id, otp_code')
      .eq('society_id', SOCIETY_ID)
      .eq('status', 'approved');

    if (body.pass_token) {
      query = query.eq('pass_token', body.pass_token);
    } else if (body.otp_code) {
      // OTP lookup: must be within the pass window ± grace period
      const now = new Date();
      const windowStart = new Date(now.getTime() - windowMins * 60000).toISOString();
      query = query
        .eq('otp_code', body.otp_code.trim())
        .gte('expires_at', now.toISOString())
        .or(`expected_time_from.is.null,expected_time_from.lte.${new Date(now.getTime() + windowMins * 60000).toISOString()}`);
    }

    const { data: pass, error } = await query.single();

    if (error || !pass) {
      return Response.json({
        error: 'INVALID_PASS',
        message: body.otp_code ? 'Invalid or expired OTP code' : 'Pass not found or no longer valid',
      }, { status: 404 });
    }

    const now = new Date();
    const validUntil = new Date(pass.expires_at);
    const validFrom  = pass.expected_time_from ? new Date(pass.expected_time_from) : null;

    if (validUntil < now) {
      return Response.json({ error: 'PASS_EXPIRED', message: 'This pass has expired', visitor_name: pass.visitor_name }, { status: 410 });
    }
    if (validFrom && validFrom > new Date(now.getTime() + windowMins * 60000)) {
      return Response.json({
        error: 'PASS_NOT_YET_VALID',
        message: `Pass is valid from ${new Date(pass.expected_time_from!).toLocaleString('en-IN')}`,
        visitor_name: pass.visitor_name,
      }, { status: 422 });
    }
    if (pass.scan_count >= pass.max_uses) {
      return Response.json({ error: 'PASS_MAXED_OUT', message: 'This pass has already been used the maximum number of times', visitor_name: pass.visitor_name }, { status: 409 });
    }

    // Record entry in visitor_logs
    const { data: logEntry, error: logErr } = await sb.from('visitor_logs').insert({
      society_id:       SOCIETY_ID,
      pre_approval_id:  pass.id,
      visitor_name:     pass.visitor_name,
      host_unit_id:     pass.host_unit_id,
      entry_type:       'pre_approved',
      entry_time:       now.toISOString(),
      logged_by:        user.id,
    }).select('id').single();

    if (logErr) throw Object.assign(new Error(logErr.message), { status: 500 });

    // Increment scan_count and mark used if maxed out
    const newCount = pass.scan_count + 1;
    const updates: Record<string, unknown> = {
      scan_count: newCount,
      first_used_at: pass.scan_count === 0 ? now.toISOString() : undefined,
    };
    if (newCount >= pass.max_uses) updates.status = 'used';

    await sb.from('visitor_pre_approvals').update(updates).eq('id', pass.id);

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: 'visitor_log', resourceId: logEntry?.id ?? pass.id,
      ip: extractClientIP(request),
      newValues: { pass_id: pass.id, visitor_name: pass.visitor_name, method: body.pass_token ? 'qr' : 'otp' },
    });

    return Response.json({
      ok: true,
      visitor_name: pass.visitor_name,
      purpose: pass.purpose,
      unit: pass.host_unit_id,
      log_id: logEntry?.id,
      uses_remaining: pass.max_uses - newCount,
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
