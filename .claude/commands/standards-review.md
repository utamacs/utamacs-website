# UTAMACS Standards Review

Reviews code changes against all UTAMACS architecture, design, and functional standards. Run this before every commit on portal or API code.

## Usage
`/standards-review [file-or-directory]`

If no argument, reviews all staged and unstaged changes. If a path is given, reviews that specific file or directory.

## What this agent does

Spawn a general-purpose agent with the following instructions:

You are reviewing UTAMACS portal code for compliance with the project's mandatory standards. Read `CLAUDE.md` first for all rules. Then check the target code against every rule below. Report every violation found — do not stop at the first one. For each violation: state the file, line number, what rule is broken, and the exact fix required.

**Checklist — check every item:**

### Identity & Language
- [ ] No competitor product names anywhere (code, comments, UI strings, variable names)
- [ ] No references to external society management platforms by name
- [ ] All user-visible text uses "Urban Trilla Apartments" or "UTA MACS" — never generic placeholders left in

### Storage (CRITICAL)
- [ ] No `fs.writeFile`, `fs.createWriteStream`, or any Node.js filesystem write for a user-uploaded file
- [ ] No `writeFile` calls with file/binary content from a request
- [ ] All file upload API routes use `SupabaseStorageService.upload()` via the service interface
- [ ] Storage key (not file content or URL) is what gets saved to the database column
- [ ] Signed URLs generated via `storageService.getSignedUrl()` — not permanent public URLs
- [ ] Signed URL expiry is ≤ 3600 seconds for identity documents

### Portal Page Structure
- [ ] Every `.astro` portal page starts with `export const prerender = false;`
- [ ] Every portal page imports and uses `PortalLayout` with correct `title`, `user`, and `activeModule` props
- [ ] Auth check present: `if (!user) return Astro.redirect('/portal/login')`
- [ ] Role checks use `isPrivileged`, `user.isAdmin`, or `user.role` — not hardcoded strings
- [ ] No sensitive data fetched client-side (initial data comes from Astro frontmatter)

### Design System
- [ ] No hardcoded hex colour values in class attributes — must use Tailwind design token names
- [ ] No `style="color: #..."` or `style="background: #..."` inline styles
- [ ] Buttons use `.btn-primary`, `.btn-secondary`, `.btn-outline`, or `.btn-ghost`
- [ ] Cards use `.card-premium`, `.card-hero`, `.card-feature`, or `.card-stats`
- [ ] Form inputs use `.form-input` and `.form-label`
- [ ] Page heading uses `text-2xl font-bold text-primary-600 font-poppins` pattern
- [ ] Status badges use `inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium`
- [ ] Detail views use the right-side drawer pattern — not a `<dialog>` modal

### API Routes
- [ ] `export const prerender = false` at top
- [ ] Auth via `resolveFromRequest()` — not a direct Supabase session check
- [ ] Wrapped in `try/catch` using `normalizeError()` for error responses
- [ ] Write operations call `writeAuditLog()` with action, resourceType, resourceId
- [ ] Input validation present for all user-supplied fields
- [ ] UUIDs validated before use in database queries
- [ ] File upload routes validate MIME type AND file size before calling storage service

### Database / Migrations
- [ ] New tables have `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- [ ] New tables have `society_id uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE`
- [ ] New tables have `created_at timestamptz NOT NULL DEFAULT now()`
- [ ] `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` present for every new table
- [ ] At minimum one SELECT policy and one write policy per new table
- [ ] No UPDATE or DELETE policies on `payments`, `audit_logs`, `privacy_consents`
- [ ] Migration filename follows `{seq}_{description}.sql` pattern

### DPDPA Compliance
- [ ] Personal data columns have SQL comment `-- personal data: {purpose}`
- [ ] Aadhaar numbers: only last-4 displayed; full number encrypted at application layer
- [ ] Identity document access logged in audit_logs
- [ ] Anonymous submissions: display hides identity; DB still records `submitted_by`
- [ ] Signed URLs for identity docs expire in ≤ 3600 seconds

### JavaScript
- [ ] No jQuery, no additional UI framework imports beyond React (dashboards only)
- [ ] No `document.write()`
- [ ] All icons have `aria-hidden="true"`
- [ ] Interactive elements have `aria-label` where button text alone is not self-descriptive

### Forbidden patterns (immediate CRITICAL fail)
- Any `fs.writeFile` or `fs.createWriteStream` receiving file upload bytes
- Any hardcoded `society_id` UUID literal — must come from `PUBLIC_SOCIETY_ID` env var
- Any `export const prerender = true` on a portal page
- Any `<style>` block duplicating an existing named class (`.card-premium`, `.btn-primary`, etc.)
- Any comment or UI string referencing a competitor product or external platform by name

## Output format

```
UTAMACS STANDARDS REVIEW
========================
Target: {path or "staged changes"}

VIOLATIONS: {n}

[CRITICAL] src/pages/portal/example/index.astro:42
Rule: Storage — filesystem write
Found: fs.writeFile(uploadPath, buffer)
Fix:  Use SupabaseStorageService.upload(bucket, key, buffer, mimeType)

[HIGH] src/pages/portal/example/index.astro:15
Rule: Design system — hardcoded colour
Found: class="bg-[#1E3A8A]"
Fix:  class="bg-primary-600"

PASSED: {categories with zero violations}
```

Severity: CRITICAL (storage, auth bypass) > HIGH (design system, missing RLS) > MEDIUM (missing audit log) > LOW (style, naming).
