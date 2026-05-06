# UTA MACS — HOTO & Vendor Management Platform Design
## v3 — Risk-Hardened Architecture, Data Model, UX & Implementation Plan

**Society:** Urban Trilla Apartment Owners Mutually Aided Cooperative Maintenance Society Limited  
**Registration No:** TG/RRD/MACS/2026-15/FOW & M (registered 10-02-2026)  
**Location:** SY NO:425/2/1, Kondakal Village, Shankarpally Mandal, Rangareddy District, Telangana  
**Builder (Promoter):** Ankura Homes | **HOTO Consultant:** Ascenza Global Infra Care Pvt Ltd  
**HOTO Start Date:** June 1, 2026 | **Maintenance Tracking From:** May 1, 2025  
**Document Version:** 3.0 — May 2026 (post risk analysis; all mitigations incorporated)

---

## Table of Contents

1. [What We Are Building and Why](#1-what-we-are-building-and-why)
2. [Byelaw Governance Rules Hardcoded into the System](#2-byelaw-governance-rules-hardcoded-into-the-system)
3. [System Architecture](#3-system-architecture)
4. [Infrastructure Resilience Design](#4-infrastructure-resilience-design)
5. [Module 1 — HOTO Management](#5-module-1--hoto-management)
6. [Module 2 — Snag List Management](#6-module-2--snag-list-management)
7. [Module 3 — Vendor Evaluation & Selection](#7-module-3--vendor-evaluation--selection)
8. [Module 4 — Financial Tracking](#8-module-4--financial-tracking)
9. [Module 5 — Formal Notice Generation](#9-module-5--formal-notice-generation)
10. [Workflow Engine & Approval Delegation](#10-workflow-engine--approval-delegation)
11. [Non-Tech User Experience Specification](#11-non-tech-user-experience-specification)
12. [Dashboard & UX Design](#12-dashboard--ux-design)
13. [Git Storage Strategy](#13-git-storage-strategy)
14. [Data Model](#14-data-model)
15. [Security & Privacy Compliance](#15-security--privacy-compliance)
16. [Data Migration Sprint](#16-data-migration-sprint)
17. [Role-Based Access Control](#17-role-based-access-control)
18. [Document Management](#18-document-management)
19. [Scope Boundary](#19-scope-boundary)
20. [Phase-wise Implementation Plan](#20-phase-wise-implementation-plan)
21. [Comprehensive Risk Register](#21-comprehensive-risk-register)

---

## 1. What We Are Building and Why

Urban Trilla MACS has 136 units (40-50 currently occupied), 14 committee members, and is entering the most consequential phase of a cooperative society — the Handover/Takeover from builder Ankura Homes. The HOTO process starts June 1, 2026, has a 45-day Ascenza-led audit timeline, and is expected to span 2-3 months depending on builder responsiveness.

**The problem today:** All evidence, decisions, communications, and tracking live in WhatsApp messages, personal emails, Google Drive folders, and physical files. The two most senior decision-makers (President Bal Reddy and Working President) are non-technical users who are comfortable with WhatsApp. For the system to succeed, it must be simpler than a WhatsApp group in terms of mental load.

**The three core pillars (unchanged):**
1. **Radical simplicity** — President and Working President can use it without training
2. **Complete auditability** — every action permanently recorded; nothing disappears
3. **Byelaw compliance** — governance rules hardcoded, not configurable

**What v3 adds over v2 — mitigations baked into the design:**

| Risk from v2 Analysis | How v3 Design Responds |
|---|---|
| Vercel 10s timeout kills PDF | Async PDF generation with job queue; Vercel Pro before HOTO |
| GitHub API limits on bulk upload | `upload_queue` table; cron-processed batches; never direct browser upload |
| GitHub token silent failure | `github_api_log` + health-check endpoint + Resend alert on failure |
| Supabase free tier pauses DB | Cron ping every 6 days; upgrade path documented |
| President doesn't adopt | Zero-ambiguity mobile screen with exactly 2 buttons; pre-launch walkthrough |
| WhatsApp shortcuts governance | Financial payments require portal approval record — no portal = no payment |
| Snag scope confusion (common vs apartment) | `snag_scope` field; liability disclaimer on individual items |
| RERA document metadata | Server-generated timestamps, SHA-256 hash, source description on every upload |
| Proxy / joint ownership voting disputes | Proxy doc upload linked to vote; joint ownership policy committed to GitHub pre-vote |
| DPDP Act PII compliance | Privacy policy page + consent checkbox + consent timestamp stored |
| Private key exposure | Pre-commit hook blocking key commit; quarterly rotation policy |
| Corpus fund overdraft | Server-side balance check; payment API rejects if balance insufficient |
| Builder SLA drift | SLA date on every builder item; escalation cron at 7/14/30 days overdue |
| Phase 1 too late for June 1 | Emergency sprint plan: minimum viable system live May 31 |
| Committee turnover mid-HOTO | All assignments are role-based, not person-based; orphaned items auto-escalate |
| Historical data stuck on WhatsApp | Dedicated data migration sprint before go-live; CSV bulk import tool |
| Scope creep from residents | Written scope boundary document committed to governance-data repo |
| Architecture bus-factor | Non-developer runbook written before go-live |

---

## 2. Byelaw Governance Rules Hardcoded into the System

These are legal requirements under registered Byelaws (Reg No: TG/RRD/MACS/2026-15/FOW & M). Each rule is cited with the exact Byelaw section. They are not configurable by any admin.

### 2.1 Voting Rules

| Rule | Byelaw Reference | System Implementation |
|---|---|---|
| One apartment = one vote | **§4.16** "one Apartment one vote basis" | Each member gets exactly 1 vote; no weighting by role |
| Cannot vote if >90 days maintenance arrears | **§4.6** | System checks `payment_status` before showing vote button; blocks if `defaulter_90d` |
| Board decisions by majority vote | **§7.16(c)** | Simple majority of votes cast |
| President has casting vote on tie | **§7.16(c) & §8.1** | If tied, President gets deciding vote; logged permanently with byelaw citation |
| Voting method = formal poll | **§7.9(a)** | Portal voting = digital equivalent of formal poll |
| Board quorum = simple majority of directors | **§7.16(a)** | With 14 directors, minimum 8 must vote for quorum |
| Member can authorize family via registered PoA | **§4.16** | PoA field in member profile; admin must upload notarized PoA document before activation |
| Joint ownership (husband + wife on title) | Policy derived from §4.16 | First named owner votes by default; can submit notarized proxy. Policy published in governance-data *before* first vote. |

### 2.2 Decision Approval Chain

| Scenario | Byelaw Reference | System Rule |
|---|---|---|
| All HOTO/vendor approvals require dual sign-off | **§8.1** (President general control) + **§8.3** (Secretary implements) | Both President AND Secretary/Gen Secretary must approve |
| President absent (planned, >7 working days) | **§8.2** | Admin sets delegation → VP. All VP actions flagged "Acting per §8.2" |
| President absent (unplanned/urgent) | **§8.2** | VP may act immediately; flagged for President review on return |
| Secretary absent (planned) | **§8.4** | Joint Secretary takes all Secretary functions; admin activates delegation |
| Both President and VP unavailable | None | System freezes approval gates; shows "Approval chain unavailable — contact admin" |

### 2.3 Financial Authority Limits

| Authority | Limit | Byelaw Reference | System Rule |
|---|---|---|---|
| Secretary (urgent remedial) | Up to ₹10,000/- | **§9.11(a)** | API allows Secretary approval ≤₹10K; rejects above |
| President (urgent remedial) | Up to ₹20,000/- | **§9.11(a)** | API allows President approval ≤₹20K; rejects above |
| Board of Directors | Up to ₹50,000/- | **§9.11(b)** | Requires Board vote with quorum before payment is authorized |
| Beyond ₹50,000/- | General Body required | **§9.11(b)** | API blocks payment; shows "Requires General Body Meeting approval" |
| All payments >₹10,000/- | Must be electronic | **§9.11(c)** | System records payment mode; warns if non-electronic indicated |
| Cash payments | Prohibited | **§5.3(p) & §9.1** | Cash option removed from all screens entirely |
| **Corpus fund overdraft** | Prohibited (policy) | Financial control | Server-side: `current_balance >= payment_amount` enforced at API; never client-side |

### 2.4 Conflict of Interest

| Rule | Byelaw Reference | System Implementation |
|---|---|---|
| Director must not participate where personally interested | **§7.16(b)** | Conflict flag before every vote; recuse button; recusal permanent and logged |
| Office bearers receive no remuneration from society funds | **§3.4(b)** | Any vendor where committee member has disclosed interest is flagged on vendor card |

### 2.5 Transparency & Records

| Rule | Byelaw Reference | System Implementation |
|---|---|---|
| Minutes within 7 days of Board meeting | **§7.16(e)** | Upload tracker; dashboard flag if >7 days since meeting |
| Members can inspect records with 10 days notice | **§5.4** | Document request feature in portal |
| Financial statements by 30th September | **§9.3** | Dashboard reminder from September 1 |
| Defaulter list published monthly | **§9.6** | Auto-generated; sent to committee first Sunday of each month |
| Data retention: 10 years | Requirement | Git history = permanent; no delete operations on audit data |
| Byelaw ambiguity resolution | Policy | Every resolution/approval has a `governance_notes` text field for interpretation; quorum attendee list mandatory |

### 2.6 Defaulter Rules

| Rule | Byelaw Reference | System Flag |
|---|---|---|
| 2 months arrears = Defaulting Member | **§6.36** | Yellow flag at 60 days; committee notified |
| 3 months arrears = services can be denied | **§6.37** | Red flag at 90 days; 7-day notice countdown triggered |
| 18% per annum interest on late payments | **§19(e)** | Auto-calculated from due date; shown on maintenance record |
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
│  │  /portal/hoto/          HOTO Checklist                        │    │
│  │  /portal/snags/         Snag List (Ascenza punch list)        │    │
│  │  /portal/vendors/       Vendor Evaluation                     │    │
│  │  /portal/finances/      Maintenance & Fund Tracking           │    │
│  │  /portal/notices/       Formal Notice Generator               │    │
│  │  /portal/dashboard      Governance Dashboard                  │    │
│  └──────────────────────┬───────────────────────────────────────┘    │
└─────────────────────────┼────────────────────────────────────────────┘
                          │ HTTPS
             ┌────────────▼────────────┐
             │  Vercel Serverless       │  ← Vercel Pro (14 min timeout)
             │  /api/v1/               │    before HOTO starts
             └────┬─────────────┬──────┘
                  │             │
     ┌────────────▼──┐   ┌──────▼──────────────────────┐
     │  Supabase      │   │  GitHub (governance-data)    │
     │  PostgreSQL    │   │  Private repo                │
     │                │   │                              │
     │  - Auth        │   │  Every write = audit trail   │
     │  - Fast lists  │   │  Documents (no storage limit)│
     │  - Roles       │   │  JSON records + photos       │
     │  - Upload queue│   │  Permanent history           │
     │  - API log     │   │  10-year retention           │
     │  - Job queue   │   │                              │
     └────────────────┘   └──────────────────────────────┘
             │
     ┌───────▼────────┐
     │  Resend         │  ← Email: notifications,
     │  (email)        │    alerts, weekly digest,
     │                 │    health-check failures
     └─────────────────┘
```

### 3.2 Two Repositories

```
utamacs/utamacs-website      ← Code (public — portal.utamacs.org)
utamacs/governance-data      ← Private data repo (documents + audit trail)
```

### 3.3 Key Design Constraints Carried Through Architecture

1. **No direct browser-to-GitHub upload.** All file uploads go: Browser → API route → `upload_queue` table → cron job → GitHub. This prevents rate-limit spikes and gives us retry logic.

2. **No PDF generation in the browser request cycle.** PDF generation: Browser → API saves job to `pdf_generation_jobs` → returns job_id → browser polls `/api/pdf/status/[job_id]` → cron processes → signed download URL returned.

3. **All files in GitHub, never Supabase storage.** Supabase storage limit is 500MB (free tier). GitHub private repo handles gigabytes with no additional cost.

4. **Every consequential action has a server-side guard.** Financial limits, voting eligibility, quorum check, balance check — all enforced in API routes, not in client-side JavaScript.

### 3.4 Committee Structure Mapped to Roles

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

---

## 4. Infrastructure Resilience Design

This section is new in v3. These are cross-cutting concerns that apply to all modules.

### 4.1 GitHub Upload Queue

**Problem:** Direct browser-to-GitHub upload collapses under bulk sessions. Batch uploads of 50+ photos during a site inspection will hit the 5,000 requests/hour GitHub API limit.

**Solution:** All uploads are queued and processed asynchronously.

```
Browser uploads file
  → POST /api/documents/upload
  → File stored temporarily in Vercel /tmp (max 50MB)
  → Record inserted into upload_queue (status: PENDING)
  → API returns { queue_id, estimated_seconds }
  → Browser polls GET /api/documents/status/[queue_id]
  → Cron job (/api/cron/process-uploads) runs every 60s
    → Takes 30 PENDING items (rate-safe)
    → Commits to GitHub via GitHub App
    → Updates upload_queue status: COMPLETED | FAILED
    → On COMPLETED: inserts record into documents table
    → On FAILED (3 retries): status = PERMANENTLY_FAILED; alert email sent
```

**Constraints enforced at upload:**
- Max file size: 5MB per file (enforced client-side AND server-side)
- Accepted types: PDF, JPG, PNG, XLSX, CSV, DOCX (no video)
- For video evidence: a `video_url` field accepts YouTube / Drive links only
- Blocked explicitly with clear error: "Video files cannot be uploaded. Paste a YouTube or Google Drive link instead."

### 4.2 GitHub API Health Monitor

**Problem:** GitHub App installation token expires hourly. Rotation bugs or accidental App uninstall cause silent upload failures.

**Solution:** Active health monitoring with alerting.

```
Every 15 minutes (cron):
  → POST /api/cron/github-health
  → Attempt a test write to governance-data/_meta/health-check.json
  → Log result to github_api_log (success / failure / latency_ms)
  → On failure: send Resend email to Secretary + admin
    Subject: "URGENT: Governance data storage is unavailable"
  → On 3 consecutive failures: send SMS via fallback (future)

Every 6 days (cron):
  → GET /api/cron/supabase-ping
  → Simple Supabase query to prevent free-tier pause
  → Log result to github_api_log
```

### 4.3 Async PDF Generation

**Problem:** Vercel serverless functions on Hobby plan timeout at 10 seconds. pdfmake cold start + GitHub logo fetch + multi-page letter generation exceeds this.

**Solution:** Background job pattern.

```
User clicks "Generate PDF"
  → POST /api/pdf/generate { letter_id, template }
  → Job inserted into pdf_generation_jobs (status: QUEUED)
  → Returns { job_id }
  → UI shows spinner + "Generating your letter..."
  → Cron runs every 30s → picks up QUEUED jobs → generates PDF
  → Stores PDF in GitHub at notices/[type]/[id]/letter-[date].pdf
  → Updates pdf_generation_jobs: status DONE, github_path set
  → UI polls, receives DONE, shows [Download Letter] button

Failure handling:
  → After 3 attempts: status = FAILED
  → Error stored in pdf_generation_jobs.error_message
  → UI shows: "Generation failed. Please try again or contact admin."
```

**Immediate action before HOTO:** Upgrade to Vercel Pro for 14-minute timeout as a belt-and-suspenders measure. The async pattern is the primary fix; Vercel Pro is the safety net.

### 4.4 Supabase Database Keep-Alive

Supabase free tier pauses databases inactive for 7 days. A cron ping every 6 days prevents this:

```
/api/cron/supabase-keepalive
  → SELECT 1 FROM profiles LIMIT 1
  → Log: { timestamp, latency_ms, success }
```

If upgrading to Supabase Pro before HOTO: pause this cron and document the upgrade in the runbook.

### 4.5 Non-Developer Operations Runbook

Before go-live, a `RUNBOOK.md` is committed to the governance-data repo covering:

- How to add a new committee member
- How to reset a member's password
- How to activate/deactivate delegation
- How to restart the app if Vercel shows errors (re-deploy from GitHub)
- How to rotate the GitHub App private key
- How to check upload queue status
- Who to contact if the system is down (implementer contact)

Written for a non-developer. Validated by asking the Secretary to follow it without assistance.

---

## 5. Module 1 — HOTO Management

### 5.1 HOTO Scope (Ascenza-Aligned Categories)

| Category | Items | Ascenza Scope Section |
|---|---|---|
| Statutory Compliance | Land docs, GHMC approval, Occupancy Certificate, NOCs, Fire NOC, regularisation | Statutory Compliance Due Diligence |
| Technical - Electrical | LT/HT systems, DG sets, earthing, lightning arrestors, UPS, common lighting | Technical Due Diligence |
| Technical - Lifts | 4 elevators (3 blocks), commissioning reports, technical audit, AMC transfer | Technical Due Diligence |
| Technical - Fire & Safety | Hydrant system, sprinkler system (incl. sample flat check), fire extinguishers, hoses, fire doors | Security & Fire Safety Due Diligence |
| Technical - HVAC & Ventilation | Mechanical ventilation, pressurization, exhaust, fresh air systems | Technical Due Diligence |
| Technical - Water & Plumbing | DWS/SWS/FWS, STP, WTP, boreholes, hydro-pneumatic, dewatering | Technical Due Diligence |
| Technical - Security & IT | CCTV, access control, boom barriers, intercom, internet/OFC/TV cabling | Technical Due Diligence |
| MEP - Miscellaneous | Solar panels, gas bank, BMS, Elmeasure, PA system, fountains | Technical Due Diligence |
| AMC Due Diligence | All existing AMC contracts — status, scope, transfer to association | AMC Due Diligence |
| Snagging | Civil, seepage, exterior, common areas, basements, terrace, club house | Snagging of Common Areas |
| Asset/Inventory | Asset register validation vs actuals, parking allocations, spare keys | Asset/Inventory Verification |
| Financial Handover | Corpus fund transfer (CA certified), maintenance corpus, builder dues | (Custom — see Module 4) |
| Pending Works | Snagging items committed by builder, timelines, completion | (Tracked in Snag Module) |

### 5.2 HOTO Item State Machine

```
NOT_STARTED
    │
    ▼
IN_PROGRESS ──────── (builder delays / comments logged here)
    │
    ▼
EVIDENCE_UPLOADED ── (≥1 document uploaded; required docs checked)
    │
    ▼
UNDER_REVIEW ──────── (committee reviewing evidence)
    │
    ▼
PENDING_PRESIDENT ── (Secretary submits for President approval)
    │
    ▼
PENDING_SECRETARY ── (President approved; now needs Secretary)
    │
    ▼
APPROVED ───────────── (both approved; auto-set by system)
    │
    ▼
COMPLETED ──────────── (physical handover confirmed)
    │
    └── DISPUTED ──── (reopen path if deficiency found post-completion)
              │
              ▼
         UNDER_REVIEW (new approval cycle begins)
```

**State transition role rules:**
- `NOT_STARTED → IN_PROGRESS`: Any executive or above
- `IN_PROGRESS → EVIDENCE_UPLOADED`: Any executive or above (requires ≥1 document; hard gate)
- `EVIDENCE_UPLOADED → UNDER_REVIEW`: Any executive or above
- `UNDER_REVIEW → PENDING_PRESIDENT`: Secretary / Joint Secretary only
- `PENDING_PRESIDENT → PENDING_SECRETARY`: President (or VP if delegated per §8.2)
- `PENDING_SECRETARY → APPROVED`: Secretary (or Joint Secretary if delegated per §8.4) — cannot be the same person who set PENDING_PRESIDENT
- `APPROVED → COMPLETED`: President or Secretary only
- `COMPLETED → DISPUTED`: President or Secretary — requires written reason (stored in `governance_notes`)
- `DISPUTED → UNDER_REVIEW`: Auto-transition; new approval cycle

### 5.3 Builder SLA Escalation (New in v3)

Every HOTO item with builder involvement has a `builder_sla_date`. A cron job checks daily:

```
Days overdue = today - builder_sla_date (when status ≠ COMPLETED)

7 days overdue:
  → Email to committee: "[HOTO-042] Lift AMC Transfer is 7 days overdue"
  → Status tag: BUILDER_DELAYED

14 days overdue:
  → Email with URGENT flag
  → Dashboard shows red countdown

30 days overdue:
  → System auto-generates draft formal notice (Module 5 template)
  → Notifies Secretary: "Draft notice ready for your review — [View & Send]"
  → Status: RERA_ELIGIBLE (if item is marked rera_escalation_eligible)
```

This means the builder cannot be forgotten just because the committee is busy — the system actively escalates without anyone having to remember.

### 5.4 HOTO Item Schema

```json
{
  "item_id": "HOTO-2026-042",
  "ascenza_category": "Technical - Lifts",
  "title": "Lift No. 2 (Block B) AMC Transfer to Association",
  "description": "Transfer the KONE lift AMC from Ankura Homes to association name.",
  "builder_commitment": "Transfer within 30 days of possession",
  "builder_contact": "Ms. Srilatha / Ms. Saritha — Ankura Homes",
  "priority": "HIGH",
  "status": "IN_PROGRESS",
  "builder_sla_date": "2026-07-01",
  "days_overdue": 0,
  "deadline": "2026-08-01",
  "responsible_role": "treasurer",
  "responsible_user_id": "user-uuid-treasurer",
  "dependencies": ["HOTO-2026-040"],
  "rera_escalation_eligible": true,
  "required_documents": [
    { "name": "Original KONE AMC Contract", "required": true, "uploaded": false },
    { "name": "NOC from Builder for Transfer", "required": true, "uploaded": false },
    { "name": "New AMC Agreement in Association Name", "required": true, "uploaded": false }
  ],
  "governance_notes": "",
  "notice_sent": false,
  "notice_date": null,
  "documents": [],
  "comments": [],
  "approvals": { "president": null, "secretary": null },
  "github_path": "hoto/Technical-Lifts/HOTO-042/item.json"
}
```

**Key changes from v2:**
- `responsible_role` added alongside `responsible_user_id` — if person leaves, role persists; new person in that role takes over automatically
- `builder_sla_date` added — drives escalation cron
- `governance_notes` added — for byelaw interpretation notes; quorum attendee lists; dispute reasons
- `days_overdue` computed field stored in Supabase for fast filtering

### 5.5 Evidence Upload Rules

- PDFs, JPG, PNG, XLSX, CSV, DOCX — accepted
- Max 5MB per file (enforced server-side, not just client-side)
- Video: rejected at upload with message; `video_url` field for YouTube/Drive links
- Every uploaded document gets: uploader ID (server-side), server timestamp (not client clock), SHA-256 hash of file, source description (free text: "Received from Ankura Homes on 2026-04-15")
- Documents are queued via `upload_queue`; UI shows "Upload in progress" status

### 5.6 Assignment Orphan Prevention (New in v3)

When a committee member's role changes or they are marked inactive:
1. System queries all HOTO items where `responsible_user_id` = that person
2. Auto-reassigns to the *role* owner: if `responsible_role = 'treasurer'`, new treasurer gets the item
3. If the role itself is vacant: escalates to Secretary
4. All reassignments logged in `audit_log` with reason "Auto-reassigned due to member role change"

---

## 6. Module 2 — Snag List Management

### 6.1 Snag Scope Classification (New in v3)

Every snag item must declare its scope:

| `snag_scope` | Meaning | Liability |
|---|---|---|
| `COMMON_AREA` | Corridor, terrace, basement, lobby, clubhouse, external | Society responsibility post-HOTO |
| `INDIVIDUAL_APARTMENT` | Inside a specific flat | Owner's responsibility — builder's obligation to that owner |

For `INDIVIDUAL_APARTMENT` snags: a non-removable banner displays:
> "UTA MACS is logging this as a service to the owner. The Society is not a party to this snag's resolution. This item is between the flat owner and Ankura Homes."

This prevents residents from using the platform to create liability for the Society.

Only `COMMON_AREA` snags are included in formal HOTO documentation and notices to the builder. `INDIVIDUAL_APARTMENT` snags are tracked as a courtesy record only.

### 6.2 Snag Item States

```
OPEN → IN_PROGRESS → BUILDER_NOTIFIED → BUILDER_COMMITTED → RESOLVED → VERIFIED_CLOSED
                                                                   └── REOPENED
```

### 6.3 Snag Item Features

- **Create**: Any committee member; must declare `snag_scope`, category, location, severity
- **Update**: Any committee member; description, photos, severity, scope
- **Delete**: Admin only (President/Secretary); soft-delete with mandatory `deletion_reason`; permanently logged
- **Mark RESOLVED**: Committee member
- **Mark VERIFIED_CLOSED**: President or Secretary only
- **REOPEN**: President or Secretary — requires written reason

### 6.4 Snag Item Schema

```json
{
  "snag_id": "SNAG-2026-0089",
  "snag_scope": "COMMON_AREA",
  "category": "Civil",
  "subcategory": "Seepage",
  "location": "Block B, Floor 3, Common Corridor",
  "description": "Water seepage from roof visible on corridor ceiling, approx. 2 sq ft area",
  "severity": "MEDIUM",
  "status": "BUILDER_NOTIFIED",
  "reported_by": "user-uuid",
  "reported_date": "2026-06-15",
  "builder_committed_date": "2026-07-01",
  "builder_sla_days_overdue": 0,
  "photos": [],
  "video_url": null,
  "ascenza_reference": "Ascenza-Report-Snag-145",
  "notice_sent": true,
  "notice_date": "2026-06-20",
  "formal_notice_doc": "notices/builder/notice-snag-089.pdf",
  "resolution_notes": null,
  "verified_by": null,
  "deleted": false,
  "deletion_reason": null,
  "github_path": "snags/civil/SNAG-089/item.json"
}
```

### 6.5 Bulk Import from Ascenza Excel

The system supports bulk creation from Ascenza's standard punch-list format:
- CSV/XLSX upload via admin panel
- Column mapping screen (maps Ascenza column headers to system fields)
- Preview before import (shows first 5 rows for validation)
- Import creates `upload_queue` entries for all associated photos (zipped folder supported)
- All imported items default `snag_scope = COMMON_AREA`; individual scope change is manual

---

## 7. Module 3 — Vendor Evaluation & Selection

### 7.1 Active Vendor Evaluations

| # | Category | Known Vendors | Status |
|---|---|---|---|
| 1 | Property Management Platform | MyGate, NoBroker | Quotes received |
| 2 | Accounting/Finance Tool | Mandix, Hari | Quotes received |
| 3 | Facility Management | Kapston, Kapil | Quotes received |
| 4 | Legal Counsel | TBD | Evaluation |
| 5 | Security Vendor | TBD | Evaluation |

### 7.2 Voting Model (Byelaw §4.16 — One Apartment One Vote)

Each director gets exactly 1 vote. No role weighting. Quorum = 8 of 14 (§7.16(a)). Tie → President casting vote (§7.16(c)). All votes visible (transparent per byelaw spirit).

### 7.3 Proxy and Joint Ownership (New in v3)

**Proxy voting:**
- Member can authorize another via registered PoA (§4.16)
- Admin must upload the notarized PoA document to the voter's profile before the vote opens
- Proxy authorization is recorded in `proxy_authorizations` table
- Proxy doc is linked to the specific vote record — immutable once cast

**Joint ownership (husband + wife on title):**
- Policy: First named owner votes by default
- Alternative: submit notarized proxy to second named owner
- This policy is committed as `_meta/voting-policy.md` in governance-data *before* the first vote, with its commit timestamp serving as proof it predated any vote challenge

### 7.4 Conflict of Interest (§7.16(b))

Before any voting opens, each director must declare:
- "I have no personal interest in any vendor listed in this evaluation" → proceed to vote
- "I have an interest in [Vendor Name] — recuse me" → excluded from vote for this requirement permanently; logged in audit trail

If a committee member is a director or employee of a vendor being evaluated, the system flags this based on the vendor profile data.

### 7.5 Scope Document Commitment

Before the first vote is opened, the implementer commits `_meta/scope-v1.md` to governance-data repo defining what the platform does and does not cover. This is the formal scope boundary (see Section 19). The commit timestamp makes it tamper-evident.

### 7.6 Vendor Decision Record (Permanent, Immutable)

```json
{
  "decision_id": "DEC-2026-001",
  "decided_at": "2026-06-15T16:00:00Z",
  "selected_vendor": "VND-001-A",
  "selection_reason": "Full committee text of why selected",
  "vote_summary": {
    "total_eligible_voters": 14,
    "total_votes_cast": 12,
    "quorum_met": true,
    "quorum_required": 8,
    "results": { "VendorA": 8, "VendorB": 4 }
  },
  "recusals": ["user-uuid-member-with-conflict"],
  "rejected_vendors": [
    { "vendor": "VendorB", "rejection_reason": "Full committee text" }
  ],
  "president_approval": { "by": "user-uuid", "at": "...", "note": "..." },
  "secretary_approval": { "by": "user-uuid", "at": "...", "note": "..." },
  "byelaw_compliance_note": "Decision per §7.16(c); quorum §7.16(a) met (12/14 voted)",
  "github_commit": "immutable-sha",
  "can_be_modified": false
}
```

Once written to GitHub and the commit SHA stored, this record is considered sealed. Any dispute after this point starts a new `decision-v2.json` — the v1 is never deleted or modified.

### 7.7 Post-Selection Tracking

- Contract upload with key terms (start date, end date, renewal clause, exit clause)
- Renewal reminder: email 90 days before expiry
- Monthly performance rating by committee (Good / Needs Improvement / Poor)
- Complaint log against vendor
- Performance history displayed on vendor card

---

## 8. Module 4 — Financial Tracking

This is a lightweight tracking module, not a full accounting system. It supports the HOTO financial items and ongoing governance.

### 8.1 What Gets Tracked

```
Maintenance Collection (from May 1, 2025)
├── Per flat: flat number, owner, amount, date paid, payment mode
├── Month-wise summary
├── Defaulter tracking (byelaw §6.36, §4.6)
└── Interest auto-calculated (18% p.a. per §19(e))

Corpus Fund
├── Received from builder (₹1,36,000 per §4.11 share capital)
├── Interest earned (kept as corpus per §4.11)
├── Approved uses (with Board resolution reference)
└── Current balance (always displayed; used in overdraft check)

Expenses
├── Each expense: amount, payee, date, approved by, payment mode, byelaw authority cited
├── Sanction authority auto-applied and stored (§9.11)
└── Balance check BEFORE approval (server-side: balance ≥ amount required)

Builder Dues Tracker
├── Corpus fund owed by builder
├── Maintenance corpus from builder
└── Committed pending works with SLA dates
```

### 8.2 Corpus Fund Overdraft Prevention (New in v3)

Every payment approval call hits this check server-side:

```typescript
// In /api/finances/approve-payment
const { data: balance } = await supabase
  .rpc('get_corpus_balance', { p_society_id: society_id });

if (balance < amount) {
  return Response.json({
    error: 'INSUFFICIENT_BALANCE',
    message: `Available balance: ₹${balance}. Requested: ₹${amount}. Payment cannot be approved.`,
    current_balance: balance
  }, { status: 422 });
}
```

This check is **never client-side.** The UI shows the balance for user convenience, but the API enforces it regardless of what the client sends.

### 8.3 Defaulter Tracking

| Day Threshold | Action | Byelaw |
|---|---|---|
| 30 days overdue | Reminder email sent to member | - |
| 60 days overdue | "Defaulting Member" flag; committee notified; interest starts accruing | §6.36 |
| 90 days overdue | Vote rights suspended; `payment_status = defaulter_90d` | §4.6 |
| 90+ days | 7-day notice countdown begins; notice template auto-populated | §6.37 |

Monthly defaulter list is auto-generated on the first Sunday of each month and emailed to the committee. Published on the notice board per §9.6.

---

## 9. Module 5 — Formal Notice Generation

This module integrates with the existing letter generation system built in the portal (`/portal/letters/`).

### 9.1 Notice Types and Triggers

| Notice | Trigger | Who Reviews | Next Step |
|---|---|---|---|
| HOTO Item 7-day Reminder | Item overdue 7 days | Secretary | Send or edit |
| HOTO Item 14-day Reminder | Item overdue 14 days | Secretary | Send — escalation path |
| HOTO Legal Notice (auto-draft) | Item overdue 30 days (RERA eligible) | Secretary + President | Both approve before send |
| Snag Rectification Notice | Snag open past builder committed date | Secretary | Send or edit |
| Maintenance Defaulter Notice | 90+ days arrears + 7 days warning | Secretary | Post on flat door + notice board |
| RERA Complaint Package | Post HOTO Legal Notice with no response | Secretary + President | External filing — exports all evidence |

### 9.2 Auto-Draft Mechanism (New in v3)

When the SLA cron marks an item as 30 days overdue:
1. System calls the letter generation API with pre-filled data (item title, builder contact, dates, evidence list)
2. Draft letter is saved to GitHub at `notices/drafts/[date]/[item-id]-draft.pdf`
3. Supabase record created: `notices` table with `status = DRAFT`
4. Email to Secretary: "A draft formal notice for HOTO-042 is ready for your review. [Review Draft] [Send Now] [Discard]"

The Secretary reviews, edits if needed, then sends. Sending updates the notice record to `SENT` with send timestamp. No manual letter creation needed.

### 9.3 RERA Escalation Tracker

For items marked `rera_escalation_eligible`:
- Tracks: Notice sent → Response date / No response → RERA filing status
- Evidence package: auto-assembled ZIP of all documents, comments, notice copies, photo evidence
- Status: `MONITORING | NOTICE_SENT | RERA_ELIGIBLE | RERA_FILED | RESOLVED`

---

## 10. Workflow Engine & Approval Delegation

### 10.1 Delegation Chain (Byelaw Compliant)

```
Default Approval Chain:
  President + Secretary (both required, in either order)

If President absent (planned, >7 working days — §8.2):
  Admin sets: "President delegation active → Vice President"
  All VP actions tagged: "Acting as President per §8.2"
  Delegation stored in approval_delegations table with start/end date

If President unexpectedly unavailable (urgent — §8.2):
  VP may act immediately
  All actions tagged: "Acting on behalf of absent President per §8.2"
  President reviews and acknowledges on return (audit flag)

If Secretary/Gen Secretary absent (planned — §8.4):
  Admin activates Joint Secretary delegation
  All Joint Secretary actions tagged: "Acting as Secretary per §8.4"

If both President and VP unavailable:
  System shows: "Approval chain unavailable — contact admin"
  No approvals can be given; items stay at PENDING_PRESIDENT
  Admin must resolve by activating next delegation
```

### 10.2 Delegation Management UI

Admin-only at `/portal/admin/delegation`:

```
ACTIVE DELEGATIONS

[President] Bal Reddy
  Currently: ACTIVE — no delegation
  [+ Set Delegation]

[Secretary] [Name]
  Currently: ACTIVE — no delegation
  [+ Set Delegation]

─────────────────────────────────────────────
DELEGATION HISTORY

Jun 15–Jun 22, 2026
  Secretary → Joint Secretary (Planned)
  Reason: Medical leave
  All 3 approvals during this period are tagged "per §8.4"
```

### 10.3 Notification Design

| Event | Recipients | Subject Line | Priority |
|---|---|---|---|
| New HOTO item created | All committee | "New HOTO item: [title]" | Normal |
| Status changed | Responsible member + approvers | "Update: [item] is now [status]" | Normal |
| Pending President approval | President (or VP if delegated) | "ACTION REQUIRED: [item] needs your approval" | High |
| Pending Secretary approval | Secretary (or Joint Sec if delegated) | "ACTION REQUIRED: [item] needs your approval" | High |
| Vote opened | All eligible voters | "VOTE OPEN: [vendor category] — closes [date]" | High |
| Voting closes in 48 hours | Non-voters only | "REMINDER: Your vote on [vendor] closes in 48 hours" | High |
| Builder SLA overdue 7 days | Committee | "OVERDUE: [item] builder deadline was [date]" | High |
| Builder SLA overdue 30 days | Secretary + President | "Draft formal notice ready for [item]" | High |
| Maintenance default 60 days | Treasurer + Secretary | "60-day default: Flat [number] — [owner name]" | High |
| GitHub health check failed | Secretary + implementer | "URGENT: Governance storage unavailable" | Critical |
| Weekly digest | All committee | "HOTO Week [N] Summary" | Low |

Emails sent via Resend (existing integration). Domain utamacs.org must be verified in Resend DNS before notifications can be sent.

---

## 11. Non-Tech User Experience Specification

This section is new in v3. It specifies exactly what Bal Reddy (President) and the Working President see.

### 11.1 Design Principle

The non-tech user screen has exactly one job: show what action is needed right now, and make taking that action require one tap.

**Rules for non-tech screens:**
- Never show a table with more than 3 columns
- Never show a list of more than 5 items without a "load more"
- Status = one word + one color: Approved (green), Pending (orange), Rejected (red), Done (blue)
- Action buttons minimum 56px tall
- All text minimum 16px
- No icons without a text label next to them
- English only (no abbreviations, no acronyms)

### 11.2 My Actions Screen (Default View for Non-Tech Users)

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
│  │  Your approval completes this item.     │   │
│  │                                         │   │
│  │  [Read the Details]   [APPROVE]         │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│  ┌─────────────────────────────────────────┐   │
│  │  🟠  VOTE                                │   │
│  │  Choose Property Management Platform    │   │
│  │  Voting closes June 10. 6 of 14 voted.  │   │
│  │                                         │   │
│  │  [See Options & Vote]                   │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│  ✅  Nothing else needs your attention today    │
│                                                 │
├────────────────────────────────────────────────┤
│  [View All HOTO Items]   [View All Snags]       │
└────────────────────────────────────────────────┘
```

### 11.3 Approval Screen (Non-Tech User)

```
┌────────────────────────────────────────────────┐
│  ← My Actions                                  │
│                                                 │
│  Lift No. 2 AMC Transfer (Block B)             │
│                                                 │
│  What is this about?                           │
│  ────────────────────                          │
│  The KONE company service contract for         │
│  Block B's lift needs to move from             │
│  builder Ankura Homes to our association.      │
│                                                │
│  Secretary has approved this.                  │
│  Your approval will complete this step.        │
│                                                │
│  Documents attached (3):                       │
│  📄 KONE AMC Contract  [View]                  │
│  📄 NOC from Builder   [View]                  │
│  📄 New AMC Agreement  [View]                  │
│                                                │
│  ─────────────────────────────────────────     │
│                                                │
│  ┌─────────────────────────────────────────┐  │
│  │           ✅  APPROVE                    │  │
│  │    I confirm this is correct            │  │
│  └─────────────────────────────────────────┘  │
│                                               │
│  ┌─────────────────────────────────────────┐  │
│  │           ❌  NOT YET                    │  │
│  │    I have questions or concerns         │  │
│  └─────────────────────────────────────────┘  │
│                                               │
└───────────────────────────────────────────────┘
```

If "NOT YET" is tapped, a simple text field appears:
```
  What is your concern?
  ┌─────────────────────────────────────┐
  │ [Type your question or concern...]  │
  └─────────────────────────────────────┘
  [Send to Secretary]
```

This is logged as a comment from the President, the item stays at PENDING_PRESIDENT, and the Secretary is notified with the concern.

### 11.4 Pre-Launch Walkthrough Protocol

Before go-live (targeting May 30):
1. Secretary walks through the portal with Bal Reddy using a test HOTO item
2. Bal Reddy performs: reading the detail, tapping APPROVE, seeing the confirmation
3. Bal Reddy performs: seeing a VOTE, reading the options, casting a vote
4. Any confusion noted and fixed before go-live
5. If walkthrough reveals Bal Reddy prefers WhatsApp, offer this interim bridge: Secretary can approve on behalf with explicit consent logged — this is not the goal, but it is better than no record

---

## 12. Dashboard & UX Design

### 12.1 Two Audience Profiles

**Profile A — Non-Tech (President, Working President):**
- "My Actions" is the home screen (not the full dashboard)
- Large text, high contrast, 2-button max per action
- Mobile-first (phone browser)
- Full dashboard is a secondary tab they can explore

**Profile B — Tech-Comfortable (other 12 members):**
- Full dashboard with all progress tiles
- Filtering, sorting, bulk actions
- Detailed timelines, audit logs
- Export to Excel/PDF

### 12.2 Full Dashboard Layout

```
┌──────────────────────────────────────────────────────────────────────┐
│  URBAN TRILLA MACS — Governance Dashboard   [Bal Reddy | Log out]    │
├───────────────────────────┬──────────────────────────────────────────┤
│                           │                                           │
│  YOUR ACTIONS NEEDED      │  HOTO PROGRESS                           │
│  ┌─────────────────────┐  │  ████████████░░░░░ 62%  (Starts 1 Jun)  │
│  │ 🔴 2 items need     │  │  Total: 87 items tracked                 │
│  │    YOUR APPROVAL    │  │  Approved: 12 · In Progress: 38          │
│  │  [View & Approve]   │  │  Not Started: 37                         │
│  └─────────────────────┘  │                                           │
│                           │  SNAG LIST                               │
│  ┌─────────────────────┐  │  ████░░░░░░░░░░░░ 28%  (45/160 closed)  │
│  │ 🟡 3 votes waiting  │  │  Critical open: 12 · Builder delayed: 5  │
│  │    for your input   │  │                                           │
│  │  [Cast Your Vote]   │  │  VENDOR DECISIONS                        │
│  └─────────────────────┘  │  2 of 5 finalised                        │
│                           │  Property Mgmt: ⏳ Voting open           │
│  ✅ Nothing else today    │  Accounting: 📋 Under review             │
│                           │                                           │
│  RECENT ACTIVITY          │  CRITICAL DEADLINES                      │
│  ─────────────────────    │  🔴 Snag #89 (Seepage): 5 days overdue  │
│  Today  Secretary         │  🟡 Lift AMC: 26 days remaining          │
│  approved HOTO-042        │  🟡 Fire NOC: 30 days remaining          │
│  Yesterday  New snag      │                                           │
│  added by Ravi            │  STORAGE HEALTH                          │
│                           │  ✅ GitHub: Connected (last write 4m ago) │
│                           │  ✅ Upload queue: 0 pending               │
└───────────────────────────┴──────────────────────────────────────────┘
```

The "Storage Health" tile (new in v3) gives the Secretary instant visibility into infrastructure status without needing to call the implementer.

### 12.3 Mobile Design

- All pages responsive; works in any Android/iOS browser without app install
- Dashboard collapses to single-column with "My Actions" at top
- Camera button on document upload (takes photo directly from phone)
- Large tap targets (min 56px for primary actions)
- "My Actions" is bookmarkable — non-tech users can bookmark `portal.utamacs.org/portal/my-actions`

---

## 13. Git Storage Strategy

### 13.1 Repository Structure: utamacs/governance-data (Private)

```
utamacs/governance-data/
│
├── README.md                     # Human-readable index with status summary
├── RUNBOOK.md                    # Non-developer operations guide
├── _meta/
│   ├── schema-version.json
│   ├── committee-roster.json     # Current committee + delegation status
│   ├── voting-policy.md          # Joint ownership + proxy policy (committed pre-vote 1)
│   └── scope-v1.md               # Platform scope boundary (committed pre-launch)
│
├── hoto/
│   ├── _index.json               # Lightweight index for fast list loading
│   ├── Statutory-Compliance/
│   │   └── HOTO-001/ ... HOTO-015/
│   │       ├── item.json
│   │       ├── comments.json     # Append-only
│   │       ├── approvals.json
│   │       └── documents/
│   ├── Technical-Lifts/
│   ├── Technical-Electrical/
│   ├── Technical-Fire-Safety/
│   ├── Technical-Water-Plumbing/
│   ├── Technical-Security-IT/
│   ├── Technical-HVAC/
│   ├── MEP-Miscellaneous/
│   ├── AMC-Due-Diligence/
│   ├── Asset-Inventory/
│   └── Financial-Handover/
│
├── snags/
│   ├── _index.json
│   ├── Common-Area/
│   │   ├── Civil/
│   │   ├── Electrical/
│   │   ├── Fire-Safety/
│   │   ├── Security/
│   │   └── Club-House/
│   └── Individual-Apartment/
│       └── (logged for reference; no formal action)
│
├── vendors/
│   ├── _index.json
│   ├── REQ-2026-001-Property-Management/
│   │   ├── requirement.json
│   │   ├── evaluation-criteria.json
│   │   ├── votes.json            # One record per vote cast; append-only
│   │   ├── decision.json         # Written ONCE; immutable
│   │   ├── proxy-authorizations/ # Notarized proxy documents
│   │   ├── mygate/
│   │   ├── nobroker/
│   │   └── apartmentadda/
│   └── REQ-2026-002-Accounting/
│
├── notices/
│   ├── drafts/                   # Auto-generated drafts pending review
│   ├── builder/                  # Sent formal notices to Ankura Homes
│   └── members/                  # Defaulter/maintenance notices
│
├── finances/
│   ├── maintenance/
│   │   └── 2025-05.json ... (monthly)
│   ├── corpus/
│   └── expenses/
│
└── audit/
    └── 2026-06/
        └── 2026-06-01.jsonl      # Append-only, one JSON per line
```

### 13.2 Commit Convention

```
create(HOTO-042): Lift No.2 AMC Transfer — created by Treasurer
upload(HOTO-042): kone-amc-original.pdf [sha:abc123] — Treasurer
comment(HOTO-042): new comment by President
status(HOTO-042): IN_PROGRESS → EVIDENCE_UPLOADED — Treasurer
approve(HOTO-042): President approval [per §8.1] — Bal Reddy
approve(HOTO-042): Secretary approval → status APPROVED
vote(REQ-001): ApartmentAdda — Secretary [8/14 votes cast]
decide(REQ-001): ApartmentAdda selected (12/14 quorum per §7.16)
snag-create(SNAG-089): Block B seepage [COMMON_AREA] — Ravi
snag-close(SNAG-089): verified closed — President
notice-draft(HOTO-042): auto-generated 30-day-overdue notice
notice-sent(HOTO-042): formal notice sent to Ankura Homes — Secretary
health-check: OK [latency:234ms]
```

### 13.3 Immutability Rules

- `decision.json`: written once; re-decisions create `decision-v2.json`; v1 never touched
- `approvals.json`: append-only; no updates
- `audit/*.jsonl`: append-only
- `votes.json`: append-only; cast votes cannot be modified
- `comments.json`: edits add new entry with `edited_at`; original preserved

---

## 14. Data Model

### 14.1 Supabase Tables — Complete Schema

```sql
-- ─────────────────────────────────────────────────────────────────────
-- Profiles (existing table — extend with new columns)
-- ─────────────────────────────────────────────────────────────────────
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS
  portal_role TEXT DEFAULT 'executive',
  -- Values: president | vice_president | working_president |
  --         secretary | joint_secretary | treasurer |
  --         joint_treasurer | executive | member
  payment_status TEXT DEFAULT 'current',
  -- Values: current | warned_30d | defaulting_60d | defaulter_90d
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
  policy_version TEXT NOT NULL,          -- 'v1.0', 'v1.1' etc.
  consent_given BOOLEAN NOT NULL,
  consent_at TIMESTAMPTZ DEFAULT NOW(),
  ip_hash TEXT,
  user_agent_hash TEXT
);

-- ─────────────────────────────────────────────────────────────────────
-- Upload Queue (GitHub upload batching)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE upload_queue (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  uploaded_by UUID REFERENCES profiles,
  item_type TEXT NOT NULL,              -- HOTO | SNAG | VENDOR | NOTICE | FINANCE
  item_id TEXT NOT NULL,
  file_name TEXT NOT NULL,
  file_size_bytes INTEGER,
  file_type TEXT,
  file_hash_sha256 TEXT,
  source_description TEXT,             -- "Received from Ankura Homes on 2026-04-15"
  target_github_path TEXT NOT NULL,
  status TEXT DEFAULT 'PENDING',       -- PENDING | PROCESSING | COMPLETED | FAILED | PERMANENTLY_FAILED
  attempts INTEGER DEFAULT 0,
  last_attempt_at TIMESTAMPTZ,
  error_message TEXT,
  github_sha TEXT,                     -- set on COMPLETED
  document_id TEXT,                    -- set on COMPLETED; FK to documents
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_upload_queue_status ON upload_queue(status);

-- ─────────────────────────────────────────────────────────────────────
-- GitHub API Log (health monitoring)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE github_api_log (
  id BIGSERIAL PRIMARY KEY,
  operation TEXT NOT NULL,             -- health-check | upload | read | commit
  success BOOLEAN NOT NULL,
  latency_ms INTEGER,
  error_message TEXT,
  github_path TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_github_api_log_created ON github_api_log(created_at DESC);

-- ─────────────────────────────────────────────────────────────────────
-- PDF Generation Jobs (async PDF)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE pdf_generation_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  requested_by UUID REFERENCES profiles,
  job_type TEXT NOT NULL,              -- LETTER | NOTICE | REPORT
  letter_id TEXT,
  template TEXT,
  input_data JSONB,
  status TEXT DEFAULT 'QUEUED',        -- QUEUED | PROCESSING | DONE | FAILED
  attempts INTEGER DEFAULT 0,
  github_path TEXT,                    -- set on DONE
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- ─────────────────────────────────────────────────────────────────────
-- HOTO Items
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE hoto_items (
  id TEXT PRIMARY KEY,                  -- 'HOTO-2026-042'
  society_id UUID NOT NULL,
  ascenza_category TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  builder_commitment TEXT,
  builder_contact TEXT,
  priority TEXT DEFAULT 'MEDIUM',       -- LOW | MEDIUM | HIGH | CRITICAL
  status TEXT NOT NULL DEFAULT 'NOT_STARTED',
  deadline DATE,
  builder_sla_date DATE,               -- SLA for builder-dependent items
  days_overdue INTEGER DEFAULT 0,      -- computed; updated by cron
  responsible_role TEXT,               -- role name; persists through committee changes
  responsible_user_id UUID REFERENCES profiles,
  rera_escalation_eligible BOOLEAN DEFAULT false,
  notice_sent BOOLEAN DEFAULT false,
  notice_sent_date TIMESTAMPTZ,
  notice_draft_path TEXT,              -- auto-generated draft path
  dependencies TEXT[],
  president_approved_at TIMESTAMPTZ,
  president_approved_by UUID REFERENCES profiles,
  secretary_approved_at TIMESTAMPTZ,
  secretary_approved_by UUID REFERENCES profiles,
  governance_notes TEXT,               -- byelaw interpretation; quorum attendees; dispute reasons
  created_by UUID REFERENCES profiles,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_updated_at TIMESTAMPTZ DEFAULT NOW(),
  github_path TEXT
);
CREATE INDEX idx_hoto_status ON hoto_items(status);
CREATE INDEX idx_hoto_category ON hoto_items(ascenza_category);
CREATE INDEX idx_hoto_overdue ON hoto_items(days_overdue) WHERE days_overdue > 0;

-- ─────────────────────────────────────────────────────────────────────
-- HOTO Required Documents (prompting system)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE hoto_required_docs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hoto_item_id TEXT REFERENCES hoto_items,
  doc_name TEXT NOT NULL,
  required BOOLEAN DEFAULT true,
  uploaded BOOLEAN DEFAULT false,
  document_id TEXT,
  bypass_by UUID REFERENCES profiles,   -- if required doc bypassed
  bypass_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────
-- Snag Items
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE snag_items (
  id TEXT PRIMARY KEY,                  -- 'SNAG-2026-089'
  society_id UUID NOT NULL,
  snag_scope TEXT NOT NULL DEFAULT 'COMMON_AREA', -- COMMON_AREA | INDIVIDUAL_APARTMENT
  category TEXT NOT NULL,
  subcategory TEXT,
  location TEXT NOT NULL,
  flat_number TEXT,                    -- set only if snag_scope = INDIVIDUAL_APARTMENT
  description TEXT NOT NULL,
  severity TEXT DEFAULT 'MEDIUM',       -- LOW | MEDIUM | HIGH | CRITICAL
  status TEXT DEFAULT 'OPEN',
  ascenza_reference TEXT,
  builder_committed_date DATE,
  builder_sla_days_overdue INTEGER DEFAULT 0,
  notice_sent BOOLEAN DEFAULT false,
  formal_notice_id TEXT,
  video_url TEXT,                      -- YouTube or Drive link; no direct video upload
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
-- Documents (all uploaded files)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  item_type TEXT NOT NULL,             -- HOTO | SNAG | VENDOR | NOTICE | FINANCE | PROXY
  item_id TEXT NOT NULL,
  name TEXT NOT NULL,
  file_type TEXT,
  file_size_bytes INTEGER,
  file_hash_sha256 TEXT NOT NULL,      -- integrity verification
  source_description TEXT,             -- who provided it; when received
  github_path TEXT NOT NULL,
  github_sha TEXT,
  upload_queue_id UUID REFERENCES upload_queue,
  uploaded_by UUID REFERENCES profiles,
  uploaded_at TIMESTAMPTZ DEFAULT NOW(), -- server-generated; not client clock
  description TEXT,
  is_confidential BOOLEAN DEFAULT false,
  superseded_by TEXT REFERENCES documents, -- for versioning
  superseded_at TIMESTAMPTZ
);

-- ─────────────────────────────────────────────────────────────────────
-- Vendor Requirements
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE vendor_requirements (
  id TEXT PRIMARY KEY,                  -- 'REQ-2026-001'
  society_id UUID NOT NULL,
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  status TEXT DEFAULT 'DRAFT',
  -- DRAFT | EVALUATION | VOTING | DECIDED | CONTRACTED
  voting_opens_at TIMESTAMPTZ,
  voting_closes_at TIMESTAMPTZ,
  quorum_required INTEGER DEFAULT 8,
  selected_vendor_id TEXT,
  voting_policy_committed BOOLEAN DEFAULT false, -- must be true before voting opens
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
  principal_user_id UUID REFERENCES profiles NOT NULL, -- apartment owner
  proxy_user_id UUID REFERENCES profiles NOT NULL,     -- authorized proxy
  requirement_id TEXT REFERENCES vendor_requirements,  -- null = general PoA
  proxy_document_id TEXT REFERENCES documents,         -- notarized PoA document
  valid_from DATE NOT NULL,
  valid_until DATE,
  activated_by UUID REFERENCES profiles,               -- admin who verified
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
  payment_mode TEXT,                    -- NEFT | RTGS | UPI | cheque (no cash per §9.1)
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
  transaction_type TEXT NOT NULL,       -- RECEIVED_FROM_BUILDER | INTEREST_EARNED | APPROVED_USE
  amount NUMERIC(12,2) NOT NULL,
  description TEXT,
  date DATE NOT NULL,
  approved_by UUID REFERENCES profiles,
  board_resolution_ref TEXT,
  payment_mode TEXT,
  reference_number TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Helper function: get current corpus balance
CREATE OR REPLACE FUNCTION get_corpus_balance(p_society_id UUID)
RETURNS NUMERIC AS $$
  SELECT COALESCE(
    SUM(CASE WHEN transaction_type IN ('RECEIVED_FROM_BUILDER','INTEREST_EARNED') THEN amount
             WHEN transaction_type = 'APPROVED_USE' THEN -amount END),
    0
  )
  FROM corpus_fund_records
  WHERE society_id = p_society_id;
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
  sanctioned_by_role TEXT,             -- secretary | president | board | general_body
  sanctioned_by UUID REFERENCES profiles,
  byelaw_authority TEXT,               -- e.g. "§9.11(a) - President sanction ≤₹20K"
  board_resolution_ref TEXT,
  corpus_fund_record_id UUID REFERENCES corpus_fund_records,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────
-- Comments (shared across modules)
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE comments (
  id TEXT PRIMARY KEY,
  item_type TEXT NOT NULL,             -- HOTO | SNAG | VENDOR_REQ | VENDOR
  item_id TEXT NOT NULL,
  parent_comment_id TEXT REFERENCES comments,
  author_id UUID REFERENCES profiles,
  content TEXT NOT NULL,
  is_pinned BOOLEAN DEFAULT false,
  edited_at TIMESTAMPTZ,
  edited_content TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  github_commit TEXT
  -- No deleted column: comments cannot be deleted; they are byelaw audit records
);

-- ─────────────────────────────────────────────────────────────────────
-- Formal Notices
-- ─────────────────────────────────────────────────────────────────────
CREATE TABLE notices (
  id TEXT PRIMARY KEY,
  notice_type TEXT NOT NULL,
  recipient TEXT NOT NULL,
  recipient_type TEXT NOT NULL,        -- BUILDER | MEMBER
  related_item_type TEXT,
  related_item_id TEXT,
  auto_generated BOOLEAN DEFAULT false, -- true if generated by SLA cron
  status TEXT DEFAULT 'DRAFT',         -- DRAFT | SENT | RESPONSE_RECEIVED
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
  from_role TEXT NOT NULL,             -- president | secretary
  to_user_id UUID REFERENCES profiles,
  reason TEXT NOT NULL,
  delegation_type TEXT NOT NULL,       -- PLANNED | UNPLANNED
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
  byelaw_reference TEXT,               -- e.g. "§7.16(c) - casting vote"
  ip_hash TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_audit_log_resource ON audit_log(resource_type, resource_id);
CREATE INDEX idx_audit_log_actor ON audit_log(actor_id, created_at DESC);
```

---

## 15. Security & Privacy Compliance

### 15.1 GitHub App Private Key Security

The GitHub App private key is the master credential for all document storage. If it leaks, all governance data is exposed.

**Rules:**
1. Key lives **only** in Vercel environment variables (`GITHUB_APP_PRIVATE_KEY`)
2. Never in code, `.env` files, or any file tracked by git
3. `.env` is in `.gitignore` — verify this before first commit
4. Pre-commit hook added to `utamacs-website` repo:

```bash
# .husky/pre-commit or .git/hooks/pre-commit
if git diff --cached --name-only | xargs grep -l "BEGIN RSA PRIVATE KEY\|BEGIN EC PRIVATE KEY" 2>/dev/null; then
  echo "ERROR: Private key detected in staged files. Commit blocked."
  exit 1
fi
```

5. Key rotated quarterly. Rotation procedure documented in RUNBOOK.md.
6. GitHub App permissions: `contents:write` on `governance-data` repo ONLY. No access to `utamacs-website`.

### 15.2 Row-Level Security (RLS) Policy

All tables containing PII or sensitive data have RLS enabled. The `anon` Supabase key has zero access to any sensitive table.

**RLS pattern for each table:**

```sql
-- Enable RLS on all tables
ALTER TABLE hoto_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE snag_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE corpus_fund_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Profiles: users see their own; committee sees all non-confidential fields
CREATE POLICY "profile_self_read" ON profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profile_committee_read" ON profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND portal_role IN ('president','vice_president','secretary','joint_secretary',
                          'treasurer','joint_treasurer','executive','working_president')
    )
  );

-- HOTO items: all committee members can read; only executive+ can write
CREATE POLICY "hoto_read_committee" ON hoto_items
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND portal_role != 'member')
  );

-- Members (role='member') get read-only to HOTO; no financial or contact data
CREATE POLICY "hoto_read_member" ON hoto_items
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Maintenance records: treasurer + secretary + president + admin only
CREATE POLICY "maintenance_committee_only" ON maintenance_records
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
      AND portal_role IN ('president','vice_president','secretary','joint_secretary',
                          'treasurer','joint_treasurer')
    )
  );
```

**RLS test requirement:** Before go-live, use the Supabase client with an `executive` role JWT and verify it cannot query `maintenance_records`. Use a `member` role JWT and verify it cannot see phone numbers in `profiles`.

### 15.3 DPDP Act Compliance (India's Digital Personal Data Protection Act 2023)

The platform stores PII for 136 apartment owners (names, phone numbers, email addresses, payment records). Obligations under DPDP Act:

1. **Privacy policy** published at `utamacs.org/privacy` before any data collection
2. **Explicit consent** required on first portal login: checkbox "I consent to UTA MACS storing and processing my personal data for society governance purposes" — non-negotiable
3. **Consent record** stored in `privacy_consents` table with timestamp and policy version
4. **Purpose limitation**: member contact data used only for governance communications; never for vendor contact sharing
5. **Data retention**: member data retained as long as membership is active; flagged inactive for 10 years post-membership (per byelaw audit requirement), then reviewed
6. **Right to access**: member can request their own data via portal
7. **Breach notification**: if GitHub repo is compromised, affected members notified within 72 hours (DPDP Act requirement)

### 15.4 Phone Number Confidentiality

Per the requirement: member phone numbers must never be visible to general members.

- `profiles.phone` is excluded from all `SELECT *` patterns
- RLS policy explicitly blocks `member` role from seeing phone column
- API routes for member data strip phone before returning if caller role is `executive` or lower
- Committee-level members (secretary+) can see phone for operational needs

### 15.5 Vercel Pro Upgrade Security Note

Upgrade to Vercel Pro before HOTO starts. Benefits:
- 14-minute function timeout (vs 10 seconds on Hobby)
- Firewall rules to restrict API routes to known IPs if needed
- Audit logs for deployments

---

## 16. Data Migration Sprint

### 16.1 The Problem

Years of HOTO-relevant documents are scattered across:
- WhatsApp group messages (photos, PDFs)
- Personal email inboxes of committee members
- Google Drive folders (shared inconsistently)
- Physical documents (builder handover letters, NOCs)

If these are not migrated before HOTO starts, the platform's timeline has gaps. Any RERA dispute that requires showing what was received, when, and by whom will be weakened by missing pre-June evidence.

### 16.2 Migration Sprint Plan (May 6-25, 3 weeks)

**Who:** One committee member with tech comfort (not the Secretary — they're already busy). Potentially a family member of a committee member.

**What to migrate:**

| Priority | Source | Content |
|---|---|---|
| P1 | Email (committee inboxes) | Builder letters, NOCs, certificates received from Ankura Homes |
| P1 | Google Drive | Ascenza scope documents, existing inspection reports |
| P1 | WhatsApp | Photos from site inspections since occupation |
| P2 | Physical | Scans of builder handover letters, signed agreements |
| P3 | WhatsApp | Meeting minutes, decisions made in WhatsApp (screenshot → PDF) |

**Tools built for migration:**

1. **Admin bulk import**: `/portal/admin/import` — CSV upload creates multiple HOTO items or snag items in one operation
2. **Bulk document upload**: Select multiple files → queued via `upload_queue` → associated with specific HOTO item
3. **Source tagging**: Every migrated document gets `source_description` = "Migrated from [WhatsApp/Drive/Email] by [person] on [date]"

**Migration checkpoint (May 25):**
- All P1 documents uploaded
- All HOTO items seeded with their required document checklists
- `_index.json` in governance-data repo reflects real state

### 16.3 Bulk HOTO Item Seeding (May 6-9)

The 80+ HOTO items covering all Ascenza categories must be seeded before committee training. The implementer seeds these from the Ascenza scope document as a one-time operation:

```bash
# Seed script: seeds/seed-hoto-items.ts
# Reads: seeds/hoto-items.csv (columns: category, title, description, priority, deadline, rera_eligible)
# Inserts into hoto_items table
# Creates required_docs records per item
# Commits _index.json to governance-data
```

All 14 committee members can then see actual HOTO items (not dummy data) during training.

---

## 17. Role-Based Access Control

### 17.1 Feature Access Matrix

| Feature | member | executive | working_president | treasurer | joint_secretary | secretary | vice_president | president |
|---|---|---|---|---|---|---|---|---|
| View HOTO items | R | R | R | R | R | R | R | R |
| Create/edit HOTO items | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Upload documents | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Add comments | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Advance HOTO status | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| President approval gate | - | - | - | - | - | - | ✓(delegated) | ✓ |
| Secretary approval gate | - | - | - | - | ✓(delegated) | ✓ | - | - |
| Create/edit snags | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Delete snags (soft) | - | - | - | - | - | - | - | ✓(President) |
| Cast vendor vote | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Open voting | - | - | - | - | ✓ | ✓ | ✓ | ✓ |
| View maintenance records | - | - | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| Add maintenance entry | - | - | - | ✓ | - | ✓ | ✓ | ✓ |
| Approve expense | - | - | - | - | - | ✓(≤₹10K) | - | ✓(≤₹20K) |
| Send formal notice | - | - | - | - | ✓ | ✓ | ✓ | ✓ |
| Manage delegation | - | - | - | - | - | - | - | admin |
| View audit log | - | - | - | - | - | ✓ | ✓ | ✓ |
| View member phone numbers | - | - | - | - | - | ✓ | ✓ | ✓ |
| Bypass required docs gate | - | - | - | - | - | ✓ | ✓ | ✓ |
| Set snag_scope to INDIVIDUAL_APARTMENT | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

### 17.2 Member Lifecycle

- **New member (owner buys)**: NOC from committee required → admin creates portal account → role = `member` → privacy consent on first login
- **Committee election**: Admin upgrades role; outgoing member reverts to `member`; all past actions remain attributed to them
- **Committee member resigns mid-HOTO**: Role changed to `member`; all their assigned HOTO/snag items auto-reassigned by role (Section 5.6)
- **Member sells flat**: Profile marked `is_active = false`; data retained for audit; no login access

---

## 18. Document Management

### 18.1 Required Document Prompting

Each HOTO item has a `required_documents` list. The system:
1. Shows a red "Missing Documents" badge on any item with unfulfilled required docs
2. Cannot advance to `UNDER_REVIEW` if required docs missing — hard gate
3. Secretary or President can bypass with a mandatory written reason (stored in `hoto_required_docs.bypass_reason` and audit log)

### 18.2 Document Metadata (v3 Additions)

Every uploaded document records:
- `uploaded_by`: user ID (server-resolved from session, not client-provided)
- `uploaded_at`: server timestamp (not client clock)
- `file_hash_sha256`: computed server-side from file bytes before uploading to GitHub
- `source_description`: free text — "Received from Ankura Homes on 2026-04-15 via email"
- `github_sha`: the git commit SHA where this file was written — cryptographically verifiable

This makes every document legally defensible as to origin and timing.

### 18.3 Document Versioning

- New version of a document can be uploaded at any time
- Old version set to `superseded_by = new_document_id` and `superseded_at = now()`
- Version history shown on document card: "Superseded by [v2 name] on [date]"
- Old version remains downloadable for audit purposes — never deleted

### 18.4 Confidentiality Rules

| Data | Visible to |
|---|---|
| Member phone numbers | secretary, joint_secretary, treasurer, vice_president, president |
| Vendor quotes | All committee (executive and above) |
| Legal notices | All committee |
| HOTO documents | All committee |
| Financial records | treasurer, joint_treasurer, secretary, vice_president, president |
| Proxy documents | secretary, president |
| Audit log | secretary, vice_president, president |
| Individual apartment snag details | All committee (logged for reference) |

---

## 19. Scope Boundary

### 19.1 What This Platform Covers (v1)

This platform is built for these specific use cases:
1. HOTO tracking — Ascenza-scope items from June 1, 2026
2. Snag list management — common area only; individual apartments as courtesy log
3. Vendor evaluation and selection — current 5 active evaluations
4. Maintenance collection tracking — from May 1, 2025
5. Corpus fund and expense tracking
6. Formal notice generation to builder and members
7. MC governance: voting, approvals, delegation

### 19.2 What This Platform Does NOT Cover (v1)

The following are explicitly out of scope for v1. If requested, this document (committed to governance-data) is the reference:

- **Clubhouse/amenity booking** — not in v1
- **Resident-to-resident contact directory** — not in v1
- **Maintenance complaint routing for residents** — not in v1
- **Individual apartment snagging resolution** — logged only; not managed
- **Annual General Body Meeting workflow** — post-HOTO
- **Gate access / visitor management** — separate system
- **WhatsApp Business API integration** — Phase 2

This document is committed to `governance-data/_meta/scope-v1.md` before the first resident sees the portal. When scope-creep requests arrive, this is the documented response.

---

## 20. Phase-wise Implementation Plan

### Urgency Context

Today is May 6, 2026. HOTO starts June 1, 2026. That is **26 days**. The original 14-week plan assumed a later start. This plan compresses the critical path to a 3-week emergency sprint, with a clear minimum viable scope for May 31.

**Principle:** Imperfect digital tracking from Day 1 is worth more than a perfect system 6 weeks later.

---

### Emergency Sprint — May 6 to May 31 (25 days)

**Goal:** System live on May 31, all 14 members onboarded, 80+ HOTO items seeded, Bal Reddy has done one walkthrough.

**Scope IN for Emergency Sprint:**
- Infrastructure: governance-data repo, GitHub App, upload queue, health-check cron, Supabase migrations
- Auth: existing Supabase auth + roles (already built) + new role columns
- HOTO item list and detail: view, comment, upload (queued), required doc alerts, status transitions
- Mobile "My Actions" view with Approve / Not Yet for President
- Email notifications: action required, status change (Resend integration)
- Seeded: all 80+ HOTO items from Ascenza scope
- Pre-launch: all 14 committee members registered; walkthrough session with Bal Reddy
- Security: pre-commit hook, RLS on all new tables, anon key blocked from sensitive tables
- Privacy: consent checkbox on first login, privacy policy page live
- Scope document: `scope-v1.md` committed to governance-data

**Scope OUT for Emergency Sprint (deferred to Phase 2):**
- Full approval workflow gates (simplified: status can be manually set by Secretary for initial phase)
- Snag module bulk CSV import
- Vendor voting system
- Financial tracking module
- Formal notice generation
- Async PDF generation (use existing sync PDF for now; upgrade Vercel Pro as backup)

| Days | Deliverable | Who |
|---|---|---|
| **May 6-9** (Days 1-4) | Create `utamacs/governance-data` private repo with full folder structure. Set up GitHub App with `contents:write` on governance-data only. Install key in Vercel env vars. Add pre-commit hook to website repo. Write Supabase migration 027 (all new tables). Run migration. | Implementer |
| **May 9-9** (Day 4) | Set up health-check cron (`/api/cron/github-health`) and Supabase keepalive cron. Verify both write to `github_api_log`. | Implementer |
| **May 10-14** (Days 5-9) | HOTO item list page: filterable by category/status, search, priority indicator. Loads from Supabase `hoto_items`. Seed 80+ items from Ascenza scope CSV. | Implementer |
| **May 14-19** (Days 10-14) | HOTO item detail page: required doc checklist with red badges, document upload (via upload_queue with status polling), comment thread, status timeline, status transition buttons with role checks. | Implementer |
| **May 19-22** (Days 15-17) | "My Actions" mobile screen for non-tech users. Simplified approve/reject UI. Email notifications: action required, status changed (Resend). | Implementer |
| **May 22-25** (Days 17-20) | Register all 14 committee members. Assign roles. Test each role's access. Fix any RLS gaps found. Upload_queue cron working end-to-end. | Implementer + 1 committee member |
| **May 25-28** (Days 20-23) | Data migration sprint: P1 documents uploaded (builder letters, NOCs, Ascenza scope docs). Bulk import tested. Privacy policy page live at utamacs.org/privacy. | Data migrator + implementer |
| **May 29-30** (Days 24-25) | Pre-launch walkthrough with Bal Reddy (President): approves a test HOTO item end-to-end. Fix any confusion discovered. Final smoke test on mobile. | Implementer + Secretary + President |
| **May 31** | **Go-live.** System opens to all 14 committee members. HOTO tracking begins. | All |

---

### Phase 2 — June 1 to June 28 (4 weeks, during active HOTO)

**Goal:** Add approval workflow, snag module, and vendor evaluation.

| Week | Deliverable |
|---|---|
| **Week 5 (Jun 1-7)** | Full President + Secretary approval workflow with delegation. Delegation management UI. Acting-on-behalf tagging on all approvals. |
| **Week 6 (Jun 8-14)** | Snag list full CRUD. Snag scope (COMMON_AREA vs INDIVIDUAL_APARTMENT) with liability disclaimer. Bulk CSV import from Ascenza Excel. Photo upload from mobile camera. |
| **Week 7 (Jun 15-21)** | Vendor evaluation module: requirement board, vendor profiles, side-by-side comparison matrix. Voting policy document committed to governance-data before voting opens. |
| **Week 8 (Jun 22-28)** | Digital voting: quorum enforcement, conflict of interest declaration, tie-breaking, proxy authorization, vote transparency. Decision record writer (immutable). |

---

### Phase 3 — July 1 to July 31 (4 weeks)

**Goal:** Financial tracking, notice generation, post-selection vendor tracking.

| Week | Deliverable |
|---|---|
| **Week 9 (Jul 1-7)** | Maintenance collection tracking from May 2025. Defaulter tracking with byelaw thresholds. Monthly defaulter list generation and email. |
| **Week 10 (Jul 8-14)** | Corpus fund tracker with overdraft prevention (server-side balance check). Expense tracker with byelaw authority enforcement. Builder dues register. |
| **Week 11 (Jul 15-21)** | Formal notice generation: integrates with existing letter system. Auto-draft on 30-day SLA breach. RERA escalation tracker with evidence package assembly. |
| **Week 12 (Jul 22-31)** | Post-selection vendor tracking: contract upload, renewal reminders, performance rating, complaint log. Async PDF generation (job queue). |

---

### Phase 4 — August 1 to August 31 (4 weeks)

**Goal:** Polish, security review, resident digest, non-developer handover.

| Week | Deliverable |
|---|---|
| **Week 13 (Aug 1-14)** | Full mobile UX audit against non-tech user spec. Storage health tile on dashboard. Resident fortnightly HOTO digest email (no login required). |
| **Week 14 (Aug 15-22)** | Security review: RLS audit with test JWTs for each role. Verify anon key has zero sensitive access. Test corpus fund overdraft check. |
| **Week 15 (Aug 23-28)** | RUNBOOK.md written and validated: Secretary follows it without assistance to add a member, reset password, check upload queue. |
| **Week 16 (Aug 29-31)** | Post-HOTO retrospective. Assess Phase 5 scope (meeting management, general resolution workflow, AGM support, WhatsApp notifications). |

---

### Pre-Launch Checklist (Must Be Done Before May 31)

- [ ] `utamacs/governance-data` private repo created
- [ ] GitHub App installed; private key in Vercel env vars; NOT in any file
- [ ] Pre-commit hook blocking private key commits
- [ ] `GITHUB_APP_PRIVATE_KEY` rotation schedule set (quarterly reminders created)
- [ ] Supabase migration 027 run and verified in production
- [ ] RLS enabled on all new tables; anon key tested with zero sensitive access
- [ ] Privacy policy live at `utamacs.org/privacy`
- [ ] `privacy_consents` table captures first logins
- [ ] Health-check cron running every 15 minutes; sends Resend alert on failure
- [ ] Supabase keepalive cron running every 6 days
- [ ] Upload queue cron running every 60 seconds
- [ ] All 14 committee members registered and roles assigned
- [ ] 80+ HOTO items seeded from Ascenza scope
- [ ] P1 historical documents uploaded with `source_description`
- [ ] `governance-data/_meta/scope-v1.md` committed
- [ ] `governance-data/_meta/voting-policy.md` committed (joint ownership + proxy policy)
- [ ] Vercel Pro upgrade completed (14-minute timeout)
- [ ] Resend DNS for `utamacs.org` verified
- [ ] Bal Reddy walkthrough completed and sign-off received
- [ ] RUNBOOK.md (initial version covering go-live procedures) committed to governance-data

---

## 21. Comprehensive Risk Register

### 21.1 Technical Risks

| Risk | Probability | Impact | Mitigation in v3 Design |
|---|---|---|---|
| GitHub API rate limit during bulk session | Medium | High | `upload_queue` table; cron processes max 30/batch; direct browser upload blocked at API |
| Vercel 10s timeout kills PDF generation | Medium | High | Async `pdf_generation_jobs` queue; Vercel Pro (14-min timeout) as backup |
| GitHub App token expiry causes silent upload failure | Medium | Critical | `github_api_log` every 15 minutes; Resend alert on 3 consecutive failures |
| Supabase free tier pauses DB (7-day inactivity) | Medium | Medium | Cron keepalive every 6 days; upgrade to Supabase Pro documented in runbook |
| pdfmake cold start exceeds timeout | Low | Medium | Cron ping every 5 minutes to keep function warm; async PDF as primary fix |
| GitHub repo size exceeds 1GB | Low | Medium | Block all video uploads; 5MB file limit enforced server-side; URL field for video links |
| Private key leaked to git | Low | Critical | Pre-commit hook; key only in Vercel env vars; quarterly rotation |
| RLS gaps expose PII | Medium | High | RLS test suite with role-specific JWTs before go-live; anon key blocked from sensitive tables |

### 21.2 Adoption Risks

| Risk | Probability | Impact | Mitigation in v3 Design |
|---|---|---|---|
| President doesn't adopt portal | High | Critical | Non-tech UX spec (Section 11); "My Actions" as default screen; pre-launch walkthrough mandatory |
| Committee members revert to WhatsApp | High | Medium | Financial payments require portal approval record — WhatsApp bypasses the financial controls |
| Committee member dropout mid-HOTO | Medium | High | Role-based assignment (not person-based); orphan auto-escalation to Secretary |
| Low resident engagement | High | Low | Resident-facing = fortnightly email digest only; no login required; reduces friction |
| Working President confusion | Medium | High | Same non-tech UX as President; included in walkthrough session |

### 21.3 Governance and Legal Risks

| Risk | Probability | Impact | Mitigation in v3 Design |
|---|---|---|---|
| Byelaw ambiguity discovered during implementation | Medium | Medium | `governance_notes` field on every resolution; quorum attendee list mandatory; interpretation documented not encoded |
| RERA document metadata challenged | Low | High | Server timestamps (not client); SHA-256 hash; source description; GitHub commit SHA = cryptographic proof |
| Vote challenged (proxy invalidity) | Low | High | Notarized proxy doc uploaded + linked to vote record; joint ownership policy committed pre-vote |
| Builder non-cooperation | High | Medium | Log builder-pending items from Day 1 regardless of formal HOTO status; SLA escalation cron |
| DPDP Act compliance gap | Low | High | Privacy policy + explicit consent + consent timestamp; purpose limitation enforced |

### 21.4 Operational Risks

| Risk | Probability | Impact | Mitigation in v3 Design |
|---|---|---|---|
| Phase 1 too late for June 1 HOTO | High | Critical | Emergency sprint with cut scope; minimum viable system = HOTO tracker + upload + comments |
| Data migration never completed | High | Medium | Dedicated migration sprint (May 6-25); P1 priority docs before go-live |
| Scope creep from residents | High | Medium | `scope-v1.md` committed to governance-data before launch; formal documented response |
| Committee turnover mid-HOTO | Medium | High | Role-based assignment; auto-escalation; RUNBOOK.md for non-developer admin |
| Ascenza scope interpreted as covering individual apartments | Medium | Medium | `snag_scope` field; liability disclaimer banner on individual items |
| Architecture bus-factor (single implementer) | High | High | RUNBOOK.md validated by Secretary before go-live; architecture overview in governance-data |

### 21.5 Financial Risks

| Risk | Probability | Impact | Mitigation in v3 Design |
|---|---|---|---|
| Corpus fund overdraft | Low | Critical | Server-side balance check in payment approval API; client can never bypass |
| Builder dues never collected | Medium | High | Builder dues tracker; SLA escalation; RERA notice auto-draft at 30 days |
| Expense exceeds byelaw authority | Low | High | API enforces financial limits per §9.11; blocks at API level with byelaw citation |
| Cash payment recorded | Low | Medium | Cash option removed from all UI screens; API rejects `payment_mode = cash` |

### 21.6 Security Risks

| Risk | Probability | Impact | Mitigation in v3 Design |
|---|---|---|---|
| Private GitHub repo exposed via leaked key | Low | Critical | Pre-commit hook; Vercel env vars only; quarterly rotation; GitHub App limited to governance-data repo |
| Member PII exposed to executives | Low | High | Phone column excluded from executive queries; RLS policy; API strips phone before returning |
| Supabase service_role key in client code | Low | Critical | Code review pre-launch; service_role only in API routes; never in client-side JavaScript |
| Malicious file upload (XSS via SVG) | Low | High | Allowlist of file types (PDF, JPG, PNG, XLSX, CSV, DOCX); SVG rejected; files stored in GitHub, never served as HTML |

### 21.7 Risk Priority: The Three That Kill the Project

If only three risks get managed before everything else:

1. **Phase 1 timing** — Cut scope to the bone for May 31. A late system means HOTO starts with no digital trail. That trail cannot be reconstructed retroactively.

2. **President adoption** — If Bal Reddy uses WhatsApp instead of the portal for approvals, the audit trail becomes useless. The "My Actions" mobile screen must be so simple he prefers it. This is tested in the pre-launch walkthrough, not assumed.

3. **GitHub token silent failure** — Unmonitored failures mean documents are lost without anyone knowing. The health-check cron and Resend alert are non-negotiable; they go live on Day 4 (May 9), not as an afterthought.

---

*Document Version 3.0 · Revised May 2026 — Risk-Hardened*  
*Based on: Registered Byelaws TG/RRD/MACS/2026-15/FOW & M · Ascenza HOTO Scope · Committee Q&A · Risk Analysis Session*  
*Changes from v2: Infrastructure resilience section added; async upload queue; GitHub health monitoring; async PDF; DPDP Act compliance; non-tech UX spec; data migration sprint; compressed implementation plan (25-day emergency sprint to May 31); comprehensive risk register; RLS test requirement; corpus fund overdraft prevention; SLA escalation cron; snag scope classification; proxy/joint-ownership voting protocol; scope boundary document*  
*Next review: Post-Phase 1 go-live (June 2026)*
