import { getSupabaseServiceClient } from './SupabaseDB';
import type {
  INotificationService,
  NotificationPayload,
  EmailTemplate,
  Unsubscribe,
} from '../../interfaces/INotificationService';

export class SupabaseNotificationService implements INotificationService {
  async sendInApp(societyId: string, userId: string, payload: NotificationPayload): Promise<void> {
    const sb = getSupabaseServiceClient();
    const { error } = await sb.from('notifications').insert({
      society_id: societyId,
      user_id: userId,
      title: payload.title,
      body: payload.body,
      type: payload.type,
      reference_table: payload.referenceTable ?? null,
      reference_id: payload.referenceId ?? null,
      channel: payload.channel ?? 'in_app',
      status: 'delivered',
    });
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
  }

  async sendEmail(to: string, template: EmailTemplate, data: Record<string, unknown>): Promise<void> {
    const resendKey = process.env.RESEND_API_KEY;
    if (!resendKey) throw new Error('RESEND_API_KEY not configured');
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: 'UTA MACS <no-reply@utamacs.org>',
        to: [to],
        subject: template.subject,
        html: this.renderTemplate(template.templateId, data),
      }),
    });
    if (!response.ok) {
      const body = await response.text();
      throw Object.assign(new Error(`Email send failed: ${body}`), { status: 500 });
    }
  }

  async sendBulk(societyId: string, userIds: string[], payload: NotificationPayload): Promise<void> {
    const sb = getSupabaseServiceClient();
    const rows = userIds.map((userId) => ({
      society_id: societyId,
      user_id: userId,
      title: payload.title,
      body: payload.body,
      type: payload.type,
      reference_table: payload.referenceTable ?? null,
      reference_id: payload.referenceId ?? null,
      channel: payload.channel ?? 'in_app',
      status: 'delivered',
    }));
    const { error } = await sb.from('notifications').insert(rows);
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
  }

  async markRead(notificationId: string, userId: string): Promise<void> {
    const sb = getSupabaseServiceClient();
    const { error } = await sb
      .from('notifications')
      .update({ is_read: true, read_at: new Date().toISOString() })
      .eq('id', notificationId)
      .eq('user_id', userId);
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
  }

  subscribe(channel: string, cb: (payload: Record<string, unknown>) => void): Unsubscribe {
    const sb = getSupabaseServiceClient();
    const sub = sb
      .channel(channel)
      .on('postgres_changes', { event: '*', schema: 'public', table: 'notifications' }, cb)
      .subscribe();
    return () => {
      sb.removeChannel(sub);
    };
  }

  private renderTemplate(templateId: string, data: Record<string, unknown>): string {
    // Minimal inline template — replace with Resend template IDs in production
    return `<p>${JSON.stringify(data)}</p>`;
  }
}
