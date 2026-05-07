# Housing360 ↔ UTAMACS Feature Comparison & Gap Analysis

**Date**: 2026-05-07  
**Purpose**: Exhaustive page-to-page, field-to-field comparison between Housing360 (Admin Manual + App Brochure) and the UTAMACS portal as built. Use this to decide what to adopt, adapt, or drop.  
**Scope**: Excludes all AI features (deferred to backlog).  
**Convention**: ✅ Present | ⚠️ Partial / Different | ❌ Missing | 🆕 UTAMACS-only

---

## Table of Contents
1. [Authentication & Onboarding](#1-authentication--onboarding)
2. [Dashboard](#2-dashboard)
3. [Masters / Configuration](#3-masters--configuration)
4. [Members & Units](#4-members--units)
5. [Notices, Announcements & Policies](#5-notices-announcements--policies)
6. [Finance & Receivables](#6-finance--receivables)
7. [Complaints & Service Requests](#7-complaints--service-requests)
8. [Facility Booking](#8-facility-booking)
9. [Visitor Management](#9-visitor-management)
10. [Parking](#10-parking)
11. [Staff & Maid Management](#11-staff--maid-management)
12. [Media Gallery](#12-media-gallery)
13. [Community & Marketplace](#13-community--marketplace)
14. [Documents & Downloads](#14-documents--downloads)
15. [Polls & Voting](#15-polls--voting)
16. [Events](#16-events)
17. [Reports](#17-reports)
18. [Refunds](#18-refunds)
19. [Admin / Settings](#19-admin--settings)
20. [UTAMACS-Only Features](#20-utamacs-only-features)
21. [Prioritised Implementation Backlog](#21-prioritised-implementation-backlog)

---

## 1. Authentication & Onboarding

### 1.1 Login

| Field / Behaviour | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Login method | Mobile number + OTP | Email + Password | ⚠️ |
| OTP channel | SMS | — | ❌ |
| Remember me / session | ✅ | ✅ | — |
| Forgot password | ✅ | ✅ | — |
| Role-based redirect after login | ✅ (Admin / Member / Guard / Facility Manager) | ✅ (Executive / Member / Guard) | ✅ |
| Biometric / Face ID (mobile) | ✅ | N/A (web) | — |

**Gap**: UTAMACS uses email+password (Supabase auth). Housing360 uses mobile OTP, which residents prefer. Adding OTP as a secondary login method would reduce friction.

**Recommendation**: Add **mobile number + OTP login** as an alternative to email/password using Supabase Phone Auth. Keep email/password for admin accounts.

---

### 1.2 Unit Registration / Onboarding Requests

| Flow | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Owner self-registers unit | Unit Request (pending admin approval) | Admin-created via Members module | ❌ |
| Tenant self-registers | Tenant Request (separate queue) | Admin-created via Members module | ❌ |
| Secondary / family member adds self | Secondary User Request (owner approves) | Admin-controlled RBAC only | ❌ |
| Approval workflow visible to requestor | ✅ (status shown in app) | ❌ | ❌ |
| Admin queue for pending registrations | ✅ distinct queue | Not a separate queue | ❌ |
| Upload docs at registration (Aadhaar / Agreement) | ✅ | ❌ | ❌ |

**Gap**: UTAMACS currently requires an executive to manually create all users. Housing360 flips this: residents apply, admins approve. This reduces executive workload and is critical for self-service.

**Recommendation**: Implement a **Self-Registration Portal** with three flows:
- Owner Registration Request (flat no. + ID proof upload)
- Tenant Registration Request (lease period + owner confirmation)
- Family Member Secondary User Request (approved by primary owner)
All three feed an **Onboarding Queue** page in the admin panel.

---

## 2. Dashboard

### 2.1 Admin Dashboard

| Widget / Data Point | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Date range filter (Today / Week / Month / Custom) | ✅ | ❌ | ❌ |
| Total collection amount (period) | ✅ | ✅ (all-time) | ⚠️ |
| Collection pie chart by category | ✅ | ❌ | ❌ |
| Month-wise collection bar chart | ✅ | ❌ | ❌ |
| Pending dues count | ✅ | ✅ | ✅ |
| Total registered units | ✅ | ✅ | ✅ |
| Occupied vs vacant units | ✅ | ❌ | ❌ |
| Facility bookings today | ✅ | ❌ | ❌ |
| Open complaints count | ✅ | ✅ | ✅ |
| Visitor count today | ✅ | ❌ | ❌ |
| Staff present today | ✅ | ❌ (attendance exists but not on dashboard) | ⚠️ |
| Announcements quick-post | ✅ | ❌ | ❌ |

### 2.2 Member Dashboard

| Widget | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| My dues / outstanding | ✅ | ✅ | ✅ |
| My complaints status | ✅ | ✅ | ✅ |
| My bookings upcoming | ✅ | ❌ | ❌ |
| My visitors today | ✅ | ❌ | ⚠️ |
| Community board preview | ✅ | ✅ | ✅ |
| Latest notice | ✅ | ✅ | ✅ |
| Quick links row | ✅ | ✅ (partial) | ⚠️ |

**Recommendation**:
- Add **date-range picker** to the Executive Dashboard with collection summary re-fetched for the period.
- Add **Collection by Category pie chart** (Maintenance / Utility / Sinking Fund / Other).
- Add **Occupied vs Vacant** unit card (derive from member status flags).
- Add **"Upcoming Bookings"** card to Member Dashboard.
- Add **Visitor Today** count card to both dashboards.

---

## 3. Masters / Configuration

### 3.1 Society Structure (Wings & Gates)

| Master | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Wings setup (Block A, B, C…) | ✅ distinct master | Units have a block field | ⚠️ |
| Floors per wing | ✅ configurable | Not explicit | ⚠️ |
| Flat types per wing | ✅ (1BHK, 2BHK…) | Unit type field | ⚠️ |
| Gates / Entry points master | ✅ distinct master | Fixed: Main Gate | ❌ |
| Gate assignment to security guard | ✅ | ❌ | ❌ |
| Bulk import units via CSV | ✅ | ❌ | ❌ |
| Bulk import parking via CSV | ✅ | ❌ | ❌ |

**Gap**: UTAMACS has flat/block data but no Wings master or Gates master. Gates management is critical for multi-gate communities and guard assignment.

**Recommendation**:
- Add **Gates Master** under Admin > Masters. Fields: Gate Name, Gate Type (Entry/Exit/Both), Active/Inactive.
- Add **Gate ↔ Guard Assignment** so guards only see visitors at their assigned gate.
- Add **CSV bulk import** for unit and parking slot seeding (one-time setup convenience).

---

### 3.2 Receivable Categories

| Field | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Category name | ✅ | ✅ | ✅ |
| Sub-category name | ✅ | ❌ | ❌ |
| Sub-category type (Fixed / Variable / Per Sqft / Per Unit) | ✅ | ❌ | ❌ |
| Frequency (Monthly / Quarterly / Annually / One-time) | ✅ | ✅ (billing period) | ⚠️ |
| Late Fee Type (Fixed / Percentage) | ✅ | ❌ | ❌ |
| Late Fee Amount / Rate | ✅ | ❌ | ❌ |
| Late Fee Frequency (One-time / Monthly) | ✅ | ❌ | ❌ |
| Grace period (days) | ✅ | ❌ | ❌ |
| Waiver type (Full / Partial / None) | ✅ | ❌ | ❌ |
| HSN / SAC code | ✅ | ❌ | ❌ |
| Apply to specific wings | ✅ | ❌ | ❌ |

**Gap**: UTAMACS finance has billing periods and flat-rate dues but lacks the full receivable configuration model (sub-categories, late fees, grace periods, waivers).

**Recommendation**: Extend `Admin > Finance Configuration` with:
- **Receivable Sub-Categories** table with type, frequency, and calculation basis.
- **Late Fee Rules** section: type (Fixed/%), amount, frequency, grace days.
- **Waiver management** per member/category.

---

## 4. Members & Units

### 4.1 Unit / Member Record

| Field | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Flat number | ✅ | ✅ | ✅ |
| Wing / Block | ✅ | ✅ | ✅ |
| Floor | ✅ | ❌ | ❌ |
| Flat area (sqft) | ✅ | ❌ | ❌ |
| Flat type (1BHK / 2BHK…) | ✅ | ✅ | ✅ |
| Owner name | ✅ | ✅ | ✅ |
| Owner mobile | ✅ | ✅ | ✅ |
| Owner email | ✅ | ✅ | ✅ |
| Owner Aadhaar number | ✅ | ❌ | ❌ |
| Owner Voter ID | ✅ | ❌ | ❌ |
| Tenant name | ✅ | ✅ | ✅ |
| Tenant mobile | ✅ | ✅ | ✅ |
| Tenant email | ✅ | ✅ | ✅ |
| Lease start / end date | ✅ | ❌ | ❌ |
| Lease document upload | ✅ | ❌ | ❌ |
| Occupancy status (Owner-Occupied / Tenant / Vacant) | ✅ | Implied by member role | ⚠️ |
| Number of occupants | ✅ | ❌ | ❌ |
| Vehicle details (per unit) | ✅ | Separate parking module | ⚠️ |
| Move-in date | ✅ | ❌ | ❌ |
| Move-out date | ✅ | ❌ | ❌ |
| NRI flag | ✅ | ❌ | ❌ |
| Emergency contact | ✅ | ❌ | ❌ |
| Profile photo | ✅ | ❌ | ❌ |

**Recommendation**:
- Add **Floor**, **Area (sqft)**, **Occupancy Status**, **Move-in/out dates**, **Lease dates** to the Unit record.
- Add **Emergency Contact** field to profile.
- Add **Lease Document upload** (PDF) — store in Supabase Storage.
- **NRI flag** useful for TDS applicability — link to TDS module.
- **Flat area** enables per-sqft billing calculations.

---

### 4.2 Member Directory (Admin View)

| Feature | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Filter by wing | ✅ | ❌ | ❌ |
| Filter by occupancy status | ✅ | ❌ | ❌ |
| Filter by tenancy expiry (< 30 days) | ✅ | ❌ | ❌ |
| Export member list CSV | ✅ | ❌ | ❌ |
| Bulk SMS / push notification to filtered set | ✅ | ❌ | ❌ |
| Member detail view (all sub-sections) | ✅ | ✅ | ✅ |
| Edit member inline | ✅ | ✅ | ✅ |
| Deactivate / archive member | ✅ | ✅ | ✅ |

**Recommendation**:
- Add **Wing filter** and **Occupancy Status filter** to Member Directory.
- Add **CSV export** of member list.
- Add **"Tenancy expiring soon"** alert card on Executive Dashboard.

---

## 5. Notices, Announcements & Policies

### 5.1 Notices (UTAMACS) vs Announcements (Housing360)

| Field / Feature | Housing360 Announcements | UTAMACS Notices | Gap |
|---|---|---|---|
| Title | ✅ | ✅ | ✅ |
| Body text | ✅ | ✅ | ✅ |
| Category / type | ✅ | ✅ | ✅ |
| Attach image | ✅ | ❌ | ❌ |
| Attach PDF document | ✅ | ❌ | ❌ |
| Attach video (upload) | ✅ | ❌ | ❌ |
| Link YouTube video | ✅ | ❌ | ❌ |
| Push notification on publish | ✅ | ❌ (email only) | ⚠️ |
| Target by wing | ✅ | ❌ | ❌ |
| Acknowledgement required flag | ✅ | ✅ | ✅ |
| Acknowledgement tracker (who/when) | ✅ | ✅ | ✅ |
| Publish scheduled date | ✅ | ❌ | ❌ |
| Expiry date | ✅ | ❌ | ❌ |
| Priority / pinned flag | ✅ | ❌ | ❌ |
| Member view: unread badge | ✅ | ✅ | ✅ |

### 5.2 Policies (Housing360 exclusive module)

| Field / Feature | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Policies as distinct module | ✅ | ❌ (merged into Documents) | ❌ |
| Policy type (Text / PDF / Video) | ✅ | ❌ | ❌ |
| Policy version number | ✅ | ❌ | ❌ |
| Policy effective date | ✅ | ❌ | ❌ |
| Acknowledgement per policy | ✅ | ❌ | ❌ |
| Member must accept before portal access | ✅ | ❌ (DPDPA consent only) | ⚠️ |

**Recommendation**:
- Add **file/image attachment** support to Notices (store in Supabase Storage).
- Add **Scheduled publish** and **Expiry date** to notices.
- Add **Wing-targeted** notices.
- Add **Pinned / Priority** flag (pinned notices appear at top).
- Elevate **Policies** from Documents into a dedicated module with version history and mandatory-acknowledgement-before-portal-access gate.

---

## 6. Finance & Receivables

### 6.1 Invoice / Demand Note Generation

| Feature | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Generate invoice for all units | ✅ | ✅ (billing period) | ✅ |
| Generate invoice for specific wing | ✅ | ❌ | ❌ |
| Generate invoice for selected units only | ✅ | ❌ | ❌ |
| Receivable sub-categories on invoice | ✅ (line items) | ❌ (single amount) | ❌ |
| Late fee auto-added to overdue invoices | ✅ | ❌ | ❌ |
| Invoice number auto-generation | ✅ | ❌ | ❌ |
| Invoice PDF download (member) | ✅ | ❌ | ❌ |
| Payment gateway link in invoice | ✅ | ❌ | ❌ |
| Mark as paid (admin manual) | ✅ | ✅ | ✅ |
| Partial payment recording | ✅ | ❌ | ❌ |
| Payment mode (Cash / UPI / Cheque / NEFT) | ✅ | ✅ | ✅ |
| Payment reference / UTR capture | ✅ | ✅ | ✅ |
| Receipt PDF generation | ✅ | ❌ | ❌ |
| Due date per invoice | ✅ | Per billing period | ⚠️ |
| Advance payment credit | ✅ | ❌ | ❌ |

### 6.2 Collection Reports

| Report | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Total Collection by period | ✅ | ✅ (basic) | ⚠️ |
| Collection by receivable category | ✅ | ❌ | ❌ |
| Member-wise collection history | ✅ | ✅ | ✅ |
| Pending dues list | ✅ | ✅ | ✅ |
| Month-wise trend chart | ✅ | ❌ | ❌ |
| Wing-wise collection summary | ✅ | ❌ | ❌ |

**Recommendation** (phased):
- **Phase 1**: Add **invoice number**, **due date**, **invoice PDF download**, and **receipt PDF generation**.
- **Phase 2**: Add **line-item billing** (multiple receivable sub-categories per invoice).
- **Phase 3**: Add **late fee auto-calculation** based on grace period rules.
- **Phase 4**: Add **partial payments** and **advance credit** ledger.
- Add **Wing-wise generation** filter to billing period creation.
- Add **month-wise collection chart** to Executive Dashboard.

---

### 6.3 Refunds (Housing360 exclusive)

| Feature | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Refund Rules per service type | ✅ | ❌ | ❌ |
| Refund Rule: cancellation window (hours) | ✅ | ❌ | ❌ |
| Refund Rule: refund % | ✅ | ❌ | ❌ |
| Refund Request by member | ✅ | ❌ | ❌ |
| Admin approve / reject refund | ✅ | ❌ | ❌ |
| Refund via payment gateway reversal | ✅ | ❌ | ❌ |
| Refund via manual bank transfer | ✅ | ❌ | ❌ |
| Refund status tracking | ✅ | ❌ | ❌ |

**Recommendation**: Once payment gateway is integrated, implement **Refund Rules** (configurable % within cancellation window) and a **Refund Requests** queue for facility booking cancellations. Start with manual bank transfer; PG reversal is a later enhancement.

---

## 7. Complaints & Service Requests

### 7.1 Complaint Record

| Field | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Complaint title | ✅ | ✅ | ✅ |
| Description | ✅ | ✅ | ✅ |
| Category | ✅ | ✅ | ✅ |
| Sub-category | ✅ | ❌ | ❌ |
| Priority (Low / Medium / High / Critical) | ✅ | ✅ | ✅ |
| Photo attachment | ✅ | ❌ | ❌ |
| Video attachment | ✅ | ❌ | ❌ |
| Assign to staff member | ✅ | ✅ (assignee) | ✅ |
| Expected resolution date | ✅ | ❌ | ❌ |
| Resolution notes | ✅ | ✅ | ✅ |
| Member satisfaction rating (post-close) | ✅ | ❌ | ❌ |
| SLA breach indicator | ✅ | ❌ | ❌ |
| Work order auto-created on assignment | ✅ | ✅ | ✅ |
| Comment thread | ✅ | ✅ | ✅ |
| Status history log | ✅ | ✅ | ✅ |

**Recommendation**:
- Add **Sub-category** dropdown (e.g., Electrical > Short circuit / Power fluctuation).
- Add **Photo/Video attachment** on complaint creation and resolution.
- Add **Expected resolution date** and **SLA breach** visual indicator (overdue badge).
- Add **Post-resolution satisfaction rating** (1–5 stars) sent to resident when complaint is closed.

---

## 8. Facility Booking

### 8.1 Facility Configuration (Admin)

| Field | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Facility name | ✅ | ✅ | ✅ |
| Facility type | ✅ | ✅ | ✅ |
| Description | ✅ | ✅ | ✅ |
| Photo(s) | ✅ | ❌ | ❌ |
| Capacity (total) | ✅ | ✅ | ✅ |
| Guest types (Child / Adult / Senior) | ✅ | ❌ | ❌ |
| Quota per guest type | ✅ | ❌ | ❌ |
| Fee per guest type | ✅ | ❌ | ❌ |
| Time slots configuration | ✅ | ✅ | ✅ |
| Advance booking days | ✅ | ✅ | ✅ |
| Cancellation window | ✅ | ❌ | ❌ |
| Refund rule linkage | ✅ | ❌ | ❌ |
| Buffer time between slots | ✅ | ❌ | ❌ |
| Maintenance block dates | ✅ | ❌ | ❌ |

### 8.2 Booking Workflow

| Feature | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Guest count entry at booking | ✅ (per type) | ❌ | ❌ |
| Total fee auto-calculated | ✅ | ✅ (flat fee) | ⚠️ |
| Availability calendar view | ✅ | ✅ | ✅ |
| Booking approval by admin | ✅ | ✅ | ✅ |
| Payment before confirmation | ✅ (PG link) | ❌ | ❌ |
| Auto-cancellation if unpaid | ✅ | ❌ | ❌ |
| QR code for entry verification | ✅ | ❌ | ❌ |
| Booking history per member | ✅ | ✅ | ✅ |
| Recurring booking | ✅ | ❌ | ❌ |

### 8.3 Availability Report

| Feature | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Date-range availability report | ✅ | ❌ | ❌ |
| Occupancy % per facility | ✅ | ❌ | ❌ |
| Revenue per facility (period) | ✅ | ❌ | ❌ |

**Recommendation**:
- Add **guest type configuration** to facility setup (Adult / Child / Senior Citizen with per-type quota and rate).
- Add **cancellation window** and link to Refund Rules.
- Add **buffer time** between slots.
- Add **maintenance block** date picker.
- Add **Availability Report** — date range, facility-wise occupancy %.

---

## 9. Visitor Management

### 9.1 Visitor Types

Housing360 provides a rich **pre-defined visitor type list** that categorises entries for analytics. UTAMACS has a generic visitor type field.

| Visitor Type | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Guest | ✅ | ✅ | ✅ |
| Delivery Person | ✅ | ✅ | ✅ |
| Maid | ✅ | ⚠️ (separate module) | ⚠️ |
| Driver | ✅ | ❌ | ❌ |
| Doctor | ✅ | ❌ | ❌ |
| Car Cleaner | ✅ | ❌ | ❌ |
| Milkman | ✅ | ❌ | ❌ |
| Nanny | ✅ | ❌ | ❌ |
| Paperboy | ✅ | ❌ | ❌ |
| Plumber / Electrician / Repair (categorised) | ✅ | ❌ | ❌ |
| Tuition Teacher | ✅ | ❌ | ❌ |
| Dance / Karate / Sports Instructor | ✅ | ❌ | ❌ |
| Cable TV Repair | ✅ | ❌ | ❌ |

### 9.2 Visitor Record Fields

| Field | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Visitor name | ✅ | ✅ | ✅ |
| Mobile number | ✅ | ✅ | ✅ |
| Visitor type | ✅ | ✅ (basic) | ⚠️ |
| Vehicle number | ✅ | ✅ | ✅ |
| Photo capture (guard camera) | ✅ | ❌ | ❌ |
| Aadhaar / ID scan | ✅ | ❌ | ❌ |
| Expected flat (unit) | ✅ | ✅ | ✅ |
| Member pre-approval (invite) | ✅ | ✅ | ✅ |
| OTP for pre-approved visitor | ✅ | ❌ | ❌ |
| Entry timestamp | ✅ | ✅ | ✅ |
| Exit timestamp | ✅ | ✅ | ✅ |
| Purpose of visit | ✅ | ✅ | ✅ |
| Gate used | ✅ | ❌ (single gate) | ⚠️ |
| Delivery item description | ✅ | ✅ | ✅ |
| Delivery collected by | ✅ | ✅ | ✅ |
| Filter by visitor type | ✅ | ❌ | ❌ |
| Filter by date range | ✅ | ✅ | ✅ |
| Filter by unit | ✅ | ✅ | ✅ |
| Export visitor log CSV | ✅ | ❌ | ❌ |

**Recommendation**:
- Expand visitor type list to the full Housing360 set — this is a configuration/dropdown change.
- Add **Gate filter** once Gates master is implemented.
- Add **Visitor type filter** to the visitor log.
- Add **CSV export** of visitor log.
- Add **OTP for pre-approved visitor** (member shares a 4-digit OTP; guard verifies before allowing entry).
- **Photo capture** is a mobile/camera feature — mark as progressive enhancement for mobile browsers.

---

## 10. Parking

### 10.1 Parking Slot Record

| Field | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Slot number | ✅ | ✅ | ✅ |
| Slot type (2-Wheeler / 4-Wheeler / EV) | ✅ | ✅ | ✅ |
| Level / Floor | ✅ | ❌ | ❌ |
| Block / Wing | ✅ | ❌ | ❌ |
| Assigned to unit | ✅ | ✅ | ✅ |
| Vehicle number | ✅ | ✅ | ✅ |
| Vehicle make / model | ✅ | ❌ | ❌ |
| Vehicle colour | ✅ | ❌ | ❌ |
| RC / Insurance document upload | ✅ | ❌ | ❌ |
| Monthly fee for slot | ✅ | ❌ | ❌ |
| Slot status (Available / Assigned / Reserved) | ✅ | ✅ | ✅ |
| Waitlist for desired slot type | ✅ | ✅ | ✅ |
| Transfer slot between units | ✅ | ❌ | ❌ |

**Recommendation**:
- Add **Level/Floor** and **Block** to parking slot record.
- Add **Vehicle make, model, colour** fields.
- Add **RC document upload**.
- Add **Monthly parking fee** field (ties into receivable sub-categories).
- Add **Slot transfer** workflow (relinquish → reassign).

---

## 11. Staff & Maid Management

### 11.1 Staff (Society-Employed)

| Feature | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Staff profile (name, role, mobile) | ✅ | ✅ | ✅ |
| Aadhaar / ID document | ✅ | ❌ | ❌ |
| Photo | ✅ | ❌ | ❌ |
| Attendance tracking | ✅ | ✅ | ✅ |
| Shift assignment | ✅ | ❌ | ❌ |
| Gate assignment (guards) | ✅ | ❌ | ❌ |
| Leave requests | ✅ | ❌ | ❌ |
| Salary / payroll (basic) | ✅ | ❌ (TDS tracking exists) | ⚠️ |

### 11.2 Maid / Domestic Help Tracking (Housing360 exclusive)

This is a **standalone module** in Housing360 with no equivalent in UTAMACS.

| Field | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Maid name | ✅ | ❌ | ❌ |
| Mobile number | ✅ | ❌ | ❌ |
| Photo | ✅ | ❌ | ❌ |
| Aadhaar number + upload | ✅ | ❌ | ❌ |
| Voter ID + upload | ✅ | ❌ | ❌ |
| Linked flats (serves multiple units) | ✅ | ❌ | ❌ |
| Entry / exit time per day | ✅ | ❌ | ❌ |
| Approval by flat owner before access | ✅ | ❌ | ❌ |
| Blocked / suspended flag | ✅ | ❌ | ❌ |
| Maid list visible to security guard | ✅ | ❌ | ❌ |
| Maid list visible to member (their own) | ✅ | ❌ | ❌ |
| Background check document | ✅ | ❌ | ❌ |

**Recommendation**: Implement a **Domestic Help / Maid Registry** module:
- Member registers their maids with photo + Aadhaar.
- Guard sees the maid's photo and approved flats at the gate.
- Maid entry/exit tracked like a visitor with a known-person shortcut.
- Admin can flag a maid as suspended (blocked from all flats).
- This is a high-value safety feature for residents; implement with UTAMACS flavor emphasising resident privacy and data minimisation (DPDPA compliant).

---

## 12. Media Gallery

Housing360 has a full **Media Gallery module** as a top-level navigation item. UTAMACS has no equivalent.

| Feature | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Photo albums | ✅ | ❌ | ❌ |
| Video uploads | ✅ | ❌ | ❌ |
| PDF documents in gallery | ✅ | Documents module (not gallery) | ⚠️ |
| YouTube links | ✅ | ❌ | ❌ |
| Album title + description | ✅ | ❌ | ❌ |
| Cover photo per album | ✅ | ❌ | ❌ |
| Published date | ✅ | ❌ | ❌ |
| Admin-only upload | ✅ | — | — |
| Member view (read-only) | ✅ | — | — |
| Gallery on public website | ✅ | ❌ | ❌ |

**Recommendation**: Create a **Photo Gallery** module (simpler than Housing360's full media gallery):
- Admin creates albums (Diwali Celebration 2024, AGM 2025, etc.).
- Photos uploaded to Supabase Storage.
- Member view: masonry or grid layout, lightbox on click.
- **Public website gallery** page (currently missing entirely on utamacs.org).
- Defer video uploads; start with photos only. YouTube embed links can be added as a second step.

---

## 13. Community & Marketplace

### 13.1 Community Board

| Feature | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Post text content | ✅ | ✅ | ✅ |
| Post image | ✅ | ❌ | ❌ |
| Post category | ✅ | ✅ | ✅ |
| Reactions (like / etc.) | ✅ | ✅ | ✅ |
| Comment thread | ✅ | ✅ | ✅ |
| Pin post (admin) | ✅ | ❌ | ❌ |
| Report / flag post | ✅ | ❌ | ❌ |
| Admin moderation queue | ✅ | ❌ | ❌ |

### 13.2 Marketplace

| Feature | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| List item for sale / rent | ✅ | ✅ | ✅ |
| Category (Furniture / Electronics…) | ✅ | ✅ | ✅ |
| Price field | ✅ | ✅ | ✅ |
| Photos of item | ✅ | ❌ | ❌ |
| Contact seller via in-app message | ✅ | ❌ | ❌ |
| Mark as sold | ✅ | ✅ | ✅ |
| Admin moderation / remove listing | ✅ | ❌ | ❌ |
| Expiry date on listing | ✅ | ❌ | ❌ |

**Recommendation**:
- Add **image attachment** to Community Board posts and Marketplace listings.
- Add **Pin post** (executive privilege).
- Add **Report post** button for members → feeds a moderation queue.
- Add **Listing expiry** (auto-archive after 30/60 days).
- Add **Admin moderation queue** in admin panel.

---

## 14. Documents & Downloads

### 14.1 Document Library

| Feature | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Upload document (PDF) | ✅ | ✅ | ✅ |
| Category tagging | ✅ | ✅ | ✅ |
| Access control (All / Members / Executive) | ✅ | ✅ | ✅ |
| Version history | ✅ | ❌ | ❌ |
| Download count tracking | ✅ | ❌ | ❌ |
| Expiry date | ✅ | ❌ | ❌ |
| Mandatory read acknowledgement | ✅ (Policy type) | ❌ | ❌ |
| Search by title / keyword | ✅ | ❌ | ❌ |

**Recommendation**:
- Add **Search** to document library.
- Add **Version history** (upload new version, retain old ones).
- Add **Download count** tracking.
- Split **Policies** into a separate module with acknowledgement gating.

---

## 15. Polls & Voting

### 15.1 Poll Record

| Field | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Question | ✅ | ✅ | ✅ |
| Options (multiple) | ✅ | ✅ | ✅ |
| Poll type (Single choice / Multiple choice) | ✅ | ✅ | ✅ |
| Anonymous voting | ✅ | ✅ | ✅ |
| Open / Close date | ✅ | ✅ | ✅ |
| Target audience (all / wing / flat type) | ✅ | ❌ | ❌ |
| Quorum requirement | ✅ | ❌ | ❌ |
| Results visible before close | ✅ (configurable) | ❌ | ❌ |
| PDF result export | ✅ | ❌ | ❌ |
| Attach document to poll | ✅ | ❌ | ❌ |

**Recommendation**:
- Add **Quorum** field (minimum % participation required for result to be valid).
- Add **Target audience** (all / specific wing) to polls.
- Add **Results visibility** toggle (hidden until close vs. live tally).
- Add **PDF result export** (useful for AGM minutes).
- Add **Attach document** to poll (e.g., budget proposal PDF linked to the vote).

---

## 16. Events

### 16.1 Event Record

| Field | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Event title | ✅ | ✅ | ✅ |
| Description | ✅ | ✅ | ✅ |
| Date / Time | ✅ | ✅ | ✅ |
| Venue | ✅ | ✅ | ✅ |
| Banner image | ✅ | ❌ | ❌ |
| RSVP / Registration | ✅ | ✅ | ✅ |
| Max attendees | ✅ | ✅ | ✅ |
| Waitlist | ✅ | ✅ | ✅ |
| Guest allowed (non-residents) | ✅ | ❌ | ❌ |
| Fee for event (paid event) | ✅ | ❌ | ❌ |
| Event photo gallery post-event | ✅ | ❌ | ❌ |
| Attendance marking (day-of) | ✅ | ❌ | ❌ |
| Certificate of participation | ✅ | ❌ | ❌ |

**Recommendation**:
- Add **Banner image** upload to events.
- Add **Guest allowed** flag (resident can bring +N guests).
- Add **Paid event** support with fee collection.
- Add **Post-event photo gallery** link (connects to Gallery module).
- Add **Day-of attendance marking** by executive.

---

## 17. Reports

Housing360 has a dedicated **Reports** section. UTAMACS has finance reporting embedded within the Finance module.

| Report | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Service Bookings Report | ✅ | ❌ | ❌ |
| Member-wise Booking Report | ✅ | ❌ | ❌ |
| Total Collection Report (period) | ✅ | ✅ (basic) | ⚠️ |
| Receivable Collection Report | ✅ | ⚠️ (dues list) | ⚠️ |
| Status History Report (complaints) | ✅ | ❌ | ❌ |
| Tenants Expiration Report | ✅ | ❌ | ❌ |
| Availability Report (facilities) | ✅ | ❌ | ❌ |
| Visitor Log Report | ✅ | ❌ | ❌ |
| Staff Attendance Report | ✅ | ✅ | ✅ |
| Member Directory Export | ✅ | ❌ | ❌ |

**Recommendation**: Create a **Reports Hub** page (Executive/Admin only) with:
1. Collection Report — date range, category breakdown, CSV + PDF
2. Pending Dues Report — by wing / unit / overdue days
3. Complaints Resolution Report — category, avg. resolution time, SLA breach %
4. Facility Utilisation Report — bookings, occupancy %, revenue
5. Visitor Log Report — date range, type filter, CSV
6. Tenant Expiry Report — leases expiring in next 30/60/90 days
7. Member Directory Export — CSV with all fields

---

## 18. Feedbacks Module (Housing360 exclusive)

| Feature | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Resident submits feedback (free text) | ✅ | ❌ | ❌ |
| Category (Maintenance / Staff / Cleanliness / Other) | ✅ | ❌ | ❌ |
| Rating (1–5 stars) | ✅ | ❌ | ❌ |
| Admin views all feedback | ✅ | ❌ | ❌ |
| Admin responds to feedback | ✅ | ❌ | ❌ |
| Export feedback CSV | ✅ | ❌ | ❌ |
| Anonymous submission option | ✅ | ❌ | ❌ |

**Recommendation**: Add a **Feedback** module (separate from Complaints — complaints are issue-tracking, feedback is satisfaction input):
- Member submits star rating + optional text per category.
- Executive sees aggregate ratings on dashboard and individual submissions.
- Monthly email digest of feedback trends to the committee.
- Anonymous option (member's identity hidden from list, but recorded for DPDPA audit log).

---

## 19. Admin / Settings

### 19.1 Configuration Parity

| Setting | Housing360 | UTAMACS | Gap |
|---|---|---|---|
| Society profile (name, address, logo) | ✅ | ❌ | ❌ |
| Email / SMS notification templates | ✅ | ✅ (email drafts) | ⚠️ |
| Push notification settings | ✅ | ❌ | ❌ |
| Feature flags (enable/disable modules) | ✅ | ✅ | ✅ |
| RBAC permission matrix | ✅ | ✅ | ✅ |
| Audit log | ✅ | ✅ | ✅ |
| Data export (full society data) | ✅ | ❌ | ❌ |
| Holiday calendar (for SLA exclusions) | ✅ | ❌ | ❌ |
| WhatsApp integration settings | ✅ | ❌ | ❌ |

**Recommendation**:
- Add **Society Profile** page in admin (name, address, registration number, logo, contact email). Currently this is hardcoded in HTML.
- Add **Full Data Export** — DPDPA compliance requires residents to be able to request their data.
- Add **Holiday Calendar** — future SLA feature dependency.
- WhatsApp integration: flag for later phase.

---

## 20. UTAMACS-Only Features

These are UTAMACS strengths that Housing360 does not have. Preserve and strengthen.

| Feature | UTAMACS | Notes |
|---|---|---|
| 🆕 HOTO Tracker | ✅ Dual-approval (Secretary + President) | Critical for cooperative handover governance |
| 🆕 Snag / Defect Tracker | ✅ Builder defects with photo evidence | Unique to UTAMACS's construction phase context |
| 🆕 DPDPA 2023 Compliance | ✅ Consent management, audit log, data requests | Legal requirement for Indian societies |
| 🆕 TDS Tracking (Section 194C) | ✅ Vendor TDS with PAN, certificate upload | Required for societies with vendor contracts |
| 🆕 Rules Engine | ✅ Configurable business rules | More flexible than Housing360's hardcoded rules |
| 🆕 AGM & Governance | ✅ Meeting minutes, board resolutions, proxies | Housing360 has no AGM module |
| 🆕 Official Letters | ✅ Templated letters with PDF export | Housing360 has no letter generation |
| 🆕 Work Orders | ✅ Linked to complaints and vendors | Housing360 work orders are less integrated |
| 🆕 Infrastructure Asset Management | ✅ Lifts, CCTV, generators, AMC tracking | Housing360 has no asset registry |
| 🆕 Board Resolution Workflow | ✅ Draft → approve → execute | Housing360 has no governance workflow |
| 🆕 Email Drafts + Bulk Send | ✅ Templated bulk email | Housing360 relies on push notifications |

---

## 21. Prioritised Implementation Backlog

Items ranked by resident impact × implementation feasibility. AI features excluded.

### Priority 1 — High Impact, Low Complexity

| # | Feature | Module | Effort |
|---|---|---|---|
| 1.1 | Expanded visitor type list (maid, driver, plumber, etc.) | Visitor Management | S |
| 1.2 | Visitor type filter in log | Visitor Management | S |
| 1.3 | Photo/video attachment on complaints | Complaints | S |
| 1.4 | Expected resolution date + SLA overdue badge | Complaints | S |
| 1.5 | Image attachment on notices | Notices | S |
| 1.6 | Scheduled publish + expiry date on notices | Notices | S |
| 1.7 | Wing-targeted notices | Notices | S |
| 1.8 | Pinned / priority notices | Notices | XS |
| 1.9 | Sub-category for complaints | Complaints | S |
| 1.10 | Image attachment on community posts & marketplace | Community | S |
| 1.11 | Marketplace listing expiry | Marketplace | XS |
| 1.12 | Post-resolution satisfaction rating (1–5 stars) | Complaints | S |
| 1.13 | Floor + Vehicle make/model/colour in parking | Parking | S |
| 1.14 | CSV export for visitor log | Visitor Management | S |
| 1.15 | CSV export for member directory | Members | S |

### Priority 2 — High Impact, Medium Complexity

| # | Feature | Module | Effort |
|---|---|---|---|
| 2.1 | Self-registration: Owner / Tenant / Family member request | Auth | M |
| 2.2 | Onboarding Queue in admin panel | Admin | M |
| 2.3 | Invoice number + due date + Invoice PDF | Finance | M |
| 2.4 | Receipt PDF generation | Finance | M |
| 2.5 | Maid / Domestic Help Registry | New module | M |
| 2.6 | Gates Master + Guard assignment | Admin Masters | M |
| 2.7 | Photo Gallery module (albums, Supabase Storage) | New module | M |
| 2.8 | Public website gallery page | Public site | M |
| 2.9 | Reports Hub (Collection, Dues, Complaints, Visitor) | Reports | M |
| 2.10 | Date-range filter on Executive Dashboard | Dashboard | S |
| 2.11 | Collection by category pie chart on dashboard | Dashboard | M |
| 2.12 | OTP for pre-approved visitor entry | Visitor Management | M |
| 2.13 | Lease start/end dates + Tenant expiry report | Members | M |
| 2.14 | Feedback module (star rating + category) | New module | M |
| 2.15 | Quorum + target audience on polls | Polls | S |
| 2.16 | Banner image on events | Events | XS |
| 2.17 | Society Profile page in admin | Admin | S |

### Priority 3 — Medium Impact, Medium–High Complexity

| # | Feature | Module | Effort |
|---|---|---|---|
| 3.1 | Mobile OTP login (Supabase Phone Auth) | Auth | M |
| 3.2 | Receivable sub-categories (line-item billing) | Finance | L |
| 3.3 | Late fee rules (grace period, %, frequency) | Finance | L |
| 3.4 | Late fee auto-calculation on overdue invoices | Finance | L |
| 3.5 | Guest type quotas in facility booking | Facilities | M |
| 3.6 | Cancellation window + Refund Rules | Facilities / Finance | M |
| 3.7 | Refund Requests workflow | Finance | M |
| 3.8 | Policies module (separate from Documents) | New module | M |
| 3.9 | Wing-wise invoice generation | Finance | M |
| 3.10 | Partial payment recording | Finance | M |
| 3.11 | Admin moderation queue for community | Admin | M |
| 3.12 | Paid events + fee collection | Events | L |
| 3.13 | Document version history | Documents | M |
| 3.14 | Facility availability + occupancy report | Reports | M |
| 3.15 | Holiday calendar (SLA exclusion) | Admin | S |

### Priority 4 — Lower Priority / Later Phase

| # | Feature | Notes |
|---|---|---|
| 4.1 | Shift assignment for staff | Tied to payroll system |
| 4.2 | Payment gateway integration (PG) | Infrastructure decision |
| 4.3 | Auto-cancellation for unpaid bookings | Depends on PG |
| 4.4 | Advance payment credit ledger | Complex accounting |
| 4.5 | WhatsApp notification integration | Third-party dependency |
| 4.6 | QR code for facility entry | Depends on guard tablet/phone |
| 4.7 | Recurring facility bookings | Complex calendar logic |
| 4.8 | Post-event photo gallery | Depends on Gallery module |
| 4.9 | Video uploads in Gallery/Notices | Storage cost + transcoding |
| 4.10 | Full society data export (DPDPA) | Needs data portability design |
| 4.11 | CSV bulk import for units / parking | One-time seeding; do manually for now |

---

## Summary Scorecard

| Domain | Housing360 Features | UTAMACS Coverage | Gap % |
|---|---|---|---|
| Authentication | 8 | 4 | 50% |
| Dashboard | 15 | 7 | 53% |
| Members & Units | 20 | 10 | 50% |
| Masters / Config | 12 | 5 | 58% |
| Notices / Announcements | 14 | 7 | 50% |
| Finance & Billing | 22 | 8 | 64% |
| Complaints | 14 | 10 | 29% |
| Facility Booking | 18 | 9 | 50% |
| Visitor Management | 18 | 10 | 44% |
| Parking | 12 | 7 | 42% |
| Staff & Maids | 14 | 5 | 64% |
| Media Gallery | 10 | 0 | 100% |
| Community / Marketplace | 12 | 7 | 42% |
| Documents | 8 | 5 | 37% |
| Polls | 9 | 6 | 33% |
| Events | 12 | 7 | 42% |
| Reports | 10 | 2 | 80% |
| Feedbacks | 7 | 0 | 100% |
| Refunds | 8 | 0 | 100% |
| Admin / Settings | 10 | 6 | 40% |
| **TOTAL** | **241** | **115** | **52%** |

UTAMACS also has ~11 exclusive features Housing360 lacks (HOTO, Snag, DPDPA, TDS, AGM, Letters, Rules Engine, Assets, Board Resolutions, Audit Log, Bulk Email).

---

*End of report. Use the Priority 1 and Priority 2 backlog as the near-term implementation roadmap.*
