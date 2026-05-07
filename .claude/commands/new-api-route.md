# New API Route

Scaffolds a new UTAMACS portal API route under `src/pages/api/v1/` with all mandatory boilerplate: auth, role guard, audit logging, input validation, and error handling.

## Usage
`/new-api-route <path> [GET] [POST] [PATCH] [DELETE] [access: all|exec|admin|guard]`

Examples:
- `/new-api-route gallery/albums GET POST exec`
- `/new-api-route maids/[id]/suspend PATCH exec`
- `/new-api-route visitors/verify-otp POST all`

Arguments:
- `path` — route path relative to `api/v1/`, e.g. `gallery/albums` or `maids/[id]`
- HTTP methods to implement (space-separated)
- `access` — `all` (any authenticated user), `exec` (executive/secretary/president/admin), `admin` (is_admin only), `guard` (security_guard role)

## What this agent does

Read CLAUDE.md sections 7 (API Route Standards) and 5 (Database Standards) before generating anything.

Create `src/pages/api/v1/{path}.ts` with every selected HTTP method. Use the exact template below — do not omit any section.

### Full template

```typescript
export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// UUID validation regex — use for every id param
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

// ─── Access guard helper ──────────────────────────────────────────────────────
// Replace the body of this function based on the access argument:
function isAuthorised(user: { portalRole: string; isAdmin: boolean; role: string }): boolean {
  // exec: return ['executive','secretary','president'].includes(user.portalRole) || user.isAdmin;
  // admin: return user.isAdmin;
  // guard: return user.role === 'security_guard';
  // all: return true;
  return ['executive','secretary','president'].includes(user.portalRole) || user.isAdmin;
}

// ─── GET ─────────────────────────────────────────────────────────────────────
export const GET: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED', message: 'Authentication required' }, { status: 401 });
    if (!isAuthorised(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    // Parse and validate query params
    const url = new URL(request.url);
    // const page = Math.max(1, parseInt(url.searchParams.get('page') ?? '1', 10));
    // const limit = Math.min(100, Math.max(1, parseInt(url.searchParams.get('limit') ?? '50', 10)));

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('{table_name}')
      .select('*')
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false });
      // .range((page - 1) * limit, page * limit - 1);  // pagination

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// ─── POST ────────────────────────────────────────────────────────────────────
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!isAuthorised(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    // Parse body — use request.formData() for file uploads, request.json() for JSON
    const body = await request.json();

    // ── Input validation ──────────────────────────────────────────────────────
    // Validate every field. Return 400 for any validation failure.
    const errors: string[] = [];
    if (!body.name?.trim()) errors.push('name is required');
    // if (!UUID_RE.test(body.some_id)) errors.push('some_id is not a valid UUID');
    if (errors.length > 0) {
      return Response.json({ error: 'VALIDATION_ERROR', message: errors.join('; ') }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('{table_name}')
      .insert({
        society_id: SOCIETY_ID,
        name: body.name.trim(),
        created_by: user.id,
      })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    // ── Audit log — required for all write operations ──────────────────────────
    await writeAuditLog({
      societyId: SOCIETY_ID,
      userId: user.id,
      action: 'CREATE',
      resourceType: '{table_name}',
      resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { name: data.name },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// ─── PATCH ───────────────────────────────────────────────────────────────────
export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!isAuthorised(user)) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    // Validate URL param id
    const id = params.id;
    if (!id || !UUID_RE.test(id)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Invalid or missing id' }, { status: 400 });
    }

    const body = await request.json();
    const sb = getSupabaseServiceClient();

    // Fetch existing record (verifies it belongs to this society)
    const { data: existing, error: fetchErr } = await sb
      .from('{table_name}')
      .select('*')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (fetchErr || !existing) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    // Build safe update payload — only include fields that are actually updatable
    const updates: Record<string, unknown> = { updated_at: new Date().toISOString() };
    if (body.name !== undefined) updates.name = body.name.trim();
    // Add other updatable fields here

    const { data, error } = await sb
      .from('{table_name}')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID,
      userId: user.id,
      action: 'UPDATE',
      resourceType: '{table_name}',
      resourceId: id,
      ip: extractClientIP(request),
      oldValues: existing,
      newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// ─── DELETE ──────────────────────────────────────────────────────────────────
// Use soft delete (set is_active = false) rather than hard delete where possible.
// Hard delete only when data has no references and is_admin access is required.
export const DELETE: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    if (!user.isAdmin) return Response.json({ error: 'FORBIDDEN', message: 'Admin only' }, { status: 403 });

    const id = params.id;
    if (!id || !UUID_RE.test(id)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Invalid id' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();

    const { data: existing } = await sb
      .from('{table_name}')
      .select('*')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!existing) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    // Prefer soft delete:
    const { error } = await sb
      .from('{table_name}')
      .update({ is_active: false })
      .eq('id', id);

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID,
      userId: user.id,
      action: 'DELETE',
      resourceType: '{table_name}',
      resourceId: id,
      ip: extractClientIP(request),
      oldValues: existing,
    });

    return new Response(null, { status: 204 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
```

### File upload variant (for POST routes that accept files)

When the route accepts `multipart/form-data`, replace the JSON body parsing block with:

```typescript
import { SupabaseStorageService } from '@lib/services/providers/supabase/SupabaseStorageService';

// Inside POST handler, after auth:
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

// Validate MIME type
const ALLOWED_MIME: Record<string, string> = {
  'application/pdf': 'pdf',
  'image/jpeg': 'jpg',
  'image/png': 'png',
};
const ext = ALLOWED_MIME[file.type];
if (!ext) {
  return Response.json({
    error: 'VALIDATION_ERROR',
    message: `File type not allowed. Permitted: PDF, JPEG, PNG`,
  }, { status: 400 });
}

// Validate size (5 MB default — adjust per bucket)
const bytes = await file.arrayBuffer();
if (bytes.byteLength > 5 * 1024 * 1024) {
  return Response.json({ error: 'VALIDATION_ERROR', message: 'File exceeds 5MB limit' }, { status: 400 });
}

// Upload to Supabase Storage — NEVER write to filesystem
const storageKey = `{module}/${SOCIETY_ID}/${crypto.randomUUID()}.${ext}`;
const storageService = new SupabaseStorageService();
const { storageKey: savedKey } = await storageService.upload(
  '{bucket-name}',   // must match an approved bucket in CLAUDE.md section 4C
  storageKey,
  Buffer.from(bytes),
  file.type,
);

// savedKey (not a URL) goes into the database
```

### After generating the file

Tell the user:
1. The file path created
2. Which placeholder table name (`{table_name}`) and bucket (`{bucket-name}`) they must replace
3. To run `/standards-review src/pages/api/v1/{path}.ts` before committing
