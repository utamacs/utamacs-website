import { getSupabaseAnonClient, getSupabaseServiceClient } from './SupabaseDB';
import type { IAuthService, AuthSession, UserClaims, MFASetup } from '../../interfaces/IAuthService';

function sessionFromSupabase(session: { access_token: string; refresh_token: string; expires_at?: number }, user: { id: string; email?: string; user_metadata?: { role?: string; society_id?: string } }, profile?: { portal_role?: string; committee_title?: string | null; is_admin?: boolean; is_platform_admin?: boolean }): AuthSession {
  return {
    accessToken: session.access_token,
    refreshToken: session.refresh_token,
    expiresAt: session.expires_at ?? 0,
    user: {
      id: user.id,
      email: user.email ?? '',
      role: user.user_metadata?.role ?? 'member',
      portalRole: profile?.portal_role ?? 'member',
      committeeTitle: profile?.committee_title ?? null,
      isAdmin: profile?.is_admin ?? false,
      isPlatformAdmin: profile?.is_platform_admin ?? false,
      societyId: user.user_metadata?.society_id ?? '',
    },
  };
}

export class SupabaseAuthService implements IAuthService {
  async signIn(email: string, password: string): Promise<AuthSession> {
    const sb = getSupabaseAnonClient();
    const { data, error } = await sb.auth.signInWithPassword({ email, password });
    console.log('[signIn] error:', error, 'hasSession:', !!data.session, 'hasUser:', !!data.user);
    if (error || !data.session || !data.user) {
      throw Object.assign(new Error(error?.message ?? 'Sign-in failed'), { status: 401 });
    }
    let role = 'member';
    let societyId = '';
    let profile: { portal_role?: string; committee_title?: string | null; is_admin?: boolean; is_platform_admin?: boolean } = {};
    try {
      const serviceClient = getSupabaseServiceClient();
      const [roleResult, profileResult] = await Promise.all([
        serviceClient.from('user_roles').select('role, society_id').eq('user_id', data.user.id).single(),
        serviceClient.from('profiles').select('portal_role, committee_title, is_admin, is_platform_admin').eq('id', data.user.id).single(),
      ]);
      if (roleResult.data) {
        role = roleResult.data.role ?? 'member';
        societyId = roleResult.data.society_id ?? '';
      }
      if (profileResult.data) {
        profile = profileResult.data;
      }
    } catch {
      // Service key not configured — proceed with member role defaults
    }

    return sessionFromSupabase(data.session, data.user, profile);
  }

  async signOut(accessToken: string): Promise<void> {
    const sb = getSupabaseAnonClient();
    await sb.auth.admin?.signOut(accessToken).catch(() => undefined);
  }

  async validateToken(accessToken: string): Promise<UserClaims> {
    // Use the anon client for token validation — getUser(jwt) makes an HTTP
    // request to /auth/v1/user with the JWT as the Authorization header,
    // so the client's own key is irrelevant. This avoids a hard dependency on
    // SUPABASE_SERVICE_ROLE_KEY being configured for every page-load auth check.
    const anon = getSupabaseAnonClient();
    const { data, error } = await anon.auth.getUser(accessToken);
    if (error || !data.user) {
      throw Object.assign(new Error('Invalid or expired token'), { status: 401 });
    }

    // Role + profile lookup — non-fatal: defaults to 'member' if service key not configured
    let role = 'member';
    let societyId = '';
    let portalRole = 'member';
    let committeeTitle: string | null = null;
    let isAdmin = false;
    let isPlatformAdmin = false;
    try {
      const svc = getSupabaseServiceClient();
      const [roleResult, profileResult] = await Promise.all([
        svc.from('user_roles').select('role, society_id').eq('user_id', data.user.id).single(),
        svc.from('profiles').select('portal_role, committee_title, is_admin, is_platform_admin, society_id').eq('id', data.user.id).single(),
      ]);
      if (roleResult.data) {
        role = roleResult.data.role ?? 'member';
        societyId = roleResult.data.society_id ?? '';
      }
      if (profileResult.data) {
        portalRole = profileResult.data.portal_role ?? 'member';
        committeeTitle = profileResult.data.committee_title ?? null;
        isAdmin = (profileResult.data.is_admin ?? false) || role === 'admin';
        isPlatformAdmin = profileResult.data.is_platform_admin ?? false;
        if (!societyId) societyId = profileResult.data.society_id ?? '';
      }
    } catch {
      // Service key not configured or DB unavailable — member role is the safe default
    }

    return {
      id: data.user.id,
      email: data.user.email ?? '',
      role,
      portalRole,
      committeeTitle,
      isAdmin,
      isPlatformAdmin,
      societyId,
    };
  }

  async refreshToken(refreshToken: string): Promise<AuthSession> {
    const sb = getSupabaseAnonClient();
    const { data, error } = await sb.auth.refreshSession({ refresh_token: refreshToken });
    if (error || !data.session || !data.user) {
      throw Object.assign(new Error('Token refresh failed'), { status: 401 });
    }
    return sessionFromSupabase(data.session, data.user);
  }

  async sendPasswordReset(email: string): Promise<void> {
    const sb = getSupabaseAnonClient();
    const { error } = await sb.auth.resetPasswordForEmail(email, {
      redirectTo: 'https://portal.utamacs.org/api/v1/auth/callback?type=recovery',
    });
    if (error) throw Object.assign(new Error(error.message), { status: 400 });
  }

  async resetPassword(token: string, newPassword: string): Promise<void> {
    // token exchanged via URL hash by Supabase client; server uses service role
    const sb = getSupabaseServiceClient();
    const { error } = await sb.auth.admin.updateUserById(token, { password: newPassword });
    if (error) throw Object.assign(new Error(error.message), { status: 400 });
  }

  async enableMFA(_userId: string): Promise<MFASetup> {
    throw Object.assign(new Error('MFA setup must be performed via client-side TOTP flow'), { status: 501 });
  }

  async verifyMFA(_userId: string, _code: string): Promise<boolean> {
    throw Object.assign(new Error('MFA verify must be performed via Supabase client'), { status: 501 });
  }
}
