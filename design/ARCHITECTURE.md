# UTA MACS — Full-Stack Association Management Platform
## Architecture, Design & Execution Plan

---

## Context

The current site is a fully static Astro v4 + Tailwind CSS build deployed to GitHub Pages (utamacs.org). It has 10 public pages, hardcoded TypeScript data files, and no backend. The goal is to evolve it into a complete nonprofit association management platform with a live authenticated member portal, while keeping public pages on GitHub Pages untouched.

**Stack decision:** Supabase (auth + PostgreSQL + storage + RLS) + Astro SSR deployed to Vercel for the portal. Public pages stay static on GitHub Pages.

---

## 1. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        PUBLIC INTERNET                               │
└────────────────┬────────────────────────────┬───────────────────────┘
                 │                            │
         utamacs.org                  portal.utamacs.org
                 │                            │
    ┌────────────▼────────────┐   ┌───────────▼──────────────┐
    │   GitHub Pages          │   │   Vercel (Free Hobby)     │
    │   Static HTML           │   │   Astro SSR (Hybrid)      │
    │   10 public pages       │   │   Member Portal           │
    │   (existing, unchanged) │   │   Protected routes        │
    └─────────────────────────┘   └───────────┬──────────────┘
                                              │
                              ┌───────────────▼──────────────────┐
                              │         SUPABASE                  │
                              │  ┌──────────┐  ┌──────────────┐  │
                              │  │ Auth     │  │ PostgreSQL DB │  │
                              │  │ Sessions │  │ 25+ tables   │  │
                              │  │ JWT/RLS  │  │ RLS policies │  │
                              │  └──────────┘  └──────────────┘  │
                              │  ┌──────────┐  ┌──────────────┐  │
                              │  │ Storage  │  │ Edge Funcs   │  │
                              │  │ 7 buckets│  │ Notifications│  │
                              │  └──────────┘  └──────────────┘  │
                              └──────────────────────────────────┘
```

**Key principle:** Two deployment targets, one git repo. `astro.config.mjs` (static, GitHub Pages). `astro.portal.config.mjs` (hybrid SSR, Vercel). GitHub Actions deploys static docs/ unchanged. Vercel auto-deploys portal on every push to main.

---

## 2. Deployment Architecture

### Public Site — GitHub Pages (no changes)
- Domain: `utamacs.org`
- Source: `docs/` folder, existing GitHub Actions workflow unchanged
- Navbar updated to add "Portal" link → `https://portal.utamacs.org`

### Member Portal — Vercel (new)
- Domain: `portal.utamacs.org` (Vercel free custom domain)
- Adapter: `@astrojs/vercel`
- Config: `astro.portal.config.mjs` (output: 'hybrid')
- Build: triggered by Vercel GitHub integration on push to `main`
- Env vars: Supabase keys stored in Vercel dashboard (never in repo)

### DNS
```
utamacs.org          → GitHub Pages         (existing, unchanged)
portal.utamacs.org   → cname.vercel-dns.com (new CNAME record)
```

### Two Astro Configs
```
astro.config.mjs          output: 'static',  outDir: './docs'  (GitHub Pages)
astro.portal.config.mjs   output: 'hybrid',  @astrojs/vercel   (Vercel)
```
`vercel.json` overrides build command to use portal config.

---

## 3. Role Model & Access Matrix

| Capability | Public | Member | Executive | Admin |
|---|:---:|:---:|:---:|:---:|
| View public pages | ✓ | ✓ | ✓ | ✓ |
| Login / manage profile | — | ✓ | ✓ | ✓ |
| Raise & track own complaints | — | ✓ | ✓ | ✓ |
| View & manage ALL complaints | — | — | ✓ | ✓ |
| Assign complaints / update status | — | — | ✓ | ✓ |
| Create/publish notices | — | — | ✓ | ✓ |
| Create/manage events | — | — | ✓ | ✓ |
| Register for events | — | ✓ | ✓ | ✓ |
| Create polls | — | — | ✓ | ✓ |
| Vote in polls | — | ✓ | ✓ | ✓ |
| View poll results | — | own only | ✓ | ✓ |
| Create community posts | — | ✓ | ✓ | ✓ |
| Moderate/pin posts | — | — | ✓ | ✓ |
| View own dues & payments | — | ✓ | ✓ | ✓ |
| Manage dues for all members | — | — | ✓ | ✓ |
| View member directory | — | ✓ | ✓ | ✓ |
| Manage members & roles | — | — | — | ✓ |
| Manage vendors | — | — | ✓ | ✓ |
| Manage FAQs & documents | — | — | ✓ | ✓ |
| Analytics dashboard | — | — | ✓ | ✓ |
| View audit logs | — | — | — | ✓ |
| System settings | — | — | — | ✓ |

---

## 4. Database Schema (Supabase PostgreSQL)

### Auth & Profiles
```sql
-- auth.users managed by Supabase Auth (id, email, created_at)

profiles
  id              uuid PK → auth.users.id
  full_name       text
  flat_number     text          -- "A-101"
  block           text          -- A, B, C ...
  floor           int
  phone           text
  ownership_type  enum(owner, tenant)
  move_in_date    date
  avatar_url      text
  is_active       boolean DEFAULT true
  created_at / updated_at  timestamptz

user_roles
  user_id    uuid PK → auth.users.id
  role       enum(member, executive, admin)
  granted_by uuid → auth.users.id
  granted_at timestamptz DEFAULT now()
```

### Notices
```sql
notices
  id, title, body, category(enum), is_pinned, is_published
  published_at, expires_at, attachment_url
  created_by → auth.users.id
  created_at / updated_at
```

### Events
```sql
events
  id, title, description, category, starts_at, ends_at
  location, capacity, registration_deadline
  is_published, banner_url, created_by → auth.users.id

event_registrations
  id, event_id → events.id, user_id → auth.users.id
  status enum(registered, waitlisted, cancelled)
  registered_at
  UNIQUE(event_id, user_id)
```

### Complaints / Service Requests
```sql
complaints
  id, ticket_number (UTA-2025-0001, unique)
  title, description
  category enum(Plumbing, Electrical, Lift, Security, Housekeeping,
                Parking, Water_Supply, Maintenance, Common_Area,
                Pest_Control, Internet_Cable, Other)
  priority enum(Low, Medium, High, Critical) DEFAULT 'Medium'
  status   enum(Open, Assigned, In_Progress, Waiting_for_User,
                Resolved, Closed, Reopened) DEFAULT 'Open'
  raised_by → auth.users.id
  assigned_to → auth.users.id (nullable)
  flat_number, sla_deadline, resolved_at
  created_at / updated_at

complaint_comments
  id, complaint_id, user_id, comment
  is_internal boolean  -- executives-only visibility
  created_at

complaint_attachments
  id, complaint_id, file_url, file_name, uploaded_by, created_at

complaint_status_history
  id, complaint_id, old_status, new_status, note, changed_by, changed_at
```

### Polls & Voting
```sql
polls
  id, title, description
  poll_type enum(single_choice, multiple_choice, yes_no)
  is_anonymous boolean, starts_at, ends_at, is_published, created_by

poll_options
  id, poll_id, option_text, order_index, vote_count (cached)

poll_votes
  id, poll_id, option_id
  user_id (nullable for anonymous)
  voted_at
  UNIQUE(poll_id, user_id)
```

### Community Posts
```sql
posts
  id, title, body, author_id, category
  is_pinned, is_published, like_count
  created_at / updated_at

post_comments
  id, post_id, author_id, body, parent_id (nullable for replies), created_at

post_likes
  post_id, user_id  PRIMARY KEY(post_id, user_id)
```

### Finance
```sql
maintenance_dues
  id, flat_number, user_id, amount, due_date
  period ("Q1 2025"), status enum(pending, paid, overdue)
  created_at

payments
  id, dues_id, user_id, amount, payment_method
  payment_reference, receipt_url, paid_at, created_at
```

### Supporting Tables
```sql
documents   id, title, subtitle, description, category(enum), file_url,
            is_public, created_by, created_at/updated_at

galleries   id, title, image_url, event_id(nullable), uploaded_by,
            is_published, created_at

vendors     id, name, category, phone, email, is_active, created_at

faqs        id, question, answer, category, order_index,
            is_published, created_by, created_at

notifications
            id, user_id, title, body
            type enum(complaint, event, notice, poll, payment, post, system)
            reference_id(nullable), is_read DEFAULT false, created_at

audit_logs  id, user_id, action(CREATE/UPDATE/DELETE/LOGIN/LOGOUT)
            resource_type, resource_id, old_values(jsonb), new_values(jsonb)
            ip_address, created_at
```

### Storage Buckets
| Bucket | Read Access | Write Access |
|--------|-------------|--------------|
| `profile-photos` | Auth users | Owner only |
| `notice-attachments` | Auth users | Executive/Admin |
| `event-banners` | Public | Executive/Admin |
| `complaint-attachments` | Owner + Executive | Owner |
| `documents` | Public or auth (per row) | Executive/Admin |
| `gallery` | Public | Executive/Admin |
| `receipts` | Owner only | System |

---

## 5. Row-Level Security (RLS) Patterns

```sql
-- Reusable helper (avoids per-row joins)
CREATE FUNCTION get_user_role(uid uuid) RETURNS text LANGUAGE sql STABLE AS $$
  SELECT role::text FROM user_roles WHERE user_id = uid
$$;

-- Complaints: member sees own, executive sees all
CREATE POLICY complaints_select ON complaints FOR SELECT USING (
  raised_by = auth.uid()
  OR get_user_role(auth.uid()) IN ('executive', 'admin')
);

-- Complaints: any authenticated user can insert (own complaints only)
CREATE POLICY complaints_insert ON complaints FOR INSERT WITH CHECK (
  raised_by = auth.uid()
);

-- Complaints: executives/admins can update
CREATE POLICY complaints_update ON complaints FOR UPDATE USING (
  get_user_role(auth.uid()) IN ('executive', 'admin')
);

-- Notices: anyone can read published
CREATE POLICY notices_public_read ON notices FOR SELECT USING (is_published = true);

-- Notices: executive/admin can write
CREATE POLICY notices_write ON notices FOR ALL USING (
  get_user_role(auth.uid()) IN ('executive', 'admin')
);

-- Dues: member sees own only
CREATE POLICY dues_select ON maintenance_dues FOR SELECT USING (
  user_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive', 'admin')
);

-- Polls: one vote per member
CREATE POLICY poll_votes_once ON poll_votes FOR INSERT WITH CHECK (
  user_id = auth.uid()
  AND NOT EXISTS (SELECT 1 FROM poll_votes WHERE poll_id = NEW.poll_id AND user_id = auth.uid())
);

-- Audit logs: admin only
CREATE POLICY audit_admin_only ON audit_logs FOR SELECT USING (
  get_user_role(auth.uid()) = 'admin'
);
```

---

## 6. Project Folder Structure

```
utamacs-website/
├── src/
│   ├── components/
│   │   ├── layout/
│   │   │   ├── Layout.astro              existing (public pages)
│   │   │   ├── PortalLayout.astro        NEW — sidebar + header shell
│   │   │   ├── Navbar.astro              modify: add "Portal" link
│   │   │   └── Footer.astro              existing
│   │   ├── ui/                           all existing UI components
│   │   ├── sections/                     all existing section components
│   │   └── portal/                       NEW — React islands (client-side)
│   │       ├── auth/
│   │       │   ├── LoginForm.tsx
│   │       │   └── ResetPasswordForm.tsx
│   │       ├── shared/
│   │       │   ├── DataTable.tsx         reusable sortable/filterable table
│   │       │   ├── StatusBadge.tsx
│   │       │   ├── Pagination.tsx
│   │       │   └── NotificationBell.tsx  realtime badge + dropdown
│   │       ├── dashboard/
│   │       │   ├── MemberDashboard.tsx
│   │       │   ├── ExecutiveDashboard.tsx  recharts analytics
│   │       │   └── AdminDashboard.tsx
│   │       ├── complaints/
│   │       │   ├── ComplaintForm.tsx
│   │       │   ├── ComplaintList.tsx
│   │       │   └── ComplaintDetail.tsx
│   │       ├── notices/
│   │       │   ├── NoticeEditor.tsx
│   │       │   └── NoticeManager.tsx
│   │       ├── events/
│   │       │   ├── EventRegistration.tsx
│   │       │   └── EventEditor.tsx
│   │       ├── polls/
│   │       │   ├── PollVoting.tsx
│   │       │   └── PollEditor.tsx
│   │       ├── finance/
│   │       │   ├── DuesTracker.tsx
│   │       │   └── PaymentHistory.tsx
│   │       ├── community/
│   │       │   ├── PostFeed.tsx
│   │       │   └── PostEditor.tsx
│   │       ├── admin/
│   │       │   ├── UserManager.tsx
│   │       │   ├── RoleAssigner.tsx
│   │       │   └── AuditLogViewer.tsx
│   │       └── profile/
│   │           └── ProfileEditor.tsx
│   ├── lib/
│   │   ├── supabase/
│   │   │   ├── client.ts           browser client (PUBLIC_SUPABASE_ANON_KEY)
│   │   │   ├── server.ts           SSR client using @supabase/ssr + cookies
│   │   │   └── database.types.ts   generated: `supabase gen types typescript`
│   │   ├── auth/
│   │   │   └── helpers.ts          getSession(), requireRole(), redirectTo()
│   │   └── utils/
│   │       ├── format.ts           date, currency, ticket number formatters
│   │       └── constants.ts        roles, categories, statuses enums
│   ├── middleware.ts                session validation + role guards on /portal/*
│   ├── pages/
│   │   ├── (all existing public pages — unchanged)
│   │   ├── login.astro             modify: embed LoginForm.tsx island
│   │   ├── api/
│   │   │   └── auth/
│   │   │       ├── callback.ts     email confirmation + OAuth redirect handler
│   │   │       └── signout.ts      POST: destroy session, redirect to /login
│   │   └── portal/                 NEW SSR pages (export const prerender = false)
│   │       ├── index.astro         dashboard (role-adaptive)
│   │       ├── profile.astro
│   │       ├── complaints/
│   │       │   ├── index.astro
│   │       │   ├── new.astro
│   │       │   └── [id].astro
│   │       ├── notices/
│   │       │   ├── index.astro
│   │       │   └── [id].astro
│   │       ├── events/
│   │       │   ├── index.astro
│   │       │   └── [id].astro
│   │       ├── polls/index.astro
│   │       ├── finance/index.astro
│   │       ├── community/index.astro
│   │       └── admin/              admin-only
│   │           ├── users.astro
│   │           ├── settings.astro
│   │           └── audit.astro
│   ├── data/                       existing static data (public pages only)
│   └── styles/
│       ├── global.css              existing
│       └── portal.css              NEW — sidebar, dashboard layout styles
├── supabase/
│   ├── migrations/
│   │   ├── 001_schema.sql          all CREATE TABLE statements
│   │   ├── 002_rls.sql             all RLS ENABLE + CREATE POLICY
│   │   ├── 003_functions.sql       helper functions + audit triggers
│   │   └── 004_seed.sql            test users, sample notices/events
│   └── config.toml                 local Supabase CLI config
├── astro.config.mjs                existing (static, docs/ output)
├── astro.portal.config.mjs         NEW (hybrid, @astrojs/vercel)
├── vercel.json                     NEW (points build to portal config)
├── tailwind.config.mjs             modify: add @tailwindcss/forms plugin
├── tsconfig.json                   modify: add @portal/* path alias
├── package.json                    modify: add React, Supabase, Recharts deps
└── .env.example                    PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY
```

---

## 7. Authentication Flow

```
User → portal.utamacs.org/login
         │
    LoginForm.tsx (React island, client:load)
    supabase.auth.signInWithPassword({ email, password })
         │
    ┌────▼──────────────────────────────────────────────────┐
    │ Success: session set via @supabase/ssr cookie handler │
    │ /api/auth/callback.ts stores cookie                   │
    └────┬──────────────────────────────────────────────────┘
         │
    middleware.ts validates session on every /portal/* request
    queries user_roles → stores role in request.locals.role
         │
    ┌────▼──────────────────────────────────────────────────┐
    │ role = 'member'    → /portal (MemberDashboard)        │
    │ role = 'executive' → /portal (ExecutiveDashboard)     │
    │ role = 'admin'     → /portal (AdminDashboard)         │
    └───────────────────────────────────────────────────────┘

Unauthenticated /portal/* → middleware redirects to /login
Sign out → POST /api/auth/signout → destroy cookie → redirect /login
Password reset → supabase.auth.resetPasswordForEmail() → email link
  → /api/auth/callback?type=recovery → /portal/profile?tab=password
```

---

## 8. Dashboard Wireframes

### Member Dashboard
```
┌─ Portal ────────────────────────────────── 🔔3  [K.B. Reddy ▼] ┐
│ Dashboard    ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│ My Profile   │  Open    │ │ Upcoming │ │ Pending  │ │ Active │ │
│ Complaints   │Complaints│ │  Events  │ │  Dues    │ │ Polls  │ │
│ Notices      │    2     │ │    3     │ │ ₹5,000   │ │   1    │ │
│ Events       └──────────┘ └──────────┘ └──────────┘ └────────┘ │
│ Polls        ┌─────────────────────────┐ ┌───────────────────┐  │
│ Finance      │ Recent Notices          │ │ My Complaints     │  │
│ Community    │ • AGM Scheduled  [1d]   │ │ UTA-001 Open      │  │
│              │ • Water shutoff  [3d]   │ │ UTA-003 Resolved  │  │
│              └─────────────────────────┘ └───────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Executive Dashboard (adds analytics)
```
┌─ Portal ────────────────────────────────────────────────────────┐
│ + Manage:    ┌─────────────────────────┐ ┌───────────────────┐  │
│   Notices    │ Complaints by Status    │ │ Dues Collection   │  │
│   Events     │ [Donut chart]           │ │ [Bar chart]       │  │
│   Polls      │ Open:5 Assigned:3       │ │ Apr: ₹3.2L/₹4L   │  │
│   Vendors    │ In Progress:2 Closed:12 │ │ May: ₹2.8L/₹4L   │  │
│   FAQs       └─────────────────────────┘ └───────────────────┘  │
│   Analytics  ┌───────────────────────────────────────────────┐  │
│              │ Complaints Aging Table (sortable, filterable)  │  │
│              │ Ticket# | Title | Priority | Days Open | Owner │  │
│              └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 9. Notification Flow

```
Event                    →  DB trigger / Edge Function  →  notifications table
──────────────────────────────────────────────────────────────────────────────
Complaint raised          →  notify assigned executive
Complaint status changed  →  notify complaint owner
New notice published      →  notify ALL members (batch insert)
New event published       →  notify ALL members
Poll published            →  notify ALL members
Due approaching (3 days)  →  notify flat owner  (cron via pg_cron)
──────────────────────────────────────────────────────────────────────────────
NotificationBell.tsx → Supabase Realtime channel → badge count updates live
Mark read → UPDATE notifications SET is_read=true WHERE user_id = auth.uid()

Email (Phase 3): Supabase Edge Function → Resend API (free 3K/month)
Templates: complaint update, event reminder, dues reminder, welcome
```

---

## 10. New Package Dependencies

```json
"dependencies": {
  "@supabase/supabase-js": "^2.x",
  "@supabase/ssr":         "^0.x",
  "react":                 "^18.x",
  "react-dom":             "^18.x",
  "recharts":              "^2.x"
},
"devDependencies": {
  "@astrojs/react":        "^3.x",
  "@astrojs/vercel":       "^7.x",
  "@types/react":          "^18.x",
  "@types/react-dom":      "^18.x",
  "@tailwindcss/forms":    "^0.5.x"
}
```

---

## 11. Phased Execution Plan

### Phase 1 — Foundation (Weeks 1–2)
**Goal:** Auth working, portal shell live on Vercel

1. Create Supabase project → run 001_schema.sql + 002_rls.sql + 003_functions.sql
2. Add `astro.portal.config.mjs` (output: hybrid, @astrojs/vercel, @astrojs/react)
3. Add `vercel.json` with build command override
4. Update `package.json` with new deps → `npm install`
5. Create `src/lib/supabase/client.ts` and `server.ts`
6. Create `src/middleware.ts` (session + role guard on /portal/*)
7. Create `PortalLayout.astro` (collapsible sidebar, header, notification bell)
8. Create `src/styles/portal.css` (sidebar layout tokens)
9. Replace static `login.astro` form with `LoginForm.tsx` island
10. Create `portal/index.astro` (role-adaptive dashboard shell)
11. Create `api/auth/callback.ts` + `api/auth/signout.ts`
12. Configure Vercel project, add env vars, connect custom domain
13. Add GitHub Secrets for Supabase keys
14. Verify: login → dashboard → logout → unauthenticated redirect

### Phase 2 — Member Core (Weeks 3–5)
**Goal:** Members can use all their day-to-day features

1. `ProfileEditor.tsx` — edit name, phone, flat, avatar upload to Storage
2. `ComplaintForm.tsx` — category, priority, description, file attach
3. `ComplaintList.tsx` — own complaints, status badges, pagination
4. `ComplaintDetail.tsx` — timeline, comments, status history
5. `portal/notices/index.astro` — live from Supabase (replaces static)
6. `portal/events/index.astro` + `EventRegistration.tsx` — RSVP + capacity
7. `DuesTracker.tsx` — pending/paid list, download receipt stub
8. `NotificationBell.tsx` — Realtime subscription, badge, dropdown
9. `MemberDashboard.tsx` — KPI cards wired to real data
10. Seed: migrate existing notices/events/documents TypeScript data → Supabase

### Phase 3 — Executive Features (Weeks 6–8)
**Goal:** Executives can manage all content and work complaints

1. `NoticeEditor.tsx` — rich text, pin, publish/unpublish, expiry, attachment
2. `EventEditor.tsx` — create/edit, view registrations, attendance tracking
3. `PollEditor.tsx` + `PollVoting.tsx` — full poll lifecycle, recharts results
4. Executive complaint view — all complaints, assign, status update, internal comments
5. SLA indicators — color-coded aging (green < 24h, amber < 48h, red > 48h)
6. `ExecutiveDashboard.tsx` — recharts: complaint donut, dues bar, member activity
7. Vendor CRUD — add/edit/deactivate vendors per category
8. FAQ management CRUD
9. Gallery management — upload/publish/delete images
10. Document management — replace static `downloads.ts` with Supabase-driven list

### Phase 4 — Admin & Community (Weeks 9–11)
**Goal:** Admin control + community engagement features

1. `UserManager.tsx` — list all members, search, filter by block, deactivate
2. `RoleAssigner.tsx` — promote/demote roles with confirmation dialog
3. `AuditLogViewer.tsx` — filterable audit trail, export CSV
4. `AdminDashboard.tsx` — all-module KPIs, system health
5. `PostFeed.tsx` — community posts, like/comment, pin, infinite scroll
6. `PostEditor.tsx` — create post, image upload, category tag
7. Email notifications — Resend API integration via Edge Function
8. System settings page — contact info, maintenance window toggle
9. Full dues management — executive can add/edit dues for all flats
10. Payment recording — mark dues paid, upload receipt

### Phase 5 — Polish & Advanced (Weeks 12+)
1. Realtime complaint updates (Supabase channel live status in ComplaintDetail)
2. QR code for event attendance check-in
3. Export reports — complaints CSV, dues PDF
4. PWA manifest + service worker (offline notice reading)
5. WhatsApp/SMS notification scaffold (Twilio stub)
6. Mobile UX audit — portal optimized for 375px viewport
7. Performance — Lighthouse ≥ 90 on portal dashboard
8. Supabase Pro upgrade for production (removes auto-pause)
9. Update CLAUDE.md with full platform docs

---

## 12. Critical Files — Create / Modify Summary

| File | Action | Phase |
|------|--------|-------|
| `astro.portal.config.mjs` | Create | 1 |
| `vercel.json` | Create | 1 |
| `src/middleware.ts` | Create | 1 |
| `src/lib/supabase/client.ts` | Create | 1 |
| `src/lib/supabase/server.ts` | Create | 1 |
| `src/lib/supabase/database.types.ts` | Generate via CLI | 1 |
| `src/components/layout/PortalLayout.astro` | Create | 1 |
| `src/styles/portal.css` | Create | 1 |
| `src/pages/login.astro` | Modify (add React island) | 1 |
| `src/pages/portal/index.astro` | Create | 1 |
| `src/pages/api/auth/callback.ts` | Create | 1 |
| `src/pages/api/auth/signout.ts` | Create | 1 |
| `src/components/portal/auth/LoginForm.tsx` | Create | 1 |
| `supabase/migrations/001_schema.sql` | Create | 1 |
| `supabase/migrations/002_rls.sql` | Create | 1 |
| `supabase/migrations/003_functions.sql` | Create | 1 |
| `supabase/migrations/004_seed.sql` | Create | 1 |
| `package.json` | Modify (add 6 deps) | 1 |
| `tailwind.config.mjs` | Modify (add @tailwindcss/forms) | 1 |
| `tsconfig.json` | Modify (add @portal/* alias) | 1 |
| `src/components/layout/Navbar.astro` | Modify (add Portal link) | 1 |
| All `src/components/portal/*.tsx` (22 files) | Create | 2–4 |
| All `src/pages/portal/*.astro` (12 pages) | Create | 2–4 |

---

## 13. Cost Summary

| Service | Plan | Cost |
|---------|------|------|
| GitHub Pages | Free | $0 |
| Vercel (portal) | Hobby (free) | $0 |
| Supabase | Free (dev only — auto-pauses after 7 days) | $0 |
| Supabase | **Pro (production)** | **$25/mo** |
| Resend (email) | Free 3K/month | $0 |
| **Development total** | | **$0/month** |
| **Production total** | | **$25/month** |

---

## 14. GitHub Pages Compatibility Rules

- `astro.config.mjs` (static build → docs/) never processes portal pages
- Portal pages live in `src/pages/portal/` — excluded from static build
- GitHub Actions workflow runs `astro build` (static config) → unchanged
- Vercel uses `astro.portal.config.mjs` (all pages, hybrid mode)
- `PUBLIC_SUPABASE_URL` and `PUBLIC_SUPABASE_ANON_KEY`:
  - Stored in Vercel dashboard environment variables
  - Stored in GitHub Actions secrets (for any portal CI needs)
  - Never committed to the repository

---

## 15. Verification Checklist

### Phase 1
- [ ] `portal.utamacs.org` loads the portal login page
- [ ] Login with member credentials → member dashboard
- [ ] Login with admin credentials → admin dashboard
- [ ] Unauthenticated `/portal/*` → redirects to `/login`
- [ ] Sign out → session cleared → `/login`
- [ ] `utamacs.org` (GitHub Pages) unchanged and still working
- [ ] No Supabase keys in any committed file

### Phase 2
- [ ] Member can raise complaint → appears in list → status updates visible
- [ ] Executive can see all complaints; member cannot see others' (RLS verified)
- [ ] File upload → stored in `complaint-attachments` bucket
- [ ] Notification bell shows badge on new notification (realtime)
- [ ] Event RSVP respects capacity; next registration gets waitlisted

### End-to-End Scenarios
1. New member login → complete profile → raise complaint → track status
2. Executive assigns complaint → updates status → member sees notification
3. Executive creates poll → member votes → results shown in executive dashboard
4. Admin promotes member to executive → user sees executive dashboard on next login
5. Member registers for event → event full → shown on waitlist
