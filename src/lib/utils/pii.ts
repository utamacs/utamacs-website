// Fields stripped from audit log snapshots before storage (DPDPA compliance)
const PII_FIELDS: Set<string> = new Set([
  'phone_encrypted',
  'id_proof_encrypted',
  'bank_account_encrypted',
  'otp_code_hash',
  'visitor_phone_hash',
  'password',
  'password_hash',
]);

export function stripPII(obj: Record<string, unknown>): Record<string, unknown> {
  if (!obj || typeof obj !== 'object') return obj;
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj)) {
    if (!PII_FIELDS.has(key)) {
      result[key] = value;
    }
  }
  return result;
}

export function maskEmail(email: string): string {
  const [local, domain] = email.split('@');
  if (!domain) return '***';
  const visible = local.length > 2 ? local.slice(0, 2) : local.slice(0, 1);
  return `${visible}***@${domain}`;
}
