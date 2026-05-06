# UTA MACS — HOTO & Vendor Management Platform Design
## Revised Complete System Architecture, Data Model, UX & Implementation Plan

**Society:** Urban Trilla Apartment Owners Mutually Aided Cooperative Maintenance Society Limited  
**Registration No:** TG/RRD/MACS/2026-15/FOW & M (registered 10-02-2026)  
**Location:** SY NO:425/2/1, Kondakal Village, Shankarpally Mandal, Rangareddy District, Telangana  
**Builder (Promoter):** Ankura Homes | **HOTO Consultant:** Ascenza Global Infra Care Pvt Ltd  
**HOTO Start Date:** June 1, 2026 | **Maintenance Tracking From:** May 1, 2025  
**Document Version:** 2.0 — May 2026 (post requirements clarification)

---

## Table of Contents

1. [What We Are Building and Why](#1-what-we-are-building-and-why)
2. [Byelaw Governance Rules Hardcoded into the System](#2-byelaw-governance-rules-hardcoded-into-the-system)
3. [System Architecture](#3-system-architecture)
4. [Module 1 — HOTO Management](#4-module-1--hoto-management)
5. [Module 2 — Snag List Management](#5-module-2--snag-list-management)
6. [Module 3 — Vendor Evaluation & Selection](#6-module-3--vendor-evaluation--selection)
7. [Module 4 — Financial Tracking (HOTO Support)](#7-module-4--financial-tracking-hoto-support)
8. [Module 5 — Formal Notice Generation](#8-module-5--formal-notice-generation)
9. [Workflow Engine & Approval Delegation](#9-workflow-engine--approval-delegation)
10. [Dashboard & UX Design](#10-dashboard--ux-design)
11. [Git Storage Strategy](#11-git-storage-strategy)
12. [Data Model](#12-data-model)
13. [Role-Based Access Control](#13-role-based-access-control)
14. [Document Management & Missing Document Alerts](#14-document-management--missing-document-alerts)
15. [Phase-wise Implementation Plan](#15-phase-wise-implementation-plan)
16. [Risks & Trade-offs](#16-risks--trade-offs)

---

## 1. What We Are Building and Why

Urban Trilla MACS has 136 units (40-50 currently occupied), 14 committee members, and is entering the most consequential phase of a cooperative society — the Handover/Takeover from builder Ankura Homes. The HOTO process starts June 1, 2026, has a 45-day Ascenza-led audit timeline, and is expected to span 2-3 months depending on builder responsiveness.

**The problem today:** All evidence, decisions, communications, and tracking live in WhatsApp messages, personal emails, Google Drive folders, and physical files. The two most senior decision-makers (President Bal Reddy and Working President) are non-technical users who are comfortable with WhatsApp. For the system to succeed, it must be simpler than a WhatsApp group in terms of mental load.

**Success definition (your own words):** *"If we were able to build this system that helps all the members go through the HOTO and Vendor selection process seamlessly and effectively with the best possible user experience and context that we can bring to the board, then that is success."*

**The three core pillars:**
1. **Radical simplicity** — President and Working President can use it without training
2. **Complete auditability** — every action permanently recorded; nothing disappears
3. **Byelaw compliance** — governance rules hardcoded, not configurable

---

## 2. Byelaw Governance Rules Hardcoded into the System

These are not design choices — they are legal requirements under your registered Byelaws (Reg No: TG/RRD/MACS/2026-15/FOW & M). Each rule is cited with the exact Byelaw section.

### 2.1 Voting Rules

| Rule | Byelaw Reference | System Implementation |
|---|---|---|
| One apartment = one vote | **§4.16** "one Apartment one vote basis" | Each member gets exactly 1 vote per vote; no weighting |
| Cannot vote if >90 days maintenance arrears | **§4.6** | System checks payment status before showing vote button |
| Board decisions by majority vote | **§7.16(c)** | Simple majority of votes cast |
| President has casting vote on tie | **§7.16(c) & §8.1** | If tied, President gets deciding vote; logged permanently |
| Voting method = show of hands / poll | **§7.9(a)** | Portal voting = digital equivalent of formal poll |
| Board quorum = simple majority of directors | **§7.16(a)** | With 14 directors, minimum 8 must vote for quorum |
| Member can authorize family via registered PoA | **§4.16** | PoA field in member profile; admin must verify and record |

### 2.2 Decision Approval Chain

| Scenario | Byelaw Reference | System Rule |
|---|---|---|
| All HOTO approvals require dual sign-off | **§8.1** (President has general control) + **§8.3** (Secretary implements decisions) | Both President AND Secretary/General Secretary must approve |
| President absent (planned, >7 working days) | **§8.2** | System auto-delegates approvals to Vice President after admin sets delegation |
| President absent (unplanned/urgent) | **§8.2** | Vice President may act immediately; logged for President's review on return |
| Secretary absent (prolonged planned) | **§8.4** | Joint Secretary takes all Secretary functions |

### 2.3 Financial Authority Limits

| Authority | Limit | Byelaw Reference | System Rule |
|---|---|---|---|
| Secretary (urgent remedial) | Up to ₹10,000/- per transaction | **§9.11(a)** | System allows Secretary to approve expenditure ≤₹10K |
| President (urgent remedial) | Up to ₹20,000/- per transaction | **§9.11(a)** | System allows President to approve ≤₹20K |
| Board of Directors | Up to ₹50,000/- per transaction | **§9.11(b)** | Requires Board vote with quorum |
| Beyond ₹50,000/- | General Body Meeting required | **§9.11(b)** | System blocks and flags: "Requires General Body approval" |
| All payments >₹10,000/- | Must be electronic | **§9.11(c)** | System records payment mode; warns if cash indicated |
| No cash payments ever | Absolute prohibition | **§5.3(p) & §9.1** | Cash payment option removed from all screens |

### 2.4 Conflict of Interest

| Rule | Byelaw Reference | System Implementation |
|---|---|---|
| Director must not participate in matter where personally interested | **§7.16(b)** | Conflict of interest flag on any vote/decision; recuse button; recusal permanently logged |
| Office bearers receive no remuneration from society funds | **§3.4(b)** | Any vendor where committee member has interest is flagged |

### 2.5 Transparency & Records

| Rule | Byelaw Reference | System Implementation |
|---|---|---|
| Minutes communicated within 7 days of Board meeting | **§7.16(e)** | System tracks when minutes were uploaded; flags if >7 days |
| Members can inspect records with 10 days notice | **§5.4** | Portal document access; document request feature |
| Financial statements published by 30th September each year | **§9.3** | Dashboard reminder; upload prompt in September |
| Defaulter list published monthly | **§9.6** | Maintenance tracking module; monthly list generation |
| Data retention: 10 years | Your requirement | All records retained minimum 10 years; Git = permanent |

### 2.6 Expulsion & Defaulter Rules

| Rule | Byelaw Reference | System Flag |
|---|---|---|
| Default = failure to pay within time fixed | **§2(e)** | System marks member as defaulter; blocks vote access |
| 2 months arrears = Defaulting Member | **§6.36** | Yellow flag at 60 days |
| 3 months arrears = services can be denied | **§6.37** | Red flag at 90 days; 7-day notice countdown |
| 18% per annum interest on late payments | **§19(e)** | Interest auto-calculated from due date |

---

## 3. System Architecture

### 3.1 Revised Architecture (Reflecting Reality)

```
┌──────────────────────────────────────────────────────────────────┐
│               COMMITTEE MEMBER (any device, browser)            │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  portal.utamacs.org  (Astro SSR on Vercel)                 │  │
│  │                                                             │  │
│  │  Designed for two audiences:                               │  │
│  │  [A] Non-tech (President, Working President): WhatsApp-    │  │
│  │      like simplicity. Big buttons. Clear status. English.  │  │
│  │  [B] Tech-comfortable (12 others): Full feature access     │  │
│  │                                                             │  │
│  │  Modules:                                                   │  │
│  │  /portal/hoto/          HOTO Checklist                     │  │
│  │  /portal/snags/         Snag List (Ascenza punch list)     │  │
│  │  /portal/vendors/       Vendor Evaluation                  │  │
│  │  /portal/finances/      Maintenance & Fund Tracking        │  │
│  │  /portal/notices/       Formal Notice Generator            │  │
│  │  /portal/dashboard      Governance Dashboard               │  │
│  └──────────────────────┬─────────────────────────────────────┘  │
└─────────────────────────┼────────────────────────────────────────┘
                          │ HTTPS
             ┌────────────▼────────────┐
             │  Vercel Serverless       │
             │  API Routes (/api/v1/)   │
             └────┬───────────────┬────┘
                  │               │
     ┌────────────▼──┐   ┌────────▼──────────────────┐
     │  Supabase      │   │  GitHub (governance-data)  │
     │  PostgreSQL    │   │  Private repo              │
     │                │   │                            │
     │  - Auth        │   │  Every write = audit trail │
     │  - Fast queries│   │  Documents + JSON records  │
     │  - Roles       │   │  Permanent history         │
     │  - Maintenance │   │  10-year retention         │
     └────────────────┘   └────────────────────────────┘
```

### 3.2 Two Repos

```
utamacs/utamacs-website      ← Code (this repo, portal.utamacs.org)
utamacs/governance-data      ← Private data repo (Git = database + audit)
```

### 3.3 Committee Structure Mapped to Roles

| Actual Title | System Role | Approval Power |
|---|---|---|
| President | `president` | Final approver; casting vote; delegation to VP |
| Vice President | `vice_president` | Acts as president when delegated |
| Working President | `working_president` | Executive committee member; same as executive |
| General Secretary | `secretary` | Co-approver with President |
| Joint Secretary | `joint_secretary` | Acts as secretary when delegated |
| Treasurer | `treasurer` | Approves financial tracking entries |
| Joint Treasurer | `joint_treasurer` | Acts as treasurer when delegated |
| Executive Member (×7) | `executive` | Comment, vote, upload, advance status |
| General Member | `member` | Read-only portal access |
| Security Guard | `security_guard` | Gate access only (separate features) |

---

## 4. Module 1 — HOTO Management

### 4.1 HOTO Scope (Ascenza-Aligned Categories)

The HOTO checklist is structured to exactly mirror Ascenza Global Infra Care's scope of work:

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

### 4.2 HOTO Item State Machine

```
NOT_STARTED
    │
    ▼
IN_PROGRESS ────────────── (builder delays/issues noted in comments)
    │
    ▼
EVIDENCE_UPLOADED ──────── (photos, certificates, reports uploaded)
    │
    ▼
UNDER_REVIEW ──────────── (committee reviewing evidence)
    │
    ▼
PENDING_PRESIDENT ──────── (Secretary submits for President approval)
    │
    ▼
PENDING_SECRETARY ──────── (President approves, now needs Secretary)
    │
    ▼
APPROVED ────────────────── (both approved — auto by system)
    │
    ▼
COMPLETED ───────────────── (physical handover confirmed)
    │
    └── DISPUTED ────────── (reopen path if deficiency found post-completion)
```

**State Transition Rules:**
- `NOT_STARTED → IN_PROGRESS`: Any executive or above
- `IN_PROGRESS → EVIDENCE_UPLOADED`: Any executive or above (after uploading ≥1 document)
- `EVIDENCE_UPLOADED → UNDER_REVIEW`: Any executive or above
- `UNDER_REVIEW → PENDING_PRESIDENT`: Secretary / Joint Secretary only
- `PENDING_PRESIDENT → PENDING_SECRETARY`: President (or VP if delegated)
- `PENDING_SECRETARY → APPROVED`: Secretary (or Joint Secretary if delegated) — cannot be same person who set PENDING_PRESIDENT
- `APPROVED → COMPLETED`: Admin only (President/Secretary)
- `COMPLETED → DISPUTED`: President or Secretary — requires written reason
- `DISPUTED → UNDER_REVIEW`: System auto-transition; new approval cycle begins

### 4.3 HOTO Item Schema

```json
{
  "item_id": "HOTO-2026-042",
  "ascenza_category": "Technical - Lifts",
  "title": "Lift No. 2 (Block B) AMC Transfer to Association",
  "description": "Full description of what needs to happen and current state",
  "builder_commitment": "Transfer within 30 days of possession",
  "builder_contact": "Ms. Srilatha / Ms. Saritha — Ankura Homes",
  "priority": "HIGH",
  "status": "IN_PROGRESS",
  "previous_state": "Builder-owned AMC with KONE",
  "current_state": "Association taking over; builder to formally transfer",
  "expected_outcome": "AMC in association's name, prepaid 1 year by builder",
  "deadline": "2026-08-01",
  "responsible_member": "user-uuid-treasurer",
  "dependencies": ["HOTO-2026-040"],
  "required_documents": [
    { "name": "Original KONE AMC Contract", "required": true, "uploaded": false },
    { "name": "NOC from Builder for Transfer", "required": true, "uploaded": false },
    { "name": "New AMC Agreement in Association Name", "required": true, "uploaded": false }
  ],
  "rera_escalation_eligible": true,
  "notice_sent": false,
  "notice_date": null,
  "status_history": [...],
  "documents": [...],
  "comments": [...],
  "approvals": { "president": null, "secretary": null },
  "github_path": "hoto/Technical-Lifts/HOTO-042/item.json"
}
```

### 4.4 Evidence Types Accepted

From your answer (Question 11) — committee members inspect, invite external vendors, evidence is photos and Excel files. The system accepts:
- PDFs (statutory documents, certificates, NOCs)
- Images (JPG, PNG — photos from site inspection)
- Excel/CSV (snag lists from Ascenza, inventory lists)
- Word/Work documents
- CAD files (as-built drawings from builder)
- Max file size: GitHub's 100MB limit per file — adequate for all above formats

### 4.5 Ascenza Weekly Report Integration

Ascenza provides weekly status updates and weekly stakeholder meetings. The system creates a "Weekly HOTO Status" entry where:
- Ascenza uploads their weekly status report
- Committee can view and acknowledge
- Items flagged by Ascenza as critical are auto-elevated to HIGH priority

---

## 5. Module 2 — Snag List Management

This is a **separate module** from HOTO items, as you clarified (Answer 6). Snag items come from:
- Ascenza's physical walkthrough punch lists
- Committee member observations
- Resident complaints
- Builder's own punch list

### 5.1 Snag Item States

```
OPEN → IN_PROGRESS → BUILDER_NOTIFIED → BUILDER_COMMITTED → RESOLVED → VERIFIED_CLOSED
                                                                    └── REOPENED
```

### 5.2 Snag Item Features (Full CRUD per your requirement)

- **Create**: Any committee member can create; must set category, location, severity
- **Update**: Any committee member can update description, photos, severity
- **Delete**: Admin only (President/Secretary); deletion is soft-delete with audit log (records who deleted and why)
- **Mark Complete**: Committee member marks "RESOLVED"; President or Secretary verifies and sets "VERIFIED_CLOSED"
- **Status tracking**: Full history with timestamps and who made each change

### 5.3 Snag Item Schema

```json
{
  "snag_id": "SNAG-2026-0089",
  "category": "Civil",
  "subcategory": "Seepage",
  "location": "Block B, Floor 3, Common Corridor",
  "description": "Water seepage from roof visible on corridor ceiling, approximately 2 sq ft area",
  "severity": "MEDIUM",
  "status": "BUILDER_NOTIFIED",
  "reported_by": "user-uuid",
  "reported_date": "2026-06-15",
  "builder_committed_date": "2026-07-01",
  "photos": ["snags/civil/SNAG-089/photo1.jpg", "snags/civil/SNAG-089/photo2.jpg"],
  "ascenza_reference": "Ascenza-Report-Snag-145",
  "notice_sent": true,
  "notice_date": "2026-06-20",
  "formal_notice_doc": "notices/builder/notice-snag-089.pdf",
  "resolution_notes": null,
  "verified_by": null,
  "github_path": "snags/civil/SNAG-089/item.json"
}
```

### 5.4 Bulk Import from Excel

Given that you have photos and Excel files from inspections, the system supports:
- CSV/Excel upload to bulk-create snag items
- Photo folder upload (zipped)
- System parses standard Ascenza Excel format columns automatically

---

## 6. Module 3 — Vendor Evaluation & Selection

### 6.1 Active Vendor Evaluations (Confirmed)

Based on your answer (Q15: active evaluations currently), all 5 vendor categories are live:

| # | Category | Known Vendors | Status |
|---|---|---|---|
| 1 | Property Management Platform | MyGate, NoBroker | Quotes received |
| 2 | Accounting/Finance Tool | Mandix, Hari | Quotes received |
| 3 | Facility Management | Kapston, Kapil | Quotes received |
| 4 | Legal Counsel | TBD | Evaluation |
| 5 | Security Vendor | TBD | Evaluation |

Vendors have visited the site (Q18: yes). Quotes are already in hand (Q17: yes).

### 6.2 Corrected Voting Model (Byelaw Compliant)

**IMPORTANT CORRECTION from initial design:** The initial design used role-weighted voting. That is WRONG. Your byelaws (§4.16) explicitly state **"one Apartment one vote basis"**. This applies to all society decisions.

For committee (Board of Directors) decisions:
- Each director gets exactly 1 vote (§4.16 + §7.16(c))
- Quorum = simple majority of directors = ≥8 of 14 must vote (§7.16(a))
- Result = simple majority of votes cast
- Tie → President has casting vote (§7.16(c))
- All votes are **visible** (transparent, per byelaw spirit and your preference per Q60: go with byelaw norms)

### 6.3 Conflict of Interest (Byelaw §7.16(b))

System enforces: Before voting opens, each member must declare "I have no personal interest in any of the vendors being evaluated" OR flag a conflict. If flagged, they are excluded from the vote for that requirement (recusal is permanent and logged).

### 6.4 Vendor Decision Record (Permanent, Immutable)

Once both President AND Secretary approve the final selection:
```json
{
  "decision_id": "DEC-2026-001",
  "decided_at": "2026-06-15T16:00:00Z",
  "selected_vendor": "VND-001-A",
  "selection_reason": "Full committee text of why selected",
  "vote_summary": { "total_votes_cast": 12, "quorum_met": true, "VendorA": 8, "VendorB": 4 },
  "rejected_vendors": [
    { "vendor": "VendorB", "rejection_reason": "Detailed reason documented" }
  ],
  "president_approval": { "by": "user-uuid", "at": "...", "note": "..." },
  "secretary_approval": { "by": "user-uuid", "at": "...", "note": "..." },
  "byelaw_compliance_note": "Decision made per §7.16(c), quorum §7.16(a) satisfied with 12/14 votes",
  "github_commit": "immutable-sha",
  "can_be_modified": false
}
```

### 6.5 Post-Selection Tracking (Per Q20: Yes, track all)

After vendor selection and contracting:
- Contract upload and key terms extracted
- Renewal date reminder (system alert 90 days before)
- Monthly performance review (committee can rate: Good/Needs Improvement/Poor)
- Complaint logging against vendor
- Contract exit clause tracked

---

## 7. Module 4 — Financial Tracking (HOTO Support)

**Important:** This is NOT a full accounting system. It is a lightweight tracking module to support HOTO — to establish what funds the builder owes, what has been collected, and what has been spent since operations started. Required for:
- Corpus fund transfer verification (builder must hand over)
- Maintenance collection tracking (from May 1, 2025)
- Builder due reconciliation
- Supporting HOTO financial items

### 7.1 What Gets Tracked

```
Maintenance Collection (from May 1, 2025)
├── Per flat: flat number, owner, amount, date paid, payment mode
├── Month-wise summary
├── Defaulter tracking (90-day rule per §4.6)
└── Interest on late payment (18% p.a. per §19(e))

Corpus Fund
├── Received from builder (₹1,36,000 per §4.11 share capital)
├── Interest earned (kept as corpus per §4.11)
└── Transfer status from Ankura Homes

Expenses (tracked against byelaw financial powers)
├── Each expense: amount, payee, date, approved by, payment mode
├── Non-recurring sanction authority auto-applied (§9.11)
└── Alert if expense exceeds delegated authority

Builder Dues Tracker
├── Pending payments from builder
├── Corpus fund owed
├── Maintenance corpus from builder
└── Any committed pending works cost
```

### 7.2 Defaulter List (Byelaw §9.6 + §6.36)

System auto-generates monthly defaulter list:
- 30 days overdue: Reminder email
- 60 days overdue (§6.36): "Defaulting Member" flag; committee notified
- 90 days overdue (§4.6): Vote rights suspended; system blocks voting
- 90+ days overdue (§6.37): Committee prompted to send 7-day notice

---

## 8. Module 5 — Formal Notice Generation

**From your answer (Q12):** When builder doesn't respond, you want formal notices on association letterhead, and if still not resolved, RERA escalation.

This module integrates with the existing letter generation system already built in the portal.

### 8.1 Notice Types

| Notice | Trigger | Template | Next Step |
|---|---|---|---|
| HOTO Item Reminder | Item overdue >30 days | Standard builder follow-up | 2nd notice |
| HOTO Legal Notice | Item overdue >60 days + 1 reminder sent | Formal legal-language notice | RERA escalation |
| Snag Rectification Notice | Snag open >builder-committed date | Standard snag notice | Legal notice |
| Maintenance Defaulter Notice | 90+ days arrears + 7 days warning (§6.37) | Member notice (posted on flat door + notice board) | Legal recovery |

### 8.2 RERA Escalation Tracker

For serious HOTO items (marked as `rera_escalation_eligible: true`):
- System tracks: Notice sent → Response received / No response → RERA filing status
- Documents: Copies of all correspondence automatically attached
- Status: Monitoring / Filed / Resolved

---

## 9. Workflow Engine & Approval Delegation

### 9.1 Delegation Chain (Byelaw Compliant)

```
Default Approval Chain:
President + Secretary (both required)

If President is absent (planned, >7 working days — §8.2):
Admin sets: "President delegation active → Vice President"
Vice President acts as President until delegation is lifted

If President unexpectedly unavailable (urgent matter — §8.2):
Vice President may act immediately
All actions flagged: "Acting on behalf of President per §8.2"
President reviews on return

If Secretary/Gen Secretary absent (planned):
Joint Secretary takes over (§8.4)
Admin activates delegation in settings

If both President and VP unavailable:
System freezes approval gates (shows: "Approval chain unavailable")
Admin must resolve delegation manually
```

### 9.2 Delegation Settings (Admin Only)

```
Admin panel: /portal/admin/delegation

Currently active:
[President] Bal Reddy          → [Delegate] Vice President when absent
[Secretary] [Name]              → [Delegate] Joint Secretary when absent

Activate/Deactivate delegation with:
- Reason (planned absence / unplanned)
- Start date and expected end date
- All actions during delegation clearly marked
```

### 9.3 Notification Design

Given that members check the portal less frequently (Q49), notifications must be email-first:

| Event | Recipients | Channel | Urgency |
|---|---|---|---|
| New HOTO item | All committee | Email | Normal |
| Status changed | Responsible member + approvers | Email | Normal |
| Pending President approval | President (or VP if delegated) | Email with "ACTION REQUIRED" subject | High |
| Vote opened | All eligible voters | Email | High |
| Voting closes in 48 hours | Non-voters | Email reminder | High |
| Snag overdue by builder | Committee | Email | Normal |
| Maintenance default (60 days) | Treasurer + Secretary | Email | High |
| Weekly summary | All committee | Email digest (Sunday evening) | Low |

**WhatsApp fallback (future phase):** For critical approvals, WhatsApp Business API notification. Not in MVP.

---

## 10. Dashboard & UX Design

### 10.1 UX Design Principle: Two Levels

The system must work for **two very different user profiles**:

**Profile A — Non-Tech (President, Working President):**
- Large text, high contrast
- "My Actions" front and center — show only what THEY need to do
- No tables with 10 columns
- Status shown as color + simple word: "Needs Your Approval" (orange) / "Done" (green)
- One-click approval with confirmation dialog
- Mobile-first (they likely use phones)

**Profile B — Tech-Comfortable (other 12 members):**
- Full filtering, sorting, bulk actions
- Detailed timelines, audit logs visible
- Export to Excel/PDF

### 10.2 Dashboard Layout

```
┌────────────────────────────────────────────────────────────────────┐
│  URBAN TRILLA MACS — Governance Dashboard    [Bal Reddy | Log out] │
├──────────────────────────┬─────────────────────────────────────────┤
│                          │                                          │
│  YOUR ACTIONS NEEDED     │  HOTO PROGRESS                          │
│  ┌────────────────────┐  │  ████████████░░░░░ 62%  (Starts 1 Jun) │
│  │ 🔴 2 items need    │  │  Total: 87 items tracked                │
│  │    YOUR APPROVAL   │  │  Approved: 12 · In Progress: 38         │
│  │                    │  │  Not Started: 37                        │
│  │ [View & Approve]   │  │                                          │
│  └────────────────────┘  │  SNAG LIST                              │
│                          │  ████░░░░░░░░░░░░ 28%  (45/160 closed) │
│  ┌────────────────────┐  │  Critical open: 12                      │
│  │ 🟡 3 votes waiting │  │                                          │
│  │    for your input  │  │  VENDOR DECISIONS                       │
│  │                    │  │  2 of 5 finalised                       │
│  │ [Cast Your Vote]   │  │  Property Mgmt: ⏳ Voting open           │
│  └────────────────────┘  │  Accounting: 📋 Under review            │
│                          │                                          │
│  ┌────────────────────┐  │  CRITICAL DEADLINES                     │
│  │ ✅ Nothing else    │  │  🔴 Snag #89 (Seepage): 5 days          │
│  │    needs your      │  │  🟡 Lift AMC: 26 days                   │
│  │    attention today │  │  🟡 Fire NOC: 30 days                   │
│  └────────────────────┘  │                                          │
│                          │  FINANCIAL TRACKING                     │
│  RECENT ACTIVITY         │  Maintenance collected: May 25          │
│  ─────────────────────   │  Defaulters (60+ days): 3 flats         │
│  Today  Secretary        │                                          │
│  approved HOTO-042       │                                          │
│  Yesterday  New snag     │                                          │
│  added by Ravi           │                                          │
└──────────────────────────┴─────────────────────────────────────────┘
```

### 10.3 Key Screen — HOTO Item Detail (Simplified)

```
← HOTO Items

Lift No. 2 AMC Transfer (Block B)              🔴 HIGH PRIORITY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Status: ⏳ In Progress         Due: 1 Aug 2026 (86 days away)

What needs to happen:
Transfer the KONE lift AMC from Ankura Homes to association name.
Builder contact: Ms. Srilatha / Ms. Saritha

━━━━ Documents Required ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
❌ Original KONE AMC Contract     [+ Upload]
❌ NOC from Builder for Transfer   [+ Upload]
❌ New AMC in Association Name     (not yet available)

━━━━ Discussion ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Treasurer]  Contacted KONE. They need NOC from builder first.
  [Secretary ↩]  Srilatha said NOC will come within a week.
    [President ↩]  If not received by 20th, formal notice goes out.

[Write a comment...]                               [Send]

━━━━ Actions ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[Mark as Under Review]   [Send Builder Notice]   [View History]
```

### 10.4 Voting Screen (Clean, Simple)

```
VOTE: Property Management Platform Selection

Voting closes: 12 Jun 2026 at 11:59 PM (7 days remaining)
Committee votes cast: 6 of 14 · Quorum needed: 8

─────────────────────────────────────────────────────────
Your vote is final and will be visible to all members
(per Byelaw §4.16 and society transparency principles)
─────────────────────────────────────────────────────────

○ MyGate          ₹45,000/month   Score: 7.4/10
○ NoBroker        ₹38,000/month   Score: 6.1/10  
● ApartmentAdda   ₹52,000/month   Score: 8.5/10  ← I select this

Why I'm voting for this vendor (required):
┌──────────────────────────────────────────────────────┐
│ Best features for our 136-unit complex. Local        │
│ references verified. Strong SLA commitment.          │
└──────────────────────────────────────────────────────┘

⚠️  Conflict of interest declaration:
☑ I confirm I have no personal interest in any vendor listed

[CONFIRM MY VOTE]
```

### 10.5 Mobile Design Considerations

- All pages work on any Android/iOS browser (no app install)
- Dashboard shows only "My Actions" prominently on mobile
- Swipe to navigate between HOTO items
- Camera button on document upload (takes photo directly)
- Large tap targets (min 48px)

---

## 11. Git Storage Strategy

### 11.1 Repository: utamacs/governance-data (Private)

```
utamacs/governance-data/
│
├── README.md                     # Human readable index with status summary
├── _meta/
│   ├── schema-version.json
│   └── committee-roster.json     # Current committee + delegation status
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
│   ├── Civil/
│   ├── Electrical/
│   ├── Fire-Safety/
│   ├── Security/
│   ├── Landscaping/
│   └── Club-House/
│
├── vendors/
│   ├── _index.json
│   ├── REQ-2026-001-Property-Management/
│   │   ├── requirement.json
│   │   ├── evaluation-criteria.json
│   │   ├── votes.json            # One record per vote cast
│   │   ├── decision.json         # Written ONCE; immutable
│   │   ├── mygate/
│   │   ├── nobroker/
│   │   └── apartmentadda/
│   └── REQ-2026-002-Accounting/
│
├── notices/
│   ├── builder/                  # Formal notices to Ankura Homes
│   └── members/                  # Defaulter/maintenance notices
│
├── finances/
│   ├── maintenance/
│   │   ├── 2025-05.json          # May 2025 onwards
│   │   └── ...
│   ├── corpus/
│   └── expenses/
│
└── audit/
    └── 2026-06/
        └── 2026-06-01.jsonl      # Append-only audit log, one JSON per line
```

### 11.2 Commit Convention (Human-Readable Audit Trail)

```
create(HOTO-042): Lift No.2 AMC Transfer — created by Treasurer
upload(HOTO-042): original-kone-amc.pdf uploaded by Treasurer
comment(HOTO-042): new comment by President
status(HOTO-042): IN_PROGRESS → EVIDENCE_UPLOADED by Treasurer
approve(HOTO-042): President approval granted
approve(HOTO-042): Secretary approval granted → status APPROVED
vote(REQ-001): vote cast for ApartmentAdda by Secretary [8/14 votes]
decide(REQ-001): ApartmentAdda selected — quorum met (12/14 voted)
snag-create(SNAG-089): Block B seepage — reported by Ravi
snag-close(SNAG-089): verified closed by President
notice(builder-001): Formal notice sent to Ankura Homes for HOTO-042
```

### 11.3 Immutability Rules

- `decision.json` files: written once, never updated. If decision reopened, a new file `decision-v2.json` is created
- `approvals.json`: append-only, never modified
- `audit/*.jsonl`: append-only, one line per event
- `comments.json`: edits create a new entry with `edited_at` field; original preserved

---

## 12. Data Model

### 12.1 Supabase Tables

```sql
-- Extended profiles (already exists — extend with new fields)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS
  portal_role TEXT DEFAULT 'executive',
  -- portal_role values: president | vice_president | working_president |
  --                     secretary | joint_secretary | treasurer |
  --                     joint_treasurer | executive | member | security_guard
  payment_status TEXT DEFAULT 'current',
  -- current | warned_30d | defaulting_60d | defaulter_90d
  last_maintenance_paid_date DATE,
  maintenance_arrears_days INTEGER DEFAULT 0;

-- HOTO Items
CREATE TABLE hoto_items (
  id TEXT PRIMARY KEY,                  -- 'HOTO-2026-042'
  society_id UUID NOT NULL,
  ascenza_category TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  builder_commitment TEXT,
  priority TEXT DEFAULT 'MEDIUM',       -- LOW | MEDIUM | HIGH | CRITICAL
  status TEXT NOT NULL DEFAULT 'NOT_STARTED',
  deadline DATE,
  responsible_user_id UUID REFERENCES profiles,
  rera_escalation_eligible BOOLEAN DEFAULT false,
  notice_sent BOOLEAN DEFAULT false,
  notice_sent_date TIMESTAMPTZ,
  dependencies TEXT[],                   -- Array of HOTO item IDs
  president_approved_at TIMESTAMPTZ,
  president_approved_by UUID REFERENCES profiles,
  secretary_approved_at TIMESTAMPTZ,
  secretary_approved_by UUID REFERENCES profiles,
  created_by UUID REFERENCES profiles,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_updated_at TIMESTAMPTZ DEFAULT NOW(),
  github_path TEXT
);

-- Required documents per HOTO item (prompting system)
CREATE TABLE hoto_required_docs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hoto_item_id TEXT REFERENCES hoto_items,
  doc_name TEXT NOT NULL,
  required BOOLEAN DEFAULT true,
  uploaded BOOLEAN DEFAULT false,
  document_id UUID REFERENCES documents,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Snag Items
CREATE TABLE snag_items (
  id TEXT PRIMARY KEY,                  -- 'SNAG-2026-089'
  society_id UUID NOT NULL,
  category TEXT NOT NULL,
  subcategory TEXT,
  location TEXT NOT NULL,
  description TEXT NOT NULL,
  severity TEXT DEFAULT 'MEDIUM',       -- LOW | MEDIUM | HIGH | CRITICAL
  status TEXT DEFAULT 'OPEN',
  -- OPEN | IN_PROGRESS | BUILDER_NOTIFIED | BUILDER_COMMITTED |
  -- RESOLVED | VERIFIED_CLOSED | REOPENED
  ascenza_reference TEXT,
  builder_committed_date DATE,
  notice_sent BOOLEAN DEFAULT false,
  formal_notice_id TEXT,
  reported_by UUID REFERENCES profiles,
  reported_date DATE DEFAULT CURRENT_DATE,
  verified_by UUID REFERENCES profiles,
  verified_at TIMESTAMPTZ,
  deleted BOOLEAN DEFAULT false,        -- soft delete
  deleted_by UUID REFERENCES profiles,
  deleted_at TIMESTAMPTZ,
  deletion_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  github_path TEXT
);

-- Vendor Requirements
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
  quorum_required INTEGER DEFAULT 8,    -- from §7.16(a)
  selected_vendor_id TEXT,
  created_by UUID REFERENCES profiles,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vendors
CREATE TABLE vendors (
  id TEXT PRIMARY KEY,
  requirement_id TEXT REFERENCES vendor_requirements,
  vendor_name TEXT NOT NULL,
  contact_person TEXT,
  contact_email TEXT,
  contact_phone TEXT,
  site_visited BOOLEAN DEFAULT false,
  quote_monthly INTEGER,
  quote_setup INTEGER,
  submitted_at TIMESTAMPTZ,
  github_path TEXT
);

-- Votes (one per member per requirement)
CREATE TABLE votes (
  id TEXT PRIMARY KEY,
  requirement_id TEXT REFERENCES vendor_requirements,
  voter_id UUID REFERENCES profiles,
  vendor_id TEXT REFERENCES vendors,
  reason TEXT NOT NULL,
  conflict_declared BOOLEAN DEFAULT false,
  recused BOOLEAN DEFAULT false,
  cast_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(requirement_id, voter_id)
);

-- Maintenance Collection
CREATE TABLE maintenance_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  flat_number TEXT NOT NULL,
  member_id UUID REFERENCES profiles,
  amount NUMERIC(10,2) NOT NULL,
  period_month INTEGER NOT NULL,
  period_year INTEGER NOT NULL,
  paid_date DATE,
  payment_mode TEXT,                    -- NEFT | RTGS | UPI | cheque (NOT cash per §9.1(r))
  reference_number TEXT,
  recorded_by UUID REFERENCES profiles,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Corpus Fund Records
CREATE TABLE corpus_fund_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  transaction_type TEXT NOT NULL,       -- RECEIVED_FROM_BUILDER | INTEREST_EARNED | APPROVED_USE
  amount NUMERIC(10,2) NOT NULL,
  description TEXT,
  date DATE NOT NULL,
  approved_by UUID REFERENCES profiles,
  payment_mode TEXT,
  reference_number TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Expenses
CREATE TABLE expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id UUID NOT NULL,
  amount NUMERIC(10,2) NOT NULL,
  payee TEXT NOT NULL,
  purpose TEXT NOT NULL,
  expense_date DATE NOT NULL,
  payment_mode TEXT NOT NULL,          -- electronic only per §9.11(c)
  reference_number TEXT,
  is_recurring BOOLEAN DEFAULT false,
  sanctioned_by_role TEXT,             -- president | secretary | board | general_body
  sanctioned_by UUID REFERENCES profiles,
  byelaw_authority TEXT,               -- e.g. "§9.11(a) - President sanction ≤₹20K"
  board_resolution_ref TEXT,           -- if board-level sanction
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Comments (shared across HOTO, Snags, Vendor items)
CREATE TABLE comments (
  id TEXT PRIMARY KEY,
  item_type TEXT NOT NULL,             -- HOTO | SNAG | VENDOR_REQ | VENDOR
  item_id TEXT NOT NULL,
  parent_comment_id TEXT REFERENCES comments,
  author_id UUID REFERENCES profiles,
  content TEXT NOT NULL,
  is_pinned BOOLEAN DEFAULT false,
  edited_at TIMESTAMPTZ,
  edited_content TEXT,                 -- stores edit history
  created_at TIMESTAMPTZ DEFAULT NOW(),
  github_commit TEXT
  -- NOTE: no deleted column — comments cannot be deleted per byelaw audit requirements
);

-- Comment Acknowledgements
CREATE TABLE comment_acks (
  comment_id TEXT REFERENCES comments,
  user_id UUID REFERENCES profiles,
  acked_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY(comment_id, user_id)
);

-- Documents
CREATE TABLE documents (
  id TEXT PRIMARY KEY,
  item_type TEXT NOT NULL,
  item_id TEXT NOT NULL,
  name TEXT NOT NULL,
  file_type TEXT,
  github_path TEXT NOT NULL,
  github_sha TEXT,
  uploaded_by UUID REFERENCES profiles,
  uploaded_at TIMESTAMPTZ DEFAULT NOW(),
  description TEXT,
  file_size_bytes INTEGER,
  is_confidential BOOLEAN DEFAULT false  -- phone numbers, legal docs = committee only
);

-- Formal Notices
CREATE TABLE notices (
  id TEXT PRIMARY KEY,
  notice_type TEXT NOT NULL,           -- HOTO_REMINDER | HOTO_LEGAL | SNAG | MAINTENANCE_DEFAULT
  recipient TEXT NOT NULL,             -- Builder name or member name
  recipient_type TEXT NOT NULL,        -- BUILDER | MEMBER
  related_item_type TEXT,
  related_item_id TEXT,
  sent_date DATE NOT NULL,
  sent_by UUID REFERENCES profiles,
  document_path TEXT,                  -- GitHub path to the letter
  response_received BOOLEAN DEFAULT false,
  response_date DATE,
  rera_filed BOOLEAN DEFAULT false,
  rera_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Delegation Status
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

-- Audit Log
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

---

## 13. Role-Based Access Control

### 13.1 Feature Access Matrix

| Feature | member | executive | working_president | treasurer | joint_secretary | secretary | vice_president | president | admin |
|---|---|---|---|---|---|---|---|---|---|
| View HOTO items | R | R | R | R | R | R | R | R | R |
| Create/edit HOTO items | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Upload documents | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Add comments | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Advance HOTO status | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| President approval gate | - | - | - | - | - | - | ✓(delegated) | ✓ | ✓* |
| Secretary approval gate | - | - | - | - | ✓(delegated) | ✓ | - | - | ✓* |
| Create/edit snags | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Delete snags | - | - | - | - | - | - | - | - | ✓ |
| Cast vendor vote | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | - |
| Trigger voting | - | - | - | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| View vendor quotes | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| View maintenance records | - | - | - | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| Add maintenance entry | - | - | - | ✓ | - | ✓ | ✓ | ✓ | ✓ |
| Send formal notice | - | - | - | - | ✓ | ✓ | ✓ | ✓ | ✓ |
| Manage delegation | - | - | - | - | - | - | - | - | ✓ |
| View audit log | - | - | - | - | - | ✓ | ✓ | ✓ | ✓ |
| Member phone numbers | - | - | - | - | - | ✓ | ✓ | ✓ | ✓ |

*Admin can surrogate only with explicit delegation record.

### 13.2 Member Onboarding / Offboarding

- **New member joins** (Q26: owner sells, NOC received from committee): Admin receives NOC confirmation, creates portal account, assigns `member` role
- **Committee election**: Admin upgrades role; old committee member reverts to `member`; all past actions remain attributed to them (Q62: remain attributed)
- **Member death/transfer**: Profile preserved, flagged as `inactive`; NOC workflow handles successor membership

---

## 14. Document Management & Missing Document Alerts

### 14.1 Required Document Prompting (Q28: Yes, system should ask)

Each HOTO item has a `required_documents` list. The system:
1. Shows a red "Missing Documents" badge on any item where required docs are not uploaded
2. On the item detail page, clearly shows: `❌ Original KONE AMC Contract — NOT YET UPLOADED [+ Upload Now]`
3. Cannot advance status to `UNDER_REVIEW` if any `required: true` document is missing (hard gate)
4. Can be bypassed by President or Secretary with a written reason (logged in audit)

### 14.2 Document Confidentiality

- Member phone numbers: **never visible to general members** (Q58: phone number should not be visible)
- Vendor quotes: Committee only (Q59: committee member only)
- Legal notices: Committee only
- HOTO documents: All committee (for transparency)
- All financial records: Treasurer + Secretary + President

### 14.3 Document Update/Replace (Q32: Yes)

- New version of a document can be uploaded; old version is archived, not deleted
- System shows version history: "Superseded by [new document] on [date]"

---

## 15. Phase-wise Implementation Plan

### Phase 1: HOTO MVP (6 weeks, before June 1 HOTO start)

**Goal: System live before HOTO officially starts**

| Week | Deliverable |
|---|---|
| **Week 1** | Set up `utamacs/governance-data` private repo with folder structure. Create Supabase migration 026 with all new tables. Set up GitHub App for governance-data writes. |
| **Week 2** | HOTO item list page: filterable by category/status, search, priority. Load from governance-data `_index.json`. Seed all HOTO items from Ascenza scope. |
| **Week 3** | HOTO item detail page: documents section with upload + required doc alerts, comment thread, status timeline. |
| **Week 4** | Status transition API with role checks, byelaw-enforced approval gates, delegation logic. President/Secretary approval screens (simplified for Bal Reddy). |
| **Week 5** | Snag list full CRUD module. CSV import for bulk snag upload from Ascenza Excel. Photo upload from mobile camera. |
| **Week 6** | Basic dashboard (HOTO progress, pending actions, critical deadlines). Weekly email digest. Testing with committee. |

**Target: System is live with all 14 committee members registered and 80+ HOTO items seeded by May 31, 2026.**

### Phase 2: Vendor Module (3 weeks, June)

| Week | Deliverable |
|---|---|
| **Week 7** | Vendor requirement board. Vendor profiles. Side-by-side comparison matrix with weighted scores. |
| **Week 8** | Digital voting system: quorum enforcement (§7.16a), conflict of interest declaration (§7.16b), tie-breaking by President (§7.16c), vote transparency. |
| **Week 9** | Decision record writer (immutable). Vendor onboarding checklist. Post-selection tracking (contract, renewals, complaints). |

### Phase 3: Financial Tracking & Notices (3 weeks, July)

| Week | Deliverable |
|---|---|
| **Week 10** | Maintenance collection tracking from May 2025. Defaulter tracking with byelaw-compliant thresholds. Monthly defaulter list generation. |
| **Week 11** | Corpus fund tracker. Expense tracker with byelaw financial authority enforcement. Builder dues register. |
| **Week 12** | Formal notice generation module (integrates with existing letter system). RERA escalation tracker. |

### Phase 4: Polish & Onboarding (2 weeks, August)

| Week | Deliverable |
|---|---|
| **Week 13** | Full mobile UX audit. Simplified "My Actions" view for non-tech users. Delegation management UI. |
| **Week 14** | Committee training session (focus on Bal Reddy and Working President). Go-live support. Feedback collection. |

### Future (Post-HOTO)

- Meeting management module (agenda, minutes as structured items)
- General resolution workflow (any board decision)
- Annual General Body Meeting support
- WhatsApp Business API notifications for critical approvals

---

## 16. Risks & Trade-offs

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Non-tech users don't adopt | **Medium** | **High** | "My Actions" screen is so simple they only need to click "Approve" or "Vote". Onboarding training session. Secretary assists non-tech members. |
| Builder delays HOTO items (2-3 months) | **High** | **Medium** | Tracker designed for delays; formal notice system built-in; RERA path tracked |
| Git API rate limit | **Low** | **Medium** | Supabase = primary data store, GitHub = document/audit store. Well within 5000 req/hour for 14 users |
| governance-data repo security | **Low** | **High** | Private repo; GitHub App with minimal permissions (contents only on governance-data); no access to website code |
| President/Secretary both unavailable | **Low** | **High** | Delegation chain per §8.2 and §8.4; Joint office bearers exist for exactly this scenario |
| Votes challenged as invalid | **Low** | **High** | Full audit trail; byelaw §4.16 and §7.16 quoted in every decision record; GitHub commit = immutable evidence |
| Missing documents delay approval | **Medium** | **Medium** | Required doc prompting; secretary can bypass with written reason; Ascenza provides documents directly to committee |
| Supabase free tier limits | **Low** | **Medium** | 14 users + 500K rows max; well within free tier for Phase 1-3 |
| Phase 1 not ready before June 1 | **Medium** | **High** | Start Week 1 immediately. MVP can be item list + detail + upload. Full approval flow can be Week 4-5. |

---

*Document Version 2.0 · Revised May 2026 with full requirements clarification*  
*Based on: Registered Byelaws TG/RRD/MACS/2026-15/FOW & M · Ascenza HOTO Scope · Committee Q&A Session*  
*Next review: Post-Phase 1 go-live (June 2026)*
