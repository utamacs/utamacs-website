import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

type NotifPrefKey =
  | 'complaints' | 'notices' | 'events' | 'polls' | 'payments'
  | 'visitor_alerts' | 'community' | 'marketplace' | 'maids'
  | 'gallery' | 'feedback' | 'snags';

interface FanoutOptions {
  societyId: string;
  excludeUserId?: string;
  preferenceKey: NotifPrefKey;
  title: string;
  body: string;
  type: string;
  referenceTable: string;
  referenceId: string;
}

/** Insert a notification row for every society member who has not opted out. Fire-and-forget: never throws. */
export async function fanoutNotification(opts: FanoutOptions): Promise<void> {
  try {
    const sb = getSupabaseServiceClient();

    // All user IDs in this society
    const { data: profiles } = await sb
      .from('profiles')
      .select('id')
      .eq('society_id', opts.societyId);

    let userIds = (profiles ?? []).map((p: any) => p.id as string);
    if (opts.excludeUserId) userIds = userIds.filter((id) => id !== opts.excludeUserId);
    if (!userIds.length) return;

    // Users who explicitly opted out of this notification type
    const { data: optedOut } = await sb
      .from('notification_preferences')
      .select('user_id')
      .in('user_id', userIds)
      .eq(opts.preferenceKey, false);

    const optedOutSet = new Set((optedOut ?? []).map((p: any) => p.user_id as string));
    const recipients = userIds.filter((id) => !optedOutSet.has(id));
    if (!recipients.length) return;

    const CHUNK = 100;
    for (let i = 0; i < recipients.length; i += CHUNK) {
      await sb.from('notifications').insert(
        recipients.slice(i, i + CHUNK).map((userId) => ({
          user_id: userId,
          society_id: opts.societyId,
          title: opts.title,
          body: opts.body,
          type: opts.type,
          reference_table: opts.referenceTable,
          reference_id: opts.referenceId,
          is_read: false,
        })),
      );
    }
  } catch {
    // Non-critical — swallow so the main operation is never blocked
  }
}
