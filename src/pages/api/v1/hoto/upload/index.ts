export const prerender = false;
import type { APIRoute } from 'astro';
import { createHash } from 'crypto';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { resolveFromRequest, requireFeature } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';
import { getRules, ruleInt } from '@lib/utils/getRules';

const SOCIETY_ID    = import.meta.env.PUBLIC_SOCIETY_ID     ?? '00000000-0000-0000-0000-000000000001';
const GITHUB_REPO   = import.meta.env.GITHUB_HOTO_REPO      ?? '';
const GITHUB_TOKEN  = import.meta.env.GITHUB_HOTO_TOKEN     ?? import.meta.env.GITHUB_LETTERS_TOKEN ?? '';
const GITHUB_BRANCH = import.meta.env.GITHUB_HOTO_BRANCH    ?? 'main';

const ALLOWED_MIME: Record<string, string> = {
  'application/pdf': 'pdf',
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
  'text/csv': 'csv',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'docx',
};

// target_path validated server-side: prefix regex, no '..' or '//'
const PATH_RE = /^(hoto|snags|vendors|notices|finances|audit)\/[a-zA-Z0-9/_.-]+$/;

async function commitToGitHub(
  path: string,
  contentBase64: string,
  commitMessage: string,
): Promise<{ sha: string }> {
  const url = `https://api.github.com/repos/${GITHUB_REPO}/contents/${path}`;
  const headers = {
    Authorization: `Bearer ${GITHUB_TOKEN}`,
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  let existingSha: string | undefined;
  const checkRes = await fetch(url, { headers });
  if (checkRes.ok) {
    const existing = await checkRes.json() as { sha?: string };
    existingSha = existing.sha;
  }

  const body: Record<string, unknown> = {
    message: commitMessage,
    content: contentBase64,
    branch: GITHUB_BRANCH,
  };
  if (existingSha) body.sha = existingSha;

  const res = await fetch(url, {
    method: 'PUT',
    headers: { ...headers, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text();
    throw Object.assign(new Error(`GitHub commit failed (${res.status}): ${text.slice(0, 200)}`), { status: 502 });
  }

  const json = await res.json() as { content: { sha: string } };
  return { sha: json.content.sha };
}

// POST — upload a governance document for a HOTO item
// Attempts synchronous GitHub commit; on failure queues for cron retry.
// Auth: hoto.upload feature required
// Body: multipart/form-data
//   file             — the file (required)
//   item_id          — HOTO item id (required)
//   item_type        — 'hoto_item' (default)
//   target_path      — github path relative to repo root (required, validated)
//   source_description — human description of document origin (optional)
//   is_confidential  — 'true'/'false' (default false)
//   required_doc_id  — UUID of hoto_required_doc to mark as uploaded (optional)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    requireFeature(user, 'hoto.upload');

    let formData: FormData;
    try {
      formData = await request.formData();
    } catch {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Expected multipart/form-data' }, { status: 400 });
    }

    const file = formData.get('file') as File | null;
    if (!file || !(file instanceof File)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'file is required' }, { status: 400 });
    }

    const itemId        = (formData.get('item_id') as string | null)?.trim() ?? '';
    const itemType      = (formData.get('item_type') as string | null)?.trim() || 'hoto_item';
    const targetPath    = (formData.get('target_path') as string | null)?.trim() ?? '';
    const sourceDesc    = (formData.get('source_description') as string | null)?.trim() ?? null;
    const isConfidential = formData.get('is_confidential') === 'true';
    const requiredDocId = (formData.get('required_doc_id') as string | null)?.trim() ?? null;

    if (!itemId) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'item_id is required' }, { status: 400 });
    }

    if (!targetPath || !PATH_RE.test(targetPath) || targetPath.includes('..') || targetPath.includes('//')) {
      return Response.json({
        error: 'INVALID_PATH',
        message: 'File path is not permitted. Must match: (hoto|snags|vendors|notices|finances|audit)/...',
      }, { status: 400 });
    }

    const mimeType = file.type || 'application/octet-stream';
    if (!ALLOWED_MIME[mimeType]) {
      return Response.json({
        error: 'VALIDATION_ERROR',
        message: `File type not allowed. Permitted: PDF, JPG, PNG, XLSX, CSV, DOCX`,
      }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const rules = await getRules(sb, SOCIETY_ID, ['UPLOAD_LIMIT_HOTO_MB']);
    const maxFileBytes = ruleInt(rules, 'UPLOAD_LIMIT_HOTO_MB', 5) * 1024 * 1024;

    const bytes = await file.arrayBuffer();
    if (bytes.byteLength > maxFileBytes) {
      return Response.json({
        error: 'VALIDATION_ERROR',
        message: `File exceeds ${ruleInt(rules, 'UPLOAD_LIMIT_HOTO_MB', 5)} MB limit (got ${(bytes.byteLength / 1024 / 1024).toFixed(1)}MB)`,
      }, { status: 400 });
    }

    const hashHex = createHash('sha256').update(Buffer.from(bytes)).digest('hex');
    const contentBase64 = Buffer.from(bytes).toString('base64');

    // Verify item exists in this society
    const { data: hotoItem } = await sb
      .from('hoto_items')
      .select('id')
      .eq('id', itemId)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!hotoItem) {
      return Response.json({ error: 'NOT_FOUND', message: 'HOTO item not found' }, { status: 404 });
    }

    // Idempotency key: same file + path + user cannot be double-uploaded
    const idempotencyKey = createHash('sha256')
      .update(`${hashHex}:${targetPath}:${user.id}`)
      .digest('hex');

    const { data: dupCheck } = await sb
      .from('upload_queue')
      .select('id, status, document_id')
      .eq('idempotency_key', idempotencyKey)
      .maybeSingle();

    if (dupCheck && (dupCheck as any).status === 'DONE') {
      return Response.json({
        document_id: (dupCheck as any).document_id,
        status: 'DONE',
        message: 'Identical file already uploaded',
      });
    }

    // Insert into upload_queue (PENDING initially)
    const { data: queueRecord, error: queueErr } = await sb
      .from('upload_queue')
      .insert({
        society_id: SOCIETY_ID,
        uploaded_by: user.id,
        item_type: itemType,
        item_id: itemId,
        file_name: file.name,
        file_size_bytes: bytes.byteLength,
        file_type: mimeType,
        file_hash_sha256: hashHex,
        source_description: sourceDesc,
        target_github_path: targetPath,
        status: 'PENDING',
        idempotency_key: idempotencyKey,
      })
      .select('id')
      .single();

    if (queueErr) throw Object.assign(new Error(queueErr.message), { status: 500 });

    const queueId = (queueRecord as any).id as string;

    // Attempt synchronous GitHub commit — fall back to async queue on failure
    let githubSha: string | null = null;
    let githubError: string | null = null;

    if (GITHUB_REPO && GITHUB_TOKEN) {
      try {
        const { sha } = await commitToGitHub(
          targetPath,
          contentBase64,
          `docs: upload ${file.name} for ${itemType}/${itemId}`,
        );
        githubSha = sha;
      } catch (err) {
        githubError = err instanceof Error ? err.message : String(err);
        console.error('[upload] GitHub commit failed (will retry via cron):', githubError);
      }
    }

    if (githubSha) {
      // Commit succeeded — create governance_files record
      const fileId = `FILE-${Date.now()}-${Math.random().toString(36).slice(2, 6).toUpperCase()}`;

      const { data: fileRecord, error: fileErr } = await sb.from('governance_files').insert({
        id: fileId,
        item_type: itemType,
        item_id: itemId,
        name: file.name,
        file_type: mimeType,
        file_size_bytes: bytes.byteLength,
        file_hash_sha256: hashHex,
        source_description: sourceDesc,
        github_path: targetPath,
        github_sha: githubSha,
        upload_queue_id: queueId,
        uploaded_by: user.id,
        is_confidential: isConfidential,
      }).select().single();

      if (fileErr) console.error('[upload] governance_files insert failed:', fileErr.message);

      await sb.from('upload_queue').update({
        status: 'DONE',
        github_sha: githubSha,
        document_id: fileErr ? null : fileId,
        attempts: 1,
        last_attempt_at: new Date().toISOString(),
      }).eq('id', queueId);

      // Mark associated required_doc as uploaded
      if (requiredDocId && !fileErr) {
        await sb.from('hoto_required_docs').update({
          uploaded: true,
          document_id: fileId,
        }).eq('id', requiredDocId).eq('hoto_item_id', itemId);
      }

      await writeAuditLog({
        societyId: SOCIETY_ID, userId: user.id,
        action: 'CREATE', resourceType: 'governance_files', resourceId: fileId,
        ip: extractClientIP(request),
        newValues: { item_type: itemType, item_id: itemId, file_name: file.name, github_path: targetPath },
      });

      return Response.json({
        document_id: fileErr ? null : fileId,
        queue_id: queueId,
        status: 'DONE',
        github_path: targetPath,
        ...(fileRecord ? { file: fileRecord } : {}),
      }, { status: 201 });
    }

    // GitHub not configured or commit failed — queued for cron retry
    if (githubError) {
      await sb.from('upload_queue').update({
        status: 'FAILED',
        attempts: 1,
        last_attempt_at: new Date().toISOString(),
        error_message: githubError.slice(0, 500),
        backoff_until: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
      }).eq('id', queueId);
    }

    return Response.json({
      document_id: null,
      queue_id: queueId,
      status: githubError ? 'QUEUED_RETRY' : 'QUEUED',
      message: githubError
        ? 'GitHub commit failed. Upload queued for automatic retry.'
        : 'Upload queued (GitHub not configured in this environment).',
    }, { status: 202 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
