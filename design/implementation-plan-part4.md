# UTAMACS Portal — Full Implementation Plan (Part 4 of 4)
# Modules: Reports Hub · Admin Settings · Society Profile · Navigation & PortalLayout · Migration Sequence · Implementation Sprints

---

## MODULE 19 — Reports Hub

### 19A. No new tables — all reports query existing tables

### 19B. New Page: `src/pages/portal/analytics/index.astro`

The existing `analytics/index.astro` is likely a stub. Extend it into the full Reports Hub.

**Access:** exec/admin only (redirect 403 for member/guard/vendor)

**Layout:** left sidebar for report type selection (on desktop) | main content area

```html
<div class="flex gap-6">
  <!-- Sidebar -->
  <div class="w-64 shrink-0 hidden lg:block">
    <div class="card-premium p-4">
      <p class="text-xs font-semibold text-text-secondary uppercase tracking-wide mb-3">Reports</p>
      <nav class="space-y-1">
        <a href="#collection" class="report-nav-link active">
          <i class="fas fa-rupee-sign w-4"></i> Collection Report
        </a>
        <a href="#dues" class="report-nav-link">
          <i class="fas fa-exclamation-circle w-4"></i> Pending Dues
        </a>
        <a href="#complaints" class="report-nav-link">
          <i class="fas fa-tools w-4"></i> Complaint Resolution
        </a>
        <a href="#facilities" class="report-nav-link">
          <i class="fas fa-swimming-pool w-4"></i> Facility Utilisation
        </a>
        <a href="#visitors" class="report-nav-link">
          <i class="fas fa-user-check w-4"></i> Visitor Log
        </a>
        <a href="#tenants" class="report-nav-link">
          <i class="fas fa-key w-4"></i> Tenant Expiry
        </a>
        <a href="#members" class="report-nav-link">
          <i class="fas fa-users w-4"></i> Member Directory
        </a>
      </nav>
    </div>
  </div>

  <!-- Report content area -->
  <div class="flex-1 min-w-0" id="report-area">
    <!-- Report panels loaded via fetch on nav click -->
  </div>
</div>
```

Report nav link style: `flex items-center gap-2 px-3 py-2 rounded-lg text-sm text-text-secondary hover:bg-primary-50 hover:text-primary-700 transition-colors`
Active state: `bg-primary-100 text-primary-700 font-medium`

### 19C. Individual Reports

#### Report 1: Collection Report

**Filter bar:**
- Date From / Date To (date inputs)
- Wing (select, all wings)
- Payment Mode (All / Cash / UPI / Cheque / NEFT)
- Category (All / from receivable_categories)
- "Generate" button → fetches `/api/v1/reports/collection?from=&to=&wing=&mode=&category=`

**Output:**
- Summary row: Total Collected ₹ | Period | Unit Count | Avg per Unit
- Chart: Bar chart by month (recharts BarChart, colors: primary-600)
- Table:
  ```
  Date | Flat No. | Block | Member Name | Category | Mode | Reference | Amount
  ```
- Totals row at bottom (bold)
- Export CSV button: `/api/v1/reports/collection/export`
- Export PDF button: generates PDF via pdfmake with table + summary

#### Report 2: Pending Dues Report

**Filter bar:** Wing | Overdue by (All / > 30 days / > 60 days / > 90 days) | Billing Period

**Output:**
- Summary: Total Pending ₹ | Count of units with dues | Average overdue days
- Table:
  ```
  Flat No. | Block | Owner Name | Billing Period | Due Date | Base Amount | Late Fee | Total Due | Overdue Days
  ```
- Colour coding: `>90 days = text-red-600`, `>60 days = text-orange-500`, `>30 days = text-amber-600`
- Export CSV + PDF

#### Report 3: Complaint Resolution Report

**Filter bar:** Date Range | Category | Assigned To | Priority

**Output:**
- Summary cards: Total Raised | Resolved | SLA Breached | Avg Resolution Hours | Avg Rating
- Category breakdown table:
  ```
  Category | Total | Open | Resolved | SLA Breached | Avg Hours to Resolve | Avg Rating
  ```
- Individual complaints table:
  ```
  Ticket # | Date Raised | Category | Priority | Assignee | Resolved Date | Hours | SLA | Rating
  ```
- Export CSV

#### Report 4: Facility Utilisation Report

**Filter bar:** Date Range | Facility

**Output:**
- Summary: Total Bookings | Total Revenue ₹ | Occupancy %
- Per-facility table:
  ```
  Facility | Bookings | Occupancy % | Adults | Children | Seniors | Revenue ₹
  ```
- Month-wise trend bar chart
- Export CSV

#### Report 5: Visitor Log Report

**Filter bar:** Date Range | Gate | Visitor Type | Flat No.

**Output:**
- Summary: Total visits | Unique visitors | By type breakdown (donut chart)
- Table:
  ```
  Date | Time In | Time Out | Name | Phone | Type | Flat | Gate | Vehicle No. | Recorded By
  ```
- Export CSV

#### Report 6: Tenant Expiry Report

**Filter bar:** Expiring within (30 / 60 / 90 / 180 days) | Wing

**Output:**
- Summary: Count expiring in 30/60/90 days
- Table:
  ```
  Flat No. | Block | Tenant Name | Phone | Lease Start | Lease End | Days Remaining | Owner Name
  ```
- Colour: ≤30 days = red, 31–60 = amber, 61–90 = yellow
- Export CSV (for sending reminders)

#### Report 7: Member Directory Export

**Filter bar:** Wing | Occupancy Status | Role

**Output:**
- Full table preview (10 rows) + "Download Full CSV" button
- CSV columns:
  ```
  Flat No., Block, Floor, Type, Occupancy Status, Owner Name, Owner Email, Owner Phone,
  Tenant Name, Tenant Email, Tenant Phone, Move In Date, Move Out Date, NRI, Num Occupants
  ```

### 19D. API Routes

- `GET /api/v1/reports/collection` + `/export`
- `GET /api/v1/reports/dues` + `/export`
- `GET /api/v1/reports/complaints` + `/export`
- `GET /api/v1/reports/facilities` + `/export`
- `GET /api/v1/reports/visitors` + `/export`
- `GET /api/v1/reports/tenant-expiry` + `/export`
- `GET /api/v1/reports/members/export`

All exec-only. CSV export returns `Content-Type: text/csv; charset=utf-8` with `Content-Disposition: attachment; filename="{report}-{date}.csv"`.

---

## MODULE 20 — Admin Settings Enhancements

### 20A. Society Profile Page

**Migration: addition to `034_self_registration.sql` or new `053_society_profile.sql`:**

```sql
-- Societies table already exists; extend with UI-editable fields
ALTER TABLE societies
  ADD COLUMN IF NOT EXISTS logo_key           text,         -- Supabase Storage key
  ADD COLUMN IF NOT EXISTS tagline            text,         -- short description
  ADD COLUMN IF NOT EXISTS contact_email      text,
  ADD COLUMN IF NOT EXISTS contact_phone      text,
  ADD COLUMN IF NOT EXISTS website_url        text,
  ADD COLUMN IF NOT EXISTS facebook_url       text,
  ADD COLUMN IF NOT EXISTS whatsapp_group_url text,
  ADD COLUMN IF NOT EXISTS fiscal_year_start  text DEFAULT 'april'
    CHECK (fiscal_year_start IN ('january','april')),
  ADD COLUMN IF NOT EXISTS timezone           text DEFAULT 'Asia/Kolkata',
  ADD COLUMN IF NOT EXISTS currency_symbol    text DEFAULT '₹',
  ADD COLUMN IF NOT EXISTS invoice_prefix     text DEFAULT 'INV',
  ADD COLUMN IF NOT EXISTS receipt_prefix     text DEFAULT 'RCP';
```

**`src/pages/portal/admin/society-profile.astro`** (new page)
- Access: admin only (isAdmin = true)
- Grouped sections:

**Section 1: Basic Information**
```html
<div class="card-premium p-6">
  <h2 class="text-xl font-semibold text-primary-600 mb-4">
    <i class="fas fa-building mr-2"></i>Basic Information
  </h2>
  <div class="flex gap-6 mb-6">
    <!-- Logo upload -->
    <div class="text-center">
      <div class="w-24 h-24 rounded-xl bg-primary-50 flex items-center justify-center overflow-hidden mb-2">
        <img id="logo-preview" src="{society.logo_url}" class="w-full h-full object-contain" />
      </div>
      <label class="btn-outline text-xs py-1.5 cursor-pointer">
        Change Logo
        <input type="file" accept="image/jpeg,image/png,image/svg+xml" class="hidden" id="logo-upload" />
      </label>
    </div>
    <!-- Fields -->
    <div class="flex-1 grid grid-cols-1 md:grid-cols-2 gap-4">
      <div>
        <label class="form-label">Society Name</label>
        <input type="text" name="name" class="form-input" value="{society.name}" />
      </div>
      <div>
        <label class="form-label">Registration Number</label>
        <input type="text" name="registration_no" class="form-input" value="{society.registration_no}" readonly />
        <p class="text-xs text-text-secondary mt-1">Contact admin to change registration number</p>
      </div>
      <div>
        <label class="form-label">Tagline</label>
        <input type="text" name="tagline" class="form-input" placeholder="e.g. Your home, our responsibility" />
      </div>
      <div>
        <label class="form-label">GSTIN</label>
        <input type="text" name="gstin" class="form-input" value="{society.gstin}" />
      </div>
      <div>
        <label class="form-label">PAN</label>
        <input type="text" name="pan" class="form-input" value="{society.pan}" />
      </div>
    </div>
  </div>
</div>
```

**Section 2: Address**
```html
<div class="card-premium p-6 mt-4">
  <h2 class="text-xl font-semibold text-primary-600 mb-4">
    <i class="fas fa-map-marker-alt mr-2"></i>Address
  </h2>
  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <div class="md:col-span-2">
      <label class="form-label">Street Address</label>
      <input type="text" name="address" class="form-input" value="{society.address}" />
    </div>
    <div>
      <label class="form-label">City</label>
      <input type="text" name="city" class="form-input" value="{society.city}" />
    </div>
    <div>
      <label class="form-label">State</label>
      <input type="text" name="state" class="form-input" value="{society.state}" />
    </div>
    <div>
      <label class="form-label">PIN Code</label>
      <input type="text" name="pincode" class="form-input" value="{society.pincode}" maxlength="6" pattern="[0-9]{6}" />
    </div>
  </div>
</div>
```

**Section 3: Contact & Social**
```html
<div class="card-premium p-6 mt-4">
  <h2 class="text-xl font-semibold text-primary-600 mb-4">
    <i class="fas fa-phone mr-2"></i>Contact & Social
  </h2>
  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <div>
      <label class="form-label">Contact Email</label>
      <input type="email" name="contact_email" class="form-input" />
    </div>
    <div>
      <label class="form-label">Contact Phone</label>
      <input type="tel" name="contact_phone" class="form-input" />
    </div>
    <div>
      <label class="form-label">Website URL</label>
      <input type="url" name="website_url" class="form-input" placeholder="https://utamacs.org" />
    </div>
    <div>
      <label class="form-label">WhatsApp Group Link</label>
      <input type="url" name="whatsapp_group_url" class="form-input" />
    </div>
  </div>
</div>
```

**Section 4: Finance & Billing Preferences**
```html
<div class="card-premium p-6 mt-4">
  <h2 class="text-xl font-semibold text-primary-600 mb-4">
    <i class="fas fa-cog mr-2"></i>Finance Preferences
  </h2>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    <div>
      <label class="form-label">Invoice Prefix</label>
      <input type="text" name="invoice_prefix" class="form-input" value="INV" maxlength="10" />
      <p class="text-xs text-text-secondary mt-1">e.g. INV → INV-2025-0001</p>
    </div>
    <div>
      <label class="form-label">Receipt Prefix</label>
      <input type="text" name="receipt_prefix" class="form-input" value="RCP" maxlength="10" />
    </div>
    <div>
      <label class="form-label">Fiscal Year Start</label>
      <select name="fiscal_year_start" class="form-input">
        <option value="april" selected>April (Indian FY)</option>
        <option value="january">January</option>
      </select>
    </div>
  </div>
</div>
```

**Save button:** `btn-primary mt-6` → PATCH `/api/v1/admin/society`

### 20B. Holiday Calendar

**Migration: add to `053_society_profile.sql`:**

```sql
CREATE TABLE holiday_calendar (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  date        date NOT NULL,
  name        text NOT NULL,             -- "Republic Day", "Diwali", etc.
  is_national bool NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(society_id, date)
);

-- Used by: SLA exclusion (don't count holidays in SLA hours),
-- Facility booking (warn/block if holiday maintenance)
```

**`src/pages/portal/admin/holidays.astro`** (new page, sub-section under admin)
- Year selector (current year shown)
- Calendar grid view (12 months, 4 cols × 3 rows)
  - Holiday dates highlighted with amber background
  - Click date → add/remove holiday modal
- Bulk: "Import National Holidays {year}" button → pre-seeds standard Indian national holidays for that year
- Table below calendar: Date | Holiday Name | Type | Actions

**Pre-seed function for national holidays:**
```typescript
const INDIAN_NATIONAL_HOLIDAYS_2025 = [
  { date: '2025-01-26', name: "Republic Day" },
  { date: '2025-08-15', name: "Independence Day" },
  { date: '2025-10-02', name: "Gandhi Jayanti" },
  // State holidays for Telangana:
  { date: '2025-06-02', name: "Telangana Formation Day" },
]
```

---

## MODULE 21 — PortalLayout & Navigation Updates

### 21A. New Module Registrations in `PortalLayout.astro`

Add to the fallback modules array (and ensure `feature_flags` table gets corresponding seeds):

```typescript
// New modules to add
const NEW_MODULES = [
  { key: 'gallery',     displayName: 'Gallery',      icon: 'fas fa-images',          path: '/portal/gallery',            roles: ['all'] },
  { key: 'maids',       displayName: 'Domestic Help', icon: 'fas fa-user-friends',    path: '/portal/maids',              roles: ['all'] },
  { key: 'feedback',    displayName: 'Feedback',      icon: 'fas fa-star-half-alt',   path: '/portal/feedback',           roles: ['all'] },
  { key: 'policies',    displayName: 'Policies',      icon: 'fas fa-shield-alt',       path: '/portal/policies',           roles: ['all'] },
  { key: 'refunds',     displayName: 'Refunds',       icon: 'fas fa-undo',             path: '/portal/finance/refunds',    roles: ['all'] },
  { key: 'reports',     displayName: 'Reports',       icon: 'fas fa-chart-bar',        path: '/portal/analytics',          roles: ['executive','admin'] },
  { key: 'onboarding',  displayName: 'Onboarding',    icon: 'fas fa-user-plus',        path: '/portal/admin/onboarding',   roles: ['executive','admin'] },
]
```

**Sidebar navigation grouping** — group modules into logical sections with dividers:

```html
<!-- My Home section -->
<div class="nav-section">
  <p class="nav-section-label">My Home</p>
  <!-- Dashboard, Profile, Feedback -->
</div>

<!-- Community section -->
<div class="nav-section">
  <p class="nav-section-label">Community</p>
  <!-- Notices, Events, Polls, Community Board, Gallery -->
</div>

<!-- Services section -->
<div class="nav-section">
  <p class="nav-section-label">Services</p>
  <!-- Complaints, Facilities, Visitors, Maids, Parking, Vendors -->
</div>

<!-- Finance section -->
<div class="nav-section">
  <p class="nav-section-label">Finance</p>
  <!-- Finance & Dues, Refunds -->
</div>

<!-- Society section -->
<div class="nav-section">
  <p class="nav-section-label">Society</p>
  <!-- Documents, Policies, AGM, HOTO, Snags, Letters -->
</div>

<!-- Management (exec/admin only) -->
<div class="nav-section" x-show="isPrivileged">
  <p class="nav-section-label">Management</p>
  <!-- Members, Reports, Analytics, Notifications -->
</div>

<!-- Administration (admin only) -->
<div class="nav-section" x-show="isAdmin">
  <p class="nav-section-label">Administration</p>
  <!-- Admin sub-pages: Society Profile, Gates, Receivables, Refund Rules, Holidays,
       RBAC, Features, Audit, Consent, Staff, TDS, Email Drafts, Onboarding -->
</div>
```

Nav section label style: `text-xs font-semibold text-text-secondary uppercase tracking-wider px-3 py-2 mt-4 first:mt-0`

### 21B. Notification Badges on Nav

Add unread counts to sidebar items:
- Notices: unread count
- Complaints (exec): open SLA-breached count
- Onboarding (exec): pending requests count
- Feedback (exec): unread count

Implementation: fetch single lightweight API `GET /api/v1/nav/badges` on page load:
```typescript
interface NavBadges {
  unread_notices: number
  open_complaints: number      // exec only
  sla_breached: number         // exec only
  onboarding_pending: number   // exec only
  unread_feedback: number      // exec only
  unread_notifications: number
  upcoming_bookings: number
}
```

Badge HTML (add alongside nav link text):
```html
{count > 0 && (
  <span class="ml-auto bg-red-500 text-white text-xs font-bold rounded-full w-5 h-5 flex items-center justify-center">
    {count > 99 ? '99+' : count}
  </span>
)}
```

---

## MODULE 22 — Feature Flag Seeds

Migration: `054_feature_flag_seeds.sql`

```sql
-- Seed feature flags for new modules
INSERT INTO feature_flags (society_id, module_key, is_active, display_order)
SELECT s.id, m.key, true, m.display_order
FROM societies s
CROSS JOIN (VALUES
  ('gallery', 18),
  ('maids', 19),
  ('feedback', 20),
  ('policies', 21),
  ('refund_rules', 22),
  ('onboarding_queue', 23),
  ('reports_hub', 24),
  ('gates_master', 25),
  ('receivable_config', 26),
  ('holiday_calendar', 27),
  ('society_profile', 28)
) AS m(key, display_order)
ON CONFLICT (society_id, module_key) DO NOTHING;
```

---

## MODULE 23 — Public Website Additions (utamacs.org)

These are changes to the `_old_src` / `src/site` static site, not the portal.

### 23A. Photo Gallery Page (`src/site/pages/gallery.html` or equivalent)

- Public gallery showing published albums
- Fetches from Supabase (public RLS read on published albums)
- Grid of albums with cover photos
- Click album → photo grid with lightbox
- No authentication required
- Same Tailwind theme as public website

### 23B. Nav link addition

Add "Gallery" to the public website navigation (nav.html component):
```html
<a href="/gallery.html" class="nav-link">Gallery</a>
```

---

## MIGRATION SEQUENCE (run in order)

| # | File | Description |
|---|------|-------------|
| 034 | `034_self_registration.sql` | Onboarding requests table |
| 035 | `035_phone_login.sql` | Phone field on profiles |
| 036 | `036_gates_master.sql` | Gates + guard assignments |
| 037 | `037_receivable_config.sql` | Receivable categories, sub-categories, late fee rules |
| 038 | `038_member_unit_enhancements.sql` | Profile + unit field additions, tenancies table |
| 039 | `039_notices_enhancements.sql` | Notice attachments, scheduling, Policies module |
| 040 | `040_finance_enhancements.sql` | Invoice line items, late fee charges, partial payments, credits |
| 041 | `041_refunds.sql` | Refund rules + requests |
| 042 | `042_complaints_enhancements.sql` | Sub-categories, attachments, ratings |
| 043 | `043_facility_enhancements.sql` | Guest types, photos, maintenance blocks, buffers |
| 044 | `044_visitor_enhancements.sql` | Gate_id on visitor_logs, expanded type list, visitor_invites |
| 045 | `045_parking_enhancements.sql` | Parking level/block/vehicle, slot transfers |
| 046 | `046_maid_registry.sql` | Maids, maid_unit_approvals, maid_attendance |
| 047 | `047_gallery.sql` | Gallery albums + photos |
| 048 | `048_community_enhancements.sql` | Post images, pin, report, marketplace images/expiry |
| 049 | `049_document_enhancements.sql` | Document versions, download count, search_text |
| 050 | `050_polls_enhancements.sql` | Quorum, target_wings, results visibility, attachment |
| 051 | `051_events_enhancements.sql` | Banner, guests, paid events, attendance |
| 052 | `052_feedbacks.sql` | Feedback table |
| 053 | `053_society_profile.sql` | Society profile extensions, holiday calendar |
| 054 | `054_feature_flag_seeds.sql` | Feature flag entries for new modules |

---

## IMPLEMENTATION SPRINTS

### Sprint 1 — Foundation & Quick Wins (2 weeks)
**Goal:** Highest-impact changes with lowest risk. All are isolated additions.

1. `038` migration → member/unit field additions (no breaking changes)
2. Profile page → emergency contact + avatar upload
3. Member directory → Wing filter + Occupancy filter + CSV export
4. `042` migration (partial) → complaint sub-categories seed + filter
5. Complaint new form → sub-category select + photo attachment
6. Complaint detail → SLA overdue badge + post-resolution star rating
7. `044` migration → expanded visitor type list + gate_id column
8. Visitor list → type filter + gate filter + CSV export
9. Notice form → image attachment + scheduled publish + expiry + pinned flag
10. Community post form → image upload

### Sprint 2 — Core New Modules (3 weeks)
**Goal:** New standalone modules that don't depend on Sprint 3 finance.

1. `036` migration + Gates Master page + guard assignment UI
2. `046` migration + Maid Registry pages (member + guard + exec views)
3. `047` migration + Gallery module (albums + photo upload + lightbox)
4. Public website gallery page
5. `048` migration + community/marketplace image support + moderation queue
6. `052` migration + Feedback module (member form + exec view)
7. `039` migration + Policies module (create, view, acknowledge, portal gate)
8. `045` migration + Parking enhancements (level, vehicle, RC upload)
9. `051` migration + Event banner + attendance marking

### Sprint 3 — Finance & Billing Depth (3 weeks)
**Goal:** Serious finance work — additive to existing billing without breaking it.

1. `037` migration + Receivable Categories/Sub-categories + Late Fee Rules pages
2. `040` migration + Invoice line items (billing period form extended)
3. Invoice PDF generation (pdfmake)
4. Receipt PDF generation
5. Late fee auto-calculation edge function
6. Partial payment UI
7. `041` migration + Refund Rules config page
8. Refund Requests workflow (member + exec)
9. `039` (society profile table) → `053` migration + Society Profile admin page
10. Holiday Calendar page

### Sprint 4 — Reports Hub & Dashboard Enhancement (2 weeks)
**Goal:** Turn raw data into insight.

1. Reports Hub page with 7 report types + CSV export
2. Date-range picker on Executive Dashboard
3. Collection by category pie chart
4. Monthly trend bar chart
5. Occupied/Vacant KPI cards
6. Onboarding Pending badge + Tenancy Expiry alert card
7. `034` + `035` migrations + Self-registration pages (owner/tenant/family)
8. Onboarding Queue admin page
9. Nav badge system (unread counts)
10. Sidebar navigation grouping

### Sprint 5 — Visitor OTP, Polls, Docs, Facility Depth (2 weeks)
**Goal:** Polish remaining gaps.

1. `044` visitor_invites table + Pre-approved visitor OTP (member invite + guard verify)
2. `043` facility_guest_types + Guest type quotas + live fee calculator in booking
3. Facility availability report
4. Facility photo gallery in facility edit
5. Facility maintenance blocks
6. `050` polls quorum + target wings + results visibility + PDF export
7. `049` document version history + download count + search
8. OTP login tab on portal login page (Supabase Phone Auth)
9. Parking slot transfer workflow
10. Feature flag seeds + PortalLayout navigation grouping update

---

## STORAGE BUCKETS REQUIRED

Add to Supabase Storage (public bucket = no auth for read; private = signed URL required):

| Bucket | Access | Used For |
|--------|--------|----------|
| `notice-attachments` | private | Notice images/PDFs |
| `policy-documents` | private | Policy PDFs |
| `complaint-attachments` | private | Complaint photos/videos |
| `facility-photos` | private | Facility gallery images |
| `gallery-photos` | private | Society photo gallery |
| `community-images` | private | Community post images |
| `marketplace-images` | private | Marketplace listing photos |
| `maid-documents` | private | Maid Aadhaar/Voter ID |
| `member-documents` | private | Lease agreements, RC docs |
| `event-banners` | private | Event banner images |
| `onboarding-docs` | private | Owner/tenant registration docs |
| `invoice-pdfs` | private | Generated invoice PDFs |
| `receipt-pdfs` | private | Generated receipt PDFs |
| `society-assets` | public | Society logo, public images |
| `avatars` | private | Member profile photos |

**Standard bucket policy (private):** Require auth; member reads own files; exec reads all within society. Signed URLs valid for 1 hour.

**API helper:** `src/lib/storage.ts` — `getSignedUrl(bucket, key, expiresIn=3600)` returns signed URL.

---

## ENVIRONMENT VARIABLES REQUIRED

Add to Vercel environment (and `.env.local` for dev):

```bash
# Existing
PUBLIC_SUPABASE_URL=
PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=

# New
SUPABASE_STORAGE_URL=           # for constructing signed URLs
PDFMAKE_FONT_URL=               # optional: custom font for PDF generation
SMTP_HOST=                      # for self-registration email notifications
SMTP_PORT=587
SMTP_USER=
SMTP_PASS=
FROM_EMAIL=noreply@utamacs.org
```

---

## COMPONENT REUSE GUIDELINES

These patterns must be followed across all new pages to maintain UTAMACS flavour:

### Status Badge
```tsx
// Status badge function — use everywhere
function statusBadge(status: string, colorMap: Record<string, string>) {
  const colors = colorMap[status] ?? 'bg-gray-100 text-gray-600'
  return `<span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${colors}">${status}</span>`
}
```

### Page Header Pattern
```html
<div class="flex items-center justify-between mb-6">
  <div>
    <h1 class="text-2xl font-bold text-primary-600 font-poppins">{Module Title}</h1>
    <p class="text-text-secondary text-sm mt-1">{Subtitle for context}</p>
  </div>
  {isPrivileged && (
    <button class="btn-primary" id="create-btn">
      <i class="fas fa-plus mr-2"></i>{Primary Action}
    </button>
  )}
</div>
```

### Empty State Pattern
```html
<div class="text-center py-16">
  <i class="fas fa-{icon} text-5xl text-primary-200 mb-4"></i>
  <h3 class="text-lg font-semibold text-text-primary mb-2">{No items yet}</h3>
  <p class="text-text-secondary text-sm mb-4">{Helpful description}</p>
  {canCreate && <button class="btn-primary">{Create First Item}</button>}
</div>
```

### Drawer / Side Panel Pattern
All detail views use a right-side panel (not modal) on desktop, bottom sheet on mobile:
```html
<div id="detail-panel" class="fixed inset-y-0 right-0 w-full sm:w-96 lg:w-[480px] bg-white shadow-large z-40 
     transform translate-x-full transition-transform duration-300 overflow-y-auto">
  <div class="sticky top-0 bg-white border-b border-border-light p-4 flex items-center justify-between">
    <h2 class="text-lg font-semibold text-primary-600">{Title}</h2>
    <button id="close-panel" class="text-text-secondary hover:text-text-primary">
      <i class="fas fa-times text-xl"></i>
    </button>
  </div>
  <div class="p-4">
    <!-- Content -->
  </div>
</div>
<!-- Backdrop -->
<div id="panel-backdrop" class="fixed inset-0 bg-black/40 z-30 hidden"></div>
```

### Form Validation Pattern
```javascript
// All forms use this pattern — no third-party libraries
function validateForm(formEl) {
  let valid = true
  formEl.querySelectorAll('[required]').forEach(input => {
    if (!input.value.trim()) {
      input.classList.add('border-red-400', 'ring-1', 'ring-red-400')
      valid = false
    } else {
      input.classList.remove('border-red-400', 'ring-1', 'ring-red-400')
    }
  })
  return valid
}
```

### API Call Pattern
```javascript
// All API calls use this helper (inline in each page's script tag)
async function apiCall(url, method = 'GET', body = null) {
  const opts = { method, headers: { 'Content-Type': 'application/json' } }
  if (body) opts.body = JSON.stringify(body)
  const res = await fetch(url, opts)
  if (!res.ok) {
    const err = await res.json().catch(() => ({ error: 'Request failed' }))
    throw new Error(err.error || `HTTP ${res.status}`)
  }
  return res.json()
}
```

### Toast Notification Pattern
```javascript
// Lightweight toast (already in main.js? if not, add once to PortalLayout)
function showToast(message, type = 'success') {
  const toast = document.createElement('div')
  toast.className = `fixed bottom-6 right-6 z-50 px-4 py-3 rounded-xl shadow-large text-sm font-medium
    transform translate-y-4 opacity-0 transition-all duration-300
    ${type === 'success' ? 'bg-secondary-500 text-white' : 'bg-red-500 text-white'}`
  toast.textContent = message
  document.body.appendChild(toast)
  requestAnimationFrame(() => {
    toast.classList.remove('translate-y-4', 'opacity-0')
  })
  setTimeout(() => {
    toast.classList.add('translate-y-4', 'opacity-0')
    setTimeout(() => toast.remove(), 300)
  }, 3000)
}
```

---

## DPDPA COMPLIANCE NOTES (for new modules)

Every new module that collects personal data must:

1. **Maid Registry**: Aadhaar numbers must be encrypted at the application layer before storage. Display only last-4 digits. Add field to consent log: "Maid registry data collected with resident consent".

2. **Onboarding Requests**: Uploaded documents (sale deed, lease agreement) stored in private Supabase bucket with 24-hour signed URL expiry. Auto-delete after 2 years if request rejected.

3. **Visitor Invites / OTP**: OTPs stored as SHA-256 hash; plain OTP shown once to member, never retrievable.

4. **Feedback (anonymous)**: `is_anonymous = true` → `submitted_by` still recorded in DB (for rate-limiting) but display shows "Anonymous Member". Exec cannot see identity. Audit log records the view event.

5. **Emergency Contact**: Visible only to exec/admin and the member themselves. Excluded from CSV exports unless member gives explicit export consent.

6. **Photo uploads**: All uploaded photos (maid photos, profile photos, complaint photos) added to audit_log with `action='photo_upload', resource_type='user_media'` for traceability.

---

*End of implementation plan. Parts 1–4 cover all 54 migrations, all new pages, all field-level changes, API routes, and component patterns. Implement in sprint order as each sprint's migrations are independent and additive.*
