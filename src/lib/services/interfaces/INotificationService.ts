export type NotificationType =
  | 'complaint' | 'event' | 'notice' | 'poll'
  | 'payment' | 'visitor' | 'facility' | 'system' | 'security_alert';

export type NotificationChannel = 'in_app' | 'email' | 'sms' | 'whatsapp' | 'push';

export interface NotificationPayload {
  title: string;
  body: string;
  type: NotificationType;
  referenceTable?: string;
  referenceId?: string;
  channel?: NotificationChannel;
}

export interface EmailTemplate {
  templateId: string;
  subject: string;
}

export type Unsubscribe = () => void;

export interface INotificationService {
  sendInApp(societyId: string, userId: string, payload: NotificationPayload): Promise<void>;
  sendEmail(to: string, template: EmailTemplate, data: Record<string, unknown>): Promise<void>;
  sendBulk(societyId: string, userIds: string[], payload: NotificationPayload): Promise<void>;
  markRead(notificationId: string, userId: string): Promise<void>;
  subscribe(channel: string, cb: (payload: Record<string, unknown>) => void): Unsubscribe;
}
