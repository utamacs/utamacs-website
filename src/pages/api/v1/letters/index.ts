export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { generateDocxBuffer } from '@lib/utils/docxGenerator';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const GITHUB_LETTERS_REPO = import.meta.env.GITHUB_LETTERS_REPO ?? '';
const GITHUB_LETTERS_TOKEN = import.meta.env.GITHUB_LETTERS_TOKEN ?? '';
const GITHUB_LETTERS_BRANCH = import.meta.env.GITHUB_LETTERS_BRANCH ?? 'main';

function requireExecOrAdmin(role: string) {
  if (!['executive', 'admin'].includes(role)) {
    throw Object.assign(new Error('Only executive and admin can manage letters'), { status: 403 });
  }
}

// Build an organised GitHub file path: letters/YYYY/MM-MonthName/YYYYMMDD-slug.ext
function buildGitPath(title: string, date: Date, ext: 'pdf' | 'docx'): string {
  const yyyy = date.getFullYear().toString();
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const monthName = months[date.getMonth()];
  const dd = String(date.getDate()).padStart(2, '0');

  const slug = title
    .toLowerCase()
    .replace(/[^a-z0-9\s-]/g, '')
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-')
    .slice(0, 60)
    .replace(/-$/, '');

  return `letters/${yyyy}/${mm}-${monthName}/${yyyy}${mm}${dd}-${slug}.${ext}`;
}

// Commit a base64-encoded file to the private GitHub letters repo
async function commitToGitHub(
  path: string,
  contentBase64: string,
  commitMessage: string,
): Promise<{ sha: string }> {
  if (!GITHUB_LETTERS_REPO || !GITHUB_LETTERS_TOKEN) {
    throw Object.assign(
      new Error('GitHub letters repo is not configured. Set GITHUB_LETTERS_REPO and GITHUB_LETTERS_TOKEN.'),
      { status: 503 },
    );
  }

  const url = `https://api.github.com/repos/${GITHUB_LETTERS_REPO}/contents/${path}`;

  // Check if file already exists (to get its SHA for update)
  let existingSha: string | undefined;
  const checkRes = await fetch(url, {
    headers: {
      Authorization: `Bearer ${GITHUB_LETTERS_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
  });
  if (checkRes.ok) {
    const existing = await checkRes.json() as { sha?: string };
    existingSha = existing.sha;
  }

  const body: Record<string, unknown> = {
    message: commitMessage,
    content: contentBase64,
    branch: GITHUB_LETTERS_BRANCH,
  };
  if (existingSha) body.sha = existingSha;

  const res = await fetch(url, {
    method: 'PUT',
    headers: {
      Authorization: `Bearer ${GITHUB_LETTERS_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
      'X-GitHub-Api-Version': '2022-11-28',
    },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const text = await res.text();
    throw Object.assign(new Error(`GitHub commit failed (${res.status}): ${text}`), { status: 502 });
  }

  const json = await res.json() as { content: { sha: string } };
  return { sha: json.content.sha };
}

// ─── GET /api/v1/letters ──────────────────────────────────────────────────────
export const GET: APIRoute = async ({ request, url }) => {
  try {
    const user = await validateJWT(request);
    requireExecOrAdmin(user.role);

    const sb = getSupabaseServiceClient();
    const limit = Math.min(Number(url.searchParams.get('limit') ?? 30), 100);
    const offset = Number(url.searchParams.get('offset') ?? 0);

    let query = sb
      .from('generated_letters')
      .select('id, title, subject, recipient, git_repo, git_path_pdf, git_path_docx, signatures_used, created_at, created_by, letterhead_templates(name)', { count: 'exact' })
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false })
      .range(offset, offset + limit - 1);

    // Non-admin executives see only their own letters
    if (user.role === 'executive') {
      query = query.eq('created_by', user.id);
    }

    const { data, error, count } = await query;
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(JSON.stringify({ letters: data ?? [], total: count ?? 0 }), {
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// ─── POST /api/v1/letters  ────────────────────────────────────────────────────
// Receives pre-generated PDF+DOCX as base64, commits to GitHub, saves metadata in DB.
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await validateJWT(request);
    requireExecOrAdmin(user.role);

    const body = await request.json() as {
      template_id?: string;
      title?: string;
      subject?: string;
      recipient?: string;
      field_values?: Record<string, string>;
      signatures_used?: string[];
      pdf_base64?: string;
    };

    const { template_id, title, subject, recipient, field_values, signatures_used, pdf_base64 } = body;

    if (!title?.trim()) {
      return new Response(JSON.stringify({ error: 'title is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    if (!pdf_base64) {
      return new Response(JSON.stringify({ error: 'pdf_base64 is required' }), {
        status: 400, headers: { 'Content-Type': 'application/json' },
      });
    }

    const sb = getSupabaseServiceClient();
    const now = new Date();
    const commitMsg = `Add letter: ${sanitizePlainText(title.trim())} (${now.toISOString().slice(0, 10)})`;

    // Fetch full template so we can generate the DOCX server-side.
    // (The browser cannot import 'docx' — it's a Node.js package.)
    const { data: template } = await sb
      .from('letterhead_templates')
      .select('*, letterhead_committee_members(*)')
      .eq('id', template_id!)
      .single();

    let pdfPath: string | null = null;
    let pdfSha: string | null = null;
    let docxPath: string | null = null;
    let docxSha: string | null = null;

    // Commit PDF
    pdfPath = buildGitPath(title.trim(), now, 'pdf');
    const pdfResult = await commitToGitHub(pdfPath, pdf_base64, `${commitMsg} [PDF]`);
    pdfSha = pdfResult.sha;

    // Generate and commit DOCX server-side
    if (template) {
      const signatories = (signatures_used ?? []).map(d => ({ designation: d }));
      const docxBuf = await generateDocxBuffer(template, field_values ?? {}, signatories);
      const docx_base64 = docxBuf.toString('base64');
      docxPath = buildGitPath(title.trim(), now, 'docx');
      const docxResult = await commitToGitHub(docxPath, docx_base64, `${commitMsg} [DOCX]`);
      docxSha = docxResult.sha;
    }

    // Save metadata in DB
    const { data, error } = await sb
      .from('generated_letters')
      .insert({
        society_id: SOCIETY_ID,
        template_id: template_id ?? null,
        title: sanitizePlainText(title.trim()),
        subject: subject ? sanitizePlainText(subject.trim()) : null,
        recipient: recipient ? sanitizePlainText(recipient.trim()) : null,
        git_repo: GITHUB_LETTERS_REPO,
        git_path_pdf: pdfPath,
        git_path_docx: docxPath,
        git_sha_pdf: pdfSha,
        git_sha_docx: docxSha,
        field_values: field_values ?? {},
        signatures_used: signatures_used ?? [],
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // Build GitHub raw download URLs for immediate use
    const baseRaw = `https://raw.githubusercontent.com/${GITHUB_LETTERS_REPO}/${GITHUB_LETTERS_BRANCH}`;
    return new Response(JSON.stringify({
      ...data,
      download_pdf: pdfPath ? `${baseRaw}/${pdfPath}` : null,
      download_docx: docxPath ? `${baseRaw}/${docxPath}` : null,
    }), { status: 201, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
