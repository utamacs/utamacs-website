import { getSupabaseServiceClient } from '../services/providers/supabase/SupabaseDB';
import { hashIP } from '../utils/encryption';
import { stripPII } from '../utils/pii';

export type AuditAction =
  | 'CREATE' | 'UPDATE' | 'DELETE' | 'LOGIN' | 'LOGOUT'
  | 'EXPORT' | 'ROLE_CHANGE' | 'PAYMENT' | 'DATA_ERASURE';

export interface AuditEntry {
  userId: string;
  societyId: string;
  action: AuditAction;
  resourceType: string;
  resourceId?: string;
  oldValues?: Record<string, unknown>;
  newValues?: Record<string, unknown>;
  ip?: string;
  userAgent?: string;
}

export async function writeAuditLog(entry: AuditEntry): Promise<void> {
  const sb = getSupabaseServiceClient();
  await sb.from('audit_logs').insert({
    user_id: entry.userId,
    society_id: entry.societyId,
    action: entry.action,
    resource_type: entry.resourceType,
    resource_id: entry.resourceId ?? null,
    old_values: entry.oldValues ? stripPII(entry.oldValues) : null,
    new_values: entry.newValues ? stripPII(entry.newValues) : null,
    ip_hash: entry.ip ? hashIP(entry.ip) : null,
    user_agent_hash: entry.userAgent
      ? hashIP(entry.userAgent)
      : null,
  });
}

export function extractClientIP(request: Request): string {
  return (
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    request.headers.get('x-real-ip') ??
    'unknown'
  );
}
