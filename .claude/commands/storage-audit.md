# UTAMACS Storage Audit

Audits the entire codebase to ensure no user-uploaded files bypass Supabase Storage. Run this whenever a new upload feature is added or before any deploy.

## Usage
`/storage-audit [path]`

If no path is given, audits the entire `src/` directory. If a path is given, scans only that subtree.

## What this agent does

You are auditing the UTAMACS codebase for storage compliance. The project has one strict rule: **all user-uploaded binary files must go to Supabase Storage via `SupabaseStorageService` — never to the local filesystem, never committed to this git repository.**

The only intentional exception is `src/pages/api/v1/hoto/upload/index.ts`, which commits HOTO governance documents to a **separate** governance GitHub repository via the GitHub API. This does not write to the local filesystem.

Perform the following checks:

### Check 1 — Filesystem writes
Search for any code that writes uploaded file bytes to the local disk:
```
grep patterns: fs.writeFile, fs.createWriteStream, writeFileSync, createWriteStream,
               writeFile(, path.join(.*upload, path.resolve(.*upload
```
For each match: determine if the content being written is a user upload (from request FormData) or a generated file (PDF via pdfmake — which is OK, these are ephemeral). Report uploads-to-disk as CRITICAL violations. Generated PDFs piped to the HTTP response are fine.

### Check 2 — Direct Supabase storage calls (bypassing service interface)
Search for `supabase.storage.from(` or `sb.storage.from(` outside of `SupabaseStorageService.ts`. These bypass the interface and may skip validation, logging, or error handling.
```
grep: \.storage\.from\(
```
Report any occurrence outside `src/lib/services/providers/supabase/SupabaseStorageService.ts` as a HIGH violation.

### Check 3 — Storage key vs. URL saved to DB
For every INSERT or UPDATE that saves a file reference:
- CORRECT: saves `storageKey` (a path string like `complaints/uuid/filename.pdf`)
- WRONG: saves a full URL (`https://xxx.supabase.co/storage/...`) — public URLs bypass signed URL expiry
Search for patterns like: `.insert({.*url.*:.*https://` or `.update({.*storage_url`
Report as MEDIUM violation.

### Check 4 — Signed URL expiry compliance
Search for `createSignedUrl` or `getSignedUrl` calls:
```
grep: getSignedUrl\|createSignedUrl
```
For each call, check the expiry argument:
- Identity documents (aadhaar, voter_id, rc_doc, lease_doc, onboarding-docs bucket): expiry must be ≤ 3600
- Other documents (invoices, receipts, notices): expiry ≤ 86400 is acceptable
Report any identity document URL with expiry > 3600 as HIGH violation.

### Check 5 — Upload validation presence
For every API route that accepts `multipart/form-data` or processes `file` from FormData:
1. Is MIME type validated against an allowlist?
2. Is file size checked against a maximum?
3. Is the file stored before any database insert (to avoid orphaned DB records with no file)?

Report missing validation as MEDIUM violations.

### Check 6 — Bucket name consistency
Check every `storageService.upload(bucket, ...)` call. The bucket name must match one of the approved buckets listed in CLAUDE.md section 4C. Report any unrecognised bucket name as MEDIUM violation (it may not exist in Supabase, causing silent failures).

### Check 7 — .gitignore coverage
Read `.gitignore`. Verify it contains entries for `uploads/`, `tmp/`, `temp/`, `public/uploads/`. Report missing entries as LOW violation (add them).

### Check 8 — No hardcoded upload paths in public/ or src/site/
The public website is static and must never serve user-uploaded files directly. Search for any `<img src=` or `<a href=` pointing to `/uploads/` or local file paths in `src/site/` or `docs/`.

## Output format

```
UTAMACS STORAGE AUDIT
=====================
Scanned: {path}
Date: {date}

CRITICAL — {n} violations
  Files writing user uploads to filesystem

HIGH — {n} violations
  Direct Supabase storage calls / identity URL expiry

MEDIUM — {n} violations
  Storage key vs URL / missing validation / unknown bucket

LOW — {n} violations
  .gitignore gaps

─────────────────────────────

[CRITICAL] src/pages/api/v1/example/upload.ts:28
Pattern: fs.writeFile(uploadPath, buffer)
Issue: User upload written to local filesystem. Will be git-tracked.
Fix: Use SupabaseStorageService.upload('bucket-name', key, buffer, mimeType)

[HIGH] src/pages/portal/example/index.astro:91
Pattern: sb.storage.from('docs').createSignedUrl(key, 7200)
Issue: Signed URL for identity document exceeds 3600s (set to 7200s)
Fix: Change expiry to 3600

─────────────────────────────
CLEAN AREAS: {categories with zero violations}
```

After the report, if any CRITICAL violations are found, state: "Do not deploy until CRITICAL violations are fixed."
