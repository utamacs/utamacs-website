# UTA MACS — HOTO & Vendor Management Platform Design
## Complete System Architecture, Data Model, UX & Implementation Plan

**Society:** Urban Trilla Apartment Owners Mutually Aided Cooperative Maintenance Society Limited  
**Location:** Kondakal, Shankarpalle, Rangareddy District, Telangana  
**Phase:** Builder-to-Association Handover (HOTO) + Vendor Selection  
**Version:** 1.0 — May 2026

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture](#2-system-architecture)
3. [Part 1 — Vendor Management System](#3-part-1--vendor-management-system)
4. [Part 2 — HOTO Management System](#4-part-2--hoto-management-system)
5. [Part 3 — Workflow Engine](#5-part-3--workflow-engine)
6. [Part 4 — Dashboard & Tracking](#6-part-4--dashboard--tracking)
7. [Part 5 — Git as Storage Backend](#7-part-5--git-as-storage-backend)
8. [Part 6 — Data Models](#8-part-6--data-models)
9. [Part 7 — UX Design](#9-part-7--ux-design)
10. [Part 8 — Industry Best Practices](#10-part-8--industry-best-practices)
11. [Part 9 — Implementation Plan](#11-part-9--implementation-plan)
12. [Trade-offs & Risks](#12-trade-offs--risks)

---

## 1. Executive Summary

Urban Trilla MACS is entering the most critical governance phase of a residential society: **HOTO (Handover/Takeover) from builder to association**. This document designs a production-ready digital governance platform to manage:

- **Vendor evaluation and selection** with full transparency and auditability
- **HOTO checklist tracking** with item-level governance (documents, discussions, approvals)
- **A generic workflow engine** applicable to any future association decision
- **Git-backed document storage** — no paid backend required; GitHub is the database
- **A portal-integrated dashboard** for all stakeholders

### Design Principles

| Principle | How it manifests |
|---|---|
| **Radical transparency** | Every action, comment, vote, and approval is permanently logged |
| **Non-technical usability** | UI abstracts all Git operations; members never touch a terminal |
| **Dual-approval governance** | President + Secretary must both sign off on completions |
| **Audit-first** | Nothing is deleted; statuses transition forward only |
| **Mobile-first** | All screens usable on Android/iOS without app install |

---

## 2. System Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    MEMBER BROWSER                           │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  portal.utamacs.org  (Astro SSR on Vercel)           │   │
│  │                                                       │   │
│  │  /portal/hoto/          HOTO checklist portal        │   │
│  │  /portal/vendors/       Vendor evaluation portal     │   │
│  │  /portal/decisions/     Generic workflow portal      │   │
│  │  /portal/dashboard      Governance dashboard         │   │
│  └────────────────┬─────────────────────────────────────┘   │
└───────────────────┼─────────────────────────────────────────┘
                    │ HTTPS API calls
          ┌─────────▼──────────┐
          │  Vercel Serverless  │
          │  /api/v1/hoto/      │
          │  /api/v1/vendors/   │
          │  /api/v1/decisions/ │
          └────┬──────────┬────┘
               │          │
    ┌──────────▼──┐   ┌───▼──────────────────────┐
    │  Supabase   │   │  GitHub REST API          │
    │  PostgreSQL │   │  (octokit)                │
    │             │   │                           │
    │  - Users    │   │  utamacs/governance-data  │
    │  - Roles    │   │  (private repo)           │
    │  - Sessions │   │                           │
    │  - Audit    │   │  Documents, JSON records, │
    │    logs     │   │  comments, votes, files   │
    └─────────────┘   └───────────────────────────┘
```

### 2.2 Two-Repo Strategy

```
utamacs/utamacs-website      ← Code (this repo, GitHub Pages + Vercel)
utamacs/governance-data      ← Data (private, Git = database + audit trail)
```

The **governance-data** repo is a structured data store. Every write through the portal creates a Git commit — which is the audit log. The UI never exposes Git to users; they interact through forms.

### 2.3 Component Map

```
Portal (Astro SSR)
├── Auth (Supabase JWT)
├── HOTO Module
│   ├── Item List (filterable, sortable)
│   ├── Item Detail (full governance view)
│   ├── Admin: Create/Edit Item
│   └── Approval Panel (President/Secretary)
├── Vendor Module
│   ├── Requirements Board
│   ├── Vendor Profile
│   ├── Comparison Dashboard
│   ├── Voting Screen
│   └── Decision Record
├── Workflow Engine (shared)
│   ├── State machine (status transitions)
│   ├── Comments/Discussion
│   ├── Document upload → GitHub
│   ├── Vote casting
│   └── Approval gates
└── Dashboard
    ├── HOTO Progress
    ├── Vendor Decisions
    └── Pending Approvals
```

---

## 3. Part 1 — Vendor Management System

### 3.1 Vendor Lifecycle States

```
DRAFT → OPEN → SUBMITTED → EVALUATION → VOTING → APPROVED → ONBOARDING → CONTRACTED
                                                      └─── REJECTED ─────────────────┘
```

| State | Meaning | Who can advance |
|---|---|---|
| DRAFT | Requirement being written | Admin, Executive |
| OPEN | Vendors invited, can submit | Admin |
| SUBMITTED | All quotes received | Admin |
| EVALUATION | Committee reviewing | All committee |
| VOTING | Active vote in progress | Admin triggers |
| APPROVED | Majority vote passed | System (auto) |
| REJECTED | Vote failed or overridden | President |
| ONBOARDING | Contracts being signed | Admin |
| CONTRACTED | Active vendor | Admin |

### 3.2 Vendor Requirement Card

Each **Requirement** (e.g. "Property Management Platform") is the parent entity:

```
Requirement
├── ID: REQ-2026-001
├── Category: Property Management Platform
├── Description: Full-text description of what we need
├── Budget Range: ₹X – ₹Y per month
├── Timeline: Decision needed by YYYY-MM-DD
├── Evaluation Criteria (weighted):
│   ├── Cost (25%)
│   ├── Features & Fit (30%)
│   ├── Experience / References (20%)
│   ├── Support & SLA (15%)
│   └── Risk / Compliance (10%)
├── Invited Vendors: [MyGate, NoBroker, ...]
├── Status: EVALUATION
└── Documents: [RFP.pdf, Criteria-Matrix.xlsx]
```

### 3.3 Vendor Profile Schema (per vendor, per requirement)

```json
{
  "id": "VND-2026-001-A",
  "requirement_id": "REQ-2026-001",
  "vendor_name": "MyGate",
  "contact_person": "Rajesh Kumar",
  "contact_email": "rajesh@mygate.com",
  "contact_phone": "+91-9876543210",
  "company_website": "https://mygate.com",
  "years_in_business": 8,
  "associations_served": 15000,
  "local_references": [
    { "society": "Brigade Meadows", "contact": "+91-XXXXXXXX" }
  ],
  "proposed_solution": "Full text of their pitch",
  "quote_monthly": 45000,
  "quote_setup": 25000,
  "quote_breakdown": "github://governance-data/vendors/REQ-001/mygate/quote.pdf",
  "features": {
    "visitor_management": true,
    "maintenance_requests": true,
    "accounting": false,
    "community_app": true,
    "vehicle_tracking": true,
    "daily_help_management": false
  },
  "submitted_at": "2026-05-10T10:00:00Z",
  "submitted_by": "committee@utamacs.org",
  "documents": [
    { "name": "Quotation.pdf", "github_path": "vendors/REQ-001/mygate/quotation.pdf", "uploaded_at": "..." }
  ],
  "evaluation_scores": {
    "cost": null,
    "features": null,
    "experience": null,
    "support": null,
    "risk": null
  }
}
```

### 3.4 Side-by-Side Comparison View

The comparison dashboard renders a matrix:

```
┌─────────────────────┬──────────────┬──────────────┬──────────────┐
│ Criterion (Weight)  │  MyGate      │  NoBroker    │  ApartmentAdda│
├─────────────────────┼──────────────┼──────────────┼──────────────┤
│ Monthly Cost (25%)  │ ₹45,000      │ ₹38,000      │ ₹52,000      │
│ Setup Cost          │ ₹25,000      │ ₹0           │ ₹30,000      │
│ Features (30%)      │ ████████ 8/10│ ██████ 6/10  │ █████████9/10│
│ Experience (20%)    │ 8yr, 15K soc │ 5yr, 8K soc  │ 10yr, 20K   │
│ Support SLA (15%)   │ 4hr response │ 8hr response │ 2hr response │
│ Risk Score (10%)    │ Low          │ Medium       │ Low          │
├─────────────────────┼──────────────┼──────────────┼──────────────┤
│ WEIGHTED SCORE      │ 7.4 / 10     │ 6.1 / 10     │ 8.2 / 10     │
│ COMMITTEE VOTES     │ 3            │ 1            │ 5            │
│ STATUS              │ ─            │ ─            │ LEADING      │
└─────────────────────┴──────────────┴──────────────┴──────────────┘
```

### 3.5 Voting Model

**Recommended: Role-Weighted Voting**

| Role | Vote Weight | Rationale |
|---|---|---|
| President | 3× | Final governance authority |
| Secretary | 2× | Operational accountability |
| Treasurer | 2× | Financial oversight |
| Committee Member | 1× | Peer input |
| General Member | 0.5× | Voice but not decision-making |

Rules:
- Voting window: 5 days (configurable)
- Quorum: Minimum 5 committee-weight votes required
- Result: Vendor with highest weighted votes wins
- Tie-breaking: President casts deciding vote
- All votes are permanently recorded (who voted for whom, when, why)

**Vote Record:**
```json
{
  "vote_id": "VOTE-2026-001-0003",
  "requirement_id": "REQ-2026-001",
  "voter_id": "user-uuid",
  "voter_role": "secretary",
  "vote_weight": 2,
  "vendor_voted_for": "VND-2026-001-C",
  "reason": "Best feature coverage for our size; references checked",
  "cast_at": "2026-05-12T14:30:00Z",
  "ip_hash": "sha256-of-ip"
}
```

### 3.6 Decision Record (Permanent)

When selection is finalized, a **Decision Record** is written to Git and cannot be modified:

```json
{
  "decision_id": "DEC-2026-001",
  "requirement_id": "REQ-2026-001",
  "decided_at": "2026-05-15T16:00:00Z",
  "selected_vendor": "VND-2026-001-C",
  "selected_vendor_name": "ApartmentAdda",
  "selection_reason": "Highest weighted score (8.2/10). Strong local references. Best feature match for 200-unit society. Competitive pricing with zero setup cost.",
  "rejected_vendors": [
    {
      "vendor_id": "VND-2026-001-A",
      "vendor_name": "MyGate",
      "rejection_reason": "Higher monthly cost. Visitor management strong but accounting absent."
    },
    {
      "vendor_id": "VND-2026-001-B",
      "vendor_name": "NoBroker",
      "rejection_reason": "Limited committee management features. Support SLA inadequate."
    }
  ],
  "vote_summary": {
    "total_weighted_votes": 18.5,
    "ApartmentAdda": 10.5,
    "MyGate": 5.5,
    "NoBroker": 2.5
  },
  "approved_by_president": { "user_id": "...", "at": "2026-05-15T15:45:00Z", "signature": "OTP-verified" },
  "approved_by_secretary": { "user_id": "...", "at": "2026-05-15T15:50:00Z", "signature": "OTP-verified" },
  "github_commit": "abc123def456"
}
```

### 3.7 Vendor Onboarding Checklist

Once approved, a structured onboarding checklist activates:

```
□ Agreement/contract signed (PDF uploaded)
□ Bank details verified
□ Service start date confirmed
□ Integration/training session scheduled
□ Pilot period defined (30 days recommended)
□ Escalation contact registered
□ Exit clause documented
□ Member communication sent
```

---

## 4. Part 2 — HOTO Management System

### 4.1 HOTO Categories

Based on standard builder-to-association handover practices:

| # | Category | Typical Items |
|---|---|---|
| 1 | Legal & Statutory | Registration docs, bye-laws, RERA |
| 2 | Financial | Maintenance corpus, sinking fund, builder dues |
| 3 | Infrastructure | Building plans, approvals, completion certificate |
| 4 | Common Areas | Club house, gym, pool, landscaping |
| 5 | MEP Systems | Electrical, plumbing, HVAC, lifts |
| 6 | Fire & Safety | NOC, suppression system, extinguishers |
| 7 | IT & Security | CCTV, intercom, access control |
| 8 | Service Contracts | AMC agreements from builder |
| 9 | Inventory | Keys, spares, equipment list |
| 10 | Pending Works | Snagging, defects, commitments |

### 4.2 HOTO Item Status Model

```
NOT_STARTED
    │
    ▼
IN_PROGRESS ──────────────────────┐
    │                             │ (builder delays/issues)
    ▼                             │
UNDER_REVIEW ◄────────────────────┘
    │
    ▼
PENDING_PRESIDENT ──► PENDING_SECRETARY
    │                             │
    └─────────────────────────────┘
                  │
                  ▼
              APPROVED
                  │
                  ▼
            COMPLETED ──────────► DISPUTED (if issue found later)
```

**Status Definitions:**

| Status | Meaning | Who sets it |
|---|---|---|
| NOT_STARTED | Item identified, not yet initiated | System default |
| IN_PROGRESS | Association/builder working on it | Any committee member |
| UNDER_REVIEW | Evidence submitted, being checked | Committee member |
| PENDING_PRESIDENT | Awaiting President's approval | Secretary |
| PENDING_SECRETARY | Awaiting Secretary's approval | President |
| APPROVED | Both approvals received | System (auto) |
| COMPLETED | Physical handover confirmed | Admin |
| DISPUTED | Approved item found deficient later | President or Secretary |

### 4.3 HOTO Item Schema

```json
{
  "item_id": "HOTO-2026-042",
  "category": "MEP Systems",
  "subcategory": "Lifts",
  "title": "Lift Annual Maintenance Contract Transfer",
  "description": "Builder's AMC with KONE Elevators must be transferred to association. Includes maintenance logs for past 2 years.",
  "reference_clause": "Bye-law Clause 12.3 — Common Infrastructure",
  "priority": "HIGH",
  "status": "IN_PROGRESS",
  "previous_state": "Builder-owned AMC, paid by builder",
  "current_state": "Association taking over; builder to formally transfer",
  "expected_outcome": "AMC in association's name, with 1-year prepaid by builder",
  "builder_commitment": "Transfer within 30 days of possession date",
  "deadline": "2026-06-15",
  "responsible_committee_member": "user-uuid-of-treasurer",
  "builder_contact": "Ramesh Reddy, +91-XXXXXXXXXX",
  "created_at": "2026-05-01T10:00:00Z",
  "created_by": "user-uuid",
  "last_updated_at": "2026-05-06T09:00:00Z",
  "status_history": [
    {
      "from": "NOT_STARTED",
      "to": "IN_PROGRESS",
      "changed_by": "user-uuid",
      "changed_at": "2026-05-03T11:00:00Z",
      "note": "Contacted builder's PM Ramesh regarding transfer"
    }
  ],
  "documents": [
    {
      "doc_id": "DOC-042-001",
      "name": "Original KONE AMC.pdf",
      "github_path": "hoto/MEP-Systems/Lifts/HOTO-042/original-kone-amc.pdf",
      "uploaded_by": "user-uuid",
      "uploaded_at": "2026-05-04T14:00:00Z",
      "description": "Original contract scanned copy"
    }
  ],
  "approvals": {
    "president": null,
    "secretary": null
  },
  "tags": ["lift", "AMC", "KONE", "transfer"],
  "github_path": "hoto/MEP-Systems/Lifts/HOTO-042/item.json"
}
```

### 4.4 Approval Gate Rules

```
Rule 1: Only President (role=president) can set president approval
Rule 2: Only Secretary (role=secretary) can set secretary approval  
Rule 3: Both must approve within 7 days of each other (else item returns to UNDER_REVIEW)
Rule 4: Neither can approve their own submissions
Rule 5: Approved items can only be DISPUTED, never reverted to earlier states
Rule 6: Disputed items require a new approval cycle
```

### 4.5 Discussion & Comment System

Each HOTO item has a threaded discussion:

```
HOTO-042: Lift AMC Transfer
│
├── [2026-05-04] Treasurer: "Contacted KONE. They need NOC from builder."
│   └── [2026-05-04] Secretary: "Builder's PM said NOC will come within a week. Following up."
│       └── [2026-05-05] President: "Agreed. If not received by 12th, escalate to builder MD."
│           └── ✓ Acknowledged by: Secretary, Treasurer, 3 others
│
├── [2026-05-06] Committee Member Ravi: "I can reach KONE's Hyd office directly if needed."
│   └── ✓ Acknowledged by: Treasurer
│
└── [Pinned] President: "This is a HIGH priority item. All builder AMCs must transfer before monsoon."
```

**Comment Schema:**
```json
{
  "comment_id": "CMT-042-0007",
  "item_id": "HOTO-2026-042",
  "parent_comment_id": "CMT-042-0005",
  "author_id": "user-uuid",
  "author_name": "T.V.S. Sudheer",
  "author_role": "president",
  "content": "Agreed. If not received by 12th, escalate to builder MD.",
  "is_pinned": false,
  "attachments": [],
  "acknowledgedBy": ["user-uuid-2", "user-uuid-3"],
  "created_at": "2026-05-05T18:30:00Z",
  "edited_at": null,
  "github_commit": "def789abc123"
}
```

---

## 5. Part 3 — Workflow Engine

### 5.1 Generic State Machine

Both HOTO items and Vendor Requirements share the same underlying workflow engine. Each workflow type defines its own allowed transitions.

```
WorkflowItem {
  id, type (HOTO | VENDOR_REQ | DECISION | GENERAL),
  status,
  allowed_transitions: Map<currentStatus, nextStatuses[]>,
  required_roles: Map<transition, role[]>,
  hooks: Map<transition, action[]>
}
```

### 5.2 Transition Rules Table

| From | To | Allowed By | Hook |
|---|---|---|---|
| NOT_STARTED | IN_PROGRESS | committee, executive, admin | notify_responsible |
| IN_PROGRESS | UNDER_REVIEW | committee, executive, admin | notify_approvers |
| UNDER_REVIEW | IN_PROGRESS | committee, executive | notify_responsible |
| UNDER_REVIEW | PENDING_PRESIDENT | secretary, admin | notify_president |
| PENDING_PRESIDENT | PENDING_SECRETARY | president | notify_secretary |
| PENDING_SECRETARY | APPROVED | secretary | notify_all, write_approval_to_git |
| APPROVED | COMPLETED | admin | notify_all |
| APPROVED | DISPUTED | president, secretary | notify_all, reopen_approval |
| COMPLETED | DISPUTED | president | notify_all |

### 5.3 Role-Based Permission Matrix

| Action | Member | Committee | Executive | Secretary | President | Admin |
|---|---|---|---|---|---|---|
| View all items | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Add comment | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Acknowledge comment | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Upload document | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| Create HOTO item | - | - | ✓ | ✓ | ✓ | ✓ |
| Advance status | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| President approval | - | - | - | - | ✓ | ✓* |
| Secretary approval | - | - | - | ✓ | - | ✓* |
| Cast vote | - | ✓ | ✓ | ✓ | ✓ | - |
| Create vendor req | - | - | ✓ | ✓ | ✓ | ✓ |
| Trigger voting | - | - | - | ✓ | ✓ | ✓ |
| Override/dispute | - | - | - | ✓ | ✓ | ✓ |

*Admin can act as surrogate only with explicit delegation recorded.

### 5.4 Notification Design

Notifications are sent via Supabase edge functions + email (Resend):

| Trigger | Recipients | Channel |
|---|---|---|
| New HOTO item created | All committee | Email + Portal bell |
| Status changed | Responsible member + approvers | Email |
| New comment on item | All participants in thread | Portal bell |
| Item reaches PENDING_PRESIDENT | President | Email (urgent flag) |
| Vote opened | All eligible voters | Email |
| Vote closing in 24h | Non-voters | Email reminder |
| Decision made | All members | Email |
| Vendor onboarding started | Admin + Secretary | Email |

### 5.5 Document Upload Workflow

```
1. Member selects file in browser
2. Portal API receives file as multipart
3. API authenticates user (JWT)
4. API uses GitHub App token to:
   a. Base64 encode file
   b. Call PUT /repos/utamacs/governance-data/contents/{path}
   c. Path: {module}/{category}/{item-id}/{filename}
   d. Commit message: "docs: upload {filename} for {item-id} by {username}"
5. GitHub returns SHA + URL
6. API stores reference in Supabase (item_documents table)
7. API appends document metadata to item's JSON in governance-data
8. All commits visible in GitHub commit history = audit trail
```

---

## 6. Part 4 — Dashboard & Tracking

### 6.1 Dashboard Layout

```
┌────────────────────────────────────────────────────────────────┐
│  GOVERNANCE DASHBOARD          Last updated: 6 May 2026 09:00  │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  HOTO PROGRESS                    VENDOR DECISIONS             │
│  ┌──────────────────────┐         ┌───────────────────────┐   │
│  │ ████████████░░ 68%   │         │ 2 of 5 decided        │   │
│  │                      │         │                       │   │
│  │ Total:        85      │         │ Property Mgmt: ✓ Done │   │
│  │ Completed:    22      │         │ Accounting:    ✓ Done │   │
│  │ Approved:     16      │         │ Facility Mgmt: ⏳ Vote│   │
│  │ In Progress:  28      │         │ Security:      📋 Eval│   │
│  │ Not Started:  19      │         │ Legal Counsel: 📋 Eval│   │
│  └──────────────────────┘         └───────────────────────┘   │
│                                                                │
│  PENDING YOUR ACTION              CRITICAL DEADLINES           │
│  ┌──────────────────────┐         ┌───────────────────────┐   │
│  │ ⚠️  3 items need     │         │ 🔴 Lift AMC: 9 days   │   │
│  │    your approval     │         │ 🟡 OC Doc: 15 days    │   │
│  │ 📋 2 votes awaiting  │         │ 🟡 Corpus: 20 days    │   │
│  │    your input        │         │ 🟢 CCTV: 45 days      │   │
│  └──────────────────────┘         └───────────────────────┘   │
│                                                                │
│  HOTO BY CATEGORY                                              │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ Legal & Statutory   ████████████████████░░░░░  80%  12/15│ │
│  │ Financial           ████████░░░░░░░░░░░░░░░░░  33%   4/12│ │
│  │ Infrastructure      ████████████░░░░░░░░░░░░░  50%   6/12│ │
│  │ Common Areas        ████████████████░░░░░░░░░  65%   8/12│ │
│  │ MEP Systems         ████████░░░░░░░░░░░░░░░░░  40%   8/20│ │
│  │ Fire & Safety       ████████████████████████░  90%   9/10 │ │
│  │ IT & Security       ████████████░░░░░░░░░░░░░  50%   2/4  │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  RECENT ACTIVITY                                               │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ 09:15 Secretary approved HOTO-042 (Lift AMC)             │ │
│  │ 08:50 Ravi commented on HOTO-038 (Sinking Fund)          │ │
│  │ 08:30 Vendor vote closed — ApartmentAdda selected         │ │
│  │ Yesterday  President approved HOTO-041                    │ │
│  └──────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

### 6.2 HOTO Item List View

```
Filter: [All] [Not Started] [In Progress] [Pending Approval] [Completed]
Sort:   [Priority] [Deadline] [Category] [Last Updated]
Search: [                    ]

┌──────┬────────────────────────────────┬──────────────┬─────────────┬──────────────┐
│  ID  │ Title                          │ Category     │ Status      │ Deadline     │
├──────┼────────────────────────────────┼──────────────┼─────────────┼──────────────┤
│ 042  │ Lift AMC Transfer              │ MEP Systems  │ 🟡 In Prog  │ 15 Jun 🔴    │
│ 038  │ Sinking Fund Transfer          │ Financial    │ 🟠 Pend Pr. │ 30 Jun       │
│ 012  │ Occupancy Certificate          │ Legal        │ ✅ Completed│ Done         │
│ 055  │ CCTV System Handover           │ IT/Security  │ ⬜ Not Start│ 20 Jul       │
└──────┴────────────────────────────────┴──────────────┴─────────────┴──────────────┘
```

### 6.3 Metrics API

The dashboard pulls from two sources:
- **Supabase**: item counts, status breakdowns (fast, real-time)
- **GitHub**: document counts, commit history (batch-refreshed every hour)

```typescript
// /api/v1/governance/dashboard
{
  hoto: {
    total: 85,
    by_status: { not_started: 19, in_progress: 28, under_review: 12, pending_approval: 8, approved: 16, completed: 22 },
    by_category: { legal: {...}, financial: {...}, ... },
    overdue: 3,
    due_this_week: 7
  },
  vendors: {
    total_requirements: 5,
    decided: 2,
    in_voting: 1,
    in_evaluation: 2
  },
  pending_my_action: {
    approvals_needed: 3,
    votes_pending: 2,
    comments_unread: 5
  }
}
```

---

## 7. Part 5 — Git as Storage Backend

### 7.1 Repository Structure (governance-data)

```
utamacs/governance-data/
│
├── README.md                          # Human-readable index
├── _meta/
│   └── schema-version.json            # Schema versioning
│
├── hoto/
│   ├── _index.json                    # All items, lightweight index
│   ├── Legal-Statutory/
│   │   ├── HOTO-001/
│   │   │   ├── item.json              # Full item record
│   │   │   ├── comments.json          # All comments, append-only
│   │   │   ├── approvals.json         # Approval records
│   │   │   └── documents/
│   │   │       ├── society-registration.pdf
│   │   │       └── bye-laws.pdf
│   │   └── HOTO-002/
│   │       └── ...
│   ├── Financial/
│   ├── Infrastructure/
│   ├── Common-Areas/
│   ├── MEP-Systems/
│   ├── Fire-Safety/
│   ├── IT-Security/
│   ├── Service-Contracts/
│   ├── Inventory/
│   └── Pending-Works/
│
├── vendors/
│   ├── _index.json
│   ├── REQ-2026-001-Property-Management/
│   │   ├── requirement.json
│   │   ├── votes.json
│   │   ├── decision.json              # Written once, immutable
│   │   ├── mygate/
│   │   │   ├── profile.json
│   │   │   └── documents/
│   │   │       └── quotation.pdf
│   │   ├── nobroker/
│   │   └── apartmentadda/
│   └── REQ-2026-002-Accounting/
│
├── decisions/
│   └── DEC-2026-001.json              # Permanent decision records
│
└── audit/
    └── 2026-05/
        ├── 2026-05-06.jsonl           # Append-only audit log (one JSON per line)
        └── ...
```

### 7.2 Index File Strategy

`hoto/_index.json` — lightweight, loaded by the portal for list views:

```json
{
  "generated_at": "2026-05-06T09:00:00Z",
  "total": 85,
  "items": [
    {
      "id": "HOTO-2026-042",
      "category": "MEP Systems",
      "title": "Lift AMC Transfer",
      "status": "IN_PROGRESS",
      "priority": "HIGH",
      "deadline": "2026-06-15",
      "responsible": "treasurer-uuid",
      "last_updated": "2026-05-06T09:00:00Z"
    }
  ]
}
```

Index is regenerated on every write operation by the API. Full item detail is only fetched when a user opens a specific item.

### 7.3 Commit Message Convention

Every API write to governance-data uses a structured commit message:

```
{action}({item-id}): {description}

action: create | update | comment | upload | approve | vote | close
Examples:
  create(HOTO-042): new HOTO item — Lift AMC Transfer
  update(HOTO-042): status changed IN_PROGRESS → UNDER_REVIEW by treasurer
  comment(HOTO-042): new comment by president
  upload(HOTO-042): uploaded original-kone-amc.pdf by treasurer
  approve(HOTO-042): president approval granted
  vote(REQ-001): vote cast for ApartmentAdda by secretary
  close(REQ-001): vendor selected — ApartmentAdda (decision DEC-2026-001)
```

This makes `git log` a human-readable audit trail.

### 7.4 GitHub App Setup

The portal uses a **GitHub App** (not a personal access token) for security:

```
GitHub App: utamacs-governance-bot
Permissions:
  - Contents: Read & Write (for data repo only)
  - Metadata: Read
Installation: utamacs/governance-data only
Secret: Stored in Vercel environment variable GITHUB_APP_PRIVATE_KEY
```

This means the bot has no access to the website code repo — data repo only.

### 7.5 Non-Technical User Experience

Users never see Git. The abstraction:

```
User clicks "Submit for Review"
    ↓
Portal shows loading spinner
    ↓
API authenticates user
API updates item.json (read → modify → write to GitHub)
API updates _index.json
API logs to audit/YYYY-MM/YYYY-MM-DD.jsonl
API sends email notifications
    ↓
Portal shows success toast: "Status updated. President has been notified."
    ↓
GitHub has: a new commit, permanent audit trail, diff showing exactly what changed
```

---

## 8. Part 6 — Data Models

### 8.1 Supabase Tables (relational metadata, fast queries)

```sql
-- Users extended profile (links to Supabase auth)
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users,
  society_id UUID NOT NULL,
  full_name TEXT NOT NULL,
  unit_number TEXT,
  block TEXT,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'member',
  -- role: member | committee | executive | secretary | president | admin
  role_expires_at TIMESTAMPTZ,
  residency_type TEXT DEFAULT 'owner',
  move_in_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- HOTO Items (mirror of governance-data JSON, for fast queries)
CREATE TABLE hoto_items (
  id TEXT PRIMARY KEY,              -- 'HOTO-2026-042'
  society_id UUID NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT,
  title TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'NOT_STARTED',
  priority TEXT DEFAULT 'MEDIUM',
  deadline DATE,
  responsible_user_id UUID REFERENCES profiles,
  created_by UUID REFERENCES profiles,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_updated_at TIMESTAMPTZ DEFAULT NOW(),
  github_path TEXT,                 -- path in governance-data repo
  president_approved_at TIMESTAMPTZ,
  secretary_approved_at TIMESTAMPTZ
);

-- Vendor Requirements
CREATE TABLE vendor_requirements (
  id TEXT PRIMARY KEY,              -- 'REQ-2026-001'
  society_id UUID NOT NULL,
  category TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  budget_min INTEGER,
  budget_max INTEGER,
  deadline DATE,
  status TEXT NOT NULL DEFAULT 'DRAFT',
  voting_opens_at TIMESTAMPTZ,
  voting_closes_at TIMESTAMPTZ,
  selected_vendor_id TEXT,
  created_by UUID REFERENCES profiles,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vendors (per requirement)
CREATE TABLE vendors (
  id TEXT PRIMARY KEY,              -- 'VND-2026-001-A'
  requirement_id TEXT REFERENCES vendor_requirements,
  vendor_name TEXT NOT NULL,
  contact_person TEXT,
  contact_email TEXT,
  contact_phone TEXT,
  quote_monthly INTEGER,
  quote_setup INTEGER,
  submitted_at TIMESTAMPTZ,
  github_path TEXT
);

-- Votes
CREATE TABLE votes (
  id TEXT PRIMARY KEY,
  requirement_id TEXT REFERENCES vendor_requirements,
  voter_id UUID REFERENCES profiles,
  vendor_id TEXT REFERENCES vendors,
  vote_weight NUMERIC NOT NULL,
  reason TEXT,
  cast_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (requirement_id, voter_id)   -- one vote per requirement per member
);

-- Comments (both HOTO and Vendor items)
CREATE TABLE comments (
  id TEXT PRIMARY KEY,
  item_type TEXT NOT NULL,          -- 'HOTO' | 'VENDOR_REQ'
  item_id TEXT NOT NULL,
  parent_comment_id TEXT REFERENCES comments,
  author_id UUID REFERENCES profiles,
  content TEXT NOT NULL,
  is_pinned BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  edited_at TIMESTAMPTZ,
  github_commit TEXT
);

-- Comment acknowledgements
CREATE TABLE comment_acknowledgements (
  comment_id TEXT REFERENCES comments,
  user_id UUID REFERENCES profiles,
  acknowledged_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (comment_id, user_id)
);

-- Document references
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  item_type TEXT NOT NULL,
  item_id TEXT NOT NULL,
  name TEXT NOT NULL,
  github_path TEXT NOT NULL,
  github_sha TEXT,
  uploaded_by UUID REFERENCES profiles,
  uploaded_at TIMESTAMPTZ DEFAULT NOW(),
  description TEXT,
  file_size_bytes INTEGER
);

-- Audit log (append-only)
CREATE TABLE audit_log (
  id BIGSERIAL PRIMARY KEY,
  society_id UUID NOT NULL,
  actor_id UUID REFERENCES profiles,
  action TEXT NOT NULL,
  resource_type TEXT NOT NULL,
  resource_id TEXT NOT NULL,
  old_values JSONB,
  new_values JSONB,
  ip_hash TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### 8.2 Approval Record Schema

```typescript
interface ApprovalRecord {
  item_id: string;
  approver_id: string;
  approver_role: 'president' | 'secretary';
  approved_at: string;        // ISO timestamp
  note?: string;              // Optional approval note
  otp_verified: boolean;      // Future: require OTP for approvals
  github_commit: string;      // Commit that recorded this approval
}
```

### 8.3 Evaluation Criteria Schema

```typescript
interface EvaluationCriteria {
  requirement_id: string;
  criteria: {
    key: string;              // 'cost' | 'features' | 'experience' ...
    label: string;            // Display name
    weight: number;           // 0–100, all must sum to 100
    description: string;      // What to look for
  }[];
}

interface VendorScore {
  vendor_id: string;
  scored_by: string;          // user_id
  scores: Record<string, number>; // criteria_key → 0–10
  notes: Record<string, string>;  // criteria_key → comment
  scored_at: string;
}
```

---

## 9. Part 7 — UX Design

### 9.1 Navigation Structure

```
Portal Navigation
├── Home (Dashboard)
├── HOTO Management
│   ├── Overview (progress by category)
│   ├── All Items (filterable list)
│   ├── My Actions (items needing my attention)
│   └── [Admin] Create Item
├── Vendor Evaluation
│   ├── Requirements Board
│   ├── [Admin] New Requirement
│   └── Decisions Archive
├── Documents (cross-item search)
└── Activity Feed (all recent actions)
```

### 9.2 Key Screens

#### Screen 1: HOTO Item Detail

```
┌───────────────────────────────────────────────────────────────┐
│ ← HOTO Items   HOTO-042 · MEP Systems · Lifts                │
│                                                               │
│ Lift Annual Maintenance Contract Transfer           🟡 HIGH   │
│ In Progress · Due 15 Jun 2026 (9 days)                       │
│                                                               │
│ ┌─ Status Timeline ──────────────────────────────────────┐   │
│ │ ✓ Not Started → ✓ In Progress → ○ Under Review →      │   │
│ │ ○ Pend. President → ○ Pend. Secretary → ○ Approved    │   │
│ └────────────────────────────────────────────────────────┘   │
│                                                               │
│ ┌─ Details ──────────────────────────────────────────────┐   │
│ │ Previous State: Builder-owned AMC with KONE            │   │
│ │ Current State:  Association taking over                │   │
│ │ Expected:       AMC in association name, 1-yr prepaid  │   │
│ │ Responsible:    Ravi Kumar (Treasurer)                 │   │
│ │ Builder Contact: Ramesh Reddy · +91-XXXXXXXXXX         │   │
│ └────────────────────────────────────────────────────────┘   │
│                                                               │
│ ┌─ Documents (2) ────────────────────────────────────────┐   │
│ │ 📄 Original KONE AMC.pdf         4 May  [View] [⬇]   │   │
│ │ 📄 Transfer Request Letter.pdf   5 May  [View] [⬇]   │   │
│ │ [+ Upload Document]                                    │   │
│ └────────────────────────────────────────────────────────┘   │
│                                                               │
│ ┌─ Discussion (7 comments) ──────────────────────────────┐   │
│ │ [President] Pinned: HIGH priority. All AMCs before     │   │
│ │   monsoon.                                             │   │
│ │                                                        │   │
│ │ [Treasurer] Contacted KONE. They need NOC from builder │   │
│ │   [Secretary ↩] Builder's PM said NOC in a week...    │   │
│ │     [President ↩] If not by 12th, escalate to MD.     │   │
│ │       ✓ Acknowledged by Secretary, Treasurer +3        │   │
│ │                                                        │   │
│ │ [Add a comment...]                          [Submit]   │   │
│ └────────────────────────────────────────────────────────┘   │
│                                                               │
│ ┌─ Actions ──────────────────────────────────────────────┐   │
│ │ [Mark as Under Review]  ← visible to committee+       │   │
│ │ [Approve — President]   ← visible to president only   │   │
│ └────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────┘
```

#### Screen 2: Vendor Comparison Dashboard

```
┌───────────────────────────────────────────────────────────────┐
│ Property Management Platform · EVALUATION PHASE               │
│                                                               │
│ Vendors: MyGate | NoBroker | ApartmentAdda                    │
│                                                               │
│ ┌── Scores ────────────────────────────────────────────────┐  │
│ │ Criterion          Weight  MyGate  NoBroker  ApartAdda  │  │
│ │ Cost               25%     6.5     8.0       7.5        │  │
│ │ Features & Fit     30%     8.0     6.0       9.0        │  │
│ │ Experience         20%     8.5     6.5       9.0        │  │
│ │ Support & SLA      15%     7.0     5.5       8.5        │  │
│ │ Risk               10%     8.0     6.0       8.0        │  │
│ │ ─────────────────────────────────────────────────────── │  │
│ │ WEIGHTED TOTAL     100%    7.70    6.55      8.50       │  │
│ └──────────────────────────────────────────────────────────┘  │
│                                                               │
│ Documents          [Q] [Q] [Q]    (Q = Quotation uploaded)   │
│                                                               │
│ Committee Comments: 12 on MyGate · 8 on NoBroker · 15 on AA │
│                                                               │
│ [View MyGate Profile] [View NoBroker] [View ApartmentAdda]   │
│                                                               │
│ Voting: Opens 10 May at 10:00 · Closes 15 May at 23:59       │
│ Eligible voters: 8 · Votes cast so far: 0                    │
│                                                               │
│ [Open Voting Now]  ← admin/secretary only                    │
└───────────────────────────────────────────────────────────────┘
```

#### Screen 3: Voting Screen

```
┌───────────────────────────────────────────────────────────────┐
│ Cast Your Vote · Property Management Platform                 │
│ Voting closes in: 3 days 14 hours                            │
│                                                               │
│ Your vote is permanent. You may not change it after submit.  │
│                                                               │
│ ○  MyGate          Score: 7.70   ₹45,000/mo                 │
│ ○  NoBroker        Score: 6.55   ₹38,000/mo                 │
│ ●  ApartmentAdda   Score: 8.50   ₹52,000/mo  ← selected     │
│                                                               │
│ Reason for your vote (required):                             │
│ ┌─────────────────────────────────────────────────────────┐  │
│ │ Best feature coverage. Local references verified.       │  │
│ │ Support SLA is best for our society size.               │  │
│ └─────────────────────────────────────────────────────────┘  │
│                                                               │
│ [Confirm Vote]   ← requires typing "CONFIRM" then submitting │
└───────────────────────────────────────────────────────────────┘
```

### 9.3 Mobile Considerations

- All pages use the existing Tailwind responsive grid
- HOTO item detail collapses to single-column on mobile
- Comparison table scrolls horizontally on mobile (sticky first column)
- Voting UI is tap-friendly (large radio buttons)
- Document upload works from phone camera (accept="image/*,application/pdf")
- Comment composer is a full-width textarea with submit button below

---

## 10. Part 8 — Industry Best Practices

### 10.1 Governance Models from Real Associations

| Practice | Source | Applied Here |
|---|---|---|
| Dual-signature approvals | RWA governance in India | President + Secretary both required |
| Immutable decision records | Corporate board minutes | Decision JSON written once, never edited |
| Quorum requirements | Cooperative Society Act, Telangana | Minimum 5 weighted votes for validity |
| Conflict of interest disclosure | Listed company governance | Committee member recuses from vendor vote if related |
| 30-day notice for major decisions | RERA & Cooperative bye-laws | Voting opens 30 days after requirement published |
| Physical + digital evidence | Legal defensibility | Documents stored in Git, not just DB |

### 10.2 Lessons from Platforms

| Platform | What they do well | What to avoid/improve |
|---|---|---|
| **MyGate** | Visitor management, guard app | Closed ecosystem, high cost at scale |
| **NoBroker Hood** | Marketplace integration | Finance-heavy, weak governance features |
| **ApartmentAdda** | Accounting + community | Complex UI, slow mobile |
| **ADDA.io** | Committee management | Enterprise pricing, overkill for 200 units |

**Key insight from all platforms:** Members disengage when they can't see decisions being made. Radical transparency (every vote, every comment, every approval visible to all) drives participation. This design prioritizes that above all.

### 10.3 Vendor Evaluation Framework (Indian Context)

Standard RFP framework adapted for apartment associations:

1. **Pre-qualification**: Company age ≥ 3 years, serving ≥ 50 societies
2. **Technical bid**: Feature checklist, integration capabilities, SLA terms
3. **Financial bid**: Monthly cost per unit, setup cost, contract lock-in period
4. **Reference check**: Mandatory call to 2 similar societies (similar size, similar city)
5. **Pilot**: 30-day trial with rollback clause before final commitment
6. **Exit clause**: Contract must allow 60-day exit without penalty

### 10.4 HOTO Best Practices

From RERA and cooperative society handover standards:

- **Document everything in writing** before accepting handover
- **Independent structural audit** before accepting building
- **Pending work register** (snagging list) with builder commitment dates
- **Corpus fund transfer** must have CA certificate
- **All AMCs must be transferred** (not just noted) before accepting
- **NOC from all utility providers** (electricity, water, drainage)
- **Complete the sinking fund** as per RERA requirement (2.5% of apartment cost)

---

## 11. Part 9 — Implementation Plan

### Phase 1: MVP (6–8 weeks)

**Goal: Basic HOTO tracking live for all members**

| Week | Task |
|---|---|
| 1–2 | Set up governance-data repo structure; create 85 HOTO items as JSON from master checklist |
| 2–3 | Build HOTO item list page (`/portal/hoto`) with filter/sort |
| 3–4 | Build HOTO item detail page with status timeline, document list, comment thread |
| 4–5 | Build status transition API (`PUT /api/v1/hoto/:id/status`) with role checks |
| 5–6 | Build document upload API (→ GitHub) and comment API |
| 6–7 | Build approval gate (President + Secretary endpoints) |
| 7–8 | Build basic dashboard (counts + category progress bars) |

**Deliverable:** Every committee member can see all HOTO items, upload documents, comment, and approve. President/Secretary can sign off. Dashboard shows progress.

### Phase 2: Vendor Management (4–6 weeks)

**Goal: Structured vendor evaluation for all 5 pending decisions**

| Week | Task |
|---|---|
| 1–2 | Build vendor requirement board + requirement detail page |
| 2–3 | Build vendor profile pages + comparison matrix |
| 3–4 | Build voting system (weighted votes, quorum check, vote recording to Git) |
| 4–5 | Build decision record writer + vendor decision archive |
| 5–6 | Build vendor onboarding checklist (reuses HOTO item engine) |

### Phase 3: Enhancements (4 weeks)

**Goal: Better UX, notifications, mobile polish**

| Week | Task |
|---|---|
| 1 | Email notifications via Resend for all workflow transitions |
| 2 | Comment acknowledgements + threading |
| 3 | Full-text document search (GitHub API search) |
| 4 | Mobile UX audit + fixes; accessibility review |

### Phase 4: Advanced (Post-HOTO, 8+ weeks)

**Goal: Long-term governance platform**

- General decision workflow (any resolution, not just HOTO/vendors)
- Meeting management (agenda, minutes as HOTO-style items)
- Maintenance request lifecycle management
- Annual general body meeting vote system

### 11.1 Technology Stack

```
Frontend:      Astro SSR (already in use) — no change
Styling:       Tailwind CSS (already in use) — no change
Auth:          Supabase (already in use) — extend with new roles
Database:      Supabase PostgreSQL — new tables per data model above
File storage:  GitHub (governance-data repo) via GitHub App
Email:         Resend (when domain verified) — extend existing setup
GitHub App:    New app for governance-data writes
Charts:        Chart.js (CDN, no build step) or inline SVG
```

**Estimated new code:** ~3,000–4,500 lines across API routes, Astro pages, and shared utilities.

### 11.2 GitHub App Setup (one-time)

```
1. Go to github.com/settings/apps/new
2. Name: utamacs-governance-bot
3. Permissions: Contents (R/W) on governance-data repo only
4. Generate private key
5. Install on utamacs/governance-data
6. Set in Vercel:
   GITHUB_APP_ID=...
   GITHUB_APP_INSTALLATION_ID=...
   GITHUB_APP_PRIVATE_KEY=...
```

### 11.3 New Supabase Tables (migration)

Create `026_governance_schema.sql` with all tables from Part 6 above.

---

## 12. Trade-offs & Risks

| Trade-off | Decision | Rationale |
|---|---|---|
| GitHub API rate limit (5000 req/hr) | Use Supabase as primary store, GitHub for documents + audit only | At 100 users, well within limits |
| Git history is public if repo is public | governance-data must be PRIVATE | No member data in a public repo |
| PDF preview in browser | Use GitHub's raw download link with signed headers | Avoid storing duplicate copies |
| Weighted votes vs simple majority | Weighted (President 3×) | Aligns with bye-law authority hierarchy |
| President/Secretary both required for approval | Yes, non-negotiable | Legal defensibility, prevents unilateral decisions |
| Supabase free tier limits | Current plan should handle Phase 1–2 comfortably | Re-evaluate at Phase 3 if database rows > 500K |

### 12.1 Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Member adoption low | Medium | High | Simple mobile UI; WhatsApp link to items |
| Builder delays HOTO items | High | Medium | Track separately; escalation workflow built in |
| GitHub API changes | Low | High | Abstract behind service layer; swap easily |
| Data loss | Very Low | High | Git + Supabase = two copies; Git is immutable |
| Vote manipulation | Low | High | One vote per user (DB unique constraint); vote weight by role stored at vote time |
| President/Secretary unavailable | Medium | Medium | Admin surrogate role with delegation record |

---

*Document version 1.0 · Authored May 2026 · Review: July 2026 post-Phase 1*
