export interface UploadResult {
  storageKey: string;
  size: number;
}

export interface IStorageService {
  upload(bucket: string, path: string, file: Buffer, mimeType: string): Promise<UploadResult>;
  getSignedUrl(bucket: string, storageKey: string, expiresInSeconds: number): Promise<string>;
  delete(bucket: string, storageKey: string): Promise<void>;
  copy(bucket: string, fromKey: string, toKey: string): Promise<void>;
}
