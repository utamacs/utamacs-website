export interface AuthSession {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  user: UserClaims;
}

export interface UserClaims {
  id: string;
  email: string;
  role: string;
  societyId: string;
}

export interface MFASetup {
  secret: string;
  qrCodeUrl: string;
  backupCodes: string[];
}

export interface IAuthService {
  signIn(email: string, password: string): Promise<AuthSession>;
  signOut(accessToken: string): Promise<void>;
  validateToken(accessToken: string): Promise<UserClaims>;
  refreshToken(refreshToken: string): Promise<AuthSession>;
  sendPasswordReset(email: string): Promise<void>;
  resetPassword(token: string, newPassword: string): Promise<void>;
  enableMFA(userId: string): Promise<MFASetup>;
  verifyMFA(userId: string, code: string): Promise<boolean>;
}
