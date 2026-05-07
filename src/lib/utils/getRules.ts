/**
 * Thin helper to fetch one or more rule values from the rules engine table.
 * Use this in API routes to avoid hardcoding byelaw-mandated or configurable values.
 *
 * Usage:
 *   const rules = await getRules(sb, SOCIETY_ID, ['MEMBERSHIP_ADMISSION_FEE', 'AGM_QUORUM_PERCENTAGE']);
 *   const fee = rules.MEMBERSHIP_ADMISSION_FEE ?? 1000;
 */
import type { SupabaseClient } from '@supabase/supabase-js';

type RuleValue = string | number | boolean | unknown[] | null;

export async function getRules(
  sb: SupabaseClient,
  societyId: string,
  codes: string[],
): Promise<Record<string, RuleValue>> {
  if (codes.length === 0) return {};

  const { data } = await sb
    .from('rules')
    .select('rule_code, current_value')
    .eq('society_id', societyId)
    .in('rule_code', codes);

  const result: Record<string, RuleValue> = {};
  for (const row of data ?? []) {
    result[(row as { rule_code: string; current_value: RuleValue }).rule_code] =
      (row as { rule_code: string; current_value: RuleValue }).current_value;
  }
  return result;
}

/** Typed helpers for common rule value types */
export function ruleInt(rules: Record<string, RuleValue>, code: string, fallback: number): number {
  const v = rules[code];
  if (v === undefined || v === null) return fallback;
  const n = typeof v === 'number' ? v : parseInt(String(v), 10);
  return isNaN(n) ? fallback : n;
}

export function ruleStr(rules: Record<string, RuleValue>, code: string, fallback: string): string {
  const v = rules[code];
  if (v === undefined || v === null) return fallback;
  // Rules store strings as JSON-encoded strings (e.g. '"auto_approve"')
  const s = String(v);
  return s.startsWith('"') ? s.slice(1, -1) : s;
}

export function ruleBool(rules: Record<string, RuleValue>, code: string, fallback: boolean): boolean {
  const v = rules[code];
  if (v === undefined || v === null) return fallback;
  if (typeof v === 'boolean') return v;
  return String(v) === 'true';
}
