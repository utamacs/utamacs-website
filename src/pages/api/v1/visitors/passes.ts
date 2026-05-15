export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { getRules, ruleInt } from '@lib/utils/getRules';
import { UUID_RE } from '@lib/constants';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET /api/v1/visitors/passes — list passes for current user (or all for guard/exec)
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = getSupabaseServiceClient();
    const isPrivileged = user.isAdmin || ['executive', 'secretary', 'president'].includes(user.portalRole);
    const isGuard = (user as { role?: string }).role === 'security_guard';

    let query = sb
      .from('visitor_pre_approvals')
      .select('id, visitor_name, purpose, expected_date, expected_time_from, expected_time_to, expires_at, status, pass_token, otp_code, scan_count, max_uses, guard_note, vehicle_number, created_at, units(unit_number, block)')
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false })
      .limit(100);

    if (!isPrivileged && !isGuard) {
      query = query.eq('host_user_id', user.id);
    }

    const { data, error } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST /api/v1/visitors/passes — create a new time-bound or recurring visitor pass
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const body = await request.json() as {
      visitor_name?: string;
      visitor_phone?: string;
      purpose?: string;
      unit_id?: string;
      valid_from?: string;           // ISO datetime
      valid_until?: string;          // ISO datetime
      max_uses?: number;
      vehicle_number?: string;
      guard_note?: string;
      // Recurring pass fields
      is_recurring?: boolean;
      recurring_days?: number[];     // 0=Sun … 6=Sat
      recurrence_end_date?: string;  // YYYY-MM-DD
    };

    if (!body.visitor_name?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'visitor_name is required' }, { status: 400 });
    }
    if (!body.unit_id || !UUID_RE.test(body.unit_id)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'valid unit_id is required' }, { status: 400 });
    }
    if (!body.valid_from || !body.valid_until) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'valid_from and valid_until are required' }, { status: 400 });
    }

    const validFrom  = new Date(body.valid_from);
    const validUntil = new Date(body.valid_until);
    const now = new Date();

    if (isNaN(validFrom.getTime()) || isNaN(validUntil.getTime())) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Invalid date format' }, { status: 400 });
    }
    if (validUntil <= validFrom) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'valid_until must be after valid_from' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['VISITOR_PASS_MAX_HOURS', 'VISITOR_PASS_MAX_USES_DEFAULT', 'VISITOR_RECURRING_MAX_WEEKS']);
    const maxHours    = ruleInt(rules, 'VISITOR_PASS_MAX_HOURS', 168);
    const maxWeeks    = ruleInt(rules, 'VISITOR_RECURRING_MAX_WEEKS', 8);
    const isRecurring = body.is_recurring === true;

    const diffHours = (validUntil.getTime() - validFrom.getTime()) / 3600000;
    if (!isRecurring && diffHours > maxHours) {
      return Response.json({ error: 'VALIDATION_ERROR', message: `Pass cannot exceed ${maxHours} hours` }, { status: 400 });
    }

    // Validate recurring fields
    let recurringDays: number[] | null = null;
    let recurrenceEndDate: string | null = null;
    if (isRecurring) {
      if (!Array.isArray(body.recurring_days) || body.recurring_days.length === 0) {
        return Response.json({ error: 'VALIDATION_ERROR', message: 'recurring_days required for recurring passes' }, { status: 400 });
      }
      recurringDays = body.recurring_days.map(Number).filter(d => Number.isInteger(d) && d >= 0 && d <= 6);
      if (recurringDays.length !== body.recurring_days.length) {
        return Response.json({ error: 'VALIDATION_ERROR', message: 'recurring_days values must be 0–6' }, { status: 400 });
      }
      if (body.recurrence_end_date) {
        if (!/^\d{4}-\d{2}-\d{2}$/.test(body.recurrence_end_date)) {
          return Response.json({ error: 'VALIDATION_ERROR', message: 'recurrence_end_date must be YYYY-MM-DD' }, { status: 400 });
        }
        recurrenceEndDate = body.recurrence_end_date;
        const endMs = new Date(body.recurrence_end_date + 'T00:00:00').getTime();
        if ((endMs - validFrom.getTime()) > maxWeeks * 7 * 86_400_000) {
          return Response.json({ error: 'VALIDATION_ERROR', message: `Recurring pass cannot exceed ${maxWeeks} weeks` }, { status: 400 });
        }
      }
    }

    // Verify unit belongs to this society
    const { data: unit, error: unitErr } = await sb.from('units').select('id').eq('id', body.unit_id).eq('society_id', SOCIETY_ID).single();
    if (unitErr || !unit) {
      return Response.json({ error: 'NOT_FOUND', message: 'Unit not found' }, { status: 404 });
    }

    // Generate 6-digit OTP
    const otp = String(Math.floor(100000 + Math.random() * 900000));

    // Hash phone if provided (DPDPA)
    let phoneHash: string | null = null;
    if (body.visitor_phone) {
      const { hashPII } = await import('@lib/utils/encryption');
      phoneHash = hashPII(body.visitor_phone.trim());
    }

    // Recurring passes use higher max_uses (one per valid day within window)
    const defaultMaxUses = isRecurring
      ? (recurrenceEndDate
          ? Math.ceil((new Date(recurrenceEndDate + 'T00:00:00').getTime() - validFrom.getTime()) / 86_400_000)
          : 365)
      : 1;
    const maxUses = Math.max(1, Math.min(body.max_uses ?? defaultMaxUses, 500));

    const { data: pass, error: insertErr } = await sb
      .from('visitor_pre_approvals')
      .insert({
        society_id:            SOCIETY_ID,
        host_unit_id:          body.unit_id,
        host_user_id:          user.id,
        visitor_name:          body.visitor_name.trim().slice(0, 100),
        visitor_phone_hash:    phoneHash,
        purpose:               body.purpose?.trim().slice(0, 200) ?? null,
        expected_date:         validFrom.toISOString().split('T')[0],
        expected_time_from:    validFrom.toISOString(),
        expected_time_to:      validUntil.toISOString(),
        expires_at:            recurrenceEndDate
                                 ? new Date(recurrenceEndDate + 'T23:59:59+05:30').toISOString()
                                 : validUntil.toISOString(),
        otp_code:              otp,
        max_uses:              maxUses,
        status:                'approved',
        vehicle_number:        body.vehicle_number?.trim().slice(0, 20) ?? null,
        guard_note:            body.guard_note?.trim().slice(0, 300) ?? null,
        is_recurring:          isRecurring,
        recurring_days:        recurringDays,
        recurrence_end_date:   recurrenceEndDate,
      })
      .select('id, pass_token, otp_code, visitor_name, expected_time_from, expected_time_to, max_uses, is_recurring, recurring_days, recurrence_end_date')
      .single();

    if (insertErr) throw Object.assign(new Error(insertErr.message), { status: 500 });

    return Response.json(pass, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
