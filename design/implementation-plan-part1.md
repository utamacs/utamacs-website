# UTAMACS Portal — Full Implementation Plan (Part 1 of 4)
# Modules: Authentication · Dashboard · Masters · Members & Units

**Architecture conventions throughout:**
- Every new page: `export const prerender = false` at top
- Every new page imports `PortalLayout` and passes `{title, user, activeModule}`
- Every new table includes `society_id uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE`
- Tailwind classes only — no inline styles
- Cards use `.card-premium` or `bg-white rounded-xl shadow-soft`
- Primary action buttons use `.btn-primary` (bg-primary-600)
- Secondary actions use `.btn-outline`
- Destructive actions use `bg-red-600 hover:bg-red-700 text-white rounded-lg px-4 py-2`
- Form inputs use `.form-input`, labels use `.form-label`
- Status badges: inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium
- Section headers: `text-2xl font-bold text-primary-600 font-poppins`
- All new API routes under `src/pages/api/v1/`
- All new portal pages under `src/pages/portal/`
- RLS: every table gets SELECT policy per society_id; exec-only tables get INSERT/UPDATE restricted to portal_role IN ('executive','secretary','president') OR is_admin

---

## MODULE 1 — Authentication & Onboarding

### 1A. Self-Registration Flows

#### 1A-1. Database Migration: `034_self_registration.sql`

```sql
-- Onboarding requests (owner / tenant / secondary user)
CREATE TABLE onboarding_requests (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  request_type        text NOT NULL CHECK (request_type IN ('owner','tenant','secondary_user')),
  status              text NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','under_review','approved','rejected','expired')),

  -- Applicant details (collected before account creation)
  applicant_name      text NOT NULL,
  applicant_email     text NOT NULL,
  applicant_phone     text NOT NULL,
  unit_number         text NOT NULL,          -- self-declared; verified by admin
  block               text,

  -- Owner-specific
  ownership_doc_key   text,                   -- Supabase Storage key for sale deed / khata

  -- Tenant-specific
  lease_start         date,
  lease_end           date,
  lease_doc_key       text,                   -- rental agreement upload
  owner_consent_at    timestamptz,            -- timestamp when owner approved tenant request
  owner_user_id       uuid REFERENCES auth.users(id) ON DELETE SET NULL,

  -- Secondary user (family member)
  primary_user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  relationship        text,                   -- Spouse, Parent, Child, Other
  secondary_phone     text,

  -- Review
  reviewed_by         uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at         timestamptz,
  rejection_reason    text,
  notes               text,

  -- Expiry (requests expire after 30 days if not actioned)
  expires_at          timestamptz NOT NULL DEFAULT now() + interval '30 days',
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_onboarding_society_status ON onboarding_requests(society_id, status);
CREATE INDEX idx_onboarding_email ON onboarding_requests(applicant_email);

-- RLS
ALTER TABLE onboarding_requests ENABLE ROW LEVEL SECURITY;

-- Applicant can see their own request (matched by email — pre-auth)
-- Exec/admin can see all requests for their society
CREATE POLICY "exec_view_requests" ON onboarding_requests
  FOR SELECT USING (
    society_id IN (
      SELECT society_id FROM profiles WHERE id = auth.uid()
    )
    AND EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND (p.portal_role IN ('executive','secretary','president') OR p.is_admin)
    )
  );

CREATE POLICY "exec_update_requests" ON onboarding_requests
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
      AND (p.portal_role IN ('executive','secretary','president') OR p.is_admin)
    )
  );

-- Public INSERT (unauthenticated applicant submits)
CREATE POLICY "public_insert_request" ON onboarding_requests
  FOR INSERT WITH CHECK (true);
```

#### 1A-2. New Pages

**`src/pages/register/index.astro`** — Public registration landing (NO auth required)
- Page title: "Join Urban Trilla Apartments Portal"
- Three cards side-by-side (lg:grid-cols-3):
  - **Owner Registration** — Icon: home, description, CTA → `/register/owner`
  - **Tenant Registration** — Icon: key, description, CTA → `/register/tenant`
  - **Add Family Member** — Icon: users, description, CTA → `/register/secondary` (requires login)
- Breadcrumb link back to utamacs.org
- No PortalLayout — uses a minimal layout with the UTAMACS logo and primary-600 header strip

**`src/pages/register/owner.astro`** — Owner self-registration form
Fields (in order, all `.form-input` styled):
1. Full Name (`applicant_name`) — required
2. Email Address (`applicant_email`) — type=email, required
3. Mobile Number (`applicant_phone`) — type=tel, pattern=`[6-9][0-9]{9}`, required
4. Block / Wing (`block`) — text, optional
5. Flat Number (`unit_number`) — required
6. Upload Sale Deed / Khata / Allotment Letter (`ownership_doc_key`) — file, accept=".pdf,.jpg,.jpeg,.png", max 5 MB
7. Checkbox: "I confirm I am the registered owner of this flat" — required
8. Checkbox: DPDPA consent — required, links to Privacy Policy
- On submit → POST `/api/v1/register/owner` → insert into `onboarding_requests` (type='owner', status='pending') → redirect to `/register/pending?ref={id}`
- Success page at `/register/pending`: "Your request has been submitted. The executive committee will review it within 5 working days. You will receive an email at {email}."

**`src/pages/register/tenant.astro`** — Tenant self-registration form
Fields:
1. Full Name
2. Email Address
3. Mobile Number
4. Block / Wing
5. Flat Number
6. Owner's Registered Email (`owner_email`) — used to send owner consent email
7. Lease Start Date (`lease_start`) — type=date
8. Lease End Date (`lease_end`) — type=date
9. Upload Rental Agreement (`lease_doc_key`) — file, PDF only
10. DPDPA consent checkbox
- On submit → POST `/api/v1/register/tenant`:
  - Insert `onboarding_requests` (type='tenant', status='pending')
  - Look up owner by email; if found, send owner a consent email with approve link (signed JWT, 7-day expiry)
  - Redirect to `/register/pending`

**`src/pages/register/secondary.astro`** — Family member addition (requires login)
- Auth-gated (redirect to login if not authenticated)
- Pre-fills: unit from logged-in member's profile
Fields:
1. Family Member's Full Name
2. Family Member's Email
3. Family Member's Mobile
4. Relationship (select: Spouse / Parent / Child / Sibling / Other)
5. Checkbox: DPDPA consent
- On submit → POST `/api/v1/register/secondary` → insert `onboarding_requests` (type='secondary_user', primary_user_id=logged-in user)

**`src/pages/portal/admin/onboarding.astro`** — Onboarding Queue (exec/admin only)
- Access: `isPrivileged` check; redirect 403 otherwise
- activeModule: 'admin'
- Three tabs: **Pending** | **Under Review** | **Resolved** (Approved / Rejected)
- Each tab shows a table with columns:
  - Name, Email, Phone, Type (badge: Owner=blue/Tenant=green/Family=purple), Flat No., Submitted, Expires, Actions
- **Pending** tab: action buttons "Review" (opens side drawer) + "Mark Expired"
- **Side drawer** fields shown:
  - All applicant fields read-only
  - Document preview link (opens Supabase Storage signed URL in new tab)
  - Notes textarea (exec internal note)
  - Status select: Under Review / Approved / Rejected
  - Rejection Reason (shown only if Rejected)
  - "Save Decision" button → PATCH `/api/v1/admin/onboarding/{id}`
  - On Approved: system auto-sends invite email to applicant via Supabase Auth `inviteUserByEmail()`

#### 1A-3. API Routes

- `POST /api/v1/register/owner` — public, no auth, inserts onboarding_request
- `POST /api/v1/register/tenant` — public, no auth
- `POST /api/v1/register/secondary` — auth required
- `GET /api/v1/admin/onboarding` — exec only, query params: status, type, page
- `PATCH /api/v1/admin/onboarding/[id]` — exec only, update status + reviewed_by
- `GET /api/v1/register/owner-consent/[token]` — public, verifies JWT, marks owner_consent_at

---

### 1B. OTP Login (Mobile Number)

#### 1B-1. Database Migration: `035_phone_login.sql`

```sql
-- Add phone (plaintext for Supabase auth lookup; separate from encrypted phone on profiles)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone_verified text UNIQUE;

-- Index for phone lookup
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON profiles(phone_verified);
```

Supabase Phone Auth must be enabled in the Supabase dashboard (Settings > Auth > Phone).

#### 1B-2. UI Changes

**`src/pages/portal/login.astro`** — Modified, not replaced
- Add a second tab strip below the header: **"Email & Password"** | **"Mobile OTP"**
- Tab toggle via vanilla JS (toggle hidden class on two form sections)
- OTP form fields:
  1. Mobile Number (type=tel, placeholder="+91 98765 43210")
  2. "Send OTP" button → POST `/api/v1/auth/send-otp`
  3. OTP field (6-digit, type=text, pattern=`\d{6}`) — shown after OTP sent
  4. "Verify & Login" button → POST `/api/v1/auth/verify-otp`
- Email form remains unchanged below the tab
- Tab indicator: border-b-2 border-primary-600 on active tab

#### 1B-3. API Routes

- `POST /api/v1/auth/send-otp` — calls `supabase.auth.signInWithOtp({ phone })`, returns {success}
- `POST /api/v1/auth/verify-otp` — calls `supabase.auth.verifyOtp({ phone, token, type:'sms' })`, sets session cookie, redirects to `/portal`

---

## MODULE 2 — Dashboard Enhancements

### 2A. Database: No new tables — derive from existing

New computed values needed from existing tables:
- Occupied vs Vacant: `units.is_vacant` already exists
- Visitor today: `visitor_logs` table (check if exists; add if not — see Visitor module)
- Upcoming bookings (member): `facility_bookings` table
- Collection by category: requires `receivable_categories` (new, see Finance module)

### 2B. API Changes

**`GET /api/v1/admin/kpis`** — extend response to include:

```typescript
// Add to ExecKPIs interface in ExecutiveDashboard.tsx:
interface ExecKPIs {
  // existing fields...
  total_complaints: number
  open_complaints: number
  sla_breached: number
  pending_dues_total: number
  collection_rate: number
  active_members: number
  upcoming_events: number
  pending_bookings: number
  // NEW:
  occupied_units: number
  vacant_units: number
  total_units: number
  visitors_today: number
  staff_present_today: number
  collection_this_month: number
  collection_last_month: number
  collection_by_category: { category: string; amount: number }[]  // for pie chart
  monthly_collection_trend: { month: string; amount: number }[]   // last 6 months
  onboarding_pending: number
}

// Add to MemberKPIs interface in MemberDashboard.tsx:
interface MemberKPIs {
  // existing...
  open_complaints: number
  pending_dues: number
  upcoming_events: number
  active_polls: number
  unread_notices: number
  unread_notifications: number
  // NEW:
  upcoming_bookings: number
  visitors_today: number  // member's own visitors
}
```

**`GET /api/v1/admin/kpis`** — add date_range query param:
- `?range=today|week|month|custom&from=YYYY-MM-DD&to=YYYY-MM-DD`
- collection_this_month and trend respect the range

### 2C. ExecutiveDashboard.tsx — Changes

**Date Range Picker** (add above KPI grid):
```tsx
// New state
const [range, setRange] = useState<'today'|'week'|'month'|'custom'>('month')
const [customFrom, setCustomFrom] = useState('')
const [customTo, setCustomTo] = useState('')

// UI: four pill buttons (Today / This Week / This Month / Custom)
// Custom shows two date inputs inline
// On change → re-fetch KPIs with ?range= param
```
Pill button style: `px-3 py-1.5 rounded-full text-sm font-medium border` with active state `bg-primary-600 text-white border-primary-600`

**New KPI Cards** (add to existing 8-card grid → expand to 12):
- Card 9: Occupied Units — icon=building, value=`{occupied_units}/{total_units}`, color=secondary-500
- Card 10: Vacant Units — icon=home (outline), value=`{vacant_units}`, color=accent-500
- Card 11: Visitors Today — icon=user-check, value=`{visitors_today}`, color=primary-400
- Card 12: Onboarding Pending — icon=clock, value=`{onboarding_pending}`, link to `/portal/admin/onboarding`, color=red-500 if >0 else gray

**New Chart: Collection by Category (Pie)**
```tsx
// Replace or add alongside existing pie chart
<PieChart width={280} height={280}>
  <Pie data={kpis.collection_by_category} dataKey="amount" nameKey="category"
       cx="50%" cy="50%" outerRadius={100} label={({category, percent}) =>
         `${category} ${(percent*100).toFixed(0)}%`} />
  <Tooltip formatter={(v: number) => `₹${v.toLocaleString('en-IN')}`} />
  <Legend />
</PieChart>
// Colors cycle through COLORS array
```

**New Chart: Monthly Collection Trend (Bar)**
```tsx
<BarChart width={480} height={220} data={kpis.monthly_collection_trend}>
  <CartesianGrid strokeDasharray="3 3" stroke="#E5E7EB" />
  <XAxis dataKey="month" tick={{fontSize:12}} />
  <YAxis tickFormatter={(v) => `₹${(v/1000).toFixed(0)}k`} />
  <Tooltip formatter={(v: number) => `₹${v.toLocaleString('en-IN')}`} />
  <Bar dataKey="amount" fill="#1E3A8A" radius={[4,4,0,0]} />
</BarChart>
```
Wrap both charts in `.card-premium p-6` with heading `text-lg font-semibold text-primary-600`.

**New Card: Upcoming Bookings for Member** (MemberDashboard.tsx)
- Fetch `/api/v1/facilities/my-bookings?upcoming=true&limit=3`
- Show date, facility name, time slot, status badge
- CTA: "View All Bookings" → `/portal/facilities`

---

## MODULE 3 — Masters / Configuration

### 3A. Gates Master

#### 3A-1. Migration: `036_gates_master.sql`

```sql
CREATE TABLE gates (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  name          text NOT NULL,                          -- "Main Gate", "East Gate", "Service Entry"
  gate_type     text NOT NULL DEFAULT 'both'
                  CHECK (gate_type IN ('entry','exit','both')),
  location_hint text,                                   -- "Near Block A", "Opposite Club House"
  is_active     bool NOT NULL DEFAULT true,
  display_order int  NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(society_id, name)
);

-- Guard ↔ Gate assignment (one guard can cover one gate per shift)
CREATE TABLE guard_gate_assignments (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  guard_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  gate_id     uuid NOT NULL REFERENCES gates(id) ON DELETE CASCADE,
  shift_start timestamptz NOT NULL DEFAULT now(),
  shift_end   timestamptz,                              -- NULL = open-ended
  assigned_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE gates ENABLE ROW LEVEL SECURITY;
ALTER TABLE guard_gate_assignments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "society_read_gates" ON gates FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "exec_manage_gates" ON gates FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE POLICY "guard_view_assignment" ON guard_gate_assignments FOR SELECT
  USING (guard_id = auth.uid() OR EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));
```

**Seed data** (insert after migration for Urban Trilla):
```sql
INSERT INTO gates (society_id, name, gate_type, location_hint, display_order)
SELECT id, 'Main Gate', 'both', 'Primary entrance', 1 FROM societies WHERE registration_no = 'UTAMACS-REG';
```

#### 3A-2. Page: `src/pages/portal/admin/gates.astro`

- activeModule: 'admin'
- Access: isPrivileged only
- **Gates table**: Name | Type badge | Location | Status toggle | Edit | Delete
  - Type badges: Entry=green, Exit=amber, Both=primary-600
  - Status toggle: slide toggle (rounded-full w-10 h-5 bg-primary-600 when active)
- **Add Gate button** → inline expandable form row (no modal, fits UTAMACS pattern)
  - Fields: Name (text), Gate Type (select), Location Hint (text), Active (checkbox)
  - Save → POST `/api/v1/admin/gates`
- **Guard Assignments sub-section** below gates table:
  - Shows active guard → gate mappings for today
  - Assign button → modal with: Guard select (filtered to security_guard role), Gate select, Shift End (optional datetime)

#### 3A-3. API Routes

- `GET /api/v1/admin/gates` — list society gates
- `POST /api/v1/admin/gates` — create gate (exec only)
- `PATCH /api/v1/admin/gates/[id]` — update gate
- `DELETE /api/v1/admin/gates/[id]` — soft delete (set is_active=false)
- `POST /api/v1/admin/gates/[id]/assign` — assign guard to gate
- `GET /api/v1/admin/gates/current-assignments` — today's guard assignments

---

### 3B. Receivable Sub-Categories & Late Fee Rules

#### 3B-1. Migration: `037_receivable_config.sql`

```sql
-- Top-level receivable categories (Maintenance, Sinking Fund, Utility, etc.)
CREATE TABLE receivable_categories (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  name          text NOT NULL,
  description   text,
  hsn_sac_code  text,                    -- GST compliance
  is_active     bool NOT NULL DEFAULT true,
  display_order int  NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(society_id, name)
);

-- Sub-categories with calculation rules
CREATE TABLE receivable_subcategories (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  category_id         uuid NOT NULL REFERENCES receivable_categories(id) ON DELETE CASCADE,
  name                text NOT NULL,
  calculation_type    text NOT NULL DEFAULT 'fixed'
                        CHECK (calculation_type IN ('fixed','per_sqft','per_unit','variable')),
  amount              numeric(12,2),           -- fixed amount OR rate per sqft/unit
  frequency           text NOT NULL DEFAULT 'monthly'
                        CHECK (frequency IN ('monthly','quarterly','half_yearly','annually','one_time')),
  apply_to_wings      text[],                  -- NULL = all wings; populated = specific wings only
  gst_rate            numeric(5,2) DEFAULT 0,  -- GST % (0, 5, 12, 18)
  is_active           bool NOT NULL DEFAULT true,
  display_order       int  NOT NULL DEFAULT 0,
  created_at          timestamptz NOT NULL DEFAULT now()
);

-- Late fee rules per sub-category
CREATE TABLE late_fee_rules (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  subcategory_id      uuid NOT NULL REFERENCES receivable_subcategories(id) ON DELETE CASCADE,
  grace_period_days   int  NOT NULL DEFAULT 0,     -- days after due date before late fee kicks in
  fee_type            text NOT NULL DEFAULT 'fixed'
                        CHECK (fee_type IN ('fixed','percentage')),
  fee_amount          numeric(12,2) NOT NULL,      -- fixed ₹ OR percentage %
  fee_frequency       text NOT NULL DEFAULT 'one_time'
                        CHECK (fee_frequency IN ('one_time','monthly')),  -- one_time = single charge; monthly = recurring
  max_fee_cap         numeric(12,2),               -- NULL = uncapped
  waiver_type         text NOT NULL DEFAULT 'none'
                        CHECK (waiver_type IN ('none','full','partial')),
  created_at          timestamptz NOT NULL DEFAULT now(),
  UNIQUE(subcategory_id)
);

-- Enable RLS on all three tables
ALTER TABLE receivable_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE receivable_subcategories ENABLE ROW LEVEL SECURITY;
ALTER TABLE late_fee_rules ENABLE ROW LEVEL SECURITY;

-- Read: all authenticated members of society
CREATE POLICY "society_read_categories" ON receivable_categories FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));
CREATE POLICY "society_read_subcategories" ON receivable_subcategories FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));
CREATE POLICY "society_read_late_fees" ON late_fee_rules FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

-- Write: exec/admin only
CREATE POLICY "exec_manage_categories" ON receivable_categories FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid() AND (portal_role IN ('executive','secretary','president') OR is_admin)));
CREATE POLICY "exec_manage_subcategories" ON receivable_subcategories FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid() AND (portal_role IN ('executive','secretary','president') OR is_admin)));
CREATE POLICY "exec_manage_late_fees" ON late_fee_rules FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid() AND (portal_role IN ('executive','secretary','president') OR is_admin)));
```

#### 3B-2. Page: `src/pages/portal/admin/receivables.astro`

- Tab 1: **Categories** — table: Name | HSN/SAC | Status | Actions
  - Add form (inline): Name, Description, HSN/SAC Code, Active
- Tab 2: **Sub-Categories** — table: Category | Sub-Category | Type | Amount | Frequency | Wings | Active | Actions
  - Add/edit form (modal):
    - Category (select, from categories list)
    - Sub-Category Name
    - Calculation Type (select: Fixed ₹ / Per Sq.Ft / Per Unit / Variable)
    - Amount (number, shown for Fixed/Per Sqft/Per Unit)
    - Frequency (select: Monthly / Quarterly / Half-Yearly / Annually / One-Time)
    - Apply to Wings (multi-select, optional — leave blank for all)
    - GST Rate % (select: 0 / 5 / 12 / 18)
    - Active toggle
- Tab 3: **Late Fee Rules** — one row per sub-category that has a rule
  - Add/edit form (modal):
    - Sub-Category (select)
    - Grace Period (days, number, default 0)
    - Fee Type (radio: Fixed ₹ / Percentage %)
    - Fee Amount / Rate (number)
    - Fee Frequency (radio: One-Time / Monthly recurring)
    - Maximum Cap ₹ (optional)
    - Waiver Type (select: None / Full Waiver / Partial)

---

## MODULE 4 — Members & Units

### 4A. Schema Additions: `038_member_unit_enhancements.sql`

```sql
-- Units table already has: unit_number, block, floor, area_sqft, unit_type, is_vacant
-- Profiles table already has: residency_type, move_in_date, move_out_date, family_members (jsonb)
-- Add missing fields:

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS emergency_contact_name  text,
  ADD COLUMN IF NOT EXISTS emergency_contact_phone text,
  ADD COLUMN IF NOT EXISTS emergency_contact_rel   text,          -- relationship
  ADD COLUMN IF NOT EXISTS num_occupants           int DEFAULT 1,
  ADD COLUMN IF NOT EXISTS nri_flag                bool DEFAULT false,
  ADD COLUMN IF NOT EXISTS avatar_url              text;          -- public URL (from storage key)

-- Units: add explicit occupancy status (derived currently from is_vacant)
ALTER TABLE units
  ADD COLUMN IF NOT EXISTS occupancy_status text NOT NULL DEFAULT 'vacant'
    CHECK (occupancy_status IN ('owner_occupied','tenant_occupied','vacant','under_renovation'));

-- Tenancy tracking (separate from profile so history is preserved when tenant changes)
CREATE TABLE tenancies (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  unit_id         uuid NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  tenant_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lease_start     date NOT NULL,
  lease_end       date NOT NULL,
  lease_doc_key   text,               -- Supabase Storage key
  monthly_rent    numeric(12,2),      -- informational; not used for billing
  is_active       bool NOT NULL DEFAULT true,
  created_by      uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (lease_end > lease_start)
);

CREATE INDEX idx_tenancies_unit ON tenancies(unit_id, is_active);
CREATE INDEX idx_tenancies_expiry ON tenancies(lease_end) WHERE is_active = true;

ALTER TABLE tenancies ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_own_tenancy" ON tenancies FOR SELECT
  USING (tenant_user_id = auth.uid() OR EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE POLICY "exec_manage_tenancies" ON tenancies FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));
```

### 4B. Member Directory Page Enhancements

**`src/pages/portal/members/index.astro`** — extend existing page

**Add filter bar** above the member table (currently missing):
```html
<!-- Filter bar — same pattern as complaints page -->
<div class="flex flex-wrap gap-3 mb-6">
  <!-- Wing/Block filter -->
  <select id="filter-block" class="form-input w-auto text-sm py-2">
    <option value="">All Wings</option>
    <!-- populated from units.block distinct values -->
  </select>

  <!-- Occupancy status filter -->
  <select id="filter-occupancy" class="form-input w-auto text-sm py-2">
    <option value="">All Occupancy</option>
    <option value="owner_occupied">Owner Occupied</option>
    <option value="tenant_occupied">Tenant Occupied</option>
    <option value="vacant">Vacant</option>
    <option value="under_renovation">Under Renovation</option>
  </select>

  <!-- Role filter (existing, keep) -->
  <select id="filter-role" class="form-input w-auto text-sm py-2">...</select>

  <!-- Tenancy expiry alert -->
  <button id="filter-expiring" class="btn-outline text-sm py-2 text-amber-600 border-amber-400">
    <i class="fas fa-clock mr-1"></i> Expiring in 30 days
  </button>

  <!-- Export -->
  <button id="export-csv" class="btn-outline text-sm py-2 ml-auto">
    <i class="fas fa-download mr-1"></i> Export CSV
  </button>
</div>
```

**Member detail drawer / modal** — extend with new fields:
- Floor (read from `units.floor`)
- Area (sqft) (read from `units.area_sqft`)
- Occupancy Status (editable select for exec)
- Move-in Date (editable date for exec)
- Move-out Date (editable date for exec)
- Emergency Contact (Name, Phone, Relationship)
- NRI Flag (checkbox, visible to exec — affects TDS module)
- Number of Occupants
- Lease Details sub-section (tenant only): Lease Start, Lease End, Days Remaining badge, Upload Agreement

**Tenancy Expiry Alert card** — add to Executive Dashboard:
```tsx
// Fetch /api/v1/admin/tenancies?expiring_within=30
// If count > 0, show amber card:
<div class="card-premium p-4 border-l-4 border-amber-400">
  <div class="flex items-center gap-2">
    <i class="fas fa-exclamation-triangle text-amber-500"></i>
    <span class="font-semibold text-amber-700">{count} Tenancies expiring in 30 days</span>
  </div>
  <a href="/portal/members?filter=expiring" class="text-sm text-primary-600 mt-1 block">View Details →</a>
</div>
```

### 4C. Profile Page Enhancements

**`src/pages/portal/profile.astro`** — extend existing page

Add new sections (after existing DPDPA section):

**Emergency Contact section:**
```html
<div class="card-premium p-6 mt-6">
  <h2 class="text-xl font-semibold text-primary-600 mb-4">
    <i class="fas fa-phone-alt mr-2"></i>Emergency Contact
  </h2>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    <div>
      <label class="form-label">Full Name</label>
      <input type="text" name="emergency_contact_name" class="form-input" />
    </div>
    <div>
      <label class="form-label">Mobile Number</label>
      <input type="tel" name="emergency_contact_phone" class="form-input" />
    </div>
    <div>
      <label class="form-label">Relationship</label>
      <select name="emergency_contact_rel" class="form-input">
        <option>Spouse</option><option>Parent</option><option>Sibling</option>
        <option>Child</option><option>Friend</option><option>Other</option>
      </select>
    </div>
  </div>
</div>
```

**Profile Photo section:**
```html
<div class="flex items-center gap-4 mb-6">
  <div class="w-20 h-20 rounded-full bg-primary-100 flex items-center justify-center overflow-hidden">
    <!-- Show avatar_url if set, else initials -->
    <img id="avatar-preview" src="{user.avatar_url || ''}" class="w-full h-full object-cover hidden" />
    <span id="avatar-initials" class="text-2xl font-bold text-primary-600">{initials}</span>
  </div>
  <div>
    <label class="btn-outline cursor-pointer text-sm py-2">
      <i class="fas fa-camera mr-1"></i> Change Photo
      <input type="file" accept="image/jpeg,image/png" class="hidden" id="avatar-upload" />
    </label>
    <p class="text-xs text-text-secondary mt-1">JPG or PNG, max 2 MB</p>
  </div>
</div>
```

### 4D. API Routes (new)

- `GET /api/v1/admin/members` — extend to accept `?block=&occupancy=&expiring_within=30`
- `GET /api/v1/admin/members/export` — CSV download, exec only
- `PATCH /api/v1/admin/members/[id]` — extend to accept new profile fields
- `GET /api/v1/admin/tenancies` — list tenancies with `?expiring_within=` param
- `POST /api/v1/admin/tenancies` — create tenancy record
- `PATCH /api/v1/admin/tenancies/[id]` — update tenancy (lease dates, doc upload)
- `PATCH /api/v1/profile` — extend to accept emergency_contact_* fields, num_occupants
- `POST /api/v1/profile/avatar` — upload avatar to Supabase Storage, update avatar_url

### 4E. CSV Bulk Import (one-time setup utility)

**`src/pages/portal/admin/import.astro`** — exec/admin only

Two sections:
1. **Import Units** — download template CSV → upload filled CSV → preview table → confirm import
   - CSV columns: unit_number, block, floor, area_sqft, unit_type
   - On import → upsert into `units` table (ON CONFLICT unit_number DO UPDATE)
2. **Import Parking Slots** — download template → upload → preview → confirm
   - CSV columns: slot_number, slot_type, level, block, status

API: `POST /api/v1/admin/import/units`, `POST /api/v1/admin/import/parking`
Both use `supabase.from('units').upsert([...])` with `onConflict: 'society_id,unit_number'`
```
