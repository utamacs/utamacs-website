import type { INotificationService, NotificationPayload, EmailTemplate, Unsubscribe } from '../../interfaces/INotificationService';

// Azure SignalR + Communication Services stub — implement when PROVIDER=azure
export class AzureSignalRService implements INotificationService {
  private notImplemented(): never {
    throw Object.assign(new Error('Azure provider not yet implemented'), { status: 501 });
  }

  sendInApp(_societyId: string, _userId: string, _payload: NotificationPayload): Promise<void> { this.notImplemented(); }
  sendEmail(_to: string, _template: EmailTemplate, _data: Record<string, unknown>): Promise<void> { this.notImplemented(); }
  sendBulk(_societyId: string, _userIds: string[], _payload: NotificationPayload): Promise<void> { this.notImplemented(); }
  markRead(_notificationId: string, _userId: string): Promise<void> { this.notImplemented(); }
  subscribe(_channel: string, _cb: (payload: Record<string, unknown>) => void): Unsubscribe { this.notImplemented(); }
}
