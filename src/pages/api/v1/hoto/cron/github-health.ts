export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID   = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const CRON_SECRET  = import.meta.env.CRON_SECRET;
const GITHUB_REPO  = import.meta.env.GITHUB_HOTO_REPO ?? '';
const GITHUB_TOKEN = import.meta.env.GITHUB_HOTO_TOKEN ?? import.meta.env.GITHUB_LETTERS_TOKEN ?? '';
const SENDER_NAME  = 'UTA MACS Society';
const SENDER_EMAIL = import.meta.env.SOCIETY_SENDER_EMAIL ?? 'no-reply@utamacs.org';

const FAILURE_THRESHOLD = 3; // consecutive failures before opening circuit

// GET — ping GitHub API; manage circuit breaker in system_config.
// Runs every 15 minutes. Opens circuit after 3 consecutive failures;
// closes it on first successful ping and notifies committee.
export const GET: APIRoute = async ({ request }) => {
  const t0 = Date.now();
  try {
    if (CRON_SECRET && request.headers.get('authorization') !== `Bearer ${CRON_SECRET}`) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 });
    }

    const sb = getSupabaseServiceClient();

    if (!GITHUB_REPO || !GITHUB_TOKEN) {
      await heartbeat(sb, 'github-health', 'OK', 0, 0, Date.now() - t0, 'GitHub not configured — skipping');
      return Response.json({ status: 'SKIPPED', reason: 'GitHub not configured' });
    }

    // Read current circuit state and failure count
    const [{ data: cbRow }, { data: failRow }] = await Promise.all([
      sb.from('system_config').select('value').eq('key', 'github_circuit_breaker').single(),
      sb.from('system_config').select('value').eq('key', 'github_consecutive_failures').single(),
    ]);

    const wasOpen = (cbRow?.value as string) === 'OPEN';
    const prevFailures = (failRow?.value as number) ?? 0;

    // Attempt GitHub ping
    let githubOk = false;
    let pingError = '';
    try {
      const res = await fetch(`https://api.github.com/repos/${GITHUB_REPO}`, {
        headers: {
          Authorization: `Bearer ${GITHUB_TOKEN}`,
          Accept: 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        signal: AbortSignal.timeout(10_000),
      });
      githubOk = res.ok;
      if (!res.ok) pingError = `HTTP ${res.status}`;
    } catch (err) {
      pingError = err instanceof Error ? err.message.slice(0, 200) : String(err);
    }

    if (githubOk) {
      // Success — reset failures, close circuit if it was open
      await Promise.all([
        sb.from('system_config').update({ value: 0, updated_at: new Date().toISOString() }).eq('key', 'github_consecutive_failures'),
        sb.from('system_config').update({ value: 'CLOSED', updated_at: new Date().toISOString() }).eq('key', 'github_circuit_breaker'),
      ]);

      if (wasOpen) {
        // Notify committee that GitHub storage has recovered
        const committee = await getCommitteeEmails(sb);
        for (const person of committee) {
          await sb.from('email_drafts').insert({
            society_id: SOCIETY_ID,
            tier: 1,
            triggered_by: 'cron:github-health',
            trigger_resource_type: 'system_config',
            trigger_resource_id: 'github_circuit_breaker',
            recipient_type: 'COMMITTEE',
            recipient_email: person.email,
            recipient_name: person.name,
            subject: '[RESOLVED] GitHub document storage is back online',
            body_html: `<p>The GitHub document storage service has recovered. The circuit breaker has been closed and uploads will resume automatically.</p><p>Previous consecutive failures: ${prevFailures}</p>`,
            body_text: `GitHub document storage recovered. Circuit breaker closed. Previous consecutive failures: ${prevFailures}`,
            suggested_sender_name: SENDER_NAME,
            suggested_sender_email: SENDER_EMAIL,
            status: 'DRAFT',
          });
        }
      }

      await heartbeat(sb, 'github-health', 'OK', 1, 0, Date.now() - t0);
      return Response.json({ status: 'OK', circuit: 'CLOSED', wasOpen });
    }

    // Failure — increment counter
    const newFailures = prevFailures + 1;
    await sb.from('system_config').update({
      value: newFailures,
      updated_at: new Date().toISOString(),
    }).eq('key', 'github_consecutive_failures');

    if (newFailures >= FAILURE_THRESHOLD && !wasOpen) {
      // Open circuit breaker
      await sb.from('system_config').update({
        value: 'OPEN',
        updated_at: new Date().toISOString(),
      }).eq('key', 'github_circuit_breaker');

      // Alert committee
      const committee = await getCommitteeEmails(sb);
      for (const person of committee) {
        await sb.from('email_drafts').insert({
          society_id: SOCIETY_ID,
          tier: 1,
          triggered_by: 'cron:github-health',
          trigger_resource_type: 'system_config',
          trigger_resource_id: 'github_circuit_breaker',
          recipient_type: 'COMMITTEE',
          recipient_email: person.email,
          recipient_name: person.name,
          subject: '[ALERT] GitHub document storage unavailable — uploads paused',
          body_html: `<p>GitHub document storage has been unreachable for ${newFailures} consecutive health checks. The circuit breaker is now <strong>OPEN</strong>.</p><p><strong>Impact:</strong> New document uploads are being queued but not committed to GitHub.</p><p><strong>Error:</strong> ${pingError}</p><p>The circuit will automatically close once GitHub becomes reachable again.</p>`,
          body_text: `GitHub document storage is unavailable (${newFailures} consecutive failures). Circuit breaker OPEN. Uploads paused.\n\nError: ${pingError}\n\nThe circuit will close automatically when GitHub recovers.`,
          suggested_sender_name: SENDER_NAME,
          suggested_sender_email: SENDER_EMAIL,
          status: 'DRAFT',
        });
      }

      await heartbeat(sb, 'github-health', 'FAILED', 0, 1, Date.now() - t0, `Circuit opened after ${newFailures} failures: ${pingError}`);
      return Response.json({ status: 'FAILED', circuit: 'OPEN', failures: newFailures, error: pingError });
    }

    await heartbeat(sb, 'github-health', 'FAILED', 0, 1, Date.now() - t0, `Failure ${newFailures}/${FAILURE_THRESHOLD}: ${pingError}`);
    return Response.json({ status: 'FAILED', circuit: wasOpen ? 'OPEN' : 'CLOSED', failures: newFailures, error: pingError });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

async function getCommitteeEmails(sb: ReturnType<typeof getSupabaseServiceClient>) {
  const { data: members } = await sb
    .from('profiles')
    .select('id, full_name, portal_role')
    .eq('society_id', SOCIETY_ID)
    .in('portal_role', ['secretary', 'president'])
    .eq('is_active', true);

  const result: { id: string; name: string; email: string }[] = [];
  for (const m of members ?? []) {
    const { data: auth } = await (sb as any).auth.admin.getUserById(m.id);
    if (auth?.user?.email) result.push({ id: m.id, name: m.full_name, email: auth.user.email });
  }
  return result;
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
