import { create } from 'zustand';

export interface UserPermissions {
  role: 'member' | 'executive' | 'admin' | 'security_guard' | 'vendor';
  portalRole: 'member' | 'executive' | 'secretary' | 'president';
  isAdmin: boolean;
  committeeTitle: string | null;
  unitId: string | null;
  features: Set<string>;
}

export interface AuthUser {
  id: string;
  email: string;
  fullName: string;
  unitNumber: string | null;
  avatarPath: string | null;
  permissions: UserPermissions;
  permissionsLoadedAt: number;
}

interface AuthState {
  user: AuthUser | null;
  isLoading: boolean;
  isAuthenticated: boolean;

  setUser: (user: AuthUser) => void;
  clearUser: () => void;
  setLoading: (loading: boolean) => void;

  // Permission helpers
  hasFeature: (feature: string) => boolean;
  isPrivileged: () => boolean;
  isGuard: () => boolean;
}

export const useAuthStore = create<AuthState>((set, get) => ({
  user: null,
  isLoading: true,
  isAuthenticated: false,

  setUser: (user) => set({ user, isAuthenticated: true, isLoading: false }),
  clearUser: () => set({ user: null, isAuthenticated: false, isLoading: false }),
  setLoading: (isLoading) => set({ isLoading }),

  hasFeature: (feature) => {
    const { user } = get();
    if (!user) return false;
    if (user.permissions.isAdmin) return true;
    return user.permissions.features.has(feature);
  },

  isPrivileged: () => {
    const { user } = get();
    if (!user) return false;
    return (
      user.permissions.isAdmin ||
      ['executive', 'secretary', 'president'].includes(user.permissions.portalRole)
    );
  },

  isGuard: () => {
    const { user } = get();
    return user?.permissions.role === 'security_guard';
  },
}));
