# UTA MACS — Production Operationalization Playbook
## Code → Fully Operational, Secure, Production-Ready Platform

---

## EXECUTION LEGEND
- `[AUTO]` — Claude executes this: code changes, file creation, CLI commands
- `[MANUAL]` — You execute this: external dashboards, DNS registrar, payment portals
- `[x]` — Completed
- `[ ]` — Not yet done
- `[!]` — Blocked or needs attention

---

## AUTOMATED TASKS — Execute in Order

| # | Task | File | Status |
|---|------|------|--------|
| A1 | Verify service role key uses `process.env` | `src/lib/services/providers/supabase/SupabaseDB.ts` | `[x]` Confirmed safe — already uses `process.env` |
| A2 | Replace in-memory rate limiter with Upstash Redis | `src/lib/middleware/rateLimiter.ts` | `[x]` Done — Upstash `slidingWindow`, in-memory fallback for local dev |
| A3 | Create health check endpoint | `src/pages/api/v1/health.ts` | `[x]` Done — DB connectivity check, returns 200/503 |
| A4 | Create Vercel CI/CD pipeline | `.github/workflows/deploy-portal.yml` | `[x]` Done — type-check → build → deploy jobs |
| A5 | Add production domain alias to vercel.json | `vercel.json` | `[x]` Done |
| A6 | Create Dependabot config | `.github/dependabot.yml` | `[x]` Done — weekly on Monday 9am IST |

## MANUAL TASKS — Detailed step-by-step below each section

| # | Task | Where |
|---|------|--------|
| M1 | Create Upstash Redis database + get credentials | upstash.com |
| M2 | Set all Vercel environment variables | Vercel Dashboard |
| M3 | Create Supabase prod project (ap-south-1) | supabase.com |
| M4 | Apply 16 migrations to Supabase prod | Terminal (Supabase CLI) |
| M5 | Configure Supabase auth settings | Supabase Dashboard |
| M6 | Create Supabase storage buckets | Supabase Dashboard |
| M7 | Configure DNS records at registrar | Domain registrar |
| M8 | Configure GitHub Pages custom domain | GitHub repo settings |
| M9 | Create Vercel project + connect GitHub | Vercel Dashboard |
| M10 | Verify Resend domain + configure SMTP | resend.com + Supabase |
| M11 | Set up Razorpay account + webhooks | razorpay.com |
| M12 | Configure Supabase password policy + MFA | Supabase Dashboard |
| M13 | Set up Sentry error tracking | sentry.io |
| M14 | Set up Uptime Robot monitoring | uptimerobot.com |
| M15 | Add GitHub repo secrets for CI/CD | GitHub repo settings |
| M16 | Enable GitHub branch protection | GitHub repo settings |
| M17 | Set CRON_SECRET in Vercel | Vercel Dashboard |
| M18 | Seed initial society data | Supabase SQL editor |

---

## Context

All 7 development phases are complete. This playbook covers everything needed to take the system live and keep it running. The platform runs on two separate deployments:
- **utamacs.org** → GitHub Pages (static public site, builds to `/docs/`)
- **portal.utamacs.org** → Vercel serverless (hybrid SSR portal + all `/api/v1/*` endpoints)

Critical issues discovered during audit that must be fixed before go-live:
1. `import.meta.env.SUPABASE_SERVICE_ROLE_KEY` is accessed in some files — **service role key must NEVER reach the browser bundle**
2. Rate limiter is **in-memory** (`Map`) — resets on every Vercel cold start, ineffective for brute force protection across instances → must swap to Upstash Redis before launch
3. **No Vercel CI/CD pipeline** — only GitHub Pages has a workflow; portal deploys need their own pipeline
4. **No staging environment** — only production Supabase and Vercel project
5. **No monitoring, alerting, or log aggregation** in place
6. **CRON_SECRET** env var must be set — all 4 cron endpoints check this but no secret is provisioned

---

## Part 1 — Critical Pre-Launch Fixes (Do These First)

### 1.1 Fix Service Role Key Exposure

**Problem:** `import.meta.env.SUPABASE_SERVICE_ROLE_KEY` in `SupabaseDB.ts` is accessed via `import.meta.env`, which Vite/Astro may inline into the client bundle if the file is ever imported in an island or client-side script.

**Fix:** Rename all usages from `import.meta.env.SUPABASE_SERVICE_ROLE_KEY` to `process.env.SUPABASE_SERVICE_ROLE_KEY` throughout `src/lib/services/providers/supabase/SupabaseDB.ts`. The `process.env` form is Node-only and will never reach the browser. Astro strips it at build time for server files.

**Files to audit:**
- `src/lib/services/providers/supabase/SupabaseDB.ts`
- Any file importing `getSupabaseServiceClient()` that is also used in a `<script>` tag or `client:load` island

> **`[AUTO]` A1 — Status: `[x]` Verified safe** — `SupabaseDB.ts` already uses `process.env.SUPABASE_SERVICE_ROLE_KEY`. No change needed.

### 1.2 Swap Rate Limiter to Upstash Redis

**Problem:** `src/lib/middleware/rateLimiter.ts` uses a `Map` in-memory. Vercel serverless functions are stateless — each cold start resets the map. Auth brute force is therefore completely unprotected in production.

**Fix:** Install `@upstash/ratelimit` and `@upstash/redis`. Replace the in-memory Map with sliding-window Upstash rate limiting. The existing rate limit configs (100/min general, 10/15min for auth routes) can remain identical.

> **`[AUTO]` A2 — Claude will replace `src/lib/middleware/rateLimiter.ts` with Upstash implementation.**
> Interface preserved: `checkRateLimit(ip: string, path: string): void` — same call signature, same configs.
> New implementation uses `@upstash/ratelimit` `slidingWindow()` and `@upstash/redis`.
> Status: `[ ]`

> **`[MANUAL]` M1 — Create Upstash Redis database:**
> 1. Go to **console.upstash.com** → Sign up / Log in
> 2. Click **Create Database**
> 3. Name: `utamacs-ratelimit`
> 4. Type: **Regional** (not Global — cheaper, sufficient for single-region)
> 5. Region: **ap-south-1 (Mumbai)** — matches Supabase region for low latency
> 6. Click **Create**
> 7. Once created, click on the database name → scroll to **REST API** section
> 8. Copy the **UPSTASH_REDIS_REST_URL** (starts with `https://`)
> 9. Copy the **UPSTASH_REDIS_REST_TOKEN** (long alphanumeric string)
> 10. Save both values securely (1Password / Bitwarden) — you'll enter them into Vercel in M2
>
> Status: `[ ]`

### 1.3 Set CRON_SECRET

All 4 automation endpoints (`/api/v1/automation/*`) check:
```typescript
const secret = request.headers.get('authorization')?.replace('Bearer ', '');
if (secret !== import.meta.env.CRON_SECRET) return 403;
```
Generate a random 32-char secret and add it to Vercel env vars. Vercel auto-injects `CRON_SECRET` into cron call headers — no manual header configuration needed in `vercel.json`.

> **`[MANUAL]` M17 — Generate and set CRON_SECRET:**
> 1. Generate a secure secret in your terminal: `openssl rand -base64 32`
> 2. Copy the output (e.g. `xK9mP2...`)
> 3. Add to Vercel as env var `CRON_SECRET` (see M2 below for how to add Vercel env vars)
>
> Status: `[ ]`

---

## Part 2 — Secrets & Security Management

### 2.1 Secret Inventory

| Secret | Used By | Never In |
|--------|---------|----------|
| `SUPABASE_SERVICE_ROLE_KEY` | Vercel server-side only | Git, client bundle |
| `PUBLIC_SUPABASE_ANON_KEY` | Vercel + browser OK | Git |
| `PUBLIC_SUPABASE_URL` | Vercel + browser OK | Git |
| `ENCRYPTION_KEY` (AES-256) | Vercel server-side only | Git, client bundle |
| `IP_HASH_SALT` | Vercel server-side only | Git |
| `RESEND_API_KEY` | Vercel server-side only | Git |
| `ANTHROPIC_API_KEY` | Vercel server-side only | Git |
| `CRON_SECRET` | Vercel cron scheduler | Git |
| `UPSTASH_REDIS_REST_URL` | Vercel server-side only | Git |
| `UPSTASH_REDIS_REST_TOKEN` | Vercel server-side only | Git |
| `PRIVACY_POLICY_VERSION` | Vercel server-side | Git |
| `PUBLIC_SOCIETY_ID` | Vercel + browser OK | Git |

### 2.2 Where Secrets Live

> **`[MANUAL]` M2 — Set all Vercel environment variables:**
>
> **Step 1 — Get your Vercel API token:**
> 1. Go to **vercel.com** → Click your avatar (top-right) → **Settings**
> 2. Left sidebar → **Tokens**
> 3. Click **Create** → Name: `utamacs-deploy` → Scope: Full Account → Expiration: No Expiration
> 4. Copy the token — save it securely. This is `VERCEL_TOKEN` for GitHub Actions.
>
> **Step 2 — Get your Vercel Org ID and Project ID:**
> 1. Go to **vercel.com** → your project → **Settings** → **General**
> 2. Scroll down to find **Project ID** — copy it (`VERCEL_PROJECT_ID`)
> 3. Go to your **Team settings** (or personal account settings) to find **Team ID** (`VERCEL_ORG_ID`)
>    - For personal: `vercel whoami` in terminal gives your username; use that
>    - For team: Team Settings → General → Team ID
>
> **Step 3 — Add each environment variable to Vercel:**
> 1. Go to **vercel.com** → select your portal project → **Settings** tab → **Environment Variables**
> 2. For each variable below, click **Add New** → enter Name, Value, select Environments
> 3. Server-side-only secrets → select **Production** + **Preview** (NOT Development unless you want local Vercel dev access)
> 4. PUBLIC_ variables → select all three: **Production**, **Preview**, **Development**
> 5. Click **Save** after each
>
> | Variable | Scope | Source |
> |----------|-------|--------|
> | `SUPABASE_SERVICE_ROLE_KEY` | Production + Preview | Supabase Dashboard → Project Settings → API → service_role key |
> | `PUBLIC_SUPABASE_URL` | All | Supabase Dashboard → Project Settings → API → Project URL |
> | `PUBLIC_SUPABASE_ANON_KEY` | All | Supabase Dashboard → Project Settings → API → anon key |
> | `ENCRYPTION_KEY` | Production + Preview | Generate: `openssl rand -base64 32` |
> | `IP_HASH_SALT` | Production + Preview | Generate: `openssl rand -hex 16` |
> | `RESEND_API_KEY` | Production + Preview | Resend Dashboard → API Keys → Create |
> | `ANTHROPIC_API_KEY` | Production + Preview | console.anthropic.com → API Keys |
> | `CRON_SECRET` | Production + Preview | Generate: `openssl rand -base64 32` |
> | `UPSTASH_REDIS_REST_URL` | Production + Preview | From M1 (Upstash console) |
> | `UPSTASH_REDIS_REST_TOKEN` | Production + Preview | From M1 (Upstash console) |
> | `PRIVACY_POLICY_VERSION` | All | Set to `1` initially |
> | `PUBLIC_SOCIETY_ID` | All | UUID of your society row (after M18 seeding) |
> | `PROVIDER` | All | `supabase` |
>
> Status: `[ ]`

> **`[MANUAL]` M15 — Add GitHub Actions secrets:**
> 1. Go to your GitHub repo → **Settings** → **Secrets and variables** → **Actions**
> 2. Click **New repository secret** for each:
>
> | Secret | Value |
> |--------|-------|
> | `VERCEL_TOKEN` | From Step 1 above |
> | `VERCEL_ORG_ID` | From Step 2 above |
> | `VERCEL_PROJECT_ID` | From Step 2 above |
> | `PUBLIC_SUPABASE_URL` | From Supabase |
> | `PUBLIC_SUPABASE_ANON_KEY` | From Supabase |
> | `PUBLIC_SOCIETY_ID` | Your society UUID |
>
> Status: `[ ]`

**What NEVER goes in the repo:**
- `.env` files (already in `.gitignore`)
- Any API keys, tokens, or secrets in source code
- Supabase service role key

### 2.3 Key Rotation Policy

| Key | Rotation Frequency | How to Rotate |
|-----|--------------------|---------------|
| `SUPABASE_SERVICE_ROLE_KEY` | 90 days or on breach | Supabase Dashboard → Project Settings → API → Reset |
| `ENCRYPTION_KEY` | Annually (requires re-encrypting PII data) | Generate new 32-byte key, run migration script |
| `IP_HASH_SALT` | Monthly (per DPDPA design) | Update Vercel env var, redeploy |
| `RESEND_API_KEY` | 90 days | Resend Dashboard → API Keys → Revoke + Create |
| `UPSTASH_REDIS_REST_TOKEN` | 90 days | Upstash Console → Database → REST API → Regenerate |
| `CRON_SECRET` | On team change | Update in Vercel env vars, redeploy |

### 2.4 Access Control

- Vercel project: Share access only with team members who need deploy rights (Project → Members)
- Supabase project: Admin access restricted to 1-2 people. Use Supabase Organization roles.
- GitHub repo: Keep public (static site), but use branch protection rules on `main`
- Never use personal access tokens in CI — use machine accounts or fine-grained tokens

---

## Part 3 — Environment Strategy

### 3.1 Three Environments

| Environment | Purpose | Supabase Project | Vercel Project |
|-------------|---------|-----------------|----------------|
| `dev` | Local development | `utamacs-dev` | localhost:4321 |
| `staging` | Pre-prod testing | `utamacs-staging` | `staging-portal.utamacs.org` |
| `prod` | Live users | `utamacs-prod` | `portal.utamacs.org` |

### 3.2 Setup Steps

**Step 1 — Create 3 Supabase projects:**
1. Log into supabase.com → New Organization `UTA MACS`
2. Create project `utamacs-prod` (region: `Southeast Asia (Singapore)` — closest to Mumbai for DPDPA)
3. Create project `utamacs-staging` (same region)
4. Development uses local Supabase CLI: `npx supabase start`

**Step 2 — Apply migrations to each project:**
```bash
# Link to each project and push migrations
npx supabase link --project-ref <project-ref>
npx supabase db push
```
Run this for staging first, verify, then run for prod.

**Step 3 — Create 2 Vercel projects:**
1. `utamacs-portal-prod` → connected to `main` branch
2. `utamacs-portal-staging` → connected to `staging` branch

**Step 4 — Environment variable sets:**
Each Vercel project gets its own env var set pointing to its Supabase project. Never share service role keys between environments.

### 3.3 Local Development

Create `.env.local` (git-ignored):
```env
PROVIDER=supabase
PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
PUBLIC_SUPABASE_ANON_KEY=<local anon key from supabase start>
SUPABASE_SERVICE_ROLE_KEY=<local service role key from supabase start>
ENCRYPTION_KEY=<generate: openssl rand -base64 32>
IP_HASH_SALT=dev-salt-not-for-production
PUBLIC_SOCIETY_ID=00000000-0000-0000-0000-000000000001
CRON_SECRET=dev-cron-secret
```

Run dev server:
```bash
npm run dev:portal   # Astro SSR dev server for portal
npm run dev          # Static site dev server
```

---

## Part 4 — Frontend Deployment (GitHub Pages)

### 4.1 Current Setup

The static public site (utamacs.org) is built by `astro.config.mjs` → outputs to `/docs/` folder. GitHub Pages is configured to serve from `docs/` on the `main` branch. A `CNAME` file in `public/` sets the custom domain.

### 4.2 Custom Domain Setup

> **`[MANUAL]` M8 — Configure GitHub Pages custom domain:**
> 1. Go to your GitHub repo page (github.com/sravani896/utamacs-website)
> 2. Click **Settings** (top tab, not left sidebar)
> 3. Left sidebar → **Pages**
> 4. Under **Build and deployment**, Source should already be set to `Deploy from a branch`; Branch: `main`; Folder: `/ (root)` — change Folder to `/docs` if not already set
> 5. Under **Custom domain**, type `utamacs.org` and click **Save**
> 6. GitHub will do a DNS check — it will initially fail until DNS records are set (see M7 below)
> 7. Once DNS propagates, return here and tick **Enforce HTTPS**
>
> Status: `[ ]`

> **`[MANUAL]` M7 — Configure DNS records at your domain registrar:**
>
> Log in to wherever `utamacs.org` is registered (GoDaddy / Namecheap / Google Domains / etc.)
>
> **Delete any existing A or CNAME records for `@` and `www` first** to avoid conflicts.
>
> Then add these records:
>
> ```
> Type   Name     Value                     TTL
> A      @        185.199.108.153           3600
> A      @        185.199.109.153           3600
> A      @        185.199.110.153           3600
> A      @        185.199.111.153           3600
> CNAME  www      utamacs-org.github.io.    3600
> CNAME  portal   cname.vercel-dns.com.     3600
> TXT    @        v=spf1 include:resend.com -all   3600
> TXT    _dmarc   v=DMARC1; p=none; rua=mailto:admin@utamacs.org   3600
> ```
>
> The DKIM and MX records for Resend are provided in M10 below — add all DNS records in one session to avoid multiple propagation waits.
>
> DNS propagation takes 15 minutes to 48 hours. Use **dnschecker.org** to verify propagation worldwide.
>
> Status: `[ ]`

### 4.3 CI/CD for Static Site

The existing `.github/workflows/deploy.yml` already builds and commits `docs/` correctly. No changes needed.

> **`[AUTO]` A4 — Claude will create `.github/workflows/deploy-portal.yml`** — a separate Vercel deploy pipeline for the portal. Status: `[ ]`

### 4.4 Cache Invalidation

GitHub Pages caches aggressively. Astro appends content hashes to all bundled assets (e.g., `_astro/main.Cxyz123.css`), so asset cache is auto-invalidated. For HTML files, users may cache old versions for up to 10 minutes (GitHub Pages default). This is acceptable for a static public site.

---

## Part 5 — Backend Setup (Supabase Production)

### 5.1 Project Creation Checklist

> **`[MANUAL]` M3 — Create Supabase production project:**
> 1. Go to **app.supabase.com** → sign in → click **New project**
> 2. Select your organization (or create one: `UTA MACS`)
> 3. Project name: `utamacs-prod`
> 4. Database password: use a strong generated password (e.g. from 1Password: 24+ chars, mixed case, numbers, symbols)
>    **Save this password in 1Password under "Supabase utamacs-prod DB password"**
> 5. **Region: `Southeast Asia (Singapore)`** — closest available to Mumbai for DPDPA data localization
>    *(ap-south-1 Mumbai is not available as a Supabase region; Singapore is the nearest alternative)*
> 6. Pricing plan: **Free** initially, upgrade to Pro after verifying migrations work
> 7. Click **Create new project** — takes 2-3 minutes to provision
> 8. Once ready, go to **Project Settings** → **API**:
>    - Copy **Project URL** → save as `PUBLIC_SUPABASE_URL`
>    - Copy **anon (public) key** → save as `PUBLIC_SUPABASE_ANON_KEY`
>    - Copy **service_role (secret) key** → save as `SUPABASE_SERVICE_ROLE_KEY` (never commit this)
> 9. Copy **Project Reference** from URL bar (e.g. `abcdefghijklmnop`) — you'll need it for CLI
>
> Status: `[ ]`

### 5.2 Apply Migrations

> **`[MANUAL]` M4 — Apply all 16 migrations using Supabase CLI:**
>
> Run these commands in your project directory:
> ```bash
> # Install Supabase CLI globally
> npm install -g supabase
>
> # Login with your Supabase account
> npx supabase login
>
> # Link to your production project (use the Project Reference from M3)
> npx supabase link --project-ref <your-prod-project-ref>
> # It will ask for your DB password — enter the one saved in M3
>
> # Preview what migrations will be applied (dry run first)
> npx supabase db push --dry-run
>
> # Apply all 16 migrations (001 through 016)
> npx supabase db push
>
> # Verify all migrations applied successfully
> npx supabase migration list
> ```
>
> Expected output of `migration list`: all 16 migrations with status `applied`.
>
> If any migration fails, check the error message in the Supabase SQL Editor (Dashboard → SQL Editor → Logs).
>
> Status: `[ ]`

All 16 migrations (001 through 016) must apply without errors.

### 5.3 Authentication Configuration

> **`[MANUAL]` M5 — Configure Supabase auth settings:**
> 1. Go to **app.supabase.com** → select your project
> 2. Left sidebar → **Authentication** → **URL Configuration**
>    - **Site URL:** `https://portal.utamacs.org`
>    - **Redirect URLs:** Add both:
>      - `https://portal.utamacs.org/api/v1/auth/callback`
>      - `https://portal.utamacs.org/portal/login`
>    - Click **Save**
> 3. Left sidebar → **Authentication** → **Providers** → **Email**
>    - **Enable email provider:** ON
>    - **Confirm email:** ON
>    - **Secure email change:** ON
>    - Click **Save**
> 4. Left sidebar → **Authentication** → **Sessions**
>    - **JWT expiry (seconds):** `900`
>    - **Refresh token rotation:** ON
>    - **Reuse interval:** `10` seconds
>    - Click **Save**
> 5. Left sidebar → **Authentication** → **Advanced**
>    - **HaveIBeenPwned protection:** ON (leaked passwords)
>    - Click **Save**
> 6. Do NOT configure SMTP here yet — wait for M10 (Resend setup) to get the SMTP credentials first
>
> Status: `[ ]`

### 5.4 Row Level Security

All tables have RLS enabled in migrations 001–016. After applying migrations, verify:

> **`[MANUAL]` — Verify RLS in Supabase SQL Editor:**
> 1. Supabase Dashboard → **SQL Editor** → New Query
> 2. Paste and run:
>    ```sql
>    SELECT tablename, rowsecurity FROM pg_tables
>    WHERE schemaname = 'public' AND rowsecurity = false;
>    ```
> 3. Result must be **0 rows**. If any table appears, run:
>    ```sql
>    ALTER TABLE <table_name> ENABLE ROW LEVEL SECURITY;
>    ```
>
> Status: `[ ]`

### 5.5 Storage Buckets

> **`[MANUAL]` M6 — Create Supabase storage buckets:**
> 1. Supabase Dashboard → **Storage** (left sidebar)
> 2. Click **New bucket** for each bucket below:
>    - Name the bucket exactly as shown
>    - **Public bucket:** OFF for all (private)
>    - Click **Save** after each
>
> | Bucket name | Purpose |
> |-------------|---------|
> | `avatars` | Member profile photos |
> | `complaints` | Complaint attachments |
> | `documents` | Society documents |
> | `notices` | Notice attachments |
> | `assets` | Infrastructure photos |
> | `receipts` | Payment receipts |
>
> 3. All buckets are served via signed URLs (600-second expiry) — implemented in `src/lib/utils/signedUrl.ts`. No additional configuration needed.
>
> Status: `[ ]`

### 5.6 Database Backups

- **Upgrade Supabase to Pro ($25/month) before go-live** — free tier has no automatic backups
- Pro plan enables Point-in-Time Recovery (PITR) with 7-day retention

> **`[MANUAL]` — Upgrade to Supabase Pro:**
> 1. Supabase Dashboard → click your project name → **Settings** → **Billing**
> 2. Click **Upgrade to Pro**
> 3. Enter payment method and confirm
> 4. After upgrade, go to **Settings** → **Add-ons** → enable **Point in Time Recovery**
>
> Manual backup command (save for weekly use):
> ```bash
> pg_dump "postgresql://postgres:<password>@db.<project-ref>.supabase.co:5432/postgres" \
>   --no-privileges --no-owner \
>   -f backup_$(date +%Y%m%d).sql
> ```
>
> Status: `[ ]`

---

## Part 6 — API Layer (Vercel) Setup

### 6.1 Vercel Project Creation

```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# Link project (run from repo root)
vercel link

# Deploy to production
vercel --prod
```

> **`[MANUAL]` M9 — Create Vercel project and connect GitHub:**
> 1. Go to **vercel.com** → **Add New Project**
> 2. Click **Import Git Repository** → select `utamacs-website` from your GitHub list
>    - If not visible, click **Adjust GitHub App Permissions** and grant access to the repo
> 3. Configure the project:
>    - **Framework Preset:** Astro (auto-detected)
>    - **Root Directory:** leave as `.` (project root)
>    - **Build Command:** `npm run build:portal`
>    - **Output Directory:** `dist`
>    - **Install Command:** `npm install`
> 4. Before clicking Deploy, expand **Environment Variables** and add at minimum:
>    - `PUBLIC_SUPABASE_URL`, `PUBLIC_SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `PROVIDER=supabase`
> 5. Click **Deploy**
> 6. After first deploy succeeds, go to **Settings** → **Domains**
> 7. Click **Add Domain** → enter `portal.utamacs.org` → **Add**
> 8. Vercel shows: Add a CNAME record `portal → cname.vercel-dns.com` (already in M7 DNS list above)
> 9. Once DNS propagates, Vercel shows the domain as **Valid** with a green checkmark
>
> Status: `[ ]`

### 6.2 Build Configuration

`vercel.json` already exists with correct config:
- Build command: `npm run build:portal`
- Output: `dist/`
- Cron jobs: 4 scheduled automation endpoints

> **`[AUTO]` A5 — Claude will add `"alias": ["portal.utamacs.org"]` to `vercel.json`.**
> Status: `[ ]`

### 6.3 Custom Domain on Vercel

Covered in M9 above. DNS record (`CNAME portal cname.vercel-dns.com`) is already included in M7.

Vercel auto-provisions Let's Encrypt SSL for the subdomain automatically.

### 6.4 Environment Variables on Vercel

Covered in M2 above. After completing M2, all 13 env vars are set.

### 6.5 Rate Limiting Fix (Upstash)

`[AUTO]` A2 replaces the in-memory Map with Upstash. After M1 (Upstash database creation) and M2 (adding `UPSTASH_REDIS_REST_URL` + `UPSTASH_REDIS_REST_TOKEN` to Vercel), this is complete.

### 6.6 Function Timeout Limits

Vercel Hobby plan: 10 second function timeout. Vercel Pro: 60 seconds.
- AI insights endpoint calls Anthropic API — needs Pro plan for reliable execution
- Recommend: **Vercel Pro** ($20/month) for 60s timeout + higher bandwidth

> **`[MANUAL]` — Upgrade Vercel to Pro (optional but recommended):**
> Vercel Dashboard → Account Settings → Billing → Upgrade to Pro
>
> Status: `[ ]`

---

## Part 7 — Email System (Resend)

### 7.1 Domain Verification

> **`[MANUAL]` M10 — Set up Resend and verify domain:**
>
> **Step 1 — Create Resend account and API key:**
> 1. Go to **resend.com** → **Get Started** → sign up with Google or email
> 2. Left sidebar → **API Keys** → **Create API Key**
>    - Name: `utamacs-portal`
>    - Permission: **Full Access**
>    - Domain: **All Domains** (or restrict after domain verified)
>    - Click **Add** → copy the `re_...` key → save it (this is `RESEND_API_KEY`)
>
> **Step 2 — Verify the domain:**
> 1. Left sidebar → **Domains** → **Add Domain**
> 2. Enter `utamacs.org` → **Add**
> 3. Resend shows 4 DNS records to add. Copy each one — they'll look like:
>    ```
>    Type  Name                Value
>    MX    send                feedback-smtp.us-east-1.amazonses.com  (priority 10)
>    TXT   resend._domainkey   p=MIGfMA0...  (long DKIM key)
>    TXT   @                   v=spf1 include:resend.com -all
>    CNAME em.<hash>           <Resend-provided CNAME>
>    ```
> 4. Add all 4 records to your DNS registrar (M7) **in addition** to the GitHub Pages and Vercel records
> 5. Back on the Resend Domains page, click **Verify DNS Records** after propagation
> 6. Status changes from "Pending" to **Verified** ✓
>
> **Step 3 — Configure Supabase SMTP:**
> 1. Supabase Dashboard → **Project Settings** (gear icon) → **Authentication**
> 2. Scroll to **SMTP Settings** → toggle **Enable Custom SMTP** ON
>    - **Host:** `smtp.resend.com`
>    - **Port:** `587`
>    - **User:** `resend`
>    - **Password:** `<RESEND_API_KEY from Step 1>`
>    - **Sender name:** `UTA MACS`
>    - **Sender email:** `no-reply@utamacs.org`
> 3. Click **Save**
> 4. Test by sending a password reset to yourself
>
> Status: `[ ]`

### 7.2 Email Types & Templates

| Trigger | Endpoint |
|---------|----------|
| New member invite | Supabase auth (auto) |
| Password reset | `/api/v1/auth/forgot-password` |
| Complaint updated | `/api/v1/complaints/[id]/status` |
| Due reminder | `/api/v1/automation/payment-reminders` |
| Complaint SLA breach | `/api/v1/automation/sla-escalation` |
| AGM document approved | `/api/v1/agm/documents/[id]/approve` |

### 7.3 Email Rate Limits

- Resend free: 3,000 emails/month, 100/day — sufficient for a residential society
- Upgrade to Starter ($20/month) for 50K emails/month if notification volume grows

---

## Part 8 — Payment Integration (Razorpay)

*Razorpay is planned but not yet implemented in the codebase. This section covers what to implement.*

### 8.1 Account Setup

1. Register at razorpay.com with society PAN and GSTIN
2. Complete KYC (business type: Trust/Society, provide TS MACS registration)
3. Get API keys from Dashboard → Settings → API Keys
4. Generate **separate key pairs for Test and Live** — never mix them

### 8.2 Secret Storage

```env
RAZORPAY_KEY_ID=rzp_live_xxxxxxxxxx      # Public — can go in browser
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxx       # Server-only — never expose
RAZORPAY_WEBHOOK_SECRET=xxxxxxxxxxxxxxx  # For webhook signature validation
```

### 8.3 Payment Flow

**Create Order** (`POST /api/v1/finance/payments/create-order`):
```typescript
// Server-side using RAZORPAY_KEY_SECRET
const order = await razorpay.orders.create({
  amount: totalPaise,  // amount in paise
  currency: 'INR',
  receipt: duesId,
  notes: { society_id: SOCIETY_ID, dues_id: duesId }
});
// Return order_id to client
```

**Frontend Payment Modal:**
```javascript
const rzp = new Razorpay({
  key: PUBLIC_RAZORPAY_KEY_ID,
  order_id: order.id,
  handler: async (response) => {
    // Send payment_id + order_id + signature to server for verification
    await fetch('/api/v1/finance/payments/verify', { method: 'POST', body: JSON.stringify(response) });
  }
});
rzp.open();
```

**Verify Payment** (`POST /api/v1/finance/payments/verify`):
```typescript
// Verify HMAC signature: sha256(order_id + "|" + payment_id, KEY_SECRET)
const expectedSignature = crypto
  .createHmac('sha256', RAZORPAY_KEY_SECRET)
  .update(`${order_id}|${razorpay_payment_id}`)
  .digest('hex');
if (expectedSignature !== razorpay_signature) throw 400;
// Then record payment in DB
```

**Webhook Handler** (`POST /api/v1/webhooks/razorpay`):
```typescript
// Validate webhook signature using RAZORPAY_WEBHOOK_SECRET
const expectedSig = crypto
  .createHmac('sha256', RAZORPAY_WEBHOOK_SECRET)
  .update(rawBody)
  .digest('hex');
// Handle: payment.captured, payment.failed, refund.created
```

### 8.4 Webhook Setup

> **`[MANUAL]` M11 — Set up Razorpay account and webhooks:**
>
> **Step 1 — Account registration:**
> 1. Go to **razorpay.com** → **Sign Up** → select **Business Type: Trust/Co-operative Society**
> 2. Complete KYC with society PAN, GSTIN, and TS MACS registration certificate
> 3. KYC review takes 2-3 business days
>
> **Step 2 — Get API keys (after KYC approval):**
> 1. Razorpay Dashboard → **Settings** → **API Keys** → **Generate Key Pair** (Live mode)
> 2. **Key ID** (starts with `rzp_live_`) → save as `RAZORPAY_KEY_ID`
> 3. **Key Secret** → save as `RAZORPAY_KEY_SECRET` (shown only once — save immediately)
> 4. Add both to Vercel environment variables (see M2)
>
> **Step 3 — Set up webhook:**
> 1. Razorpay Dashboard → **Settings** → **Webhooks** → **Add New Webhook**
> 2. **Webhook URL:** `https://portal.utamacs.org/api/v1/webhooks/razorpay`
> 3. **Secret:** generate with `openssl rand -hex 20` → save as `RAZORPAY_WEBHOOK_SECRET`
> 4. **Active Events:** tick `payment.captured`, `payment.failed`, `refund.processed`
> 5. Click **Create Webhook**
> 6. Add `RAZORPAY_WEBHOOK_SECRET` to Vercel env vars
>
> Status: `[ ]`

---

## Part 9 — Authentication Hardening

### 9.1 Password Policy

> **`[MANUAL]` M12 — Configure Supabase auth security settings:**
> 1. Supabase Dashboard → **Authentication** → **Providers** → **Email**
>    - **Minimum password length:** 8
>    - **Password strength:** Require lowercase, uppercase, and numbers
>    - Click **Save**
> 2. Supabase Dashboard → **Authentication** → **Advanced**
>    - **HaveIBeenPwned protection:** Enabled (already covered in M5)
>
> Status: `[ ]`

### 9.2 Email Verification

- All new accounts must verify email before portal access
- Supabase handles this automatically when email confirmations are enabled (set in M5)
- The middleware already blocks unverified sessions (`validateToken` throws on invalid)

### 9.3 Session Configuration

Covered in M5 (JWT expiry, refresh token rotation). Sessions use `HttpOnly; Secure; SameSite=Strict` cookies — already implemented in the auth API.

### 9.4 MFA for Admin/Executive

Supabase supports TOTP-based MFA. The MFA endpoints are currently stubbed (501). Enabling Supabase MFA is done via dashboard; portal middleware enforcement requires code changes post-launch.

> **`[MANUAL]` — Enable Supabase MFA (recommended post-launch):**
> 1. Supabase Dashboard → **Authentication** → **Providers** → **Multi-Factor Authentication**
> 2. Toggle **TOTP** ON
> 3. Click **Save**
> Admin users will be prompted to enroll via Google Authenticator on next login.
>
> Status: `[ ]` (post-launch task)

### 9.5 Failed Login Protection

Rate limiter handles this: 10 attempts per 15 minutes per IP on `/api/v1/auth/*`. After `[AUTO]` A2 (Upstash migration), this is enforced across all function instances.

---

## Part 10 — CI/CD Pipeline

### 10.1 Existing Pipeline (GitHub Pages)

`.github/workflows/deploy.yml` already builds and deploys the static site on push to `main`. No changes needed beyond adding environment scoping.

### 10.2 New Pipeline: Portal → Vercel

> **`[AUTO]` A4 — Claude will create `.github/workflows/deploy-portal.yml`:**

```yaml
name: Deploy Portal to Vercel

on:
  push:
    branches: [main, staging]
  pull_request:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Type check
        run: npx tsc --noEmit --skipLibCheck

      - name: Build portal
        run: npm run build:portal
        env:
          PUBLIC_SUPABASE_URL: ${{ secrets.PUBLIC_SUPABASE_URL }}
          PUBLIC_SUPABASE_ANON_KEY: ${{ secrets.PUBLIC_SUPABASE_ANON_KEY }}
          PUBLIC_SOCIETY_ID: ${{ secrets.PUBLIC_SOCIETY_ID }}

      - name: Deploy to Vercel
        run: |
          npm install -g vercel
          if [ "${{ github.ref }}" = "refs/heads/main" ]; then
            vercel --prod --token=${{ secrets.VERCEL_TOKEN }} \
              --scope=${{ secrets.VERCEL_ORG_ID }} \
              --yes
          else
            vercel --token=${{ secrets.VERCEL_TOKEN }} \
              --scope=${{ secrets.VERCEL_ORG_ID }} \
              --yes
          fi
        env:
          VERCEL_PROJECT_ID: ${{ secrets.VERCEL_PROJECT_ID }}
          VERCEL_ORG_ID: ${{ secrets.VERCEL_ORG_ID }}
```

Status: `[ ]`

### 10.3 Branch Strategy

```
main      → utamacs.org (GitHub Pages) + portal.utamacs.org (Vercel prod)
staging   → staging-portal.utamacs.org (Vercel staging)
feature/* → Vercel Preview URLs (auto-generated per PR)
```

### 10.4 GitHub Branch Protection (main)

> **`[MANUAL]` M16 — Enable GitHub branch protection:**
> 1. Go to your GitHub repo → **Settings** → **Branches**
> 2. Under **Branch protection rules**, click **Add rule**
> 3. **Branch name pattern:** `main`
> 4. Enable these checkboxes:
>    - ✅ **Require a pull request before merging** → set required approvals to `1`
>    - ✅ **Require status checks to pass before merging** → search for and add: `type-check`, `build portal`
>      (These job names come from the workflow Claude creates in A4 — add them after first CI run)
>    - ✅ **Dismiss stale pull request approvals when new commits are pushed**
>    - ✅ **Restrict who can push to matching branches** → add yourself
>    - ✅ **Do not allow bypassing the above settings**
> 5. Click **Create**
>
> Status: `[ ]`

### 10.5 Supabase Migration CI

Migration validation runs as part of the `deploy-portal.yml` workflow in A4 — it validates with `--dry-run` against staging before applying to prod.

---

## Part 11 — Monitoring & Logging

### 11.1 Error Tracking — Sentry

> **`[MANUAL]` M13 — Set up Sentry error tracking:**
> 1. Go to **sentry.io** → **Sign Up** → create organization `utamacs`
> 2. **Create Project** → Platform: **JavaScript** → Framework: **Astro**
> 3. Sentry gives you a DSN URL (looks like `https://abc123@o123.ingest.sentry.io/456`)
> 4. Copy the DSN → add to Vercel env vars as `SENTRY_DSN`
> 5. Claude will add the Sentry integration to `astro.portal.config.mjs` — **do not install manually, wait for A6**
>
> Status: `[ ]`

> **`[AUTO]` A6 — Claude will add `@sentry/astro` dependency and configure it in `astro.portal.config.mjs`** after M13 provides the DSN.
>
> Status: `[ ]`

### 11.2 Vercel Log Drain

> **`[MANUAL]` — (Optional) Add Vercel Log Drain to Axiom (free):**
> 1. Create free account at **axiom.co** → New Dataset → name: `utamacs-logs`
> 2. Copy the **Axiom API token** from Settings → API Tokens
> 3. Vercel Dashboard → Project → **Settings** → **Log Drains** → **Add Log Drain**
>    - Or use: Vercel → Integrations → search "Axiom" → Install → connect
>
> Status: `[ ]` (optional)

### 11.3 Supabase Logs

Supabase Dashboard → **Logs Explorer** (left sidebar). API, Auth, and Storage logs are visible here automatically. No configuration needed beyond ensuring Pro plan for 90-day retention.

### 11.4 Uptime Monitoring

> **`[MANUAL]` M14 — Set up Uptime Robot monitoring:**
> 1. Go to **uptimerobot.com** → Sign Up (free)
> 2. **Add New Monitor** (repeat for each URL below):
>    - **Monitor Type:** HTTP(s)
>    - URL: `https://utamacs.org`
>    - Friendly Name: `UTA MACS Public Site`
>    - Monitoring Interval: `5 minutes`
>    - Alert: add your email
> 3. Add second monitor:
>    - URL: `https://portal.utamacs.org/api/v1/health`
>    - Friendly Name: `UTA MACS Portal API`
>    - Monitoring Interval: `5 minutes`
> 4. Click **Create Monitor** for each
>
> Status: `[ ]`

### 11.5 Custom Health Check Endpoint

> **`[AUTO]` A3 — Claude will create `src/pages/api/v1/health.ts`** with DB connectivity check.
>
> Status: `[ ]`

---

## Part 12 — Backup & Recovery

### 12.1 Database Backups

| Backup Type | Frequency | Retention | Tool |
|-------------|-----------|-----------|------|
| Supabase PITR | Continuous | 7 days (Pro) | Auto |
| Full pg_dump | Daily | 30 days | GitHub Action |
| Pre-migration snapshot | Before each deploy | Until next deploy | Manual |

**Automated daily backup via GitHub Actions:**
```yaml
- name: Database backup
  run: |
    pg_dump "${{ secrets.DATABASE_URL }}" \
      --no-privileges --no-owner --clean \
      | gzip > backup_$(date +%Y%m%d).sql.gz
    # Upload to Supabase Storage (private bucket) or S3
```

### 12.2 Storage Backups

Supabase Storage files are stored on AWS S3 under the hood. Manual backup:
```bash
# Download all files using Supabase Storage API
npx supabase storage download --recursive gs://storage.utamacs.org
```
Store a weekly copy in Google Drive (society's G Suite account).

### 12.3 Recovery Plan

**Database corruption/accidental delete:**
1. Stop Vercel deployments (disable Vercel project)
2. Use Supabase PITR to restore to a point before the incident
3. Or restore from `pg_dump` file: `psql <connection_string> < backup_YYYYMMDD.sql.gz`
4. Re-enable Vercel

**Vercel outage:**
- Static site (utamacs.org) on GitHub Pages is unaffected
- Portal is unavailable — communicate via WhatsApp broadcast
- Recovery: Automatic once Vercel resolves (SLA: 99.99% uptime)

**Target RTO (Recovery Time Objective):** 4 hours
**Target RPO (Recovery Point Objective):** 24 hours (daily backup)

---

## Part 13 — Domain & DNS Setup

### 13.1 Complete DNS Record Set

At your domain registrar (GoDaddy/Namecheap/Google Domains) for `utamacs.org`:

```
# GitHub Pages — main site
Type  Name   Value                    TTL
A     @      185.199.108.153          3600
A     @      185.199.109.153          3600
A     @      185.199.110.153          3600
A     @      185.199.111.153          3600
CNAME www    utamacs-org.github.io.   3600

# Vercel — portal
CNAME portal cname.vercel-dns.com.   3600

# Resend — email authentication
TXT   @      v=spf1 include:resend.com -all                     3600
TXT   resend._domainkey   <DKIM key from Resend dashboard>       3600
MX    @      feedback-smtp.us-east-1.amazonses.com (priority 10) 3600

# DMARC — email fraud prevention
TXT   _dmarc v=DMARC1; p=none; rua=mailto:dmarc@utamacs.org     3600
```

See M7 for the step-by-step registrar navigation instructions.

### 13.2 SSL/TLS

- **utamacs.org:** Auto-provisioned by GitHub Pages (Let's Encrypt)
- **portal.utamacs.org:** Auto-provisioned by Vercel (Let's Encrypt)
- Both renew automatically — no action required
- HSTS header already set in `securityHeaders.ts`: `max-age=31536000; includeSubDomains; preload`

### 13.3 HSTS Preload

After 30 days of stable HTTPS operation, submit to HSTS preload list:
- Visit: hstspreload.org
- Submit `utamacs.org` — this tells browsers to always use HTTPS even on first visit

---

## Part 14 — Security Best Practices

### 14.1 CORS Configuration

Vercel serves portal API on the same domain as the portal frontend — no CORS needed for same-origin requests. If external clients ever need API access, add explicit CORS headers in the middleware:
```typescript
// Only allow specific origins
const allowedOrigins = ['https://utamacs.org', 'https://portal.utamacs.org'];
```

### 14.2 Content Security Policy

Current CSP in `src/lib/middleware/securityHeaders.ts` is good. Before launch, audit and tighten:
- Remove `'unsafe-inline'` from `style-src` by moving all inline styles to external files
- Add `nonce` to inline scripts (Astro supports this)
- Test at: csplite.com or security-headers.com → should score A

### 14.3 Input Validation Summary

Already implemented:
- `sanitizePlainText()` for all user-submitted text (`src/lib/utils/sanitize.ts`)
- Server-side DOMPurify for rich text fields
- Type checking on all request bodies
- Enum validation for status fields, enum types

Add before launch:
- Validate file upload MIME types at the API layer (not just extension)
- Maximum request body size limit (add to Vercel route config)

### 14.4 Dependency Security

> **`[AUTO]` A6 — Claude will create `.github/dependabot.yml`** for automatic weekly dependency updates.
>
> After creation, run manually:
> ```bash
> npm audit
> npm audit fix
> ```
> Status: `[ ]`

---

## Part 15 — Performance Optimization

### 15.1 Static Site (GitHub Pages)

- Astro already produces minified, tree-shaken HTML/CSS/JS
- All bundle assets have content-hash suffixes (cache-busted automatically)
- Images in `public/` — compress using `squoosh` or `sharp` before adding
- No CDN needed for GitHub Pages — it uses Fastly globally

### 15.2 Portal (Vercel)

- Vercel Edge Network handles CDN for all static assets in `dist/_astro/`
- Server-side rendered pages are cached by Vercel by default — use `export const revalidate = 60` where appropriate
- Feature flags are cached in-memory with 60s TTL (already in `FeatureFlagService.ts`)
- Supabase queries: all queries use `select()` with only needed columns — no `SELECT *`

### 15.3 Database Performance

After applying migrations, create performance indexes:
```sql
-- Complaints: common query patterns
CREATE INDEX IF NOT EXISTS complaints_society_status_idx ON complaints (society_id, status);
CREATE INDEX IF NOT EXISTS complaints_raised_by_idx ON complaints (raised_by);

-- Notifications: unread query
CREATE INDEX IF NOT EXISTS notifications_user_read_idx ON notifications (user_id, is_read);

-- Payments: recent payments
CREATE INDEX IF NOT EXISTS payments_society_paid_at_idx ON payments (society_id, paid_at DESC);
```

### 15.4 Vercel Function Cold Starts

- Vercel serverless functions cold start in ~200-400ms on first request
- Subsequent requests are warm
- For the cron jobs, cold starts are acceptable
- To reduce: keep function bundle size small (avoid large imports)

---

## Part 16 — Testing Strategy

### 16.1 Pre-Launch Test Plan

**Environment:** Staging (separate Supabase + Vercel staging URL)

**Test Users to Create:**
| Role | Email | Purpose |
|------|-------|---------|
| admin | admin@test.utamacs.org | Full admin access |
| executive | exec@test.utamacs.org | Executive workflows |
| member | member@test.utamacs.org | Member flows |
| security_guard | guard@test.utamacs.org | Visitor logging |

### 16.2 Critical Path Tests

Run these on staging before launch:

1. **Auth Flow:** Login → access portal → log out → confirm session ended
2. **Admin Flow:** Login as admin → change feature flag → confirm change takes effect
3. **Member Flow:** Login as member → raise complaint → track status update
4. **Exec Flow:** Login as exec → assign complaint → member sees update
5. **Finance Flow:** Create billing period → member sees due → record payment → generate GST invoice
6. **Visitor Flow:** Pre-approve visitor → log entry → log exit
7. **Parking Flow:** Add slot → allocate to member → release → waitlist entry gets notified
8. **AGM Flow:** Exec submits document → Admin approves → member sees published doc
9. **Cron Jobs:** Trigger SLA escalation manually → confirm complaint notification sent
10. **Rate Limiting:** Exceed 10 auth attempts → confirm 429 response

### 16.3 TypeScript Type Check

```bash
# Must pass with 0 errors before every deploy
npx tsc --noEmit --skipLibCheck
```

### 16.4 Security Scan

Run before launch:
```bash
# Dependency audit
npm audit --audit-level=high

# Check for exposed secrets in code
npx detect-secrets scan src/ > secrets_scan.json
# Review secrets_scan.json — all findings should be false positives
```

---

## Part 17 — Go-Live Checklist

### Phase A: Preparation (1 week before)
- [ ] Supabase prod project created (M3)
- [ ] All 16 migrations applied to prod Supabase (M4)
- [ ] RLS verified — 0 unprotected tables
- [ ] All storage buckets created (M6)
- [ ] Vercel prod project created and linked (M9)
- [ ] All env vars set in Vercel prod (M2)
- [ ] Upstash Redis created, URL+token added to Vercel (M1)
- [ ] Rate limiter replaced with Upstash implementation (A2)
- [ ] Resend domain verified, SMTP configured in Supabase auth (M10)
- [ ] DNS records configured — A, CNAME, SPF, DKIM, DMARC, MX (M7)
- [ ] SSL verified on both domains (green padlock)
- [ ] GitHub branch protection rules enabled on `main` (M16)
- [ ] CI/CD pipeline for portal deployed and tested (A4)
- [ ] Health check endpoint live: `GET /api/v1/health` returns 200 (A3)
- [ ] CRON_SECRET set in Vercel (M17)

### Phase B: Staging Validation (3 days before)
- [ ] All 10 critical path tests passed on staging
- [ ] TypeScript check passes: `npx tsc --noEmit --skipLibCheck`
- [ ] `npm audit` shows 0 high/critical vulnerabilities
- [ ] Security headers score A at securityheaders.com
- [ ] Rate limiter verified: 11th auth request returns 429
- [ ] CRON_SECRET verified: Vercel cron runs complete successfully
- [ ] Email delivery confirmed (password reset email received)
- [ ] All 4 cron jobs triggered manually and produce correct results

### Phase C: Data Setup (2 days before)

> **`[MANUAL]` M18 — Seed initial society data via Supabase SQL Editor:**
>
> 1. Go to Supabase Dashboard → **SQL Editor** → **New Query**
> 2. Run this SQL to create the society record:
>    ```sql
>    INSERT INTO societies (id, name, registration_no, address, city, state, pincode, gstin, pan, contact_email, contact_phone)
>    VALUES (
>      gen_random_uuid(),
>      'UTA MACS',
>      'TS/MACS/RR/<your-reg-number>',
>      'Urban Trilla Apartments, Kondakal, Shankarpalle',
>      'Hyderabad', 'Telangana', '501203',
>      '<your-gstin>',  -- format: 36AAAAU0000A1Z5
>      '<your-pan>',
>      'management@utamacs.org',
>      '+91XXXXXXXXXX'
>    ) RETURNING id;
>    ```
> 3. **Copy the returned UUID** — this is your `PUBLIC_SOCIETY_ID`. Add it to Vercel env vars (M2).
> 4. Seed unit records (adjust block/unit numbers to match your building layout):
>    ```sql
>    -- Example: insert units for Tower A (A-101 through A-304)
>    -- Replace <society_id> with the UUID from step 3
>    INSERT INTO units (society_id, block, unit_number, floor, bedrooms, ownership_type)
>    SELECT
>      '<society_id>',
>      block,
>      unit_number,
>      floor_no,
>      2,  -- default 2BHK
>      'owned'
>    FROM (
>      SELECT
>        'A' as block,
>        'A-' || (floor_no::text) || lpad(unit_no::text, 2, '0') as unit_number,
>        floor_no
>      FROM generate_series(1, 3) as floor_no,
>           generate_series(1, 4) as unit_no
>    ) units_to_insert;
>    -- Repeat for Tower B, C as needed
>    ```
> 5. Create admin user via Supabase Dashboard → **Authentication** → **Users** → **Invite user**:
>    - Enter admin email (yours)
>    - After invite accepted, update the `members` table:
>      ```sql
>      UPDATE members SET role = 'admin' WHERE email = '<your-email>';
>      ```

- [ ] Society record created in `societies` table (M18)
- [ ] Initial unit records seeded (all flat numbers in Tower A/B/C)
- [ ] `PUBLIC_SOCIETY_ID` set in Vercel env vars (M2)
- [ ] Admin user created and role set to `admin`
- [ ] Executive user accounts created
- [ ] Feature flags configured for initial rollout — enable core modules only:
  - ✅ complaints, notices, finance, members
  - ❌ community, marketplace, parking (enable after 2 weeks)

### Phase D: Go-Live (launch day)
- [ ] Announce to committee: planned maintenance window 10pm–midnight
- [ ] Final pg_dump backup of staging (as reference)
- [ ] Deploy portal to Vercel prod: `vercel --prod`
- [ ] Confirm GitHub Pages site live at utamacs.org
- [ ] Send password-set emails to all member accounts
- [ ] Monitor Sentry for first 2 hours — zero new errors expected
- [ ] Monitor Uptime Robot — both URLs green
- [ ] Committee smoke test: each executive logs in and confirms dashboard loads

### Phase E: Rollback Plan
If critical issues found within 24 hours of launch:
1. Vercel: Redeploy previous build (Vercel Dashboard → Deployments → select previous → Promote)
2. Supabase: No rollback needed unless schema migration is involved — data is forward-only
3. GitHub Pages: Revert `docs/` folder commit: `git revert HEAD` + push
4. Communicate downtime via society WhatsApp group

---

## Part 18 — Post-Launch Operations

### 18.1 First 30 Days

| Week | Action |
|------|--------|
| 1 | Monitor daily: Sentry errors, Supabase auth logs, Uptime Robot |
| 1 | Collect member feedback via WhatsApp / committee meeting |
| 2 | Enable parking module via feature flag |
| 2 | Enable community posts module |
| 3 | Enable marketplace listings |
| 4 | Review: TDS tracking accuracy, AGM document workflow adoption |
| 4 | Run first manual database backup, verify restore works |

### 18.2 Monthly Operations Checklist

- [ ] Review Sentry: resolve all new errors
- [ ] Rotate `IP_HASH_SALT` (per DPDPA design)
- [ ] Review Vercel usage: function invocations, bandwidth
- [ ] Review Resend usage: email delivery rate, bounces
- [ ] Review Upstash: command count vs. free tier limit
- [ ] Apply any `npm audit` security patches

### 18.3 Quarterly Operations

- [ ] Rotate API keys (Supabase service role, Resend, Upstash)
- [ ] Review member consent status (portal/admin/consent)
- [ ] Review audit log volume — archive logs older than 90 days if needed
- [ ] Update `PRIVACY_POLICY_VERSION` env var if policy changed (triggers member re-consent)
- [ ] Review executive role expiry dates — update in member management

### 18.4 Feature Rollout Strategy

Use the feature flag system (portal/admin/features) to roll out new features:
1. Enable for `executive` role only → internal testing
2. Enable for all roles → soft launch
3. Monitor for 1 week → confirm stable
4. Document in member newsletter

---

## Critical Files — Automated Changes Summary

### `[AUTO]` Files Claude will create/modify:

| Task | File | Action |
|------|------|--------|
| A2 | `src/lib/middleware/rateLimiter.ts` | Replace in-memory Map with Upstash Redis |
| A3 | `src/pages/api/v1/health.ts` | Create new health check endpoint |
| A4 | `.github/workflows/deploy-portal.yml` | Create Vercel CI/CD pipeline |
| A5 | `vercel.json` | Add `"alias": ["portal.utamacs.org"]` |
| A6 | `.github/dependabot.yml` | Create dependency auto-update config |

### `[MANUAL]` External services to configure:

Complete M1 through M18 in order, referencing the detailed steps in each section above.
