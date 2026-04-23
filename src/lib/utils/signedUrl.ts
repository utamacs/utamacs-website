import { SignJWT, jwtVerify } from 'jose';

const SIGNED_URL_SECRET = new TextEncoder().encode(
  process.env.ENCRYPTION_KEY ?? 'fallback-dev-secret-change-in-prod',
);

export async function createSignedStorageToken(
  bucket: string,
  storageKey: string,
  expiresInSeconds: number,
): Promise<string> {
  return new SignJWT({ bucket, storageKey })
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(`${expiresInSeconds}s`)
    .sign(SIGNED_URL_SECRET);
}

export interface StorageTokenPayload {
  bucket: string;
  storageKey: string;
}

export async function verifySignedStorageToken(token: string): Promise<StorageTokenPayload> {
  const { payload } = await jwtVerify(token, SIGNED_URL_SECRET);
  return payload as unknown as StorageTokenPayload;
}

export function buildStorageProxyUrl(bucket: string, storageKey: string): string {
  const base = process.env.API_BASE_URL ?? '';
  return `${base}/storage/${bucket}/${encodeURIComponent(storageKey)}`;
}
