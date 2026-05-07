import { describe, it, expect } from 'vitest';
import { normalizeError } from '../../src/lib/middleware/errorNormalizer';

describe('normalizeError', () => {
  it('returns a Response object', () => {
    const res = normalizeError(new Error('test'));
    expect(res).toBeInstanceOf(Response);
  });

  it('Content-Type is application/problem+json', () => {
    const res = normalizeError(new Error('test'));
    expect(res.headers.get('Content-Type')).toBe('application/problem+json');
  });

  it('plain Error without status → 500', async () => {
    const res = normalizeError(new Error('something broke'));
    expect(res.status).toBe(500);
    const body = await res.json();
    expect(body.status).toBe(500);
    expect(body.title).toBe('Internal Server Error');
    expect(body.detail).toBe('An internal error occurred');
  });

  it('Error with status 400 → 400 response', async () => {
    const err = Object.assign(new Error('Bad input'), { status: 400 });
    const res = normalizeError(err);
    expect(res.status).toBe(400);
    const body = await res.json();
    expect(body.status).toBe(400);
    expect(body.title).toBe('Bad Request');
    expect(body.detail).toBe('Bad input'); // < 500 errors expose message
  });

  it('Error with status 401 → 401 response', async () => {
    const err = Object.assign(new Error('Unauthorized'), { status: 401 });
    const res = normalizeError(err);
    expect(res.status).toBe(401);
    const body = await res.json();
    expect(body.status).toBe(401);
    expect(body.title).toBe('Unauthorized');
  });

  it('Error with status 403 → 403 response', async () => {
    const err = Object.assign(new Error('Forbidden: feature not enabled'), { status: 403, code: 'FEATURE_FORBIDDEN' });
    const res = normalizeError(err);
    expect(res.status).toBe(403);
    const body = await res.json();
    expect(body.status).toBe(403);
    expect(body.title).toBe('Forbidden');
    expect(body.detail).toBe('Forbidden: feature not enabled');
  });

  it('Error with status 404 → 404 response', async () => {
    const err = Object.assign(new Error('Not found'), { status: 404 });
    const res = normalizeError(err);
    expect(res.status).toBe(404);
    const body = await res.json();
    expect(body.status).toBe(404);
    expect(body.title).toBe('Not Found');
  });

  it('5xx errors hide internal details', async () => {
    const err = Object.assign(new Error('DB connection failed'), { status: 500 });
    const res = normalizeError(err);
    const body = await res.json();
    expect(body.detail).not.toBe('DB connection failed');
    expect(body.detail).toBe('An internal error occurred');
  });

  it('non-Error thrown value → 500 generic', async () => {
    const res = normalizeError('just a string error');
    expect(res.status).toBe(500);
    const body = await res.json();
    expect(body.status).toBe(500);
    expect(body.detail).toBe('An unexpected error occurred');
  });

  it('null thrown → 500', async () => {
    const res = normalizeError(null);
    expect(res.status).toBe(500);
  });

  it('instance URL is included when provided', async () => {
    const err = Object.assign(new Error('test'), { status: 400 });
    const res = normalizeError(err, '/api/v1/test');
    const body = await res.json();
    expect(body.instance).toBe('/api/v1/test');
  });

  it('type field follows utamacs.org error URL pattern', async () => {
    const err = Object.assign(new Error('test'), { status: 400 });
    const res = normalizeError(err, undefined);
    const body = await res.json();
    expect(body.type).toMatch(/^https:\/\/utamacs\.org\/errors\//);
  });
});
