// Rules engine — reads configurable business and byelaw rules from the `rules` table.
// All calls resolve from a pre-loaded in-memory map to avoid per-rule round-trips.

import { getSupabaseServiceClient } from './services/providers/supabase/SupabaseDB';

export type RuleValue = string | number | boolean | string[] | number[];

export interface RuleRecord {
  rule_code: string;
  rule_category: string;
  current_value: unknown;
  is_locked: boolean;
  label: string;
}

// Batch-fetch all rules for a society in a single query.
// Call once per request and pass the map to r() for individual lookups.
export async function loadRules(societyId: string): Promise<Map<string, RuleRecord>> {
  const sb = getSupabaseServiceClient();
  const { data, error } = await sb
    .from('rules')
    .select('rule_code, rule_category, current_value, is_locked, label')
    .eq('society_id', societyId);

  if (error) {
    console.error('[rules] loadRules failed:', error.message);
    return new Map();
  }

  const map = new Map<string, RuleRecord>();
  for (const row of data ?? []) {
    map.set(row.rule_code, row as RuleRecord);
  }
  return map;
}

// Read a single rule value from the pre-loaded map with a typed fallback.
// Usage: const quorum = r(rules, 'QUORUM_GENERAL_BODY', 20);
export function r<T extends RuleValue>(
  rules: Map<string, RuleRecord>,
  code: string,
  fallback: T,
): T {
  const record = rules.get(code);
  if (!record) return fallback;

  const val = record.current_value;
  if (val === null || val === undefined) return fallback;

  // JSONB values come back as parsed JS objects from Supabase
  return val as T;
}

// Convenience: fetch a single rule without pre-loading (use only for one-off reads)
export async function getRule<T extends RuleValue>(
  societyId: string,
  ruleCode: string,
  fallback: T,
): Promise<T> {
  const sb = getSupabaseServiceClient();
  const { data } = await sb
    .from('rules')
    .select('current_value')
    .eq('society_id', societyId)
    .eq('rule_code', ruleCode)
    .single();

  if (!data) return fallback;
  const val = data.current_value;
  return (val === null || val === undefined ? fallback : val) as T;
}

// Well-known rule codes (typed constants to avoid magic strings in callers)
export const RULE = {
  QUORUM_GENERAL_BODY:              'QUORUM_GENERAL_BODY',
  QUORUM_BOARD:                     'QUORUM_BOARD',
  TOTAL_DIRECTORS:                  'TOTAL_DIRECTORS',
  VOTE_SUSPENSION_DAYS:             'VOTE_SUSPENSION_DAYS',
  DEFAULTER_FLAG_DAYS:              'DEFAULTER_FLAG_DAYS',
  DEFAULTER_NOTICE_DAYS:            'DEFAULTER_NOTICE_DAYS',
  MAINTENANCE_INTEREST_RATE:        'MAINTENANCE_INTEREST_RATE',
  SECRETARY_APPROVAL_LIMIT:         'SECRETARY_APPROVAL_LIMIT',
  PRESIDENT_APPROVAL_LIMIT:         'PRESIDENT_APPROVAL_LIMIT',
  BOARD_APPROVAL_LIMIT:             'BOARD_APPROVAL_LIMIT',
  MINUTES_SUBMISSION_DAYS:          'MINUTES_SUBMISSION_DAYS',
  ANNUAL_STATEMENT_DEADLINE:        'ANNUAL_STATEMENT_DEADLINE',
  INVITE_EXPIRY_DAYS:               'INVITE_EXPIRY_DAYS',
  PROXY_VOTING_ENABLED:             'PROXY_VOTING_ENABLED',
  UPLOAD_MAX_SIZE_MB:               'UPLOAD_MAX_SIZE_MB',
  PDF_PURGE_DAYS:                   'PDF_PURGE_DAYS',
  EMAIL_DRAFT_RETENTION_DAYS:       'EMAIL_DRAFT_RETENTION_DAYS',
  HOTO_APPROVAL_CHAIN:              'HOTO_APPROVAL_CHAIN',
  HOTO_APPROVAL_ALTERNATE_VP:       'HOTO_APPROVAL_ALTERNATE_VP',
  HOTO_APPROVAL_ALTERNATE_JOINT_SEC:'HOTO_APPROVAL_ALTERNATE_JOINT_SEC',
  VENDOR_DECISION_REQUIRES_BOTH:    'VENDOR_DECISION_REQUIRES_BOTH',
  EXPENSE_APPROVAL_CHAIN_10K:       'EXPENSE_APPROVAL_CHAIN_10K',
  EXPENSE_APPROVAL_CHAIN_20K:       'EXPENSE_APPROVAL_CHAIN_20K',
  EXPENSE_APPROVAL_CHAIN_50K:       'EXPENSE_APPROVAL_CHAIN_50K',
  HOTO_SLA_ESCALATION_DAYS:         'HOTO_SLA_ESCALATION_DAYS',
  HOTO_SLA_DAY7_ACTION:             'HOTO_SLA_DAY7_ACTION',
  HOTO_SLA_DAY14_ACTION:            'HOTO_SLA_DAY14_ACTION',
  HOTO_SLA_DAY30_ACTION:            'HOTO_SLA_DAY30_ACTION',
  SNAG_SLA_WARNING_DAYS:            'SNAG_SLA_WARNING_DAYS',
  DEFAULTER_REMINDER_DAYS:          'DEFAULTER_REMINDER_DAYS',
  PENDING_APPROVAL_REMINDER_HOURS:  'PENDING_APPROVAL_REMINDER_HOURS',
  WEEKLY_DIGEST_ENABLED:            'WEEKLY_DIGEST_ENABLED',
  WEEKLY_DIGEST_DAY:                'WEEKLY_DIGEST_DAY',
  WEEKLY_DIGEST_HOUR:               'WEEKLY_DIGEST_HOUR',
  HOTO_REQUIRE_DOCS_BEFORE_REVIEW:  'HOTO_REQUIRE_DOCS_BEFORE_REVIEW',
  VOTE_REQUIRE_CONFLICT_DECLARATION:'VOTE_REQUIRE_CONFLICT_DECLARATION',
  PAYMENT_REQUIRE_ELECTRONIC_ABOVE: 'PAYMENT_REQUIRE_ELECTRONIC_ABOVE',
  SNAG_SCOPE_REQUIRED_ON_CREATE:    'SNAG_SCOPE_REQUIRED_ON_CREATE',
  INVITE_EMAIL_DOMAIN_ALLOWLIST:    'INVITE_EMAIL_DOMAIN_ALLOWLIST',
} as const;
