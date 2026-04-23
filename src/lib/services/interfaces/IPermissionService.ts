export type Action = 'read' | 'create' | 'update' | 'delete' | 'admin';

export type Resource =
  | 'complaints' | 'complaint_comments' | 'notices' | 'events' | 'polls'
  | 'poll_votes' | 'finance' | 'payments' | 'facilities' | 'bookings'
  | 'visitors' | 'visitor_logs' | 'profiles' | 'user_roles' | 'vendors'
  | 'work_orders' | 'community_posts' | 'documents' | 'assets' | 'audit_logs'
  | 'feature_flags' | 'notifications';

export interface PermissionContext {
  userId: string;
  role: string;
  societyId: string;
  resourceOwnerId?: string;
}

export interface IPermissionService {
  authorize(ctx: PermissionContext, resource: Resource, action: Action): void;
  can(ctx: PermissionContext, resource: Resource, action: Action): boolean;
}
