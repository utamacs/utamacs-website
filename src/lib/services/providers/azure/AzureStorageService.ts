import type { IStorageService, UploadResult } from '../../interfaces/IStorageService';

// Azure Blob Storage stub — implement when PROVIDER=azure
export class AzureStorageService implements IStorageService {
  private notImplemented(): never {
    throw Object.assign(new Error('Azure provider not yet implemented'), { status: 501 });
  }

  upload(_bucket: string, _path: string, _file: Buffer, _mimeType: string): Promise<UploadResult> { this.notImplemented(); }
  getSignedUrl(_bucket: string, _storageKey: string, _expiresInSeconds: number): Promise<string> { this.notImplemented(); }
  delete(_bucket: string, _storageKey: string): Promise<void> { this.notImplemented(); }
  copy(_bucket: string, _fromKey: string, _toKey: string): Promise<void> { this.notImplemented(); }
}
