import { getSupabaseAnonClient, getSupabaseServiceClient } from './SupabaseDB';
import type { IAuthService, AuthSession, UserClaims, MFASetup } from '../../interfaces/IAuthService';

function sessionFromSupabase(session: { access_token: string; refresh_token: string; expires_at?: number }, user: { id: string; email?: string; user_metadata?: { role?: string; society_id?: string } }): AuthSession {
  return {
    accessToken: session.access_token,
    refreshToken: session.refresh_token,
    expiresAt: session.expires_at ?? 0,
    user: {
      id: user.id,
      email: user.email ?? '',
      role: user.user_metadata?.role ?? 'member',
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
    const serviceClient = getSupabaseServiceClient();
    const { data: roleData } = await serviceClient
      .from('user_roles')
      .select('role, society_id')
      .eq('user_id', data.user.id)
      .single();
    const claims: UserClaims = {
      id: data.user.id,
      email: data.user.email ?? '',
      role: roleData?.role ?? 'member',
      societyId: roleData?.society_id ?? '',
    };
    return {
      accessToken: data.session.access_token,
      refreshToken: data.session.refresh_token,
      expiresAt: data.session.expires_at ?? 0,
      user: claims,
    };
  }

  async signOut(accessToken: string): Promise<void> {
    const sb = getSupabaseAnonClient();
    await sb.auth.admin?.signOut(accessToken).catch(() => undefined);
  }

  async validateToken(accessToken: string): Promise<UserClaims> {
    const sb = getSupabaseServiceClient();
    const { data, error } = await sb.auth.getUser(accessToken);
    if (error || !data.user) {
      throw Object.assign(new Error('Invalid or expired token'), { status: 401 });
    }
    const { data: roleData } = await sb
      .from('user_roles')
      .select('role, society_id')
      .eq('user_id', data.user.id)
      .single();
    return {
      id: data.user.id,
      email: data.user.email ?? '',
      role: roleData?.role ?? 'member',
      societyId: roleData?.society_id ?? '',
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
