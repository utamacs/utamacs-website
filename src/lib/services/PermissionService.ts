import type { IPermissionService, Action, Resource, PermissionContext } from './interfaces/IPermissionService';

// Role hierarchy: higher index = higher privilege
const ROLE_ORDER = ['security_guard', 'vendor', 'member', 'executive', 'admin'];

function roleGte(role: string, minimum: string): boolean {
  return ROLE_ORDER.indexOf(role) >= ROLE_ORDER.indexOf(minimum);
}

type PolicyMap = Partial<Record<Resource, Partial<Record<Action, (ctx: PermissionContext) => boolean>>>>;

const POLICIES: PolicyMap = {
  complaints: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'member'),
    update: (ctx) => roleGte(ctx.role, 'executive'),
    delete: () => false,
  },
  complaint_comments: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'member'),
    update: () => false,
    delete: () => false,
  },
  notices: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'executive'),
    update: (ctx) => roleGte(ctx.role, 'executive'),
    delete: (ctx) => roleGte(ctx.role, 'admin'),
  },
  events: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'executive'),
    update: (ctx) => roleGte(ctx.role, 'executive'),
    delete: (ctx) => roleGte(ctx.role, 'admin'),
  },
  polls: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'executive'),
    update: (ctx) => roleGte(ctx.role, 'executive'),
    delete: (ctx) => roleGte(ctx.role, 'admin'),
  },
  poll_votes: {
    create: (ctx) => roleGte(ctx.role, 'member'),
    read: (ctx) => roleGte(ctx.role, 'member'),
    update: () => false,
    delete: () => false,
  },
  finance: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'executive'),
    update: (ctx) => roleGte(ctx.role, 'executive'),
    delete: () => false,
  },
  payments: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'member'),
    update: () => false,
    delete: () => false,
  },
  facilities: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'executive'),
    update: (ctx) => roleGte(ctx.role, 'executive'),
    delete: (ctx) => roleGte(ctx.role, 'admin'),
  },
  bookings: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'member'),
    update: (ctx) =>
      roleGte(ctx.role, 'executive') || ctx.userId === ctx.resourceOwnerId,
    delete: () => false,
  },
  visitors: {
    read: (ctx) =>
      roleGte(ctx.role, 'executive') ||
      ctx.role === 'security_guard' ||
      ctx.userId === ctx.resourceOwnerId,
    create: (ctx) => roleGte(ctx.role, 'member') || ctx.role === 'security_guard',
    update: (ctx) => roleGte(ctx.role, 'executive') || ctx.role === 'security_guard',
    delete: () => false,
  },
  visitor_logs: {
    read: (ctx) => roleGte(ctx.role, 'executive') || ctx.role === 'security_guard',
    create: (ctx) => ctx.role === 'security_guard' || roleGte(ctx.role, 'executive'),
    update: (ctx) => ctx.role === 'security_guard' || roleGte(ctx.role, 'executive'),
    delete: () => false,
  },
  profiles: {
    read: (ctx) =>
      ctx.userId === ctx.resourceOwnerId || roleGte(ctx.role, 'executive'),
    create: (ctx) => ctx.userId === ctx.resourceOwnerId,
    update: (ctx) => ctx.userId === ctx.resourceOwnerId,
    delete: (ctx) => roleGte(ctx.role, 'admin'),
  },
  user_roles: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'admin'),
    update: (ctx) => roleGte(ctx.role, 'admin'),
    delete: (ctx) => roleGte(ctx.role, 'admin'),
  },
  vendors: {
    read: (ctx) => roleGte(ctx.role, 'executive') || ctx.role === 'vendor',
    create: (ctx) => roleGte(ctx.role, 'executive'),
    update: (ctx) => roleGte(ctx.role, 'executive'),
    delete: (ctx) => roleGte(ctx.role, 'admin'),
  },
  work_orders: {
    read: (ctx) => roleGte(ctx.role, 'executive') || ctx.role === 'vendor',
    create: (ctx) => roleGte(ctx.role, 'executive'),
    update: (ctx) => roleGte(ctx.role, 'executive'),
    delete: () => false,
  },
  community_posts: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'member'),
    update: (ctx) => ctx.userId === ctx.resourceOwnerId || roleGte(ctx.role, 'executive'),
    delete: (ctx) => roleGte(ctx.role, 'admin'),
  },
  documents: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'executive'),
    update: (ctx) => roleGte(ctx.role, 'executive'),
    delete: (ctx) => roleGte(ctx.role, 'admin'),
  },
  assets: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'executive'),
    update: (ctx) => roleGte(ctx.role, 'executive'),
    delete: (ctx) => roleGte(ctx.role, 'admin'),
  },
  audit_logs: {
    read: (ctx) => roleGte(ctx.role, 'admin'),
    create: () => true,
    update: () => false,
    delete: () => false,
  },
  feature_flags: {
    read: (ctx) => roleGte(ctx.role, 'member'),
    create: (ctx) => roleGte(ctx.role, 'admin'),
    update: (ctx) => roleGte(ctx.role, 'admin'),
    delete: (ctx) => roleGte(ctx.role, 'admin'),
  },
  notifications: {
    read: (ctx) => ctx.userId === ctx.resourceOwnerId,
    create: (ctx) => roleGte(ctx.role, 'member'),
    update: (ctx) => ctx.userId === ctx.resourceOwnerId,
    delete: () => false,
  },
};

export class PermissionService implements IPermissionService {
  can(ctx: PermissionContext, resource: Resource, action: Action): boolean {
    const policy = POLICIES[resource]?.[action];
    if (!policy) return false;
    return policy(ctx);
  }

  authorize(ctx: PermissionContext, resource: Resource, action: Action): void {
    if (!this.can(ctx, resource, action)) {
      const err = Object.assign(
        new Error(`Forbidden: cannot ${action} ${resource}`),
        { status: 403, code: 'FORBIDDEN' },
      );
      throw err;
    }
  }
}
