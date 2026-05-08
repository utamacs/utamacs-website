# UTA MACS — Claude Context & Mandatory Standards

> These rules are **non-negotiable**. Every implementation decision, every file written,
> every API route, every SQL migration must conform to these standards. When in doubt,
> read this file before writing any code.

---

## 1. Project Identity

**Name**: UTA MACS — Urban Trilla Apartment Owners Mutually Aided Cooperative Maintenance Society Limited  
**Location**: Kondakal, Shankarpalle, Ranga Reddy District, Telangana  
**Public site**: `utamacs.org` (GitHub Pages, `docs/` folder)  
**Resident portal**: `portal.utamacs.org` (Vercel serverless, Astro hybrid)

**FORBIDDEN**: Never reference competitor products, third-party society management platforms, or any specific external system by name in code, comments, commit messages, UI text, or documentation. Features are designed for UTAMACS residents — not derived from, compared with, or named after any other platform. If a feature idea came from a specification document, implement it with UTAMACS identity and never acknowledge the source system.

---

## 2. Architecture — Two Separate Systems

### 2A. Public Website (`src/site/` → `docs/`)
- Pure static HTML + Tailwind CSS v3 + Vanilla JS
- No frameworks, no npm dependencies at runtime
- Built with: `npm run build` → `docs/`
- Served by: GitHub Pages at `utamacs.org`

### 2B. Resident Portal (`src/` → Vercel)
- **Astro 4** with `output: 'hybrid'` (SSR + static prerender)
- **React 18** for interactive dashboard components only
- **Tailwind CSS v3** via `@astrojs/tailwind`
- **Supabase** for auth and database only (NOT file storage — see §4)
- **pdfmake** for server-side PDF generation (invoice, receipt, poll export)
- **Vercel** adapter — every portal page has `export const prerender = false`

### 2C. Build Scripts
| Script | What it does |
|--------|-------------|
| `npm run dev` | Portal dev server (Astro) |
| `npm run build` | Public site build → `docs/` |
| `npm run build:portal` | Portal build → Vercel |
| `npm run supabase:types` | Generate TypeScript types from Supabase schema |

---

## 3. Design System — Mandatory Tokens

**NEVER** use raw hex colours, hardcoded font sizes, or arbitrary Tailwind values in portal pages. Always use the design system tokens below.

### 3A. Colour Tokens (`tailwind.config.cjs`)
| Token | Hex | Semantic Use |
|-------|-----|-------------|
| `primary-600` | `#1E3A8A` | CTAs, active nav, headings, primary actions |
| `primary-50`  | (light blue) | Hover backgrounds, info banners |
| `primary-100` | (light blue) | Icon backgrounds, subtle fills |
| `secondary-500` | `#10B981` | Success states, secondary CTAs, positive indicators |
| `accent-500` | `#F59E0B` | Warnings, amber badges, attention |
| `background` | `#FFFFFF` | Page background |
| `section-alt` | `#F8FAFC` | Alternating section backgrounds |
| `text-primary` | `#111827` | All body text |
| `text-secondary` | `#4B5563` | Muted, supporting, metadata |
| `border-light` | `#E5E7EB` | Subtle borders, dividers |

Status colours (use directly, not design token names):
- Danger/Destructive: `red-600`, `red-500`, `red-100`, `red-700`
- Warning: `amber-500`, `amber-600`, `amber-50`
- Info: `blue-500`, `blue-50`

### 3B. Typography
- **Display / Headings**: `font-poppins` — `text-2xl font-bold text-primary-600 font-poppins`
- **Body**: `font-inter` (default sans) — all prose, labels, descriptions
- **Custom scale**: `text-hero`, `text-section`, `text-card`, `text-body`, `text-small`, `text-button`
- Section heading in portal: `text-2xl font-bold text-primary-600 font-poppins`
- Sub-heading: `text-lg font-semibold text-text-primary`
- Label: `text-sm font-medium text-text-secondary`

### 3C. Component Classes (from `src/styles/global.css`)
Use these classes — never re-implement the same styles inline.

**Cards:**
- `.card-premium` — standard content card (white, rounded-xl, shadow-soft, hover:shadow-medium)
- `.card-hero` — hero/featured card (rounded-2xl, shadow-large)
- `.card-feature` — centred icon + content card
- `.card-stats` — stat display card with `.number` and `.label` children

**Buttons:**
- `.btn-primary` — primary action (primary-600 bg, white text, rounded-xl)
- `.btn-secondary` — secondary action (secondary-500 bg)
- `.btn-outline` — outlined action (border-2 border-primary-600)
- `.btn-ghost` — ghost (transparent, hover bg-primary-50)

**Forms:**
- `.form-input` — all text/select/textarea inputs (w-full, px-4 py-3, border-border-light, focus:ring-primary-600)
- `.form-label` — all labels (block, text-sm, font-medium, mb-2)
- `.form-error` — validation error messages (text-sm, text-red-600)

**Shadows:** `shadow-soft` < `shadow-medium` < `shadow-large` < `shadow-glow`

### 3D. Standard UI Patterns

**Page header** (every portal page):
```html
<div class="flex items-center justify-between mb-6">
  <div>
    <h1 class="text-2xl font-bold text-primary-600 font-poppins">{Title}</h1>
    <p class="text-text-secondary text-sm mt-1">{Subtitle}</p>
  </div>
  <!-- Primary action button, exec-gated if write operation -->
</div>
```

**Status badge:**
```html
<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium {color-classes}">
  {status}
</span>
```

**Empty state:**
```html
<div class="text-center py-16">
  <i class="fas fa-{icon} text-5xl text-primary-200 mb-4" aria-hidden="true"></i>
  <h3 class="text-lg font-semibold text-text-primary mb-2">{No items yet}</h3>
  <p class="text-text-secondary text-sm mb-4">{Helpful description}</p>
</div>
```

**Detail drawer** (right-side panel, not a modal, for detail views):
```html
<div id="detail-panel" class="fixed inset-y-0 right-0 w-full sm:w-96 lg:w-[480px] bg-white
     shadow-large z-40 transform translate-x-full transition-transform duration-300 overflow-y-auto">
  <div class="sticky top-0 bg-white border-b border-border-light p-4 flex items-center justify-between">
    <h2 class="text-lg font-semibold text-primary-600">{Title}</h2>
    <button id="close-panel" class="text-text-secondary hover:text-text-primary" aria-label="Close panel">
      <i class="fas fa-times text-xl" aria-hidden="true"></i>
    </button>
  </div>
  <div class="p-4"><!-- content --></div>
</div>
<div id="panel-backdrop" class="fixed inset-0 bg-black/40 z-30 hidden"></div>
```

**Toast notification** (call from vanilla JS):
```javascript
function showToast(message, type = 'success') {
  const toast = document.createElement('div')
  const color = type === 'success' ? 'bg-secondary-500' : 'bg-red-500'
  toast.className = `fixed bottom-6 right-6 z-50 px-4 py-3 rounded-xl shadow-large
    text-sm font-medium text-white transform translate-y-4 opacity-0 transition-all duration-300 ${color}`
  toast.textContent = message
  document.body.appendChild(toast)
  requestAnimationFrame(() => toast.classList.remove('translate-y-4', 'opacity-0'))
  setTimeout(() => {
    toast.classList.add('translate-y-4', 'opacity-0')
    setTimeout(() => toast.remove(), 300)
  }, 3000)
}
```

---

## 4. File Upload & Storage — CRITICAL RULE

**RULE: ALL user-uploaded files — documents AND media (images, banners, avatars) — go to the private GitHub repository via API. Supabase Storage is NOT used for file uploads.**

Files are committed to the private `GITHUB_DOCS_REPO` by `commitDocument()`. GitHub's API returns an AWS pre-signed `download_url` (~1-hour validity) that is functionally equivalent to a Supabase signed URL. The DB column stores the GitHub file path; the API generates a fresh download URL on each request.

### 4A. Standard Upload Pattern (all modules)

```typescript
import { commitDocument, getDocumentDownloadUrl, docPath } from '@lib/utils/githubDocStore';

// 1. Read + validate file from multipart/form-data
const file = formData.get('file') as File;
const bytes = await file.arrayBuffer();
const buffer = Buffer.from(bytes);
const ALLOWED_MIME: Record<string, string> = { 'application/pdf': 'pdf', 'image/jpeg': 'jpg', 'image/png': 'png' };
if (!ALLOWED_MIME[file.type]) return Response.json({ error: 'VALIDATION', message: 'File type not allowed' }, { status: 400 });
if (buffer.length > 5 * 1024 * 1024) return Response.json({ error: 'VALIDATION', message: 'Exceeds 5 MB limit' }, { status: 400 });

// 2. Build canonical path using docPath helpers
const ext = ALLOWED_MIME[file.type];
const githubPath = docPath.memberDoc(unitId, 'sale-deed', ext); // pick the right helper

// 3. Commit to GitHub private repo
const result = await commitDocument(githubPath, buffer, `docs: ${module}/${id} uploaded by ${user.id}`);

// 4. Store the GitHub path in DB (never the raw bytes)
await sb.from('table').update({ storage_key: result.githubPath }).eq('id', id);
```

**Retrieval pattern:**
```typescript
// Generate a pre-signed download URL (~1 hour) — same model as Supabase signed URLs
const url = await getDocumentDownloadUrl(record.storage_key);
return Response.json({ url });
```

### 4B. Canonical Path Builders (`docPath` in `src/lib/utils/githubDocStore.ts`)

| Helper | Path template | Use for |
|---|---|---|
| `memberDoc(unitId, docType, ext)` | `members/{unitId}/{ts}-{docType}.{ext}` | Member docs, sale deeds, leases |
| `staffKycPhoto(staffId, ext)` | `staff-kyc/{staffId}/photo.{ext}` | Staff photos |
| `staffKycIdDoc(staffId, ext)` | `staff-kyc/{staffId}/id-doc.{ext}` | Staff ID documents |
| `maidKycPhoto(maidId, ext)` | `maids/{maidId}/photo.{ext}` | Maid photos |
| `maidKycIdDoc(maidId, ext)` | `maids/{maidId}/id-doc.{ext}` | Maid ID documents |
| `tenantKyc(tenantId, docType, ext)` | `tenant-kyc/{tenantId}/{ts}-{docType}.{ext}` | Tenant KYC |
| `registration(profileId, docType, ext)` | `registration/{profileId}/{ts}-{docType}.{ext}` | Membership application |
| `policy(policyId, version, slug, ext)` | `policies/{policyId}/v{n}-{slug}.{ext}` | Policy PDFs (versioned) |
| `notice(noticeId, filename, ext)` | `notices/{YYYY}/{noticeId}/{ts}-{filename}.{ext}` | Notice attachments |
| `parking(unitId, slotId, docType, ext)` | `parking/{unitId}/{slotId}-{docType}.{ext}` | RC / insurance |
| `pollExport(pollId)` | `polls/exports/{YYYY}/{pollId}.pdf` | Poll result PDFs |
| `vendorInvoice(vendorId, workOrderId, ext)` | `vendors/{vendorId}/invoices/{workOrderId}.{ext}` | Vendor invoices |
| `financeInvoice(invoiceId, ext)` | `finance/invoices/{YYYY}/{invoiceId}.{ext}` | Finance invoices |
| `financeReceipt(receiptId, ext)` | `finance/receipts/{YYYY}/{receiptId}.{ext}` | Finance receipts |
| `avatar(profileId, ext)` | `media/avatars/{profileId}.{ext}` | Profile / member photos |
| `galleryPhoto(albumId, photoId, ext)` | `media/gallery/{albumId}/{photoId}.{ext}` | Gallery photos |
| `eventBanner(eventId, ext)` | `media/events/{eventId}/banner.{ext}` | Event banners |
| `communityImage(postId, ext)` | `media/community/{postId}/{ts}.{ext}` | Community board images |
| `marketplaceImage(listingId, ext)` | `media/marketplace/{listingId}/{ts}.{ext}` | Marketplace images |
| `facilityImage(facilityId, ext)` | `media/facilities/{facilityId}/{ts}.{ext}` | Facility photos |
| `complaintAttachment(complaintId, ext)` | `media/complaints/{complaintId}/{ts}.{ext}` | Complaint media |
| `societyLogo(ext)` | `media/society/logo.{ext}` | Society logo |

For snag attachments (no helper): build inline as `` `snags/${snagId}/${Date.now()}-attachment.${ext}` ``
For general documents library: build inline as `` `members/${SOCIETY_ID}/${Date.now()}-${crypto.randomUUID()}.${ext}` ``

### 4C. Environment Variables

```
GITHUB_DOCS_REPO=utamacs/utamacs-docs     # owner/repo of the private document store
GITHUB_DOCS_TOKEN=ghp_...                  # PAT with repo write scope
GITHUB_DOCS_BRANCH=main                    # branch (default: main)
```

The utility falls back to `GITHUB_LETTERS_REPO` / `GITHUB_LETTERS_TOKEN` if `GITHUB_DOCS_*` are not set.

### 4D. .gitignore Safety Net
`uploads/`, `tmp/`, `temp/`, `public/uploads/`, `src/uploads/`, `docs/uploads/` are gitignored. If any code attempts to write a user file to disk, it will not reach git. Fix the code, not the gitignore.

### 4E. What NOT to use
- `SupabaseStorageService` — do NOT use for any new upload; existing calls are being migrated
- Supabase Storage buckets — not provisioned; do not create or reference them
- `sb.storage.from(bucket).upload(...)` — do not call Supabase storage API directly

---

## 5. Database Standards

### 5A. Every new table must have:
```sql
id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
society_id  uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
created_at  timestamptz NOT NULL DEFAULT now()
```

### 5B. Row Level Security — mandatory on every table:
```sql
ALTER TABLE {table} ENABLE ROW LEVEL SECURITY;
-- At minimum: member reads their own society's data
CREATE POLICY "society_read_{table}" ON {table} FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));
-- Write operations: exec/admin only
CREATE POLICY "exec_manage_{table}" ON {table} FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));
```

### 5C. Role hierarchy (use these exact column values — never invent new roles):
- `user_roles.role`: `'member'` | `'executive'` | `'admin'` | `'security_guard'` | `'vendor'`
- `profiles.portal_role`: `'member'` | `'executive'` | `'secretary'` | `'president'`
- `profiles.is_admin`: boolean — orthogonal to portal_role; grants all access

### 5D. Migration naming:
Files go in `supabase/migrations/`. Name format: `{seq}_{description}.sql` where seq is the next sequential number after the last migration. Read the last migration number before writing a new one.

### 5E. Immutable tables:
- `payments` — NO UPDATE, NO DELETE RLS policies. Payments are immutable records.
- `audit_logs` — NO UPDATE, NO DELETE RLS policies. Append-only.
- `privacy_consents` — NO UPDATE, NO DELETE. Consent history preserved.

### 5F. Sensitive data handling:
- Aadhaar numbers: encrypt at application layer; display only last 4 digits
- Phone numbers: use `phone_encrypted` column where encryption is applied
- Uploaded identity documents: private Supabase bucket, 1-hour signed URLs, log access in audit_logs

---

## 6. Portal Page Standards

### 6A. Every portal page (`src/pages/portal/**/*.astro`):
```astro
---
export const prerender = false;
import PortalLayout from '@components/portal/PortalLayout.astro';
import { resolveFromRequest } from '@lib/permissions';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';
const user = await resolveFromRequest(Astro.request, SOCIETY_ID);
if (!user) return Astro.redirect('/portal/login');

// Role guards — example for exec-only pages:
const isPrivileged = ['executive','secretary','president'].includes(user.portalRole) || user.isAdmin;
if (!isPrivileged) return new Response('Forbidden', { status: 403 });
---
<PortalLayout title="{Page Title}" user={user} activeModule="{module-key}">
  <!-- Page content -->
</PortalLayout>
```

### 6B. Access control tiers:
| Page type | Gate |
|---|---|
| All authenticated users | `if (!user) redirect('/portal/login')` |
| Member + exec | No role gate after auth check |
| Exec only | `if (!isPrivileged) return 403` |
| Admin only | `if (!user.isAdmin) return 403` |
| Guard only | `if (user.role !== 'security_guard') return 403` |

### 6C. Data fetching — server-side only:
Fetch all initial data in the Astro frontmatter using Supabase service client. Never fetch sensitive data client-side. Interactive filtering and pagination can call `/api/v1/` routes.

### 6D. Interactive components:
Use vanilla JS for all portal interactivity (filter, sort, form submit, drawer open/close, toast). Use React only for dashboard chart components that use recharts (MemberDashboard, ExecutiveDashboard).

---

## 7. API Route Standards

### 7A. Every API route (`src/pages/api/v1/**/*.ts`):
```typescript
export const prerender = false;
import type { APIRoute } from 'astro';
import { resolveFromRequest, requireRole } from '@lib/permissions';
import { normalizeError } from '@lib/middleware/errorNormalizer';
import { writeAuditLog, extractClientIP } from '@lib/middleware/auditLogger';

const SOCIETY_ID = import.meta.env.PUBLIC_SOCIETY_ID ?? '00000000-0000-0000-0000-000000000001';

export const POST: APIRoute = async ({ request }) => {
  try {
    const user = await resolveFromRequest(request, SOCIETY_ID);
    if (!user) return Response.json({ error: 'UNAUTHORIZED' }, { status: 401 });
    // role check if needed...
    // business logic...
    // audit log for writes...
    return Response.json({ ...result }, { status: 200 });
  } catch (err) {
    return normalizeError(err, request.url);
  }
};
```

### 7B. Error response shape (always use normalizeError):
```json
{ "error": "ERROR_CODE", "message": "Human-readable description" }
```

### 7C. Audit log writes:
Every CREATE / UPDATE / DELETE operation on sensitive data must call `writeAuditLog()` with action, resourceType, resourceId, oldValues, newValues.

### 7D. Input validation:
- Validate all inputs at the API boundary — never trust client values
- UUIDs: validate with regex `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$`
- Enum fields: explicit CHECK constraints in SQL + server-side validation in API
- Text fields: trim whitespace, enforce maxlength in SQL (`varchar(255)` or explicit `CHECK (length(field) <= 255)`)

---

## 8. DPDPA 2023 Compliance Rules

UTAMACS is committed to India's Digital Personal Data Protection Act 2023. Every new feature that touches personal data must:

1. **Collect minimum data** — only fields necessary for the stated purpose
2. **Document purpose** — add a SQL comment on columns containing personal data: `-- personal data: {purpose}`
3. **Enable deletion** — when a member requests account deletion, their personal data must be erasable without breaking society-level records (use SET NULL foreign keys, not CASCADE on personal data columns)
4. **Audit access** — any exec/admin access to member personal data (Aadhaar, phone, ID documents) must be logged in `audit_logs`
5. **Consent before use** — the `privacy_consents` table and the Policies portal gate enforce consent; new personal data categories require a consent version bump
6. **Anonymous feedback** — when `is_anonymous = true`, display layer hides member identity; DB still records `submitted_by` for rate-limiting only
7. **Signed URLs expire** — identity document signed URLs must expire in ≤ 3600 seconds (1 hour)

---

## 9. Directory Layout (Current)

```
src/
  pages/
    portal/           ← Portal pages (Astro, SSR)
      admin/          ← Admin-only pages (audit, assets, rules, rbac, staff, tds, memberships, staff-kyc, etc.)
      agm/            ← AGM & Governance
      analytics/      ← Reports Hub
      community/      ← Community Board + Marketplace
      complaints/     ← Complaint tracking
      documents/      ← Document library
      events/         ← Events & RSVP
      facilities/     ← Facility booking
      feedback/       ← Resident feedback
      finance/        ← Finance & Dues
      gallery/        ← Photo Gallery
      hoto/           ← HOTO Tracker (10 pages — handover, admin, finance sub-sections)
      letters/        ← Official Letters
      maids/          ← Domestic Help Registry
      members/        ← Member directory
      notices/        ← Notices & Announcements
      notifications/  ← Notification centre
      parking/        ← Parking management
      policies/       ← Policy acknowledgements & compliance gate
      polls/          ← Polls & Voting
      register/       ← Society membership application (Byelaw §4)
      security-patrol/ ← Security patrol log
      snags/          ← Snag / Defect tracking
      tenant-kyc/     ← Tenant KYC & verification
      vendors/        ← Vendors & Work Orders
      visitors/       ← Visitor Management
      water-tankers/  ← Water tanker management
    api/v1/           ← API routes (TypeScript)
  components/
    portal/           ← Portal components (PortalLayout, Dashboard components)
  lib/
    constants.ts      ← Architectural constants only (UUID_RE, MIME types, upload limits)
    utils/
      getRules.ts     ← Rules engine accessor (ruleInt, ruleStr, ruleBool)
    services/
      interfaces/     ← IAuthService, IStorageService, etc.
      providers/
        supabase/     ← Supabase implementations
        azure/        ← Azure implementations (alternative)
  styles/
    global.css        ← @layer base/components/utilities
supabase/
  migrations/         ← SQL migrations (sequential numbering)
src/site/             ← Public website source (separate from portal)
docs/                 ← GitHub Pages output (public website)
design/               ← Planning documents (NOT deployed)
tailwind.config.cjs
astro.config.mjs          ← Public site config (output: static)
astro.portal.config.mjs   ← Portal config (output: hybrid, Vercel)
```

### Module status (all built and registered)
| module_key | Display Name | Nav Order | Notes |
|---|---|---|---|
| `members` | Member Directory | 1 | |
| `complaints` | Complaints | 2 | SLA tracking, attachments |
| `notices` | Notices & Circulars | 3 | |
| `events` | Events | 4 | Waitlist; paid events & QR attendance disabled by default |
| `polls` | Polls & Voting | 5 | Anonymous voting, result export |
| `finance` | Finance & Dues | 6 | Invoicing, GST, TDS, reminders |
| `facility_booking` | Facility Booking | 7 | |
| `visitor_mgmt` | Visitor Management | 8 | **Disabled by default** — requires QR/OTP infrastructure |
| `vendors` | Vendors & Work Orders | 9 | Procurement, AMC |
| `community` | Community Board | 10 | + Marketplace |
| `documents` | Documents | 11 | Versioned document library |
| `analytics` | Analytics & Reports | 12 | |
| `notifications` | Notifications | 13 | Email+realtime on; SMS/WhatsApp/push disabled pending TRAI DLT |
| `letters` | Official Letters | 14 | Templates, letterhead |
| `agm` | AGM & Governance | 15 | Sessions, attendance, quorum, minutes |
| `parking` | Parking Management | 16 | Slot allocation, RC/insurance |
| `maids` | Domestic Help Registry | 17 | Approvals, attendance, KYC pass |
| `gallery` | Photo Gallery | 18 | Albums, photos |
| `policies` | Policies & Compliance | 19 | Compliance gate for portal access |
| `register` | Society Membership | 20 | Byelaw §4 membership application |
| `hoto` | HOTO Tracker | 21 | Handover-takeover, finance sub-module |
| `snags` | Snag List | 22 | Defect tracking integrated with HOTO |
| `tenant_kyc` | Tenant KYC | 23 | Tenant verification, re-KYC expiry |
| `water_tankers` | Water Management | 24 | Tanker bookings |
| `security_patrol` | Security Patrol Log | 25 | Guard shift logs |
| `memberships` | Membership Registry | 95 | Admin tool — byelaw membership lifecycle |
| `staff_kyc` | Staff & Maid KYC | 96 | Admin tool — KYC pass issuance |

---

## 10. Navigation & Module Registration

New portal modules must be registered in two places:

**A. `src/components/portal/PortalLayout.astro`** — add to fallback modules array:
```typescript
{ key: 'module-key', displayName: 'Display Name', icon: 'fas fa-icon-name', path: '/portal/module-key' }
```

**B. `supabase/migrations/{seq}_feature_flag_seeds.sql`** — insert into `feature_flags`:
```sql
INSERT INTO feature_flags (society_id, module_key, is_active, display_order)
SELECT id, 'module-key', true, {next_order}
FROM societies
ON CONFLICT (society_id, module_key) DO NOTHING;
```

---

## 11. Rules Engine Standard — Mandatory

Every configurable business parameter **must** live in the `rules` table and be read via `getRules()`. **Never hardcode business values in code.**

### When to use the rules engine (always)
Any value a society admin could reasonably want to change: days, durations, fees, thresholds, rates, percentages, counts.

### When to use `src/lib/constants.ts` (rare, architectural only)
- `UUID_RE` — regex used everywhere, not a business value
- `UPLOAD_LIMITS_BYTES` / `getUploadLimitBytes()` — tied to Supabase bucket policies; changing requires infra change
- `DOCUMENT_MIME_TYPES` / `IMAGE_MIME_TYPES` — security policy, not configurable
- DPDPA-mandated caps (e.g. `SIGNED_URL_EXPIRY_SECS = 3600`) — compliance floor, cannot be raised

### Code pattern — API route
```typescript
import { getRules, ruleInt, ruleStr, ruleBool } from '@lib/utils/getRules';
import { UUID_RE } from '@lib/constants';   // ← architecture constants only

// Inside handler, after creating sb:
const rules = await getRules(sb, SOCIETY_ID, ['SOME_RULE_CODE', 'ANOTHER_RULE']);
const days  = ruleInt(rules, 'SOME_RULE_CODE', 30);   // fallback = migration default
const mode  = ruleStr(rules, 'ANOTHER_RULE', 'auto');
```

### Adding a new configurable value
1. Add a row to `supabase/migrations/{seq}_*.sql` with `rule_code`, `value_type`, `current_value`, `is_locked`
2. Mark `is_locked = true` only if the value is mandated by byelaw/law
3. Read it with `getRules()` at call time — **never** as a module-level constant
4. The admin UI at `/portal/admin/rules` automatically surfaces all rules

### What NOT to do
- **No `const EXPIRY_DAYS = 30`** at module level for a business value
- **No `30 * 24 * 60 * 60 * 1000`** literals for durations — read from rules engine
- **No local `const UUID_RE = /…/`** — import from `@lib/constants`
- **No duplicate MIME/size constants** — import `DOCUMENT_MIME_TYPES` / `IMAGE_MIME_TYPES` / `getUploadLimitBytes` from `@lib/constants`

---

## 12. What NOT to Do

- **No filesystem file writes** for user uploads — always Supabase Storage
- **No raw hex colours** — use design system tokens
- **No inline `<style>` blocks** — extend `global.css` with named classes
- **No third-party UI libraries** — Tailwind + vanilla JS + recharts (dashboards only)
- **No jQuery or additional JS frameworks**
- **No hardcoded society_id** — always read from `PUBLIC_SOCIETY_ID` env var
- **No competitor product names** in any code, comment, UI text, or commit message
- **No UPDATE/DELETE on payments, audit_logs, or privacy_consents**
- **No skipping RLS** — every new table needs row level security
- **No prerender = true** on portal pages — they are all SSR (`prerender = false`)
- **No new npm runtime dependencies** without explicit approval — check if Supabase or existing deps can solve it
- **No AI features** — deferred to backlog; do not implement
- **No breaking changes to existing Tailwind token names** — many CSS classes depend on them

---

## 13. Commit Security — Sensitive Data Must Never Be Checked In

**Before every commit, verify no sensitive file is staged. This is non-negotiable.**

### Files that must NEVER be committed
| Pattern | Why |
|---|---|
| `.env`, `.env.*` (except `.env.example`) | Supabase keys, encryption keys, salts |
| `tests/.auth/*.json` | Playwright saved sessions — contain live Supabase refresh tokens |
| `*.pem`, `*.key`, `*.p12`, `*.pfx` | TLS/private keys |
| `**/service-account*.json`, `**/credentials.json` | GCP / Firebase service accounts |
| Any file with a real `sb_publishable_*` or `sb_secret_*` key | Supabase credentials |
| Any file with a real JWT, Bearer token, or refresh token | Auth material |

### Pre-commit checklist (run before every `git add`)
```bash
# Quick scan for common credential patterns
git diff --cached | grep -iE "(password|secret|token|refresh_token|api_key|anon_key|service_role)" | grep "^\+" | grep -v "REPLACE_WITH\|YOUR_.*_HERE\|example\|placeholder"
```

### What to do if sensitive data is accidentally committed
1. **Do not push** — if not yet pushed, `git rm --cached <file>` and recommit
2. **If already pushed** — immediately rotate/revoke the exposed credential; do not rely on git history rewrite alone as forks/caches may have it
3. Verify `.gitignore` covers the file pattern so it cannot recur

### `.env.example` is the only env file that may be committed
It must contain only placeholder values (`YOUR_KEY_HERE`, `REPLACE_WITH_*`), never real credentials. All other `.env.*` files are gitignored.

---

## 15. Public Website (utamacs.org) Standards

The public site at `src/site/` (output → `docs/`) is static HTML only:
- No Astro features — plain `.html` files
- Tailwind via CDN in `<script src="https://cdn.tailwindcss.com">`
- Font Awesome via kit `5a2b2f0b4f.js`
- Components (nav, footer) loaded via `fetch()` in `main.js`
- Page paths from `src/pages/` use `../` prefix for CSS/JS: `../css/styles.css`
- `docs/CNAME` = `utamacs.org` — never delete
- After changes to `src/site/`, sync to `docs/` using `/deploy` skill

---

## 16. Skills Reference

| Skill | Invocation | Purpose |
|---|---|---|
| Standards Review | `/standards-review` | Audits staged/unstaged changes against all rules in this file |
| New Portal Module | `/new-module` | Scaffolds a complete new portal module with all boilerplate |
| Storage Audit | `/storage-audit` | Checks that no upload bypasses Supabase Storage |
| New Page (public site) | `/new-page` | Creates a new public website page |
| Add Notice | `/add-notice` | Adds a notice card to the public site |
| Deploy | `/deploy` | Syncs public site to docs/ and pushes |
