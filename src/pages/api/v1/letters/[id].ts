export const prerender = false;
import type { APIRoute } from 'astro';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { validateJWT } from '@lib/middleware/jwtValidator';
import { normalizeError } from '@lib/middleware/errorNormalizer';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const GITHUB_LETTERS_REPO = import.meta.env.GITHUB_LETTERS_REPO ?? '';
const GITHUB_LETTERS_BRANCH = import.meta.env.GITHUB_LETTERS_BRANCH ?? 'main';

export const GET: APIRoute = async ({ request, params }) => {
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

    // Executives can only view their own letters
    if (user.role === 'executive' && data.created_by !== user.id) {
      throw Object.assign(new Error('Not found'), { status: 404 });
    }

    const baseRaw = `https://raw.githubusercontent.com/${GITHUB_LETTERS_REPO}/${GITHUB_LETTERS_BRANCH}`;
    return new Response(JSON.stringify({
      ...data,
      download_pdf: data.git_path_pdf ? `${baseRaw}/${data.git_path_pdf}` : null,
      download_docx: data.git_path_docx ? `${baseRaw}/${data.git_path_docx}` : null,
    }), { headers: { 'Content-Type': 'application/json' } });
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

    const GITHUB_LETTERS_TOKEN = import.meta.env.GITHUB_LETTERS_TOKEN ?? '';

    // Delete files from GitHub if they exist
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
        body: JSON.stringify({
          message: `Remove letter: ${path}`,
          sha,
          branch: GITHUB_LETTERS_BRANCH,
        }),
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
