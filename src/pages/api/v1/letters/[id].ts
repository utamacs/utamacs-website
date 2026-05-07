export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { sanitizePlainText } from '@lib/utils/sanitize';
import { generateDocxBuffer } from '@lib/utils/docxGenerator';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const GITHUB_LETTERS_REPO = import.meta.env.GITHUB_LETTERS_REPO ?? '';
const GITHUB_LETTERS_BRANCH = import.meta.env.GITHUB_LETTERS_BRANCH ?? 'main';
const GITHUB_LETTERS_TOKEN = import.meta.env.GITHUB_LETTERS_TOKEN ?? '';

async function commitToGitHub(path: string, contentBase64: string, commitMessage: string): Promise<{ sha: string }> {
  const url = `https://api.github.com/repos/${GITHUB_LETTERS_REPO}/contents/${path}`;
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
  const body: Record<string, unknown> = { message: commitMessage, content: contentBase64, branch: GITHUB_LETTERS_BRANCH };
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

export const GET: APIRoute = async ({ request, params, url }) => {
  try {
    const user = await validateJWT(request);

    if (!['executive', 'admin'].includes(user.role)) {
      throw Object.assign(new Error('Forbidden'), { status: 403 });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('generated_letters')
      .select('*, letterhead_templates(name, is_default)')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: error.code === 'PGRST116' ? 404 : 500 });

    if (user.role === 'executive' && data.created_by !== user.id) {
      throw Object.assign(new Error('Not found'), { status: 404 });
    }

    // Proxy download: ?format=pdf or ?format=docx
    const format = url.searchParams.get('format') as 'pdf' | 'docx' | null;
    if (format === 'pdf' || format === 'docx') {
      const gitPath = format === 'pdf' ? data.git_path_pdf : data.git_path_docx;
      if (!gitPath || !GITHUB_LETTERS_REPO || !GITHUB_LETTERS_TOKEN) {
        return new Response(JSON.stringify({ error: 'File not available' }), {
          status: 404, headers: { 'Content-Type': 'application/json' },
        });
      }
      const ghRes = await fetch(
        `https://api.github.com/repos/${GITHUB_LETTERS_REPO}/contents/${gitPath}`,
        {
          headers: {
            Authorization: `Bearer ${GITHUB_LETTERS_TOKEN}`,
            Accept: 'application/vnd.github.raw+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        },
      );
      if (!ghRes.ok) {
        return new Response(JSON.stringify({ error: 'File not found in repository' }), {
          status: 404, headers: { 'Content-Type': 'application/json' },
        });
      }
      const contentType = format === 'pdf'
        ? 'application/pdf'
        : 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      const filename = `${data.title ?? 'letter'}.${format}`;

      // Non-blocking download receipt: increment counter + set last_downloaded_at
      Promise.resolve(
        sb.from('generated_letters').update({
          download_count: (data.download_count ?? 0) + 1,
          last_downloaded_at: new Date().toISOString(),
        }).eq('id', params.id!),
      ).catch(() => {});

      return new Response(ghRes.body, {
        headers: {
          'Content-Type': contentType,
          'Content-Disposition': `attachment; filename="${encodeURIComponent(filename)}"`,
        },
      });
    }

    return new Response(JSON.stringify(data), { headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);
    if (!['executive', 'admin'].includes(user.role)) {
      throw Object.assign(new Error('Forbidden'), { status: 403 });
    }

    const sb = getSupabaseServiceClient();
    const { data: existing, error: fetchErr } = await sb
      .from('generated_letters')
      .select('id, template_id, git_path_pdf, git_path_docx, created_by')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !existing) {
      return new Response(JSON.stringify({ error: 'Letter not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }
    if (user.role === 'executive' && existing.created_by !== user.id) {
      throw Object.assign(new Error('Forbidden'), { status: 403 });
    }

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

    const now = new Date();
    const commitMsg = `Update letter: ${sanitizePlainText(title.trim())} (${now.toISOString().slice(0, 10)})`;
    const usedTemplateId = template_id ?? existing.template_id;

    const { data: template } = await sb
      .from('letterhead_templates')
      .select('*, letterhead_committee_members(*)')
      .eq('id', usedTemplateId)
      .single();

    let pdfSha: string | null = null;
    let docxSha: string | null = null;

    if (existing.git_path_pdf && GITHUB_LETTERS_REPO && GITHUB_LETTERS_TOKEN) {
      const r = await commitToGitHub(existing.git_path_pdf, pdf_base64, `${commitMsg} [PDF]`);
      pdfSha = r.sha;
    }

    if (template && existing.git_path_docx && GITHUB_LETTERS_REPO && GITHUB_LETTERS_TOKEN) {
      const signatories = (signatures_used ?? []).map(d => ({ designation: d }));
      const docxBuf = await generateDocxBuffer(template, field_values ?? {}, signatories);
      const docx_base64 = docxBuf.toString('base64');
      const r = await commitToGitHub(existing.git_path_docx, docx_base64, `${commitMsg} [DOCX]`);
      docxSha = r.sha;
    }

    const updatePayload: Record<string, unknown> = {
      template_id: usedTemplateId,
      title: sanitizePlainText(title.trim()),
      subject: subject ? sanitizePlainText(subject.trim()) : null,
      recipient: recipient ? sanitizePlainText(recipient.trim()) : null,
      field_values: field_values ?? {},
      signatures_used: signatures_used ?? [],
    };
    if (pdfSha) updatePayload.git_sha_pdf = pdfSha;
    if (docxSha) updatePayload.git_sha_docx = docxSha;

    const { data, error } = await sb
      .from('generated_letters')
      .update(updatePayload)
      .eq('id', params.id!)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return new Response(JSON.stringify(data), { status: 200, headers: { 'Content-Type': 'application/json' } });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await validateJWT(request);

    if (user.role !== 'admin') {
      throw Object.assign(new Error('Only admin can delete letters'), { status: 403 });
    }

    const sb = getSupabaseServiceClient();
    const { data: existing, error: checkErr } = await sb
      .from('generated_letters')
      .select('id, git_path_pdf, git_path_docx, git_sha_pdf, git_sha_docx')
      .eq('id', params.id!)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (checkErr || !existing) {
      return new Response(JSON.stringify({ error: 'Letter not found' }), {
        status: 404, headers: { 'Content-Type': 'application/json' },
      });
    }

    async function deleteFromGitHub(path: string, sha: string) {
      if (!GITHUB_LETTERS_TOKEN || !GITHUB_LETTERS_REPO) return;
      await fetch(`https://api.github.com/repos/${GITHUB_LETTERS_REPO}/contents/${path}`, {
        method: 'DELETE',
        headers: {
          Authorization: `Bearer ${GITHUB_LETTERS_TOKEN}`,
          Accept: 'application/vnd.github+json',
          'Content-Type': 'application/json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        body: JSON.stringify({ message: `Remove letter: ${path}`, sha, branch: GITHUB_LETTERS_BRANCH }),
      });
    }

    if (existing.git_path_pdf && existing.git_sha_pdf) {
      await deleteFromGitHub(existing.git_path_pdf, existing.git_sha_pdf);
    }
    if (existing.git_path_docx && existing.git_sha_docx) {
      await deleteFromGitHub(existing.git_path_docx, existing.git_sha_docx);
    }

    const { error } = await sb.from('generated_letters').delete().eq('id', params.id!);
    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
