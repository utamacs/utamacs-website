# UTA MACS — HOTO & Vendor Management Platform Design
## v3.1 — Risk-Hardened + Full RBAC Management + Feature Permission System

**Society:** Urban Trilla Apartment Owners Mutually Aided Cooperative Maintenance Society Limited  
**Registration No:** TG/RRD/MACS/2026-15/FOW & M (registered 10-02-2026)  
**Location:** SY NO:425/2/1, Kondakal Village, Shankarpally Mandal, Rangareddy District, Telangana  
**Builder (Promoter):** Ankura Homes | **HOTO Consultant:** Ascenza Global Infra Care Pvt Ltd  
**HOTO Start Date:** June 1, 2026 | **Maintenance Tracking From:** May 1, 2025  
**Document Version:** 3.1 — May 2026 (adds user/role management + feature permission system)

---

## Table of Contents

1. [What We Are Building and Why](#1-what-we-are-building-and-why)
2. [Byelaw Governance Rules Hardcoded into the System](#2-byelaw-governance-rules-hardcoded-into-the-system)
3. [System Architecture](#3-system-architecture)
4. [Infrastructure Resilience Design](#4-infrastructure-resilience-design)
5. [Module 0 — User & Role Management](#5-module-0--user--role-management)
6. [Module 1 — HOTO Management](#6-module-1--hoto-management)
7. [Module 2 — Snag List Management](#7-module-2--snag-list-management)
8. [Module 3 — Vendor Evaluation & Selection](#8-module-3--vendor-evaluation--selection)
9. [Module 4 — Financial Tracking](#9-module-4--financial-tracking)
10. [Module 5 — Formal Notice Generation](#10-module-5--formal-notice-generation)
11. [Workflow Engine & Approval Delegation](#11-workflow-engine--approval-delegation)
12. [Non-Tech User Experience Specification](#12-non-tech-user-experience-specification)
13. [Dashboard & UX Design](#13-dashboard--ux-design)
14. [Git Storage Strategy](#14-git-storage-strategy)
15. [Data Model](#15-data-model)
16. [Security & Privacy Compliance](#16-security--privacy-compliance)
17. [Data Migration Sprint](#17-data-migration-sprint)
18. [Role-Based Access Control & Feature Permissions](#18-role-based-access-control--feature-permissions)
19. [Document Management](#19-document-management)
20. [Scope Boundary](#20-scope-boundary)
21. [Phase-wise Implementation Plan](#21-phase-wise-implementation-plan)
22. [Comprehensive Risk Register](#22-comprehensive-risk-register)

---

## 1. What We Are Building and Why

Urban Trilla MACS has 136 units (40-50 currently occupied), 14 committee members, and is entering the most consequential phase of a cooperative society — the Handover/Takeover from builder Ankura Homes. The HOTO process starts June 1, 2026, has a 45-day Ascenza-led audit timeline, and is expected to span 2-3 months depending on builder responsiveness.

**The problem today:** All evidence, decisions, communications, and tracking live in WhatsApp messages, personal emails, Google Drive folders, and physical files. The two most senior decision-makers (President Bal Reddy and Working President) are non-technical users who are comfortable with WhatsApp. For the system to succeed, it must be simpler than a WhatsApp group in terms of mental load.

**The three core pillars:**
1. **Radical simplicity** — President and Working President can use it without training
2. **Complete auditability** — every action permanently recorded; nothing disappears
3. **Byelaw compliance** — governance rules hardcoded, not configurable

**What v3.1 adds over v3:**

| Addition | Why it matters |
|---|---|
| **Admin as dedicated system role** | Admin is the technical executor of user/permission management — acts on documented consent from President or Secretary; not a governance role |
| **Authorization-documented admin actions** | Every admin action on roles or permissions must record who in leadership authorized it, how (WhatsApp/email/verbal/meeting), and when — creates defensible audit trail without burdening non-tech leaders with portal logins |
| Module 0: User & Role Management | Without controlled user access, every other module's security is theoretical |
| Invite-only registration | Prevents unauthorized access to governance documents |
| Committee election bulk update | Annual elections change 14 roles simultaneously; manual one-by-one is error-prone |
| Role change with audit trail | Every role change must be logged for byelaw audit requirements |
| Feature permission system | Admin enables/disables individual features per role (with President authorization documented) |
| Per-user feature overrides | Edge cases where one person needs temporary access to a module |
| UI feature gating | Every button/section renders conditionally based on the logged-in user's actual permissions |
| Fix existing `user_roles` bug | Current table missing UNIQUE constraint — role changes silently fail |

**What v3 added over v2 (unchanged):**

| Risk from analysis | Design response |
|---|---|
| Vercel 10s timeout kills PDF | Async PDF generation with job queue; Vercel Pro before HOTO |
| GitHub API limits on bulk upload | `upload_queue` table; cron-processed batches |
| GitHub token silent failure | `github_api_log` + health-check + Resend alert |
| Supabase free tier pauses DB | Cron ping every 6 days |
| President doesn't adopt | Zero-ambiguity mobile screen; pre-launch walkthrough |
| WhatsApp shortcuts governance | Financial payments require portal approval record |
| Snag scope confusion | `snag_scope` field; liability disclaimer |
| RERA document metadata | Server timestamps, SHA-256 hash, source description |
| Corpus fund overdraft | Server-side balance check |
| Builder SLA drift | Escalation cron at 7/14/30 days overdue |
| Phase 1 too late for June 1 | Emergency sprint plan: minimum viable system live May 31 |

---

## 2. Byelaw Governance Rules Hardcoded into the System

These are legal requirements under registered Byelaws (Reg No: TG/RRD/MACS/2026-15/FOW & M). They are not configurable by any admin.

### 2.1 Voting Rules

| Rule | Byelaw Reference | System Implementation |
|---|---|---|
| One apartment = one vote | **§4.16** | Each member gets exactly 1 vote; no weighting by role |
| Cannot vote if >90 days maintenance arrears | **§4.6** | System checks `payment_status` before showing vote button |
| Board decisions by majority vote | **§7.16(c)** | Simple majority of votes cast |
| President has casting vote on tie | **§7.16(c) & §8.1** | If tied, President casting vote logged with byelaw citation |
| Board quorum = simple majority of directors | **§7.16(a)** | With 14 directors, minimum 8 must vote |
| Member can authorize via registered PoA | **§4.16** | PoA document uploaded + linked to vote record |
| Joint ownership voting | Policy per §4.16 | First named owner votes; policy committed to governance-data pre-vote |

### 2.2 Decision Approval Chain

| Scenario | Byelaw Reference | System Rule |
|---|---|---|
| HOTO/vendor approvals require dual sign-off | **§8.1 + §8.3** | Both President AND Secretary must approve |
| President absent (planned, >7 working days) | **§8.2** | Admin sets delegation → VP; all VP actions tagged "per §8.2" |
| President absent (unplanned/urgent) | **§8.2** | VP may act; flagged for President review on return |
| Secretary absent (planned) | **§8.4** | Joint Secretary takes all Secretary functions |
| Both President and VP unavailable | None | System freezes approval gates |

### 2.3 Financial Authority Limits

| Authority | Limit | Byelaw Reference | System Rule |
|---|---|---|---|
| Secretary (urgent remedial) | Up to ₹10,000/- | **§9.11(a)** | API enforces; rejects above |
| President (urgent remedial) | Up to ₹20,000/- | **§9.11(a)** | API enforces; rejects above |
| Board of Directors | Up to ₹50,000/- | **§9.11(b)** | Requires Board vote with quorum |
| Beyond ₹50,000/- | General Body required | **§9.11(b)** | API blocks with message |
| All payments >₹10,000/- | Must be electronic | **§9.11(c)** | Warning if non-electronic indicated |
| Cash payments | Prohibited | **§5.3(p) & §9.1** | Cash option removed entirely |
| Corpus fund overdraft | Prohibited (policy) | — | Server-side balance check in payment API |

### 2.4 Conflict of Interest

| Rule | Byelaw Reference | System Implementation |
|---|---|---|
| Director must not participate where personally interested | **§7.16(b)** | Recuse button before every vote; recusal permanent and logged |
| Office bearers receive no remuneration | **§3.4(b)** | Vendor with committee member interest is flagged |

### 2.5 Transparency & Records

| Rule | Byelaw Reference | System Implementation |
|---|---|---|
| Minutes within 7 days of Board meeting | **§7.16(e)** | Upload tracker; dashboard flag |
| Defaulter list published monthly | **§9.6** | Auto-generated; first Sunday each month |
| Financial statements by 30th September | **§9.3** | Dashboard reminder from Sep 1 |
| Data retention: 10 years | Requirement | Git history = permanent |

### 2.6 Defaulter Rules

| Rule | Byelaw Reference | System Flag |
|---|---|---|
| 2 months arrears = Defaulting Member | **§6.36** | Yellow flag at 60 days |
| 3 months arrears = services can be denied | **§6.37** | Red flag at 90 days; 7-day notice countdown |
| 18% per annum interest | **§19(e)** | Auto-calculated from due date |
| Vote rights suspended at 90 days | **§4.6** | `payment_status = defaulter_90d` blocks vote button |

---

## 3. System Architecture

### 3.1 Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│              COMMITTEE MEMBER  (any device, browser)                 │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  portal.utamacs.org  (Astro SSR on Vercel)                   │    │
│  │                                                               │    │
│  │  Two audience modes:                                          │    │
│  │  [A] Non-tech (President, Working President):                 │    │
│  │      "My Actions" — 2 buttons max. Mobile-first.             │    │
│  │  [B] Tech-comfortable (other 12): Full feature set           │    │
│  │                                                               │    │
│  │  /portal/admin/users        User & Role Management            │    │
│  │  /portal/admin/permissions  Feature Permission Admin          │    │
│  │  /portal/admin/delegation   Delegation Management             │    │
│  │  /portal/admin/elections    Committee Election Workflow        │    │
│  │  /portal/hoto/              HOTO Checklist                    │    │
│  │  /portal/snags/             Snag List                         │    │
│  │  /portal/vendors/           Vendor Evaluation                 │    │
│  │  /portal/finances/          Maintenance & Fund Tracking        │    │
│  │  /portal/notices/           Formal Notice Generator           │    │
│  │  /portal/dashboard          Governance Dashboard              │    │
│  │  /portal/my-actions         Non-Tech User Home                │    │
│  └──────────────────────┬───────────────────────────────────────┘    │
└─────────────────────────┼────────────────────────────────────────────┘
                          │ HTTPS
             ┌────────────▼────────────┐
             │  Vercel Serverless       │  ← Vercel Pro (14 min timeout)
             │  /api/v1/               │
             └────┬─────────────┬──────┘
                  │             │
     ┌────────────▼──┐   ┌──────▼──────────────────────┐
     │  Supabase      │   │  GitHub (governance-data)    │
     │  PostgreSQL    │   │  Private repo                │
     │                │   │                              │
     │  - Auth        │   │  Documents + JSON records    │
     │  - Fast lists  │   │  Every write = audit trail   │
     │  - Roles       │   │  Permanent history           │
     │  - Permissions │   │  10-year retention           │
     │  - Upload queue│   │                              │
     │  - API log     │   └──────────────────────────────┘
     │  - Job queue   │
     └────────────────┘
             │
     ┌───────▼────────┐
     │  Resend         │  ← Notifications, invites,
     │  (email)        │    health alerts, digests
     └─────────────────┘
```

### 3.2 Two Repositories

```
utamacs/utamacs-website      ← Code (public — portal.utamacs.org)
utamacs/governance-data      ← Private data repo (documents + audit trail)
```

### 3.3 Key Design Constraints

1. **No direct browser-to-GitHub upload.** All uploads: Browser → API → `upload_queue` → cron → GitHub.
2. **No PDF generation in the request cycle.** PDF jobs: Browser → API → `pdf_generation_jobs` → cron → stored PDF → download URL.
3. **All files in GitHub, never Supabase storage.** Supabase storage = 500MB limit; GitHub = no limit.
4. **Every consequential action has a server-side guard.** Financial limits, voting eligibility, quorum, balance check — all enforced in API routes, never in client-side JavaScript.
5. **Feature permissions are enforced at two levels.** UI: buttons/sections conditionally rendered per role. API: every route independently re-checks permissions. UI hiding is UX; API checking is security.

### 3.4 Committee Structure Mapped to Roles

**Governance roles** (control what a person can approve, vote, or act on):

| Actual Title | System Role | Approval Power |
|---|---|---|
| President | `president` | Final approver; casting vote; delegation to VP |
| Vice President | `vice_president` | Acts as president when delegated |
| Working President | `working_president` | Executive committee member; same as executive |
| General Secretary | `secretary` | Co-approver with President |
| Joint Secretary | `joint_secretary` | Acts as secretary when delegated |
| Treasurer | `treasurer` | Financial entries; approves ≤₹20K with President |
| Joint Treasurer | `joint_treasurer` | Acts as treasurer when delegated |
| Executive Member (×7) | `executive` | Comment, vote, upload, advance status |
| General Member | `member` | Read-only portal access |

**System administration flag** (orthogonal to governance role):

| Flag | Who holds it | What it enables |
|---|---|---|
| `is_admin = true` | Designated admin person (typically the implementer or a tech-savvy committee member) | Full access to user management, feature permissions, election workflow, delegation management — always with documented President/Secretary authorization |

A person can be: `is_admin = true` only (non-committee tech admin), or `is_admin = true` + a governance role (e.g., executive + admin), or just a governance role with no admin flag. The President does **not** need `is_admin = true` — the President authorizes; the admin executes.

---

## 4. Infrastructure Resilience Design

### 4.1 GitHub Upload Queue

All uploads are queued and processed asynchronously by a cron job (max 30 files per run, every 60 seconds).

```
Browser → POST /api/documents/upload
  → File in Vercel /tmp
  → Record in upload_queue (status: PENDING)
  → Returns { queue_id }
  → Browser polls GET /api/documents/status/[queue_id]

Cron /api/cron/process-uploads (every 60s):
  → Takes ≤30 PENDING items
  → Commits to GitHub via GitHub App
  → COMPLETED: inserts to documents table
  → FAILED (3 retries): PERMANENTLY_FAILED; alert email sent
```

Upload constraints:
- Max 5MB per file (enforced server-side)
- Accepted types: PDF, JPG, PNG, XLSX, CSV, DOCX
- No video — `video_url` field for YouTube/Drive links only

### 4.2 GitHub API Health Monitor

```
Every 15 minutes (cron /api/cron/github-health):
  → Test write to governance-data/_meta/health-check.json
  → Log to github_api_log
  → On 3 consecutive failures: Resend alert to Secretary + admin

Every 6 days (cron /api/cron/supabase-ping):
  → SELECT 1 FROM profiles LIMIT 1
  → Prevents Supabase free-tier 7-day pause
```

### 4.3 Async PDF Generation

```
User clicks "Generate PDF"
  → POST /api/pdf/generate → inserts pdf_generation_jobs (status: QUEUED)
  → Returns { job_id } → UI shows spinner
  → Cron every 30s processes QUEUED jobs
  → PDF stored in GitHub → job status = DONE
  → UI polls, gets DONE, shows [Download] button
```

Vercel Pro upgrade (14-minute timeout) is the backup safety net.

### 4.4 Non-Developer Operations Runbook

`RUNBOOK.md` committed to governance-data before go-live. Covers: adding members, resetting passwords, activating/deactivating delegation, checking upload queue, rotating GitHub App key, restarting the app. Validated by Secretary following it without assistance.

---

## 5. Module 0 — User & Role Management

This module is the foundation for everything else. Every action in the platform is attributed to a user with a specific role, and every button or section in the UI is conditionally rendered based on that user's permissions. Without correct role management, the approval chains, audit trails, and access controls all break down.

### 5.1 The Admin Role: Executor with Documented Authorization

**Core principle:** The President and Secretary make governance decisions. The admin executes them in the system. The admin never acts unilaterally on user access or permissions — every significant action requires documented consent from the President or Secretary.

**Why this separation?**
- The President and Working President are non-technical. They should not need to log into an admin panel to approve every user addition or role change.
- The admin (typically the implementer or a tech-savvy designated person) handles the technical execution.
- But because the admin has broad system access, every action must have a documented authorization trail — who in leadership approved it, how they communicated that (WhatsApp/email/meeting), and when.

**Who is the admin?**
- A designated person with `profiles.is_admin = true`
- Typically: the system implementer initially; later transferred to a tech-comfortable committee member
- Can hold a governance role simultaneously (e.g., admin + executive) or be admin-only (non-committee)
- The admin flag is set by another admin (or by the implementer at setup)
- A society can have more than one admin; each admin's actions are independently logged

**What the admin can do (with documented authorization):**
- Invite new members and committee members
- Change governance roles
- Run committee election bulk updates
- Grant or revoke per-user feature permission overrides
- Manage feature permissions per role
- Activate/deactivate delegation chains
- Deactivate or reactivate members
- Manage the admin flag itself (grant/revoke `is_admin` for others)

**What the admin cannot do (no matter their technical access):**
- Cast votes on vendor decisions (unless they also hold a governance role that allows voting)
- Approve HOTO items (unless they also hold president/secretary governance role)
- Act on behalf of President or Secretary in governance decisions

### 5.2 Authorization Documentation (Required for All Significant Admin Actions)

Every admin action that affects a user's access or system-wide permissions must include authorization metadata before it can be confirmed:

```
┌──────────────────────────────────────────────────────────────────┐
│  CHANGE ROLE: [Name] from executive → secretary                  │
│                                                                   │
│  This action requires documented authorization from the          │
│  President or Secretary. (§8.3 — Secretary implements decisions) │
│                                                                   │
│  Authorized by:   [President Bal Reddy ▼]                        │
│  How:             [WhatsApp message ▼]                           │
│                    WhatsApp message                               │
│                    Email                                          │
│                    Verbal instruction in meeting                  │
│                    Board resolution                               │
│  Date authorized: [2026-06-15]                                   │
│  Details (what was communicated):                                 │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │ President messaged on Jun 15: "Please make [Name] the new  │  │
│  │ General Secretary effective from today's AGM result"       │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                   │
│  [Cancel]                          [Confirm Role Change]         │
└──────────────────────────────────────────────────────────────────┘
```

This authorization metadata is stored in `role_change_log.authorized_by`, `authorization_method`, `authorization_date`, and `authorization_details`. It is shown in the audit trail and on the user's role history page.

**Which actions require authorization documentation:**

| Admin Action | Authorization Required From |
|---|---|
| Invite new member (member role) | Secretary or President |
| Invite new committee member | President |
| Change role (any direction) | President |
| Run committee election bulk update | President |
| Toggle feature permission per role | President |
| Grant per-user feature override | President |
| Deactivate a member | Secretary or President |
| Reactivate a member | Secretary or President |
| Grant admin flag to another person | President |
| Activate/deactivate delegation chain | President (for their own delegation) or Secretary (for Secretary delegation) |

**Actions that do NOT need authorization documentation:**
- Resending an expired invite (no new access is being granted)
- Cancelling a pending invite
- Viewing the user directory
- Checking system health
- Running bulk data imports

### 5.3 Registration Model: Invite-Only

No one can self-register. All portal access starts with an admin-sent invite — initiated only after the admin receives authorization from the President or Secretary.

**Registration Flow:**

```
1. Admin receives authorization (e.g., President says "add [Name] from Flat 207")

2. Admin: /portal/admin/users → [Invite Member]
   Enter: email, flat number, intended role
   Enter authorization metadata: who approved, how, when, what was said

3. System:
   → Creates member_invites record with one-time token (expires 7 days)
   → Sends Resend email with invite link + flat number + portal introduction

4. New user clicks link:
   → Registration form: name + password (email pre-filled, non-editable)
   → Privacy consent checkbox (DPDP Act — must accept to proceed)
   → On submit: account created, privacy_consents record saved

5. Admin notified: "[Name] (Flat 207) has accepted their invitation"
   Secretary also notified (so leadership knows the access was activated)

6. member_invites.accepted = true; token immediately invalidated
```

**Invite expiry:** Admin can resend from Pending Invites tab.
**Invite cancellation:** Admin can cancel; cancelled invites cannot be accepted.
**When authorization is questioned later:** The invite record stores who authorized the invite, how, and when — admin can point to this record.

### 5.4 Role Hierarchy (Governance Roles)

```
member
  ↑
executive = working_president = joint_treasurer
  ↑
treasurer = joint_secretary
  ↑
vice_president = secretary
  ↑
president
```

The `is_admin` flag is orthogonal — it is not in this hierarchy. An admin with `portal_role = member` still has full system management capability; they just cannot vote or approve HOTO items in their own name.

**Rule:** The admin can assign any governance role (with President authorization documented). No user — including the admin — can change their own role.

### 5.5 Role Change Workflow

```
1. Admin receives instruction from President or Secretary (WhatsApp/email/meeting)

2. Admin: /portal/admin/users → Click user → [Change Role]

3. Select new role from dropdown

4. Complete authorization form (required — cannot skip):
   - Authorized by: [President / Secretary / Board ▼]
   - How: [WhatsApp / Email / Verbal / Board resolution ▼]
   - Date: [date of authorization]
   - Details: [verbatim or summary of what was communicated]

5. Confirmation dialog shows all changes + authorization summary:
   "You are changing [Name]'s role from [executive] to [secretary].
   Authorized by President on 2026-06-15 via WhatsApp.
   This is permanent and will be logged. Continue?"

6. On confirm (API /api/admin/users/[id]/role PATCH):
   → profiles.portal_role updated
   → role_change_log record created (includes full authorization metadata)
   → audit_log record created
   → All assigned items reviewed for auto-reassignment
   → User receives email: "Your UTA MACS access has been updated to [new role]"
   → Secretary notified (if admin ≠ Secretary): "[Admin] changed [Name]'s role to secretary"
```

Role changes are **immediate**. The authorization documentation is recorded before the change, not after.

### 5.6 Committee Election Bulk Update

The admin runs this workflow after the General Body election concludes. The President or Secretary communicates the election outcome (via minutes, WhatsApp, or email) — the admin then executes the role changes with that authorization documented.

**Election Workflow at `/portal/admin/elections`:**

```
Step 1: [New Election]
  Enter: Election date, Description ("Annual General Body Meeting 2026")
  Enter authorization: "President Bal Reddy provided the outcome via WhatsApp
                        on 2026-06-15 with the list of elected members"
  Attach: election outcome document (optional — uploaded via document upload)

Step 2: System shows current committee lineup
  ┌─────────────────────────────────────────────────────────────┐
  │  COMMITTEE ELECTION — 15 June 2026                          │
  │  Assign new role holders. Outgoing members auto-revert.     │
  ├────────────────────┬────────────────────────────────────────┤
  │  Role              │  Current Holder → New Holder           │
  ├────────────────────┼────────────────────────────────────────┤
  │  President         │  Bal Reddy → [Bal Reddy ▼]             │
  │  Vice President    │  [Name] → [Select member ▼]            │
  │  General Secretary │  [Name] → [Select member ▼]            │
  │  Joint Secretary   │  [Name] → [Select member ▼]            │
  │  Treasurer         │  [Name] → [Select member ▼]            │
  │  Joint Treasurer   │  [Name] → [Select member ▼]            │
  │  Executive 1-7     │  [Name] → [Select member ▼] (×7)       │
  └────────────────────┴────────────────────────────────────────┘

Step 3: Preview screen — shows all changes + the authorization summary
  CHANGES (5 members affected):
  [Name] executive → secretary
  [Name] secretary → member (outgoing)
  [Name] member    → executive
  Authorized by: President Bal Reddy · WhatsApp · 2026-06-15

  [Cancel]   [Confirm Election]

Step 4: On confirm (single database transaction):
  → All role changes atomically (all succeed or all fail)
  → All changes linked to election_event_id
  → Authorization metadata stored on the event (not repeated per person)
  → Old role holders not re-elected revert to 'member'
  → Each affected person receives email with their new role
  → Secretary receives summary: "Admin has applied the June 2026 election results"
```

**Why atomic?** A partial failure leaves the system inconsistent. Either the full election applies or nothing does.

### 5.7 Member Deactivation

When an apartment owner sells their flat (NOC process complete), the admin deactivates them — after Secretary or President has authorized it:

```
1. Admin receives authorization from Secretary or President ("Flat 204 sold — remove access")

2. Admin: /portal/admin/users → Find member → [Deactivate]

3. Complete authorization form: who authorized, how, when

4. Mandatory reason: "Flat sold — NOC issued 2026-06-15 — authorized by Secretary"

5. On confirm:
   → profiles.is_active = false
   → All active sessions immediately invalidated
   → Email sent to deactivated member: "Your UTA MACS portal access has been deactivated"
   → All their assigned HOTO/snag items auto-reassigned
   → Secretary notified of deactivation (unless Secretary is the admin)
   → Data retained for 10-year audit requirement

Reactivation: Admin only; with Secretary or President authorization; mandatory reason.
```

**Account deletion:** Never. Data retention is a byelaw requirement (10 years).

### 5.8 Auto-Reassignment on Role Loss

When a user loses a committee role (downgraded or deactivated), all items assigned to them are automatically reassigned. Priority order:

```
1. Item has responsible_role set?
   → Find current holder of that role → reassign to them

2. The role itself is currently vacant?
   → Escalate to Secretary

3. Secretary also unavailable?
   → Escalate to President

4. President also unavailable?
   → System flags item as "Needs manual assignment" on dashboard

All auto-reassignments logged in audit_log:
  action: "AUTO_REASSIGNED"
  reason: "Role change: [old user] downgraded from [role]"
```

### 5.9 User Directory (`/portal/admin/users`)

Visible to: **admin** (full access) + secretary, vice_president, president (read-only view)

```
┌───────────────────────────────────────────────────────────────────────┐
│  MEMBER DIRECTORY                    [+ Invite Member]                 │
│                                                                        │
│  Filter: [All Roles ▼]  [All Status ▼]   Search: [____________]       │
│  Tabs: [Active (152)] [Pending Invites (3)] [Inactive (4)]            │
├──────────────┬──────┬─────────────┬─────────────┬──────────┬──────────┤
│  Name        │ Flat │ Role        │ Last Active │ Payment  │ Actions  │
├──────────────┼──────┼─────────────┼─────────────┼──────────┼──────────┤
│  Bal Reddy   │ 101  │ 🔵 President│ Today       │ ✅ Current│ [View]   │
│  [Name]      │ 204  │ 🟢 Secretary│ 2 days ago  │ ✅ Current│ [View]   │
│  [Name]      │ 312  │ 🟡 Executive│ 5 days ago  │ ⚠️ 45d   │ [View]   │
│  [Name]      │ 108  │ ⚪ Member   │ 12 days ago │ ✅ Current│ [View]   │
└──────────────┴──────┴─────────────┴─────────────┴──────────┴──────────┘
```

**User detail page** shows:
- Profile info + flat number
- Role history timeline: `member → executive (Jan 15 by Admin — authorized by Secretary via WhatsApp) → secretary (Jun 1 by Admin — authorized by President, AGM outcome)`
- All HOTO items assigned to them
- All votes cast (vendor, resolution)
- All documents uploaded
- All comments posted
- Their feature permissions (inherited from role + any overrides)
- All authorization records for role changes affecting this user

**What admin sees vs. what leaders see:**
- Admin: full directory + all actions (Invite, Change Role, Deactivate, Grant Override)
- President/Secretary/VP (non-admin): read-only directory — can see members, roles, last active; no action buttons. They communicate decisions to the admin; the admin executes.

### 5.8 Pending Invites Tab

```
┌─────────────────────────────────────────────────────────────────┐
│  PENDING INVITES (3)                          [+ Invite Member] │
├────────────┬──────────┬──────────┬───────────┬──────────────────┤
│  Email     │ Flat     │ Role     │ Sent      │ Expires / Action │
├────────────┼──────────┼──────────┼───────────┼──────────────────┤
│  a@b.com   │ 207      │ member   │ 3 days ago│ 4 days [Resend]  │
│  c@d.com   │ 415      │ executive│ 6 days ago│ 1 day  [Resend]  │
│  e@f.com   │ 102      │ member   │ 8 days ago│ EXPIRED [Resend] │
└────────────┴──────────┴──────────┴───────────┴──────────────────┘
```

---

## 6. Module 1 — HOTO Management

### 6.1 HOTO Scope (Ascenza-Aligned Categories)

| Category | Ascenza Scope Section |
|---|---|
| Statutory Compliance | Land docs, OC, NOCs, Fire NOC |
| Technical - Electrical | LT/HT, DG sets, earthing, common lighting |
| Technical - Lifts | 4 elevators, commissioning, AMC transfer |
| Technical - Fire & Safety | Hydrant, sprinkler, extinguishers, fire doors |
| Technical - HVAC | Ventilation, pressurization, exhaust |
| Technical - Water & Plumbing | DWS/SWS/FWS, STP, WTP, boreholes |
| Technical - Security & IT | CCTV, access control, boom barriers, intercom |
| MEP - Miscellaneous | Solar, gas bank, BMS, PA system |
| AMC Due Diligence | All AMC contracts — status, transfer to association |
| Snagging | Civil, seepage, exterior, common areas, terrace, club house |
| Asset/Inventory | Asset register, parking, spare keys |
| Financial Handover | Corpus fund transfer, maintenance corpus, builder dues |

### 6.2 HOTO Item State Machine

```
NOT_STARTED → IN_PROGRESS → EVIDENCE_UPLOADED → UNDER_REVIEW
  → PENDING_PRESIDENT → PENDING_SECRETARY → APPROVED → COMPLETED
     └──────────────────────────────────────────────── DISPUTED
```

State transition role rules:
- `NOT_STARTED → IN_PROGRESS`: executive or above
- `IN_PROGRESS → EVIDENCE_UPLOADED`: executive or above (requires ≥1 document)
- `EVIDENCE_UPLOADED → UNDER_REVIEW`: executive or above
- `UNDER_REVIEW → PENDING_PRESIDENT`: secretary / joint_secretary only
- `PENDING_PRESIDENT → PENDING_SECRETARY`: president (or VP if delegated per §8.2)
- `PENDING_SECRETARY → APPROVED`: secretary (or joint_secretary if delegated per §8.4); cannot be same person who set PENDING_PRESIDENT
- `APPROVED → COMPLETED`: president or secretary only
- `COMPLETED → DISPUTED`: president or secretary — requires written reason in `governance_notes`

### 6.3 Builder SLA Escalation

Every builder-dependent HOTO item has a `builder_sla_date`. Cron job checks daily:

```
7 days overdue  → Email committee: "[HOTO-042] Lift AMC is 7 days overdue"
14 days overdue → Email with URGENT flag; dashboard red countdown
30 days overdue → Auto-generate draft formal notice → notify Secretary to review and send
                  If rera_escalation_eligible = true: status → RERA_ELIGIBLE
```

### 6.4 Role-Based Assignment (Turnover-Safe)

Every HOTO item stores both `responsible_role` (e.g., `treasurer`) and `responsible_user_id`. If the person changes roles, the item stays with whoever currently holds the role. All auto-reassignments logged.

---

## 7. Module 2 — Snag List Management

### 7.1 Snag Scope Classification

Every snag must declare its scope:

| `snag_scope` | Meaning | Liability |
|---|---|---|
| `COMMON_AREA` | Corridor, terrace, basement, lobby, clubhouse, external | Society responsibility post-HOTO |
| `INDIVIDUAL_APARTMENT` | Inside a specific flat | Owner–builder matter |

For `INDIVIDUAL_APARTMENT` snags, a non-removable banner shows:
> "UTA MACS is logging this for reference only. The Society is not a party to this snag's resolution."

Only `COMMON_AREA` snags appear in formal HOTO documentation and builder notices.

### 7.2 Snag Item States

```
OPEN → IN_PROGRESS → BUILDER_NOTIFIED → BUILDER_COMMITTED → RESOLVED → VERIFIED_CLOSED
                                                                   └── REOPENED
```

### 7.3 Features

- **Create**: Any executive or above; must set `snag_scope`, category, location, severity
- **Update**: Any executive or above
- **Delete**: Soft-delete; president only; mandatory `deletion_reason`; permanently logged
- **VERIFIED_CLOSED**: President or Secretary only
- **Bulk import**: CSV/XLSX from Ascenza punch-list format; column mapping screen; photo ZIP supported

---

## 8. Module 3 — Vendor Evaluation & Selection

### 8.1 Active Evaluations

| Category | Known Vendors |
|---|---|
| Property Management Platform | MyGate, NoBroker |
| Accounting/Finance Tool | Mandix, Hari |
| Facility Management | Kapston, Kapil |
| Legal Counsel | TBD |
| Security Vendor | TBD |

### 8.2 Voting Model (§4.16 — One Apartment One Vote)

Each director gets exactly 1 vote. Quorum = 8 of 14 (§7.16(a)). Tie → President casting vote (§7.16(c)). All votes visible.

### 8.3 Proxy and Joint Ownership

- Proxy: notarized PoA uploaded by admin; linked to vote record
- Joint ownership: first named owner votes by default; policy committed to governance-data pre-vote
- `voting_policy_committed` flag on `vendor_requirements` must be `true` before voting opens

### 8.4 Conflict of Interest (§7.16(b))

Mandatory declaration before every vote. Recusal is permanent and logged.

### 8.5 Vendor Decision Record (Immutable)

Written once on final approval; `can_be_modified: false`. Re-decisions create `decision-v2.json`; v1 never touched. Includes: vote summary, recusals, byelaw compliance note, president approval, secretary approval, GitHub commit SHA.

### 8.6 Post-Selection Tracking

Contract upload; renewal reminder (90 days before expiry); monthly performance rating; complaint log.

---

## 9. Module 4 — Financial Tracking

Lightweight tracking module — not a full accounting system. Supports HOTO financial items and ongoing governance.

### 9.1 What Gets Tracked

- Maintenance collection (per flat, per month, from May 2025)
- Corpus fund (received from builder, interest earned, approved uses)
- Expenses (amount, payee, byelaw authority cited, balance check)
- Builder dues (pending items with SLA dates)

### 9.2 Corpus Fund Overdraft Prevention

Server-side in every payment approval API:

```typescript
const balance = await supabase.rpc('get_corpus_balance', { p_society_id });
if (balance < amount) {
  return Response.json({ error: 'INSUFFICIENT_BALANCE', current_balance: balance }, { status: 422 });
}
```

This check is **never client-side**. The UI shows the balance for convenience; the API enforces it regardless.

### 9.3 Defaulter Tracking

| Threshold | Action | Byelaw |
|---|---|---|
| 30 days | Reminder email to member | — |
| 60 days | "Defaulting Member" flag; committee notified | §6.36 |
| 90 days | Vote rights suspended; `payment_status = defaulter_90d` | §4.6 |
| 90+ days | 7-day notice countdown; template auto-populated | §6.37 |

---

## 10. Module 5 — Formal Notice Generation

Integrates with existing letter generation system in the portal.

### 10.1 Notice Types and Triggers

| Notice | Trigger | Reviewer |
|---|---|---|
| HOTO 7-day Reminder | Item overdue 7 days | Secretary |
| HOTO 14-day Escalation | Item overdue 14 days | Secretary |
| HOTO Legal Notice (auto-draft) | Item overdue 30 days (RERA eligible) | Secretary + President |
| Snag Rectification Notice | Snag past builder committed date | Secretary |
| Maintenance Defaulter Notice | 90+ days arrears | Secretary |
| RERA Complaint Package | No response to Legal Notice | Secretary + President |

### 10.2 Auto-Draft Mechanism

At 30 days overdue:
1. System generates draft letter (pre-filled with item details, builder contact, evidence list)
2. Saved to GitHub at `notices/drafts/[date]/[item-id]-draft.pdf`
3. Email to Secretary: "Draft notice ready — [Review] [Send] [Discard]"

Sending updates notice record to `SENT`. No manual letter creation needed.

---

## 11. Workflow Engine & Approval Delegation

### 11.1 Delegation Chain

```
Default: President + Secretary (both required)

President absent (planned >7 days — §8.2):
  Admin sets delegation → VP; all VP actions tagged "per §8.2"

President unexpectedly unavailable (§8.2):
  VP may act immediately; flagged for President review on return

Secretary absent (planned — §8.4):
  Admin activates Joint Secretary delegation

Both President + VP unavailable:
  System shows "Approval chain unavailable"; no approvals possible
```

### 11.2 Notification Design

| Event | Recipient | Subject | Priority |
|---|---|---|---|
| Pending President approval | President (or VP delegated) | "ACTION REQUIRED: [item] needs your approval" | High |
| Pending Secretary approval | Secretary (or Joint Sec) | "ACTION REQUIRED: [item] needs your approval" | High |
| Vote opened | All eligible voters | "VOTE OPEN: [vendor] — closes [date]" | High |
| Builder SLA overdue 7 days | Committee | "OVERDUE: [item] builder deadline was [date]" | High |
| Builder SLA overdue 30 days | Secretary + President | "Draft formal notice ready for [item]" | High |
| GitHub health check failed | Secretary + admin | "URGENT: Governance storage unavailable" | Critical |
| Weekly digest | All committee | "HOTO Week [N] Summary" | Low |

---

## 12. Non-Tech User Experience Specification

### 12.1 Design Rules for Non-Tech Screens

- "My Actions" is the home screen — not the full dashboard
- Maximum 2 action buttons per item
- Status = one word + one color: Approved (green), Pending (orange), Rejected (red)
- Minimum 56px tap targets for primary actions
- Minimum 16px text
- No icons without text labels
- All text in plain English, no abbreviations

### 12.2 My Actions Screen

```
┌────────────────────────────────────────────────┐
│  Good morning, Bal Reddy                        │
│  Tuesday, June 3, 2026                          │
├────────────────────────────────────────────────┤
│                                                 │
│  YOU NEED TO DO THESE NOW                       │
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │  🟠  APPROVE                             │   │
│  │  Lift No. 2 AMC Transfer (Block B)      │   │
│  │  Secretary approved this on June 2.     │   │
│  │                                         │   │
│  │  [Read the Details]   [APPROVE]         │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│  ✅  Nothing else needs your attention today    │
│                                                 │
│  [View All HOTO Items]   [View All Snags]       │
└────────────────────────────────────────────────┘
```

### 12.3 Approval Screen

```
← My Actions

Lift No. 2 AMC Transfer (Block B)

What is this about?
Transfer the KONE lift service contract from Ankura Homes to our
association. Secretary has approved. Your approval completes this.

Documents attached (3):
📄 KONE AMC Contract   [View]
📄 NOC from Builder    [View]
📄 New AMC Agreement   [View]

┌─────────────────────────────────────────┐
│           ✅  APPROVE                    │
│  I confirm this is correct              │
└─────────────────────────────────────────┘

┌─────────────────────────────────────────┐
│           ❌  NOT YET                    │
│  I have questions or concerns           │
└─────────────────────────────────────────┘
```

"NOT YET" opens a text field; comment logged; Secretary notified. Item stays at PENDING_PRESIDENT.

### 12.4 Pre-Launch Walkthrough Protocol

Before go-live (May 30): Secretary walks through with Bal Reddy using a test HOTO item. Bal Reddy performs a real approval and a real vote. Any confusion fixed before May 31 go-live.

---

## 13. Dashboard & UX Design

### 13.1 Full Dashboard Layout

```
┌──────────────────────────────────────────────────────────────────────┐
│  URBAN TRILLA MACS — Governance Dashboard   [Bal Reddy | Log out]    │
├───────────────────────────┬──────────────────────────────────────────┤
│  YOUR ACTIONS NEEDED      │  HOTO PROGRESS                           │
│  ┌─────────────────────┐  │  ████████████░░░░░ 62%                   │
│  │ 🔴 2 Approvals      │  │  Total: 87 items · Approved: 12          │
│  │    [View & Approve] │  │  In Progress: 38 · Not Started: 37       │
│  └─────────────────────┘  │                                           │
│  ┌─────────────────────┐  │  SNAG LIST                               │
│  │ 🟡 3 Votes pending  │  │  ████░░░░░░░░░░░░ 28%  (45/160 closed)  │
│  │    [Cast Your Vote] │  │  Critical open: 12 · Builder delayed: 5  │
│  └─────────────────────┘  │                                           │
│                           │  VENDOR DECISIONS                        │
│  RECENT ACTIVITY          │  2 of 5 finalised                        │
│  ─────────────────────    │  Property Mgmt: ⏳ Voting open           │
│  Today  Secretary         │                                           │
│  approved HOTO-042        │  CRITICAL DEADLINES                      │
│                           │  🔴 Snag #89 (Seepage): 5 days overdue  │
│                           │  🟡 Lift AMC: 26 days remaining          │
│                           │                                           │
│                           │  STORAGE HEALTH                          │
│                           │  ✅ GitHub: Connected (last write 4m ago) │
│                           │  ✅ Upload queue: 0 pending               │
└───────────────────────────┴──────────────────────────────────────────┘
```

### 13.2 Mobile Design

- Responsive; works in any browser without app install
- "My Actions" collapses to top on mobile
- Camera button on document upload
- Large tap targets (min 56px)
- Bookmarkable at `portal.utamacs.org/portal/my-actions` for non-tech users

---

## 14. Git Storage Strategy

### 14.1 Repository Structure

```
utamacs/governance-data/
├── README.md
├── RUNBOOK.md
├── _meta/
│   ├── committee-roster.json
│   ├── voting-policy.md          # Committed before first vote
│   └── scope-v1.md               # Committed before launch
├── hoto/
│   ├── _index.json
│   └── [Category]/[HOTO-NNN]/
│       ├── item.json
│       ├── comments.json         # Append-only
│       ├── approvals.json        # Append-only
│       └── documents/
├── snags/
│   ├── _index.json
│   ├── Common-Area/
│   └── Individual-Apartment/
├── vendors/
│   ├── _index.json
│   └── [REQ-NNN]/
│       ├── votes.json            # Append-only
│       ├── decision.json         # Written ONCE; immutable
│       └── proxy-authorizations/
├── notices/
│   ├── drafts/
│   ├── builder/
│   └── members/
├── finances/
│   ├── maintenance/
│   ├── corpus/
│   └── expenses/
└── audit/
    └── [YYYY-MM]/
        └── [YYYY-MM-DD].jsonl    # Append-only
```

### 14.2 Commit Convention

```
create(HOTO-042): Lift No.2 AMC Transfer — Treasurer
upload(HOTO-042): kone-amc.pdf [sha:abc123] source="Ankura Homes 2026-04-15" — Treasurer
status(HOTO-042): IN_PROGRESS → EVIDENCE_UPLOADED — Treasurer
approve(HOTO-042): President approval [per §8.1] — Bal Reddy
approve(HOTO-042): Secretary approval → APPROVED
vote(REQ-001): ApartmentAdda — Secretary [8/14 votes]
decide(REQ-001): ApartmentAdda selected (12/14 quorum per §7.16)
snag-create(SNAG-089): Block B seepage [COMMON_AREA] — Ravi
role-change: executive → secretary for [Name] — President [election-2026-06-15]
health-check: OK [latency:234ms]
```

### 14.3 Immutability Rules

- `decision.json`: written once; re-decisions create `decision-v2.json`
- `approvals.json`, `votes.json`, `audit/*.jsonl`: append-only, never modified
- `comments.json`: edits add new entry with `edited_at`; original preserved

---

## 15. Data Model

### 15.1 Complete Schema

```sql
-- ─────────────────────────────────────────────────────────────────────
-- EXISTING BUG FIX: user_roles table missing unique constraint
-- This causes role changes via UI to silently fail or create duplicates
-- Run this migration first (migration 027)
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE user_roles
  ADD CONSTRAINT IF NOT EXISTS user_roles_user_society_unique
  UNIQUE (user_id, society_id);

-- ─────────────────────────────────────────────────────────────────────
-- Profiles (existing table — extend)
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS
  portal_role TEXT DEFAULT 'executive',
  -- Governance role: member | executive | working_president | joint_treasurer |
  --                  treasurer | joint_secretary | secretary | vice_president | president
  is_admin BOOLEAN DEFAULT false,
  -- is_admin is orthogonal to portal_role. An admin executes user management with
  -- documented President/Secretary authorization. Having is_admin does NOT grant
  -- governance powers (voting, HOTO approvals) — those come from portal_role only.
  payment_status TEXT DEFAULT 'current',
  last_maintenance_paid_date DATE,
  maintenance_arrears_days INTEGER DEFAULT 0,
  privacy_consent_given BOOLEAN DEFAULT false,
  privacy_consent_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true;

-- ─────────────────────────────────────────────────────────────────────
-- Privacy Consents (DPDP Act compliance)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE privacy_consents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles NOT NULL,
  policy_version TEXT NOT NULL,
  consent_given BOOLEAN NOT NULL,
  consent_at TIMESTAMPTZ DEFAULT NOW(),
  ip_hash TEXT,
  user_agent_hash TEXT
);

-- ─────────────────────────────────────────────────────────────────────
-- Member Invites (invite-only registration)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE member_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  email TEXT NOT NULL,
  flat_number TEXT,
  intended_role TEXT NOT NULL DEFAULT 'member',
  invited_by UUID REFERENCES profiles NOT NULL,
  token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
  token_expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '7 days',
  accepted BOOLEAN DEFAULT false,
  accepted_at TIMESTAMPTZ,
  accepted_user_id UUID REFERENCES profiles,
  cancelled BOOLEAN DEFAULT false,
  cancelled_by UUID REFERENCES profiles,
  cancelled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_member_invites_token ON member_invites(token)
  WHERE NOT accepted AND NOT cancelled;

-- ─────────────────────────────────────────────────────────────────────
-- Role Change Log (fast role history; complements audit_log)
-- Includes authorization metadata: admin always documents who in leadership
-- authorized the change, how, and when — creates a defensible audit trail
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE role_change_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  user_id UUID REFERENCES profiles NOT NULL,
  old_role TEXT NOT NULL,
  new_role TEXT NOT NULL,
  changed_by UUID REFERENCES profiles NOT NULL,   -- always the admin
  reason TEXT NOT NULL,
  -- Authorization metadata (required for every role change)
  authorized_by UUID REFERENCES profiles,          -- the President or Secretary who consented
  authorization_method TEXT,                       -- 'whatsapp' | 'email' | 'verbal' | 'board_resolution'
  authorization_date DATE,
  authorization_details TEXT,                      -- verbatim or summary of what was communicated
  election_event_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_role_change_user ON role_change_log(user_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────────────
-- Election Events (groups bulk role changes)
-- Authorization metadata stored once on the event, not repeated per person
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE election_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  election_date DATE NOT NULL,
  description TEXT NOT NULL,
  total_role_changes INTEGER DEFAULT 0,
  -- Authorization metadata (required — admin must document presidential/secretarial consent)
  authorized_by UUID REFERENCES profiles,          -- President who communicated the results
  authorization_method TEXT,                       -- 'whatsapp' | 'email' | 'verbal' | 'board_resolution'
  authorization_date DATE,
  authorization_details TEXT,                      -- e.g. "AGM minutes shared on 2026-06-15"
  outcome_document_id TEXT REFERENCES documents,  -- optional: uploaded AGM minutes/resolution
  created_by UUID REFERENCES profiles,             -- the admin who executed this
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────
-- Feature Permissions (which features each role can access)
-- Only admin can change these; every change requires President authorization documented
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE feature_permissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  role TEXT NOT NULL,
  feature TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT true,
  is_locked BOOLEAN NOT NULL DEFAULT false,  -- locked = byelaw-mandated; cannot be toggled
  last_changed_by UUID REFERENCES profiles,  -- always the admin
  last_changed_at TIMESTAMPTZ DEFAULT NOW(),
  -- Authorization metadata (required for every non-locked feature change)
  authorized_by UUID REFERENCES profiles,    -- President who approved this change
  authorization_method TEXT,
  authorization_date DATE,
  authorization_details TEXT,
  UNIQUE (society_id, role, feature)
);

-- ─────────────────────────────────────────────────────────────────────
-- User Feature Overrides (per-user exceptions to role defaults)
-- Only admin can grant these; every grant requires President authorization documented
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE user_feature_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  user_id UUID REFERENCES profiles NOT NULL,
  feature TEXT NOT NULL,
  enabled BOOLEAN NOT NULL,
  reason TEXT NOT NULL,                        -- why this override is needed
  granted_by UUID REFERENCES profiles NOT NULL, -- always the admin
  granted_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  revoked_by UUID REFERENCES profiles,
  -- Authorization metadata (required — admin must document who approved this exception)
  authorized_by UUID REFERENCES profiles,      -- President who approved the override
  authorization_method TEXT,
  authorization_date DATE,
  authorization_details TEXT,
  UNIQUE (society_id, user_id, feature)
);
CREATE INDEX idx_user_feature_overrides_user ON user_feature_overrides(user_id)
  WHERE revoked_at IS NULL;

-- ─────────────────────────────────────────────────────────────────────
-- Upload Queue
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE upload_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  uploaded_by UUID REFERENCES profiles,
  item_type TEXT NOT NULL,
  item_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_size_bytes INTEGER,
  file_type TEXT,
  file_hash_sha256 TEXT,
  source_description TEXT,
  target_github_path TEXT NOT NULL,
  status TEXT DEFAULT 'PENDING',
  attempts INTEGER DEFAULT 0,
  last_attempt_at TIMESTAMPTZ,
  error_message TEXT,
  github_sha TEXT,
  document_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_upload_queue_status ON upload_queue(status);

-- ─────────────────────────────────────────────────────────────────────
-- GitHub API Log
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE github_api_log (
  id BIGSERIAL PRIMARY KEY,
  operation TEXT NOT NULL,
  success BOOLEAN NOT NULL,
  latency_ms INTEGER,
  error_message TEXT,
  github_path TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_github_api_log_created ON github_api_log(created_at DESC);

-- ─────────────────────────────────────────────────────────────────────
-- PDF Generation Jobs
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE pdf_generation_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  requested_by UUID REFERENCES profiles,
  job_type TEXT NOT NULL,
  letter_id TEXT,
  template TEXT,
  input_data JSONB,
  status TEXT DEFAULT 'QUEUED',
  attempts INTEGER DEFAULT 0,
  github_path TEXT,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- ─────────────────────────────────────────────────────────────────────
-- HOTO Items
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE hoto_items (
  id TEXT PRIMARY KEY,
  society_id UUID NOT NULL,
  ascenza_category TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  builder_commitment TEXT,
  builder_contact TEXT,
  priority TEXT DEFAULT 'MEDIUM',
  status TEXT NOT NULL DEFAULT 'NOT_STARTED',
  deadline DATE,
  builder_sla_date DATE,
  days_overdue INTEGER DEFAULT 0,
  responsible_role TEXT,
  responsible_user_id UUID REFERENCES profiles,
  rera_escalation_eligible BOOLEAN DEFAULT false,
  notice_sent BOOLEAN DEFAULT false,
  notice_sent_date TIMESTAMPTZ,
  notice_draft_path TEXT,
  dependencies TEXT[],
  president_approved_at TIMESTAMPTZ,
  president_approved_by UUID REFERENCES profiles,
  secretary_approved_at TIMESTAMPTZ,
  secretary_approved_by UUID REFERENCES profiles,
  governance_notes TEXT,
  created_by UUID REFERENCES profiles,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_updated_at TIMESTAMPTZ DEFAULT NOW(),
  github_path TEXT
);

-- ─────────────────────────────────────────────────────────────────────
-- HOTO Required Documents
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE hoto_required_docs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hoto_item_id TEXT REFERENCES hoto_items,
  doc_name TEXT NOT NULL,
  required BOOLEAN DEFAULT true,
  uploaded BOOLEAN DEFAULT false,
  document_id TEXT,
  bypass_by UUID REFERENCES profiles,
  bypass_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────
-- Snag Items
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE snag_items (
  id TEXT PRIMARY KEY,
  society_id UUID NOT NULL,
  snag_scope TEXT NOT NULL DEFAULT 'COMMON_AREA',
  category TEXT NOT NULL,
  subcategory TEXT,
  location TEXT NOT NULL,
  flat_number TEXT,
  description TEXT NOT NULL,
  severity TEXT DEFAULT 'MEDIUM',
  status TEXT DEFAULT 'OPEN',
  ascenza_reference TEXT,
  builder_committed_date DATE,
  builder_sla_days_overdue INTEGER DEFAULT 0,
  notice_sent BOOLEAN DEFAULT false,
  formal_notice_id TEXT,
  video_url TEXT,
  reported_by UUID REFERENCES profiles,
  reported_date DATE DEFAULT CURRENT_DATE,
  verified_by UUID REFERENCES profiles,
  verified_at TIMESTAMPTZ,
  deleted BOOLEAN DEFAULT false,
  deleted_by UUID REFERENCES profiles,
  deleted_at TIMESTAMPTZ,
  deletion_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  github_path TEXT
);

-- ─────────────────────────────────────────────────────────────────────
-- Documents
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  item_type TEXT NOT NULL,
  item_id TEXT NOT NULL,
  name TEXT NOT NULL,
  file_type TEXT,
  file_size_bytes INTEGER,
  file_hash_sha256 TEXT NOT NULL,
  source_description TEXT,
  github_path TEXT NOT NULL,
  github_sha TEXT,
  upload_queue_id UUID REFERENCES upload_queue,
  uploaded_by UUID REFERENCES profiles,
  uploaded_at TIMESTAMPTZ DEFAULT NOW(),
  description TEXT,
  is_confidential BOOLEAN DEFAULT false,
  superseded_by TEXT REFERENCES documents,
  superseded_at TIMESTAMPTZ
);

-- ─────────────────────────────────────────────────────────────────────
-- Vendor Requirements
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE vendor_requirements (
  id TEXT PRIMARY KEY,
  society_id UUID NOT NULL,
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'DRAFT',
  voting_opens_at TIMESTAMPTZ,
  voting_closes_at TIMESTAMPTZ,
  quorum_required INTEGER DEFAULT 8,
  selected_vendor_id TEXT,
  voting_policy_committed BOOLEAN DEFAULT false,
  created_by UUID REFERENCES profiles,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────
-- Vendors
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE vendors (
  id TEXT PRIMARY KEY,
  requirement_id TEXT REFERENCES vendor_requirements,
  vendor_name TEXT NOT NULL,
  contact_person TEXT,
  contact_email TEXT,
  contact_phone TEXT,
  site_visited BOOLEAN DEFAULT false,
  quote_monthly NUMERIC(12,2),
  quote_setup NUMERIC(12,2),
  submitted_at TIMESTAMPTZ,
  contract_start_date DATE,
  contract_end_date DATE,
  renewal_reminder_sent BOOLEAN DEFAULT false,
  github_path TEXT
);

-- ─────────────────────────────────────────────────────────────────────
-- Proxy Authorizations
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE proxy_authorizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  principal_user_id UUID REFERENCES profiles NOT NULL,
  proxy_user_id UUID REFERENCES profiles NOT NULL,
  requirement_id TEXT REFERENCES vendor_requirements,
  proxy_document_id TEXT REFERENCES documents,
  valid_from DATE NOT NULL,
  valid_until DATE,
  activated_by UUID REFERENCES profiles,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────
-- Votes
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE votes (
  id TEXT PRIMARY KEY,
  requirement_id TEXT REFERENCES vendor_requirements,
  voter_id UUID REFERENCES profiles,
  proxy_authorization_id UUID REFERENCES proxy_authorizations,
  vendor_id TEXT REFERENCES vendors,
  reason TEXT NOT NULL,
  conflict_declared BOOLEAN DEFAULT false,
  recused BOOLEAN DEFAULT false,
  cast_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(requirement_id, voter_id)
);

-- ─────────────────────────────────────────────────────────────────────
-- Maintenance Records
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE maintenance_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  flat_number TEXT NOT NULL,
  member_id UUID REFERENCES profiles,
  amount NUMERIC(10,2) NOT NULL,
  period_month INTEGER NOT NULL,
  period_year INTEGER NOT NULL,
  paid_date DATE,
  payment_mode TEXT,
  reference_number TEXT,
  recorded_by UUID REFERENCES profiles,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────
-- Corpus Fund Records
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE corpus_fund_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  transaction_type TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  description TEXT,
  date DATE NOT NULL,
  approved_by UUID REFERENCES profiles,
  board_resolution_ref TEXT,
  payment_mode TEXT,
  reference_number TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION get_corpus_balance(p_society_id UUID)
RETURNS NUMERIC AS $$
  SELECT COALESCE(
    SUM(CASE WHEN transaction_type IN ('RECEIVED_FROM_BUILDER','INTEREST_EARNED') THEN amount
             WHEN transaction_type = 'APPROVED_USE' THEN -amount END), 0)
  FROM corpus_fund_records WHERE society_id = p_society_id;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- ─────────────────────────────────────────────────────────────────────
-- Expenses
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  payee TEXT NOT NULL,
  purpose TEXT NOT NULL,
  expense_date DATE NOT NULL,
  payment_mode TEXT NOT NULL,
  reference_number TEXT,
  is_recurring BOOLEAN DEFAULT false,
  sanctioned_by_role TEXT,
  sanctioned_by UUID REFERENCES profiles,
  byelaw_authority TEXT,
  board_resolution_ref TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────
-- Comments
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE comments (
  id TEXT PRIMARY KEY,
  item_type TEXT NOT NULL,
  item_id TEXT NOT NULL,
  parent_comment_id TEXT REFERENCES comments,
  author_id UUID REFERENCES profiles,
  content TEXT NOT NULL,
  is_pinned BOOLEAN DEFAULT false,
  edited_at TIMESTAMPTZ,
  edited_content TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  github_commit TEXT
  -- No deleted column: comments are permanent audit records
);

-- ─────────────────────────────────────────────────────────────────────
-- Formal Notices
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE notices (
  id TEXT PRIMARY KEY,
  notice_type TEXT NOT NULL,
  recipient TEXT NOT NULL,
  recipient_type TEXT NOT NULL,
  related_item_type TEXT,
  related_item_id TEXT,
  auto_generated BOOLEAN DEFAULT false,
  status TEXT DEFAULT 'DRAFT',
  sent_date DATE,
  sent_by UUID REFERENCES profiles,
  document_path TEXT,
  response_received BOOLEAN DEFAULT false,
  response_date DATE,
  rera_filed BOOLEAN DEFAULT false,
  rera_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────
-- Approval Delegations
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE approval_delegations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  from_role TEXT NOT NULL,
  to_user_id UUID REFERENCES profiles,
  reason TEXT NOT NULL,
  delegation_type TEXT NOT NULL,
  active BOOLEAN DEFAULT true,
  activated_by UUID REFERENCES profiles,
  activated_at TIMESTAMPTZ DEFAULT NOW(),
  deactivated_at TIMESTAMPTZ,
  notes TEXT
);

-- ─────────────────────────────────────────────────────────────────────
-- Audit Log
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE audit_log (
  id BIGSERIAL PRIMARY KEY,
  society_id UUID NOT NULL,
  actor_id UUID REFERENCES profiles,
  action TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  old_values JSONB,
  new_values JSONB,
  byelaw_reference TEXT,
  ip_hash TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_audit_log_resource ON audit_log(resource_type, resource_id);
CREATE INDEX idx_audit_log_actor ON audit_log(actor_id, created_at DESC);
```

---

## 16. Security & Privacy Compliance

### 16.1 GitHub App Private Key Security

1. Key lives **only** in Vercel environment variables (`GITHUB_APP_PRIVATE_KEY`)
2. Never in code, `.env` files, or any git-tracked file
3. Pre-commit hook on `utamacs-website` repo:
   ```bash
   if git diff --cached --name-only | xargs grep -l "BEGIN RSA PRIVATE KEY\|BEGIN EC PRIVATE KEY" 2>/dev/null; then
     echo "ERROR: Private key in staged files. Commit blocked."; exit 1
   fi
   ```
4. Quarterly rotation; procedure in RUNBOOK.md
5. GitHub App permissions: `contents:write` on `governance-data` only

### 16.2 Row-Level Security

All sensitive tables have RLS enabled. `anon` key has zero access.

```sql
ALTER TABLE hoto_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_feature_overrides ENABLE ROW LEVEL SECURITY;
-- (all new tables)

-- Feature permissions: readable by committee; writable by president only
CREATE POLICY "feature_perms_read" ON feature_permissions
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
            AND portal_role != 'member')
  );

CREATE POLICY "feature_perms_write" ON feature_permissions
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid()
            AND portal_role = 'president')
  );
```

RLS test requirement: before go-live, test with role-specific JWTs:
- `anon` JWT: must be blocked from all sensitive tables
- `member` JWT: must be blocked from `maintenance_records`, `votes` (others)
- `executive` JWT: must be blocked from phone numbers in `profiles`

### 16.3 DPDP Act Compliance

- Privacy policy at `utamacs.org/privacy` before any data collection
- Explicit consent checkbox on first login; consent stored in `privacy_consents`
- Purpose limitation: member data used only for governance communications
- Data breach: affected members notified within 72 hours

### 16.4 Feature Permission API Security

The `feature_permissions` and `user_feature_overrides` tables drive UI rendering, but **every API route independently re-checks permissions** from the database:

```typescript
// In every API route
const { feature, user } = await resolvePermission(request, 'hoto.approve_president');
if (!feature.enabled) {
  return Response.json({ error: 'FORBIDDEN' }, { status: 403 });
}
```

This means: even if a client somehow renders a button that should be hidden, the API rejects the request. UI gating is UX; API checking is security.

---

## 17. Data Migration Sprint

### 17.1 Pre-HOTO Migration (May 6-25)

| Priority | Source | Content |
|---|---|---|
| P1 | Committee email inboxes | Builder letters, NOCs, certificates from Ankura Homes |
| P1 | Google Drive | Ascenza scope documents, inspection reports |
| P1 | WhatsApp | Photos from site inspections |
| P2 | Physical | Scans of handover letters, signed agreements |
| P3 | WhatsApp | Meeting minutes, decisions (screenshot → PDF) |

Tools built for migration:
- Admin bulk import: `/portal/admin/import` — CSV creates multiple items in one operation
- Bulk document upload: multiple files → `upload_queue` → associated with HOTO item
- Every migrated document gets `source_description` = "Migrated from [source] by [person] on [date]"

### 17.2 HOTO Item Seeding (May 6-9)

80+ items seeded from Ascenza scope CSV before committee training:
```bash
# seeds/seed-hoto-items.ts
# Reads: seeds/hoto-items.csv
# Inserts hoto_items + hoto_required_docs
# Commits _index.json to governance-data
```

---

## 18. Role-Based Access Control & Feature Permissions

### 18.1 Feature Registry

Every controllable feature in the system has a canonical name. The feature registry is the source of truth:

```typescript
// src/lib/features.ts

export const FEATURES = {
  // User Management
  'users.view_directory':    { label: 'View member directory',          locked: false },
  'users.invite_member':     { label: 'Invite new members',             locked: false },
  'users.invite_committee':  { label: 'Invite committee members',       locked: true  }, // president only
  'users.change_role':       { label: 'Change member roles',            locked: true  }, // president only
  'users.deactivate':        { label: 'Deactivate members',             locked: false },

  // HOTO
  'hoto.view':               { label: 'View HOTO items',                locked: true  }, // all committee
  'hoto.create':             { label: 'Create/edit HOTO items',         locked: false },
  'hoto.upload':             { label: 'Upload documents',               locked: false },
  'hoto.comment':            { label: 'Add comments',                   locked: false },
  'hoto.advance_status':     { label: 'Advance item status',            locked: false },
  'hoto.approve_president':  { label: 'President approval gate',        locked: true  }, // president/VP only
  'hoto.approve_secretary':  { label: 'Secretary approval gate',        locked: true  }, // secretary only
  'hoto.bypass_required_docs': { label: 'Bypass required document gate', locked: true }, // secretary+

  // Snag
  'snag.view':               { label: 'View snag list',                 locked: true  },
  'snag.create':             { label: 'Create/edit snags',              locked: false },
  'snag.delete':             { label: 'Delete snags',                   locked: true  }, // president only
  'snag.verify_close':       { label: 'Mark snags as verified closed',  locked: true  }, // president/secretary

  // Vendor
  'vendor.view':             { label: 'View vendor evaluations',        locked: true  },
  'vendor.view_quotes':      { label: 'View vendor quotes',             locked: false },
  'vendor.vote':             { label: 'Cast vendor vote',               locked: false },
  'vendor.open_voting':      { label: 'Open/close voting',             locked: false },
  'vendor.final_select':     { label: 'Confirm final vendor selection', locked: true  }, // president+secretary

  // Finance
  'finance.view':            { label: 'View financial records',         locked: false },
  'finance.enter':           { label: 'Enter maintenance/expense records', locked: false },
  'finance.approve_10k':     { label: 'Approve expenses ≤₹10K (§9.11a)',  locked: true  }, // secretary+
  'finance.approve_20k':     { label: 'Approve expenses ≤₹20K (§9.11a)',  locked: true  }, // president only
  'finance.view_member_phones': { label: 'View member phone numbers',   locked: true  }, // secretary+

  // Notices
  'notice.view':             { label: 'View formal notices',            locked: false },
  'notice.send':             { label: 'Send formal notices',            locked: false },

  // Admin
  'admin.delegation':        { label: 'Manage delegation settings',     locked: true  }, // president only
  'admin.elections':         { label: 'Run committee election update',  locked: true  }, // president only
  'admin.permissions':       { label: 'Manage feature permissions',     locked: true  }, // president only
  'admin.import':            { label: 'Bulk data import',               locked: false },

  // Audit
  'audit.view':              { label: 'View audit log',                 locked: false },
} as const;

export type Feature = keyof typeof FEATURES;
```

`locked: true` features have their default role assignment enforced by the system and cannot be changed by the admin permissions UI. `locked: false` features can be toggled per role.

### 18.2 Default Role Permissions

```typescript
export const DEFAULT_ROLE_PERMISSIONS: Record<string, Feature[]> = {
  member: [
    'hoto.view', 'snag.view', 'vendor.view', 'notice.view',
  ],
  executive: [
    'hoto.view', 'hoto.create', 'hoto.upload', 'hoto.comment', 'hoto.advance_status',
    'snag.view', 'snag.create',
    'vendor.view', 'vendor.view_quotes', 'vendor.vote',
    'notice.view',
    'audit.view',
  ],
  working_president: [/* same as executive */],
  joint_treasurer: [/* same as executive + finance.view, finance.enter */],
  treasurer: [
    '...executive features...',
    'finance.view', 'finance.enter',
    'users.view_directory',
  ],
  joint_secretary: [
    '...treasurer features...',
    'vendor.open_voting', 'notice.send',
    'hoto.approve_secretary',   // when delegated per §8.4
    'users.invite_member', 'users.deactivate', 'users.view_directory',
    'hoto.bypass_required_docs',
  ],
  secretary: [
    '...joint_secretary features...',
    'hoto.approve_secretary',
    'snag.verify_close',
    'finance.approve_10k', 'finance.view_member_phones',
    'audit.view',
  ],
  vice_president: [
    '...secretary features...',
    'hoto.approve_president',   // when delegated per §8.2
    'users.invite_member', 'users.deactivate',
  ],
  president: [
    // All features
    '...all features...',
    'hoto.approve_president',
    'admin.delegation', 'admin.elections', 'admin.permissions',
    'users.invite_committee', 'users.change_role',
    'finance.approve_20k',
    'snag.delete',
  ],
};
```

### 18.3 Permission Resolution at Runtime

Every page load and every API call resolves permissions through this function:

```typescript
// src/lib/permissions.ts

export async function resolveUserPermissions(
  userId: string,
  societyId: string
): Promise<Set<Feature>> {
  // 1. Get user's current role
  const { data: profile } = await supabase
    .from('profiles')
    .select('portal_role')
    .eq('id', userId)
    .single();

  // 2. Get role-level permissions from feature_permissions table
  //    (falls back to DEFAULT_ROLE_PERMISSIONS if no DB override)
  const { data: rolePerms } = await supabase
    .from('feature_permissions')
    .select('feature, enabled')
    .eq('society_id', societyId)
    .eq('role', profile.portal_role);

  // 3. Get user-specific overrides (non-revoked, non-expired)
  const { data: userOverrides } = await supabase
    .from('user_feature_overrides')
    .select('feature, enabled')
    .eq('society_id', societyId)
    .eq('user_id', userId)
    .is('revoked_at', null)
    .or(`expires_at.is.null,expires_at.gt.${new Date().toISOString()}`);

  // 4. Build final permission set: role defaults → role overrides → user overrides
  const permissions = new Set<Feature>(DEFAULT_ROLE_PERMISSIONS[profile.portal_role]);

  for (const perm of rolePerms ?? []) {
    perm.enabled ? permissions.add(perm.feature as Feature)
                 : permissions.delete(perm.feature as Feature);
  }
  for (const override of userOverrides ?? []) {
    override.enabled ? permissions.add(override.feature as Feature)
                     : permissions.delete(override.feature as Feature);
  }

  return permissions;
}

export function can(permissions: Set<Feature>, feature: Feature): boolean {
  return permissions.has(feature);
}
```

### 18.4 UI Enforcement Pattern

In every Astro page component:

```astro
---
// src/pages/portal/hoto/[id].astro
const user = await requireAuth(Astro);
const permissions = await resolveUserPermissions(user.id, user.society_id);
---

<!-- Buttons only render if the user has the feature -->
{can(permissions, 'hoto.upload') && (
  <button class="btn-primary">Upload Document</button>
)}

{can(permissions, 'hoto.approve_president') && item.status === 'PENDING_PRESIDENT' && (
  <button class="btn-primary btn-large">APPROVE</button>
)}

{can(permissions, 'hoto.advance_status') && (
  <StatusTransitionButtons item={item} />
)}

<!-- Disabled with tooltip for features the user almost-qualifies for -->
{!can(permissions, 'hoto.approve_president') && item.status === 'PENDING_PRESIDENT' && (
  <div class="permission-notice">
    Waiting for President's approval
  </div>
)}
```

**Rules for UI enforcement:**
- Hidden entirely: features the user's role would never have
- Disabled with explanation: features temporarily unavailable (e.g., "Voting closes in 3 days" vs "You've already voted")
- Visible but blocked: approval gates where the user sees the item but cannot act (shows who needs to act)
- Never show a 403 error page for in-page features — always render the read-only state with a clear label

### 18.5 Admin Feature Permissions UI (`/portal/admin/permissions`)

Only the **admin** (`is_admin = true`) can access this page. The admin uses it to apply a feature permission change that the President has authorized. Every save requires the authorization form to be completed.

```
FEATURE PERMISSIONS                      [Viewing: Executive Role ▼]

HOTO Module
  🔒 View HOTO items               Always ON (locked — all committee)
  ✅ Create/edit HOTO items         ON   [Toggle]
  ✅ Upload documents               ON   [Toggle]
  ✅ Add comments                   ON   [Toggle]
  ✅ Advance item status            ON   [Toggle]
  🔒 President approval gate        Always ON for president only (locked)
  🔒 Secretary approval gate        Always ON for secretary only (locked)

Snag Module
  🔒 View snag list                Always ON (locked — all committee)
  ✅ Create/edit snags              ON   [Toggle]
  🔒 Delete snags                  Always ON for president only (locked)
  🔒 Verify-close snags            Always ON for president/secretary (locked)

Vendor Module
  🔒 View vendor evaluations       Always ON (locked — all committee)
  ✅ View vendor quotes             ON   [Toggle]
  ✅ Cast vendor vote               ON   [Toggle]
  ✅ Open/close voting              ON   [Toggle]

Finance Module
  ✅ View financial records         OFF  [Toggle]
  ✅ Enter records                  OFF  [Toggle]
  🔒 Approve ≤₹10K                 Always ON for secretary only (locked)
  🔒 Approve ≤₹20K                 Always ON for president only (locked)

  [Save Changes for Executive Role]    [Reset to Defaults]
```

After clicking Save, the authorization form appears:
```
  Before saving, document the President's authorization for this change:
  Authorized by: [President Bal Reddy ▼]   How: [WhatsApp ▼]   Date: [____]
  Details: ___________________________________
  [Cancel]   [Save with Authorization]
```

Locked features display a tooltip: "This permission is mandated by the society's byelaws and cannot be changed."

**Non-locked features** can be toggled per role by the admin with documented President authorization. Examples of legitimate changes:
- Give `executive` role access to `finance.view` (see totals, not enter data)
- Give `joint_treasurer` access to `notice.send` for a specific operational period
- Remove `vendor.view_quotes` from `executive` during a sensitive procurement

### 18.6 Per-User Feature Overrides

For edge cases where one person needs temporary access outside their role. The admin grants these with documented President authorization.

```
/portal/admin/users/[id] → Permissions tab

[Name] (Flat 204) — Role: Executive

INHERITED FROM EXECUTIVE ROLE:
  ✅ hoto.view, hoto.create, hoto.upload, hoto.comment ...
  ❌ finance.view (not in executive defaults)

USER-SPECIFIC OVERRIDES:
  ┌──────────────────────────────────────────────────────────────────┐
  │  finance.view   ENABLED   Expires: 2026-08-31                    │
  │  Reason: Acting financial coordinator during Treasurer's absence │
  │  Granted by: Admin on 2026-06-15                                 │
  │  Authorized by: President (WhatsApp, Jun 15)    [Revoke]         │
  └──────────────────────────────────────────────────────────────────┘

[+ Add Override]  ← Admin only
  Feature: [finance.view ▼]   Enable/Disable: [Enable ▼]
  Reason: _________________________   Expires: ____/____/____  (optional)

  Authorization (required):
  Authorized by: [President ▼]   How: [WhatsApp ▼]   Date: [____]
  Details: ___________________________________
  [Grant Override]
```

Overrides:
- Require a mandatory reason AND authorization metadata
- Optional expiry date (auto-revoked when expired)
- Shown in the user's audit trail with full authorization details
- Can be revoked at any time by the admin (with authorization from President/Secretary)
- Only the admin can grant overrides — President/Secretary communicate the decision but the admin executes it

**Guiding principle:** Overrides are for genuine edge cases (temporary acting role, specific investigation). They are not a substitute for proper role management via the election workflow.

### 18.7 Feature Access Summary Matrix

Two orthogonal axes: **governance role** (approval/voting/action power) and **admin flag** (system management power). The President authorizes; the admin executes.

| Feature | member | executive | treasurer / joint_sec | secretary | vice_president | president | **admin** (`is_admin=true`) |
|---|---|---|---|---|---|---|---|
| **User Management** — admin executes with documented Pres/Sec authorization | | | | | | | |
| View member directory (read-only) | - | - | - | ✓ | ✓ | ✓ | ✓ |
| Invite new member | - | - | - | - | - | - | ✓ + auth from Sec/Pres |
| Invite committee member | - | - | - | - | - | - | ✓ + auth from Pres |
| Change any governance role | - | - | - | - | - | - | ✓ + auth from Pres |
| Deactivate member | - | - | - | - | - | - | ✓ + auth from Sec/Pres |
| Reactivate member | - | - | - | - | - | - | ✓ + auth from Sec/Pres |
| Run election bulk update | - | - | - | - | - | - | ✓ + auth from Pres |
| Manage feature permissions | - | - | - | - | - | - | ✓ + auth from Pres |
| Grant per-user feature override | - | - | - | - | - | - | ✓ + auth from Pres |
| Revoke per-user feature override | - | - | - | - | - | - | ✓ + auth from Pres |
| Grant / revoke admin flag | - | - | - | - | - | - | ✓ + auth from Pres |
| Manage delegation settings | - | - | - | - | - | - | ✓ + auth from Pres/Sec |
| **HOTO** — governance role controls these | | | | | | | |
| View items | R | R | R | R | R | R | R |
| Create/edit items | - | ✓ | ✓ | ✓ | ✓ | ✓ | via governance role only |
| Upload documents | - | ✓ | ✓ | ✓ | ✓ | ✓ | via governance role only |
| Advance status | - | ✓ | ✓ | ✓ | ✓ | ✓ | via governance role only |
| President approval gate | - | - | - | - | ✓(delegated) | ✓ | — (not a governance power) |
| Secretary approval gate | - | - | ✓(joint_sec) | ✓ | - | - | — |
| Bypass required docs gate | - | - | - | ✓ | ✓ | ✓ | — |
| **Snag** | | | | | | | |
| View | R | R | R | R | R | R | R |
| Create/edit | - | ✓ | ✓ | ✓ | ✓ | ✓ | via governance role only |
| Delete (soft) | - | - | - | - | - | ✓ | — |
| Verify-close | - | - | - | ✓ | - | ✓ | — |
| **Vendor** | | | | | | | |
| View evaluations | R | R | R | R | R | R | R |
| View quotes | - | ✓ | ✓ | ✓ | ✓ | ✓ | via governance role only |
| Cast vote | - | ✓ | ✓ | ✓ | ✓ | ✓ | via governance role only |
| Open voting | - | - | ✓ | ✓ | ✓ | ✓ | — |
| Final selection confirm | - | - | - | ✓ | ✓ | ✓ | — |
| **Finance** | | | | | | | |
| View records | - | - | ✓ | ✓ | ✓ | ✓ | — |
| Enter records | - | - | ✓(treasurer) | ✓ | ✓ | ✓ | — |
| Approve ≤₹10K | - | - | - | ✓ | - | - | — |
| Approve ≤₹20K | - | - | - | - | - | ✓ | — |
| View member phones | - | - | - | ✓ | ✓ | ✓ | ✓ (operational) |
| **Notices** | | | | | | | |
| View | R | R | R | R | R | R | R |
| Send | - | - | ✓(joint_sec) | ✓ | ✓ | ✓ | — |
| **Audit** | | | | | | | |
| View audit log | - | - | ✓(sec/joint_sec) | ✓ | ✓ | ✓ | ✓ |
| View authorization records | - | - | - | ✓ | ✓ | ✓ | ✓ |

**Reading the matrix:** The `president` column has no user-management ✓ marks — the President authorizes decisions verbally/via WhatsApp; the admin records that authorization and executes the change. If the admin also holds a governance role (e.g., `executive`), they get both sets of capabilities.

---

## 19. Document Management

### 19.1 Required Document Prompting

Each HOTO item has a `required_documents` list. Cannot advance to `UNDER_REVIEW` if required docs missing — hard gate. Secretary or President can bypass with mandatory written reason (stored in `hoto_required_docs.bypass_reason` and audit log).

### 19.2 Document Metadata (Every Upload)

- `uploaded_by`: server-resolved from session (not client-provided)
- `uploaded_at`: server timestamp (not client clock)
- `file_hash_sha256`: computed server-side before uploading
- `source_description`: "Received from Ankura Homes on 2026-04-15"
- `github_sha`: the git commit SHA — cryptographically verifiable

### 19.3 Document Versioning

New version uploaded → old version gets `superseded_by = new_id`. Old version stays downloadable. Version history shown on document card.

### 19.4 Confidentiality Rules

| Data | Visible to |
|---|---|
| Member phone numbers | secretary, joint_secretary, treasurer, vice_president, president |
| Vendor quotes | All committee (executive and above) |
| Legal notices | All committee |
| Financial records | treasurer, joint_treasurer, secretary, vice_president, president |
| Proxy documents | secretary, president |
| Audit log | secretary, vice_president, president |

---

## 20. Scope Boundary

### 20.1 What This Platform Covers (v1)

1. User & role management (invite, role assignment, elections, feature permissions)
2. HOTO tracking — Ascenza-scope items from June 1, 2026
3. Snag list management — common area; individual apartments as courtesy log
4. Vendor evaluation and selection — current 5 active evaluations
5. Maintenance collection tracking — from May 1, 2025
6. Corpus fund and expense tracking
7. Formal notice generation to builder and members
8. MC governance: voting, approvals, delegation

### 20.2 Explicitly Out of Scope (v1)

Committed to `governance-data/_meta/scope-v1.md` before launch. When scope-creep requests arrive, this is the documented response:

- Clubhouse/amenity booking
- Resident-to-resident contact directory
- Maintenance complaint routing for residents
- Individual apartment snagging resolution
- Annual General Body Meeting workflow
- Gate access / visitor management
- WhatsApp Business API integration

---

## 21. Phase-wise Implementation Plan

### Urgency Context

Today is May 6, 2026. HOTO starts June 1, 2026. That is **26 days**. The plan below compresses the critical path to a 3-week emergency sprint.

**Principle:** Imperfect digital tracking from Day 1 is worth more than a perfect system 6 weeks later.

---

### Emergency Sprint — May 6 to May 31 (25 days)

**Goal:** System live May 31. All 14 members onboarded with correct roles. 80+ HOTO items seeded. Bal Reddy has done one walkthrough.

**Scope IN:**
- Infrastructure: governance-data repo, GitHub App, upload queue, health-check cron, Supabase migrations
- User management: invite-only registration, role assignment, user directory, role change with audit trail
- Feature permissions: default role permissions seeded; admin permissions UI
- Auth: existing Supabase auth + new role columns + RLS on all new tables
- HOTO item list and detail: view, comment, upload (queued), required doc alerts, status transitions
- Mobile "My Actions" screen with Approve / Not Yet for President
- Email notifications: action required, status change (Resend)
- Seeded: all 80+ HOTO items + required doc checklists
- Security: pre-commit hook, RLS test, anon key blocked
- Privacy: consent checkbox on first login, privacy policy live

**Scope OUT (deferred to Phase 2):**
- Full President+Secretary approval workflow gates (simplified: Secretary manually marks "submitted for approval")
- Snag module bulk CSV import
- Vendor voting
- Financial tracking
- Formal notice generation
- Election bulk update workflow
- Per-user feature overrides

| Days | Deliverable | Notes |
|---|---|---|
| **May 6-9** (Days 1-4) | Create `utamacs/governance-data` repo. Set up GitHub App; install key in Vercel env vars. Add pre-commit hook. Run Supabase migration 027 (all new tables including `member_invites`, `role_change_log`, `election_events`, `feature_permissions`, `user_feature_overrides`). Fix `user_roles` unique constraint bug. | Critical infrastructure |
| **May 9** (Day 4) | Health-check cron + Supabase keepalive cron running. Verify both write to `github_api_log`. | Non-negotiable |
| **May 10-12** (Days 5-7) | User directory: `/portal/admin/users` — list with role badges, payment status, last active. Pending invites tab. Role change UI (dropdown + mandatory reason + confirmation + email notification + audit log). | RBAC management core |
| **May 12-14** (Days 8-9) | Invite flow: admin sends invite → Resend email with one-time link → registration with privacy consent → account created → admin notified. | Needed before onboarding 14 members |
| **May 14-17** (Days 10-12) | Seed default `feature_permissions` for all roles. Admin permissions UI at `/portal/admin/permissions` (view defaults; toggle non-locked features per role). | Needed before access is given |
| **May 17-21** (Days 13-16) | HOTO item list: filterable by category/status/priority. HOTO item detail: required doc checklist, document upload via upload_queue with status polling, comment thread, status timeline, transitions with role checks. | Core HOTO tracker |
| **May 21-24** (Days 17-19) | "My Actions" mobile screen. Simplified approve/reject UI for non-tech users. Email notifications (action required, status changed) via Resend. | President adoption |
| **May 24-27** (Days 20-22) | Invite and onboard all 14 committee members with correct roles. Verify each role's UI shows correct features (spot-check with executive and secretary accounts). | Committee onboarding |
| **May 27-29** (Days 23-24) | Data migration P1: builder letters, NOCs, Ascenza scope docs uploaded. Privacy policy live at `utamacs.org/privacy`. `scope-v1.md` and `voting-policy.md` committed to governance-data. | Legal/compliance |
| **May 29-30** (Day 25) | Pre-launch walkthrough with Bal Reddy: views My Actions, reads an item, approves. Fix any confusion. Final smoke test on mobile. | President sign-off |
| **May 31** | **Go-live.** All 14 members active. HOTO tracking begins. | |

---

### Phase 2 — June 1 to June 28 (4 weeks)

| Week | Deliverable |
|---|---|
| **Week 5 (Jun 1-7)** | Full President + Secretary approval workflow with delegation. Delegation management UI. Acting-on-behalf tagging. |
| **Week 6 (Jun 8-14)** | Snag list CRUD. Snag scope with liability disclaimer. Bulk CSV import from Ascenza. Photo upload from mobile camera. |
| **Week 7 (Jun 15-21)** | Committee election bulk update workflow at `/portal/admin/elections`. Per-user feature overrides UI. |
| **Week 8 (Jun 22-28)** | Vendor evaluation module: board, vendor profiles, comparison matrix, voting with quorum enforcement, conflict of interest, proxy, decision record. |

---

### Phase 3 — July 1 to July 31 (4 weeks)

| Week | Deliverable |
|---|---|
| **Week 9 (Jul 1-7)** | Maintenance collection tracking. Defaulter tracking with thresholds. Monthly defaulter list generation and email. |
| **Week 10 (Jul 8-14)** | Corpus fund tracker with overdraft prevention. Expense tracker with byelaw authority enforcement. Builder dues register. |
| **Week 11 (Jul 15-21)** | Formal notice generation. Auto-draft at 30-day SLA breach. RERA escalation tracker. |
| **Week 12 (Jul 22-31)** | Post-selection vendor tracking. Async PDF generation (job queue). |

---

### Phase 4 — August 1 to August 31 (4 weeks)

| Week | Deliverable |
|---|---|
| **Week 13 (Aug 1-14)** | Mobile UX audit. Storage health tile. Resident fortnightly HOTO digest email. |
| **Week 14 (Aug 15-22)** | Security review: RLS audit, feature permission enforcement test, corpus fund overdraft test. |
| **Week 15 (Aug 23-28)** | RUNBOOK.md validated: Secretary follows it without assistance. |
| **Week 16 (Aug 29-31)** | Retrospective. Phase 5 scope assessment (AGM, meeting management, WhatsApp notifications). |

---

### Pre-Launch Checklist (Must Be Done Before May 31)

**Infrastructure**
- [ ] `utamacs/governance-data` private repo created
- [ ] GitHub App installed; private key in Vercel env vars only (not in any file)
- [ ] Pre-commit hook blocking private key commits installed and tested
- [ ] Supabase migration 027 run and verified in production
- [ ] `user_roles` unique constraint added (fix for existing bug)
- [ ] Health-check cron running every 15 minutes
- [ ] Supabase keepalive cron running every 6 days
- [ ] Upload queue cron running every 60 seconds
- [ ] Vercel Pro upgrade completed (14-minute timeout)
- [ ] Resend DNS for `utamacs.org` verified

**Security & Privacy**
- [ ] RLS enabled on all new tables; anon key tested with zero sensitive access
- [ ] `executive` JWT tested: cannot see `maintenance_records` or member phone numbers
- [ ] `member` JWT tested: cannot access financial or governance documents
- [ ] Privacy policy live at `utamacs.org/privacy`
- [ ] Consent checkbox on first login; test it blocks registration until accepted

**User Management**
- [ ] Default `feature_permissions` seeded for all roles (from DEFAULT_ROLE_PERMISSIONS)
- [ ] Admin permissions UI verified: locked features cannot be toggled
- [ ] All 14 committee members invited and accepted (with correct roles)
- [ ] Invite flow tested end-to-end: invite → email → register → login → correct features visible

**Content & Compliance**
- [ ] 80+ HOTO items seeded with required document checklists
- [ ] P1 historical documents uploaded with `source_description`
- [ ] `governance-data/_meta/scope-v1.md` committed
- [ ] `governance-data/_meta/voting-policy.md` committed

**UX Validation**
- [ ] Bal Reddy walkthrough completed: viewed item, approved, saw vote screen
- [ ] Working President tested on mobile browser
- [ ] All role-specific screens spot-checked (executive, secretary, president)

---

## 22. Comprehensive Risk Register

### 22.1 RBAC & User Management Risks (New in v3.1)

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Role change via UI silently fails (existing bug) | **High** | **High** | `user_roles` unique constraint fix in migration 027; tested before go-live |
| Admin accidentally gives wrong role at election | Medium | High | Election bulk update preview screen shows all changes before confirm; atomic transaction |
| Feature permission toggle disables a byelaw-required gate | Medium | Critical | Locked features cannot be toggled; tooltip explains why; API independently checks regardless |
| Invite link forwarded to unauthorized person | Low | High | One-time token; invalidated immediately after use; email-verified only |
| Auto-reassignment misses an item | Low | Medium | Query covers ALL assigned items; tested before go-live; orphan dashboard tile shows unassigned items |
| Per-user override granted inappropriately | Low | Medium | Only President can grant overrides; mandatory reason stored; shown in user's audit trail |
| UI shows feature but API blocks it (desync) | Low | High | API independently resolves permissions from DB on every call; UI and API use same `resolveUserPermissions` function |
| Feature permissions DB record missing (new role) | Medium | Medium | Default role permissions are hardcoded in `DEFAULT_ROLE_PERMISSIONS`; DB overrides are additive |

### 22.2 Technical Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| GitHub API rate limit during bulk session | Medium | High | `upload_queue` cron, max 30/batch |
| Vercel 10s timeout kills PDF | Medium | High | Async `pdf_generation_jobs`; Vercel Pro backup |
| GitHub App token silent failure | Medium | Critical | 15-min health-check; Resend alert on failure |
| Supabase DB pauses | Medium | Medium | 6-day keepalive cron |
| RLS gaps expose PII | Medium | High | RLS test suite with role JWTs before go-live |
| Private key leaked to git | Low | Critical | Pre-commit hook; Vercel env vars only |

### 22.3 Adoption Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| President doesn't adopt portal | High | Critical | Non-tech UX spec; "My Actions" default; pre-launch walkthrough mandatory |
| Committee reverts to WhatsApp | High | Medium | Financial payments require portal approval record |
| Committee member dropout mid-HOTO | Medium | High | Role-based assignment; orphan auto-escalation |

### 22.4 Governance & Legal Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Vote challenged (proxy invalidity) | Low | High | Notarized proxy doc linked to vote; policy pre-committed |
| RERA document metadata challenged | Low | High | Server timestamps; SHA-256 hash; source description |
| DPDP Act compliance gap | Low | High | Privacy policy + consent + consent timestamp |
| Byelaw ambiguity mid-implementation | Medium | Medium | `governance_notes` field; interpretation documented not encoded |

### 22.5 Operational Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Phase 1 too late for June 1 | High | Critical | Emergency sprint; minimum viable scope explicitly defined |
| Data migration never completed | High | Medium | Dedicated migration sprint May 6-25; P1 priority enforced |
| Architecture bus-factor | High | High | RUNBOOK.md; Secretary validates before go-live |
| Scope creep from residents | High | Medium | `scope-v1.md` committed to governance-data |

### 22.6 Financial Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Corpus fund overdraft | Low | Critical | Server-side balance check; API rejects if insufficient |
| Expense exceeds byelaw authority | Low | High | API enforces §9.11 limits; blocks with byelaw citation |
| Builder dues never collected | Medium | High | SLA escalation cron; RERA notice auto-draft at 30 days |

### 22.7 The Three That Kill the Project

If only three risks get managed before everything else:

1. **Phase 1 timing** — Cut scope; May 31 non-negotiable. A late system means HOTO starts with no digital trail. That trail cannot be reconstructed retroactively.

2. **President adoption** — The "My Actions" mobile screen must be so simple Bal Reddy prefers it. Tested in the pre-launch walkthrough, not assumed.

3. **RBAC correctness** — If the role change UI silently fails (existing bug), or if features show for roles that shouldn't have them, the audit trail is meaningless and approvals cannot be trusted. Fix the `user_roles` constraint on Day 1; test every role's feature visibility before go-live.

---

*Document Version 3.1 · Revised May 2026 — Full RBAC Management + Feature Permission System*  
*Changes from v3: Added Module 0 (User & Role Management); invite-only registration; committee election bulk update; member deactivation; auto-reassignment; feature registry with locked/unlocked features; runtime permission resolution; UI enforcement pattern; admin permissions UI at /portal/admin/permissions; per-user feature overrides; fixed user_roles unique constraint bug; updated implementation plan (Days 1-4 now include RBAC infrastructure); RBAC risk register section added; pre-launch checklist expanded*  
*Based on: Registered Byelaws TG/RRD/MACS/2026-15/FOW & M · Ascenza HOTO Scope · Committee Q&A · Risk Analysis · RBAC Requirements*  
*Next review: Post-Phase 1 go-live (June 2026)*
