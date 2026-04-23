import { getSupabaseServiceClient } from './SupabaseDB';
import type { IStorageService, UploadResult } from '../../interfaces/IStorageService';

export class SupabaseStorageService implements IStorageService {
  async upload(bucket: string, path: string, file: Buffer, mimeType: string): Promise<UploadResult> {
    const sb = getSupabaseServiceClient();
    const { error } = await sb.storage.from(bucket).upload(path, file, {
      contentType: mimeType,
      upsert: false,
    });
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return { storageKey: path, size: file.length };
  }

  async getSignedUrl(bucket: string, storageKey: string, expiresInSeconds: number): Promise<string> {
    const sb = getSupabaseServiceClient();
    const { data, error } = await sb.storage
      .from(bucket)
      .createSignedUrl(storageKey, expiresInSeconds);
    if (error || !data?.signedUrl) {
      throw Object.assign(new Error(error?.message ?? 'Could not generate signed URL'), { status: 500 });
    }
    return data.signedUrl;
  }

  async delete(bucket: string, storageKey: string): Promise<void> {
    const sb = getSupabaseServiceClient();
    const { error } = await sb.storage.from(bucket).remove([storageKey]);
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
  }

  async copy(bucket: string, fromKey: string, toKey: string): Promise<void> {
    const sb = getSupabaseServiceClient();
    const { error } = await sb.storage.from(bucket).copy(fromKey, toKey);
    if (error) throw Object.assign(new Error(error.message), { status: 500 });
  }
}
