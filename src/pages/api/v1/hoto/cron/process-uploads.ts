export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID    = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const CRON_SECRET   = import.meta.env.CRON_SECRET;
const GITHUB_REPO   = import.meta.env.GITHUB_HOTO_REPO ?? '';
const GITHUB_TOKEN  = import.meta.env.GITHUB_HOTO_TOKEN ?? import.meta.env.GITHUB_LETTERS_TOKEN ?? '';
const SENDER_NAME   = 'UTA MACS Society';
const SENDER_EMAIL  = import.meta.env.SOCIETY_SENDER_EMAIL ?? 'no-reply@utamacs.org';

const BATCH_SIZE  = 30;
const MAX_ATTEMPTS = 3;
// Exponential backoff: attempt 1 → 5 min, attempt 2+ → 30 min
const BACKOFF_MS = [5 * 60_000, 30 * 60_000];

// GET — retry stalled upload_queue entries; alert permanently-failed ones.
// Runs every minute. Skips when GitHub circuit breaker is OPEN.
// Note: file content is NOT stored in the DB, so cron cannot re-upload;
// it identifies stuck entries, checks GitHub reachability, and alerts.
export const GET: APIRoute = async ({ request }) => {
  const t0 = Date.now();
  try {
    if (CRON_SECRET && request.headers.get('authorization') !== `Bearer ${CRON_SECRET}`) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const sb = getSupabaseServiceClient();
    const now = new Date().toISOString();

    const { data: cbRow } = await sb
      .from('system_config')
      .select('value')
      .eq('key', 'github_circuit_breaker')
      .single();

    if ((cbRow?.value as string) === 'OPEN') {
      await heartbeat(sb, 'process-uploads', 'CIRCUIT_OPEN', 0, 0, Date.now() - t0, 'Circuit breaker OPEN — skipping');
      return Response.json({ status: 'CIRCUIT_OPEN', processed: 0 });
    }

    const { data: items } = await sb
      .from('upload_queue')
      .select('id, attempts, error_message, target_github_path, file_name, item_type, item_id')
      .eq('society_id', SOCIETY_ID)
      .in('status', ['PENDING', 'FAILED'])
      .or(`backoff_until.is.null,backoff_until.lte.${now}`)
      .order('created_at', { ascending: true })
      .limit(BATCH_SIZE);

    if (!items?.length) {
      await heartbeat(sb, 'process-uploads', 'OK', 0, 0, Date.now() - t0);
      return Response.json({ status: 'OK', processed: 0 });
    }

    let processed = 0;
    let failCount = 0;

    for (const row of items) {
      const q = row as any;
      const attempts = (q.attempts as number) ?? 0;

      if (attempts >= MAX_ATTEMPTS) {
        await permanentlyFail(sb, q.id, now, `Max ${MAX_ATTEMPTS} attempts exceeded — please re-upload.`);
        await alertAdmins(sb, q, `[ALERT] Document upload permanently failed: ${q.file_name}`,
          `Upload for <strong>${q.file_name}</strong> exceeded ${MAX_ATTEMPTS} retry attempts and cannot be recovered automatically.`);
        failCount++;
        continue;
      }

      // Check if GitHub is reachable (only way we can help here)
      if (GITHUB_REPO && GITHUB_TOKEN) {
        try {
          const ping = await fetch(`https://api.github.com/repos/${GITHUB_REPO}`, {
            headers: {
              Authorization: `Bearer ${GITHUB_TOKEN}`,
              Accept: 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2022-11-28',
            },
            signal: AbortSignal.timeout(8_000),
          });
          if (!ping.ok) {
            const backoffMs = BACKOFF_MS[Math.min(attempts, BACKOFF_MS.length - 1)];
            await sb.from('upload_queue').update({
              attempts: attempts + 1,
              last_attempt_at: now,
              error_message: `GitHub unreachable (${ping.status}) — queued for retry`,
              backoff_until: new Date(Date.now() + backoffMs).toISOString(),
            }).eq('id', q.id);
            failCount++;
            continue;
          }
        } catch (err) {
          const backoffMs = BACKOFF_MS[Math.min(attempts, BACKOFF_MS.length - 1)];
          await sb.from('upload_queue').update({
            attempts: attempts + 1,
            last_attempt_at: now,
            error_message: `GitHub ping error: ${err instanceof Error ? err.message.slice(0, 200) : String(err)}`,
            backoff_until: new Date(Date.now() + backoffMs).toISOString(),
          }).eq('id', q.id);
          failCount++;
          continue;
        }
      }

      // GitHub is reachable but file content is gone — mark permanently failed
      await permanentlyFail(sb, q.id, now, 'File content not recoverable — please re-upload via the portal.');
      await alertAdmins(sb, q, `[ACTION REQUIRED] Re-upload needed: ${q.file_name}`,
        `Upload for <strong>${q.file_name}</strong> cannot be retried (file content not stored server-side). The uploader must re-submit this document.`);
      processed++;
    }

    const status = failCount > 0 ? 'PARTIAL' : 'OK';
    await heartbeat(sb, 'process-uploads', status, processed, failCount, Date.now() - t0);
    return Response.json({ status, processed, failed: failCount });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

async function permanentlyFail(sb: ReturnType<typeof getSupabaseServiceClient>, id: string, now: string, msg: string) {
  await sb.from('upload_queue').update({
    status: 'PERMANENTLY_FAILED',
    last_attempt_at: now,
    error_message: msg,
  }).eq('id', id);
}

async function alertAdmins(sb: ReturnType<typeof getSupabaseServiceClient>, q: any, subject: string, detail: string) {
  await sb.from('email_drafts').insert({
    society_id: q.society_id ?? import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001',
    tier: 1,
    triggered_by: 'cron:process-uploads',
    trigger_resource_type: 'upload_queue',
    trigger_resource_id: q.id,
    recipient_type: 'ADMIN',
    subject,
    body_html: `<p>${detail}</p><ul><li><strong>File:</strong> ${q.file_name}</li><li><strong>Target path:</strong> ${q.target_github_path}</li><li><strong>Item:</strong> ${q.item_type}/${q.item_id}</li>${q.error_message ? `<li><strong>Last error:</strong> ${q.error_message}</li>` : ''}</ul>`,
    body_text: `${subject}\n\nFile: ${q.file_name}\nPath: ${q.target_github_path}\nItem: ${q.item_type}/${q.item_id}${q.error_message ? `\nError: ${q.error_message}` : ''}`,
    suggested_sender_name: SENDER_NAME,
    suggested_sender_email: SENDER_EMAIL,
    status: 'DRAFT',
  });
}

async function heartbeat(
  sb: ReturnType<typeof getSupabaseServiceClient>,
  cronName: string,
  status: string,
  itemsProcessed: number,
  itemsFailed: number,
  durationMs: number,
  errorMessage?: string,
) {
  await sb.from('cron_heartbeats').insert({
    cron_name: cronName,
    status,
    items_processed: itemsProcessed,
    items_failed: itemsFailed,
    duration_ms: durationMs,
    error_message: errorMessage ?? null,
  });
}
