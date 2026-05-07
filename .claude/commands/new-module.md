# Scaffold a New Portal Module

Creates all boilerplate files for a new UTAMACS portal module — page, API routes, migration stub, and feature flag seed — following every standard in CLAUDE.md.

## Usage
`/new-module <module-key> "<Display Name>" <icon-class> [exec-only|all|guard]`

Examples:
- `/new-module gallery "Photo Gallery" fa-images all`
- `/new-module maids "Domestic Help" fa-user-friends all`
- `/new-module refund-rules "Refund Rules" fa-undo exec-only`

Arguments:
- `module-key` — kebab-case key, e.g. `gallery`, `maids`, `refund-rules`
- `Display Name` — quoted human label shown in sidebar
- `icon-class` — Font Awesome class without `fas `, e.g. `fa-images`
- `access` — `all` (authenticated members), `exec-only` (executive/admin), `guard` (security guard)

## What this agent does

Read CLAUDE.md fully before generating any file. Then create the following files exactly, substituting the provided arguments. Never use placeholder text — all class names, imports, and patterns must match the existing codebase.

---

### File 1: `src/pages/portal/{module-key}/index.astro`

```astro
---
export const prerender = false;
import PortalLayout from '@components/portal/PortalLayout.astro';
import { resolveFromRequest } from '@lib/permissions';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const user = await resolveFromRequest(Astro.request, SOCIETY_ID);
if (!user) return Astro.redirect('/portal/login');

// ACCESS GATE — adjust based on the access argument:
// exec-only:
const isPrivileged = ['executive','secretary','president'].includes(user.portalRole) || user.isAdmin;
if (!isPrivileged) return new Response('Forbidden', { status: 403 });
// all: remove the gate above
// guard: if (user.role !== 'security_guard' && !isPrivileged) return new Response('Forbidden', { status: 403 });

const sb = getSupabaseServiceClient();

// Fetch initial data server-side
const { data: items, error } = await sb
  .from('{table-name}')
  .select('*')
  .eq('society_id', SOCIETY_ID)
  .order('created_at', { ascending: false });

if (error) console.error('[{module-key}]', error.message);
---
<PortalLayout title="{Display Name}" user={user} activeModule="{module-key}">
  <!-- Page header -->
  <div class="flex items-center justify-between mb-6">
    <div>
      <h1 class="text-2xl font-bold text-primary-600 font-poppins">{Display Name}</h1>
      <p class="text-text-secondary text-sm mt-1">Manage {display name} for Urban Trilla Apartments</p>
    </div>
    {isPrivileged && (
      <button class="btn-primary" id="create-btn" aria-label="Create new {display name}">
        <i class="fas fa-plus mr-2" aria-hidden="true"></i>New {Display Name}
      </button>
    )}
  </div>

  <!-- How it works — collapsible info panel (collapsed by default) -->
  <details class="card-premium mb-6">
    <summary class="p-4 cursor-pointer font-medium text-primary-600 flex items-center gap-2">
      <i class="fas fa-info-circle" aria-hidden="true"></i>
      How {Display Name} works
    </summary>
    <div class="px-4 pb-4 text-sm text-text-secondary">
      <p>Describe the workflow here.</p>
    </div>
  </details>

  <!-- Content -->
  {items && items.length > 0 ? (
    <div class="space-y-4">
      {items.map(item => (
        <div class="card-premium p-4">
          <p class="font-medium text-text-primary">{item.id}</p>
        </div>
      ))}
    </div>
  ) : (
    <div class="text-center py-16">
      <i class="fas fa-{icon-class} text-5xl text-primary-200 mb-4" aria-hidden="true"></i>
      <h3 class="text-lg font-semibold text-text-primary mb-2">No {display name} yet</h3>
      <p class="text-text-secondary text-sm mb-4">
        {isPrivileged ? 'Create the first one using the button above.' : 'Check back later.'}
      </p>
    </div>
  )}

  <!-- Right-side detail drawer -->
  <div id="detail-panel"
       class="fixed inset-y-0 right-0 w-full sm:w-96 lg:w-[480px] bg-white shadow-large z-40
              transform translate-x-full transition-transform duration-300 overflow-y-auto">
    <div class="sticky top-0 bg-white border-b border-border-light p-4 flex items-center justify-between">
      <h2 class="text-lg font-semibold text-primary-600" id="panel-title">{Display Name} Detail</h2>
      <button id="close-panel" class="text-text-secondary hover:text-text-primary"
              aria-label="Close panel">
        <i class="fas fa-times text-xl" aria-hidden="true"></i>
      </button>
    </div>
    <div class="p-4" id="panel-content">
      <!-- Populated by JS -->
    </div>
  </div>
  <div id="panel-backdrop" class="fixed inset-0 bg-black/40 z-30 hidden"></div>
</PortalLayout>

<script>
  // Drawer open/close
  const panel = document.getElementById('detail-panel')
  const backdrop = document.getElementById('panel-backdrop')
  const closeBtn = document.getElementById('close-panel')

  function openPanel() {
    panel?.classList.remove('translate-x-full')
    backdrop?.classList.remove('hidden')
    document.body.style.overflow = 'hidden'
  }
  function closePanel() {
    panel?.classList.add('translate-x-full')
    backdrop?.classList.add('hidden')
    document.body.style.overflow = ''
  }

  closeBtn?.addEventListener('click', closePanel)
  backdrop?.addEventListener('click', closePanel)
  document.addEventListener('keydown', e => { if (e.key === 'Escape') closePanel() })

  // Toast helper
  function showToast(message, type = 'success') {
    const toast = document.createElement('div')
    const color = type === 'success' ? 'bg-secondary-500' : 'bg-red-500'
    toast.className = `fixed bottom-6 right-6 z-50 px-4 py-3 rounded-xl shadow-large
      text-sm font-medium text-white transform translate-y-4 opacity-0
      transition-all duration-300 ${color}`
    toast.textContent = message
    document.body.appendChild(toast)
    requestAnimationFrame(() => toast.classList.remove('translate-y-4', 'opacity-0'))
    setTimeout(() => {
      toast.classList.add('translate-y-4', 'opacity-0')
      setTimeout(() => toast.remove(), 300)
    }, 3000)
  }

  // API call helper
  async function apiCall(url, method = 'GET', body = null) {
    const opts = { method, headers: { 'Content-Type': 'application/json' } }
    if (body) opts.body = JSON.stringify(body)
    const res = await fetch(url, opts)
    if (!res.ok) {
      const err = await res.json().catch(() => ({ error: 'Request failed' }))
      throw new Error(err.message || `HTTP ${res.status}`)
    }
    return res.json()
  }

  // Wire up create button
  document.getElementById('create-btn')?.addEventListener('click', () => {
    document.getElementById('panel-title').textContent = 'New {Display Name}'
    document.getElementById('panel-content').innerHTML = `
      <form id="create-form" class="space-y-4">
        <!-- Add form fields here -->
        <div>
          <label class="form-label">Name</label>
          <input type="text" name="name" class="form-input" required />
        </div>
        <div class="flex gap-3 pt-2">
          <button type="submit" class="btn-primary flex-1">Save</button>
          <button type="button" class="btn-outline flex-1" id="cancel-btn">Cancel</button>
        </div>
      </form>
    `
    openPanel()
    document.getElementById('cancel-btn')?.addEventListener('click', closePanel)
    document.getElementById('create-form')?.addEventListener('submit', async e => {
      e.preventDefault()
      const data = Object.fromEntries(new FormData(e.target))
      try {
        await apiCall('/api/v1/{module-key}', 'POST', data)
        showToast('{Display Name} created successfully')
        closePanel()
        window.location.reload()
      } catch (err) {
        showToast(err.message, 'error')
      }
    })
  })
</script>
```

---

### File 2: `src/pages/api/v1/{module-key}/index.ts`

```typescript
export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

// GET — list all {module-key} records for the society
export const GET: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('{table-name}')
      .select('*')
      .eq('society_id', SOCIETY_ID)
      .order('created_at', { ascending: false });

    if (error) throw Object.assign(new Error(error.message), { status: 500 });
    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};

// POST — create a new {module-key} record (exec only)
export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole) || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const body = await request.json();
    // Validate required fields
    const { name } = body;
    if (!name?.trim()) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'name is required' }, { status: 400 });
    }

    const sb = getSupabaseServiceClient();
    const { data, error } = await sb
      .from('{table-name}')
      .insert({ society_id: SOCIETY_ID, name: name.trim(), created_by: user.id })
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'CREATE', resourceType: '{table-name}', resourceId: data.id,
      ip: extractClientIP(request),
      newValues: { name: data.name },
    });

    return Response.json(data, { status: 201 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
```

---

### File 3: `src/pages/api/v1/{module-key}/[id].ts`

```typescript
export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest } from '@lib/permissions';
import { getSupabaseServiceClient } from '@lib/services/providers/supabase/SupabaseDB';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export const PATCH: APIRoute = async ({ request, params }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });

    const isPrivileged = ['executive','secretary','president'].includes(user.portalRole) || user.isAdmin;
    if (!isPrivileged) return Response.json({ error: 'FORBIDDEN' }, { status: 403 });

    const id = params.id;
    if (!id || !UUID_RE.test(id)) {
      return Response.json({ error: 'VALIDATION_ERROR', message: 'Invalid ID' }, { status: 400 });
    }

    const body = await request.json();
    const sb = getSupabaseServiceClient();

    const { data: existing } = await sb
      .from('{table-name}')
      .select('*')
      .eq('id', id)
      .eq('society_id', SOCIETY_ID)
      .single();

    if (!existing) return Response.json({ error: 'NOT_FOUND' }, { status: 404 });

    const updates: Record<string, unknown> = {};
    if (body.name !== undefined) updates.name = body.name.trim();
    // Add other updatable fields here

    const { data, error } = await sb
      .from('{table-name}')
      .update(updates)
      .eq('id', id)
      .select()
      .single();

    if (error) throw Object.assign(new Error(error.message), { status: 500 });

    await writeAuditLog({
      societyId: SOCIETY_ID, userId: user.id,
      action: 'UPDATE', resourceType: '{table-name}', resourceId: id,
      ip: extractClientIP(request),
      oldValues: existing, newValues: updates,
    });

    return Response.json(data);
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
```

---

### File 4: Migration stub `supabase/migrations/{next-seq}_{module-key}.sql`

Before writing this file, read the `supabase/migrations/` directory listing to find the current highest sequence number. Use that number + 1.

```sql
-- Migration: {next-seq}_{module-key}
-- Purpose: Add {Display Name} module tables

CREATE TABLE {table-name} (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  name        text NOT NULL CHECK (length(name) BETWEEN 1 AND 255),
  -- personal data: none  (add comment if this table has personal data columns)
  created_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_{table-name}_society ON {table-name}(society_id);

ALTER TABLE {table-name} ENABLE ROW LEVEL SECURITY;

-- All authenticated society members can read
CREATE POLICY "society_read_{table-name}" ON {table-name} FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

-- Executives and admins can write
CREATE POLICY "exec_manage_{table-name}" ON {table-name} FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));
```

---

### File 5: Feature flag seed addition

Add to the most recent feature flag seed migration, or create a new migration:

```sql
INSERT INTO feature_flags (society_id, module_key, is_active, display_order)
SELECT id, '{module-key}', true, (SELECT COALESCE(MAX(display_order), 0) + 1 FROM feature_flags WHERE society_id = societies.id)
FROM societies
ON CONFLICT (society_id, module_key) DO NOTHING;
```

---

### File 6: PortalLayout registration

Open `src/components/portal/PortalLayout.astro` and add to the fallback modules array:

```typescript
{ key: '{module-key}', displayName: '{Display Name}', icon: 'fas {icon-class}', path: '/portal/{module-key}' }
```

---

## After scaffolding

Tell the user:
1. Which files were created
2. The table name used (they need to replace `{table-name}` placeholders with actual columns)
3. The migration sequence number used
4. That they should run `/standards-review src/pages/portal/{module-key}/` before committing
