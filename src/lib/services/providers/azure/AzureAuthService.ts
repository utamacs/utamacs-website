import type { IAuthService, AuthSession, UserClaims, MFASetup } from '../../interfaces/IAuthService';

// Azure Entra External ID stub — implement when PROVIDER=azure
export class AzureAuthService implements IAuthService {
  private notImplemented(): never {
    throw Object.assign(new Error('Azure provider not yet implemented'), { status: 501 });
  }

  signIn(_email: string, _password: string): Promise<AuthSession> { this.notImplemented(); }
  signOut(_accessToken: string): Promise<void> { this.notImplemented(); }
  validateToken(_accessToken: string): Promise<UserClaims> { this.notImplemented(); }
  refreshToken(_refreshToken: string): Promise<AuthSession> { this.notImplemented(); }
  sendPasswordReset(_email: string): Promise<void> { this.notImplemented(); }
  resetPassword(_token: string, _newPassword: string): Promise<void> { this.notImplemented(); }
  enableMFA(_userId: string): Promise<MFASetup> { this.notImplemented(); }
  verifyMFA(_userId: string, _code: string): Promise<boolean> { this.notImplemented(); }
}
