# UTAMACS Portal — Full Implementation Plan (Part 3 of 4)
# Modules: Facility Booking · Visitor Management · Parking · Staff & Maid Registry · Media Gallery · Community & Marketplace · Documents · Polls · Events

---

## MODULE 9 — Facility Booking Enhancements

### 9A. Migration: `043_facility_enhancements.sql`

```sql
-- Guest types per facility (Adult / Child / Senior Citizen)
CREATE TABLE facility_guest_types (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id     uuid NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  guest_type      text NOT NULL CHECK (guest_type IN ('adult','child','senior_citizen')),
  max_quota       int  NOT NULL DEFAULT 10,   -- max of this type per booking
  fee_per_guest   numeric(12,2) NOT NULL DEFAULT 0,
  UNIQUE(facility_id, guest_type)
);

-- Facility photo gallery
CREATE TABLE facility_photos (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id     uuid NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  storage_key     text NOT NULL,
  caption         text,
  display_order   int  NOT NULL DEFAULT 0,
  uploaded_at     timestamptz NOT NULL DEFAULT now()
);

-- Extend facilities table
ALTER TABLE facilities
  ADD COLUMN IF NOT EXISTS cancellation_window_hours int NOT NULL DEFAULT 24,
  ADD COLUMN IF NOT EXISTS buffer_minutes            int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS refund_rule_id            uuid REFERENCES refund_rules(id) ON DELETE SET NULL;

-- Maintenance blocks on facilities
CREATE TABLE facility_maintenance_blocks (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id     uuid NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  block_start     timestamptz NOT NULL,
  block_end       timestamptz NOT NULL,
  reason          text,
  created_by      uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  CHECK (block_end > block_start)
);

-- Extend bookings to capture guest breakdown
ALTER TABLE facility_bookings
  ADD COLUMN IF NOT EXISTS adults        int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS children      int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS senior_citizens int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS guest_fee     numeric(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS cancellation_requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS cancellation_reason text,
  ADD COLUMN IF NOT EXISTS refund_request_id uuid REFERENCES refund_requests(id) ON DELETE SET NULL;

ALTER TABLE facility_guest_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE facility_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE facility_maintenance_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "society_read_guest_types" ON facility_guest_types FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id=auth.uid()));
CREATE POLICY "exec_manage_guest_types" ON facility_guest_types FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));

CREATE POLICY "society_read_photos" ON facility_photos FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id=auth.uid()));
CREATE POLICY "exec_manage_photos" ON facility_photos FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));

CREATE POLICY "society_read_blocks" ON facility_maintenance_blocks FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id=auth.uid()));
CREATE POLICY "exec_manage_blocks" ON facility_maintenance_blocks FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));
```

### 9B. Facility Configuration (Admin)

**`src/pages/portal/facilities/index.astro`** — exec section for facility management, add:

**Photos sub-section** on facility edit:
- Photo grid (4 cols): each slot shows thumbnail with delete button
- "Add Photo" upload button (max 10 photos per facility)
- Drag-to-reorder for display_order

**Guest Types sub-section** on facility edit:
```html
<div class="mt-4">
  <h3 class="text-sm font-semibold text-text-primary mb-2">Guest Type Quotas & Fees</h3>
  <div class="grid grid-cols-3 gap-3">
    <div class="border border-border-light rounded-lg p-3">
      <p class="text-xs font-semibold text-text-secondary mb-2">
        <i class="fas fa-user mr-1"></i>Adults
      </p>
      <label class="form-label text-xs">Max per booking</label>
      <input type="number" name="adult_quota" class="form-input text-sm" value="20" min="0" />
      <label class="form-label text-xs mt-2">Fee per guest (₹)</label>
      <input type="number" name="adult_fee" class="form-input text-sm" value="0" min="0" step="0.01" />
    </div>
    <div class="border border-border-light rounded-lg p-3">
      <p class="text-xs font-semibold text-text-secondary mb-2">
        <i class="fas fa-child mr-1"></i>Children
      </p>
      <label class="form-label text-xs">Max per booking</label>
      <input type="number" name="child_quota" class="form-input text-sm" value="10" min="0" />
      <label class="form-label text-xs mt-2">Fee per child (₹)</label>
      <input type="number" name="child_fee" class="form-input text-sm" value="0" min="0" step="0.01" />
    </div>
    <div class="border border-border-light rounded-lg p-3">
      <p class="text-xs font-semibold text-text-secondary mb-2">
        <i class="fas fa-user-clock mr-1"></i>Senior Citizens
      </p>
      <label class="form-label text-xs">Max per booking</label>
      <input type="number" name="senior_quota" class="form-input text-sm" value="10" min="0" />
      <label class="form-label text-xs mt-2">Fee per senior (₹)</label>
      <input type="number" name="senior_fee" class="form-input text-sm" value="0" min="0" step="0.01" />
    </div>
  </div>
</div>
```

**Buffer time + Cancellation policy:**
```html
<div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
  <div>
    <label class="form-label">Buffer Between Slots (minutes)</label>
    <input type="number" name="buffer_minutes" class="form-input" value="0" min="0" step="15" />
  </div>
  <div>
    <label class="form-label">Cancellation Window (hours)</label>
    <input type="number" name="cancellation_window_hours" class="form-input" value="24" min="0" />
  </div>
  <div>
    <label class="form-label">Refund Policy</label>
    <select name="refund_rule_id" class="form-input">
      <option value="">No Refund</option>
      <!-- Populated from refund_rules -->
    </select>
  </div>
</div>
```

**Maintenance Blocks sub-section:**
```html
<div class="mt-4">
  <h3 class="text-sm font-semibold text-text-primary mb-2">
    <i class="fas fa-tools mr-1 text-amber-500"></i>Maintenance Blocks
  </h3>
  <!-- Table of existing blocks -->
  <!-- Add Block button → inline form: Start Datetime, End Datetime, Reason -->
</div>
```

### 9C. Booking Form Enhancements

**`src/pages/portal/facilities/book.astro`** — extend booking form:

```html
<!-- After slot selection, show photo gallery -->
<div id="facility-photos" class="mb-4">
  <div class="flex gap-2 overflow-x-auto pb-2">
    <!-- Thumbnails from facility_photos -->
  </div>
</div>

<!-- Guest count section (only if facility has guest_type config) -->
<div id="guest-types-section" class="card-premium p-4 mt-4">
  <h3 class="text-sm font-semibold text-text-primary mb-3">
    <i class="fas fa-users mr-1"></i>Guest Count
  </h3>
  <div class="grid grid-cols-3 gap-4">
    <div>
      <label class="form-label">Adults (max {quota})</label>
      <input type="number" name="adults" class="form-input" min="0" max="{adult_quota}" value="0" />
      <p class="text-xs text-text-secondary mt-1">₹{adult_fee} per adult</p>
    </div>
    <div>
      <label class="form-label">Children (max {quota})</label>
      <input type="number" name="children" class="form-input" min="0" max="{child_quota}" value="0" />
      <p class="text-xs text-text-secondary mt-1">₹{child_fee} per child</p>
    </div>
    <div>
      <label class="form-label">Senior Citizens (max {quota})</label>
      <input type="number" name="senior_citizens" class="form-input" min="0" max="{senior_quota}" value="0" />
      <p class="text-xs text-text-secondary mt-1">₹{senior_fee} per senior</p>
    </div>
  </div>
  <!-- Live fee calculation -->
  <div class="mt-3 p-3 bg-primary-50 rounded-lg">
    <div class="flex justify-between text-sm">
      <span class="text-text-secondary">Slot Fee</span>
      <span class="font-medium">₹<span id="slot-fee">0</span></span>
    </div>
    <div class="flex justify-between text-sm mt-1">
      <span class="text-text-secondary">Guest Fee</span>
      <span class="font-medium">₹<span id="guest-fee">0</span></span>
    </div>
    <div class="flex justify-between font-semibold text-primary-600 border-t border-primary-200 mt-2 pt-2">
      <span>Total</span>
      <span>₹<span id="total-fee">0</span></span>
    </div>
  </div>
</div>

<!-- Cancellation policy notice -->
<div class="bg-amber-50 border border-amber-200 rounded-lg p-3 mt-4 text-sm text-amber-700">
  <i class="fas fa-info-circle mr-1"></i>
  <strong>Cancellation Policy:</strong> Cancel at least {cancellation_window_hours} hours before your booking
  for a {refund_pct}% refund.
</div>
```

### 9D. Facility Availability Report

**`src/pages/portal/facilities/availability.astro`** (exec/admin only, new page)
- Filter: Date Range | Facility
- Table: Date | Facility | Slot | Booked By | Adults | Children | Seniors | Fee | Status
- Summary row: Total bookings | Total revenue | Occupancy % in period
- Export CSV button
- API: `GET /api/v1/facilities/availability-report?from=&to=&facility_id=`

---

## MODULE 10 — Visitor Management Enhancements

### 10A. Migration: `044_visitor_enhancements.sql`

```sql
-- Ensure visitor_logs table has gate_id
ALTER TABLE visitor_logs
  ADD COLUMN IF NOT EXISTS gate_id uuid REFERENCES gates(id) ON DELETE SET NULL;

-- Visitor types are stored as text enum — expand allowed values
-- Assumed current: ('guest','delivery','maid','vendor','contractor','other')
-- New comprehensive list via CHECK constraint update:
ALTER TABLE visitor_logs DROP CONSTRAINT IF EXISTS visitor_logs_visitor_type_check;
ALTER TABLE visitor_logs ADD CONSTRAINT visitor_logs_visitor_type_check
  CHECK (visitor_type IN (
    'guest','delivery','maid','driver','doctor','car_cleaner','milkman','nanny',
    'paperboy','plumber','electrician','repair','tuition_teacher','dance_instructor',
    'karate_instructor','sports_instructor','cable_tv','internet_technician',
    'laundry','pest_control','contractor','vendor','other'
  ));

-- Pre-approved visitor OTP
CREATE TABLE visitor_invites (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  invited_by      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  visitor_name    text NOT NULL,
  visitor_phone   text,
  visitor_type    text NOT NULL DEFAULT 'guest',
  expected_date   date NOT NULL,
  expected_from   time,
  expected_to     time,
  otp             text NOT NULL,              -- 6-digit, hashed in DB
  otp_used        bool NOT NULL DEFAULT false,
  otp_used_at     timestamptz,
  visitor_log_id  uuid REFERENCES visitor_logs(id) ON DELETE SET NULL,  -- filled when OTP used
  purpose         text,
  expires_at      timestamptz NOT NULL DEFAULT now() + interval '2 days',
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_visitor_invites_otp ON visitor_invites(otp) WHERE otp_used = false;

ALTER TABLE visitor_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_own_invites" ON visitor_invites FOR SELECT
  USING (invited_by = auth.uid() OR EXISTS (
    SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (role = 'security_guard' OR portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE POLICY "member_create_invite" ON visitor_invites FOR INSERT
  WITH CHECK (invited_by = auth.uid());

CREATE POLICY "guard_use_otp" ON visitor_invites FOR UPDATE
  USING (EXISTS (SELECT 1 FROM user_roles WHERE user_id=auth.uid() AND role='security_guard'));
```

### 10B. Page Changes

**`src/pages/portal/visitors/index.astro`** — extend:

**New filter bar:**
```html
<div class="flex flex-wrap gap-3 mb-6">
  <select id="filter-type" class="form-input w-auto text-sm py-2">
    <option value="">All Types</option>
    <option value="guest">Guest</option>
    <option value="delivery">Delivery</option>
    <option value="maid">Maid</option>
    <option value="driver">Driver</option>
    <option value="doctor">Doctor</option>
    <option value="car_cleaner">Car Cleaner</option>
    <option value="milkman">Milkman</option>
    <option value="nanny">Nanny</option>
    <option value="tuition_teacher">Tuition Teacher</option>
    <option value="plumber">Plumber/Electrician</option>
    <!-- ... full list ... -->
  </select>

  <select id="filter-gate" class="form-input w-auto text-sm py-2">
    <option value="">All Gates</option>
    <!-- Populated from gates table -->
  </select>

  <input type="date" id="filter-date-from" class="form-input w-auto text-sm py-2" />
  <input type="date" id="filter-date-to" class="form-input w-auto text-sm py-2" />
  <input type="text" id="filter-unit" class="form-input w-auto text-sm py-2" placeholder="Flat No." />

  <button id="export-visitors" class="btn-outline text-sm py-2 ml-auto">
    <i class="fas fa-download mr-1"></i> Export CSV
  </button>
</div>
```

**Guard Entry form — Gate selection:**
```html
<!-- Add to guard's new visitor form -->
<div class="mt-4">
  <label class="form-label">Entry Gate</label>
  <select name="gate_id" class="form-input">
    <!-- Populated from gates; pre-selected to guard's assigned gate -->
  </select>
</div>
```

**Visitor Type badge colours** (JS lookup map):
```javascript
const TYPE_COLORS = {
  guest: 'bg-primary-100 text-primary-700',
  delivery: 'bg-amber-100 text-amber-700',
  maid: 'bg-purple-100 text-purple-700',
  driver: 'bg-blue-100 text-blue-700',
  doctor: 'bg-green-100 text-green-700',
  plumber: 'bg-orange-100 text-orange-700',
  electrician: 'bg-orange-100 text-orange-700',
  tuition_teacher: 'bg-pink-100 text-pink-700',
  contractor: 'bg-gray-100 text-gray-700',
  // default:
  other: 'bg-gray-100 text-gray-600'
}
```

**Pre-approved Visitor Invites (Member view):**

**`src/pages/portal/visitors/invite.astro`** (new page, member creates invite)
- Form fields:
  - Visitor Name (text, required)
  - Visitor Mobile (tel, optional)
  - Visitor Type (select — same list)
  - Expected Date (date, min=today)
  - Expected Arrival Window: From (time) To (time)
  - Purpose (text, optional)
- On submit → POST `/api/v1/visitors/invite`:
  - Generate 6-digit OTP (crypto.randomInt)
  - Store hashed OTP in visitor_invites
  - Return OTP to member (shown once, cannot be retrieved again)
  - Member shares OTP verbally with visitor
- My Invites tab on visitors page: table showing upcoming invites + OTP reveal button + Cancel button

**Guard OTP Verification:**
On guard new visitor form, add OTP field:
```html
<div class="mt-4 p-3 bg-green-50 border border-green-200 rounded-lg">
  <label class="form-label text-sm text-green-700">Pre-Approved? Enter OTP</label>
  <div class="flex gap-2">
    <input type="text" id="visitor-otp" class="form-input text-center tracking-widest text-lg"
           maxlength="6" placeholder="000000" pattern="\d{6}" />
    <button type="button" id="verify-otp" class="btn-primary text-sm py-2 px-4">Verify</button>
  </div>
  <!-- On verify: auto-fills Visitor Name, Type, Expected Flat -->
</div>
```

API: `POST /api/v1/visitors/verify-otp` — returns invite details if OTP valid; marks otp_used=true

### 10C. Export API

`GET /api/v1/visitors/export` — exec/guard, CSV with:
`Date, Time In, Time Out, Name, Phone, Type, Purpose, Vehicle No., Flat No., Gate, Recorded By`

---

## MODULE 11 — Parking Enhancements

### 11A. Migration: `045_parking_enhancements.sql`

```sql
ALTER TABLE parking_slots
  ADD COLUMN IF NOT EXISTS level        text,           -- "Basement 1", "Ground Floor", "Open"
  ADD COLUMN IF NOT EXISTS block        text,           -- wing it's adjacent to
  ADD COLUMN IF NOT EXISTS vehicle_make text,           -- Maruti, Hyundai, Honda...
  ADD COLUMN IF NOT EXISTS vehicle_model text,          -- Swift, i20, City...
  ADD COLUMN IF NOT EXISTS vehicle_colour text,
  ADD COLUMN IF NOT EXISTS rc_doc_key   text,           -- Supabase Storage key
  ADD COLUMN IF NOT EXISTS monthly_fee  numeric(12,2) DEFAULT 0;

-- Slot transfer workflow
CREATE TABLE parking_slot_transfers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  slot_id         uuid NOT NULL REFERENCES parking_slots(id) ON DELETE CASCADE,
  from_unit_id    uuid REFERENCES units(id) ON DELETE SET NULL,
  to_unit_id      uuid REFERENCES units(id) ON DELETE SET NULL,
  reason          text,
  status          text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected')),
  requested_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_by     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE parking_slot_transfers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_own_transfers" ON parking_slot_transfers FOR SELECT
  USING (requested_by = auth.uid() OR EXISTS (
    SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE POLICY "exec_manage_transfers" ON parking_slot_transfers FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));
```

### 11B. Page Changes

**Parking slot edit form/modal** — add new fields:
```html
<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
  <div>
    <label class="form-label">Level / Location</label>
    <select name="level" class="form-input">
      <option value="Basement 1">Basement 1</option>
      <option value="Basement 2">Basement 2</option>
      <option value="Ground Floor">Ground Floor</option>
      <option value="Open">Open Parking</option>
    </select>
  </div>
  <div>
    <label class="form-label">Wing / Block</label>
    <input type="text" name="block" class="form-input" placeholder="e.g. Block A" />
  </div>
  <div>
    <label class="form-label">Vehicle Make</label>
    <input type="text" name="vehicle_make" class="form-input" placeholder="e.g. Maruti" />
  </div>
  <div>
    <label class="form-label">Vehicle Model</label>
    <input type="text" name="vehicle_model" class="form-input" placeholder="e.g. Swift Dzire" />
  </div>
  <div>
    <label class="form-label">Vehicle Colour</label>
    <input type="text" name="vehicle_colour" class="form-input" placeholder="e.g. Silver" />
  </div>
  <div>
    <label class="form-label">Monthly Parking Fee (₹)</label>
    <input type="number" name="monthly_fee" class="form-input" value="0" min="0" step="50" />
  </div>
</div>

<div class="mt-4">
  <label class="form-label">RC / Insurance Document</label>
  <div class="flex items-center gap-3">
    <label class="btn-outline cursor-pointer text-sm py-2">
      <i class="fas fa-file-upload mr-1"></i> Upload RC / Insurance
      <input type="file" accept="application/pdf,image/*" class="hidden" id="rc-upload" />
    </label>
    <span id="rc-filename" class="text-sm text-text-secondary"></span>
  </div>
</div>
```

**Parking grid view** — show Level filter:
```html
<select id="filter-level" class="form-input w-auto text-sm py-2">
  <option value="">All Levels</option>
  <!-- Distinct levels from parking_slots -->
</select>
```

**Slot Transfer** — add button to assigned slot row: "Request Transfer" → modal:
- Relinquishing Unit (pre-filled, read-only)
- Transfer To Flat (select from units)
- Reason (textarea)
- Submit → POST `/api/v1/parking/transfers`
- Exec sees transfers queue in parking page; approve/reject with notes

---

## MODULE 12 — Staff & Maid Management

### 12A. Migration: `046_maid_registry.sql`

```sql
-- Extend staff table (assumed from admin/staff page)
ALTER TABLE staff_members
  ADD COLUMN IF NOT EXISTS aadhaar_number text,       -- encrypted at application layer
  ADD COLUMN IF NOT EXISTS photo_key      text,
  ADD COLUMN IF NOT EXISTS shift_start    time,
  ADD COLUMN IF NOT EXISTS shift_end      time,
  ADD COLUMN IF NOT EXISTS gate_id        uuid REFERENCES gates(id) ON DELETE SET NULL;

-- Maid / Domestic Help Registry
CREATE TABLE maids (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id        uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  name              text NOT NULL,
  phone             text,
  photo_key         text,                    -- Supabase Storage key
  aadhaar_number    text,                    -- store last-4 only for display; full encrypted
  aadhaar_doc_key   text,                    -- uploaded scan
  voter_id_number   text,
  voter_id_doc_key  text,
  background_check_key text,                 -- police verification or agency report
  is_active         bool NOT NULL DEFAULT true,
  is_suspended      bool NOT NULL DEFAULT false,
  suspension_reason text,
  suspended_by      uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  suspended_at      timestamptz,
  registered_by     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- Which flats a maid is approved to enter
CREATE TABLE maid_unit_approvals (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  maid_id     uuid NOT NULL REFERENCES maids(id) ON DELETE CASCADE,
  unit_id     uuid NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  approved_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,  -- the flat owner/tenant
  approved_at timestamptz NOT NULL DEFAULT now(),
  revoked_at  timestamptz,
  is_active   bool NOT NULL DEFAULT true,
  typical_days text[],                        -- ['monday','tuesday'] etc.
  typical_from time,
  typical_to   time,
  UNIQUE(maid_id, unit_id)
);

-- Daily entry/exit tracking (auto-populated when guard marks maid entry)
CREATE TABLE maid_attendance (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  maid_id     uuid NOT NULL REFERENCES maids(id) ON DELETE CASCADE,
  unit_id     uuid NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  gate_id     uuid REFERENCES gates(id) ON DELETE SET NULL,
  entry_at    timestamptz NOT NULL,
  exit_at     timestamptz,
  recorded_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,  -- guard
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE maids ENABLE ROW LEVEL SECURITY;
ALTER TABLE maid_unit_approvals ENABLE ROW LEVEL SECURITY;
ALTER TABLE maid_attendance ENABLE ROW LEVEL SECURITY;

-- Member reads maids approved for their unit
CREATE POLICY "member_view_own_maids" ON maids FOR SELECT
  USING (id IN (
    SELECT m.id FROM maids m
    JOIN maid_unit_approvals mua ON mua.maid_id = m.id
    JOIN units u ON u.id = mua.unit_id
    JOIN profiles p ON p.unit_id = u.id
    WHERE p.id = auth.uid() AND mua.is_active = true
  ) OR registered_by = auth.uid() OR EXISTS (
    SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (role = 'security_guard' OR portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE POLICY "member_register_maid" ON maids FOR INSERT
  WITH CHECK (registered_by = auth.uid());

CREATE POLICY "exec_manage_maids" ON maids FOR UPDATE
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));

CREATE POLICY "member_manage_own_approvals" ON maid_unit_approvals FOR ALL
  USING (approved_by = auth.uid() OR EXISTS (
    SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE POLICY "guard_maid_attendance" ON maid_attendance FOR ALL
  USING (EXISTS (SELECT 1 FROM user_roles WHERE user_id=auth.uid() AND role='security_guard')
    OR EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
      AND (portal_role IN ('executive','secretary','president') OR is_admin)));
```

### 12B. New Module: `src/pages/portal/maids/index.astro`

**Member view:**
- "My Domestic Help" heading with card-premium container
- List of approved maids for member's flat:
  - Photo avatar | Name | Phone (masked: 98765*****) | Typical Days | Entry/Exit times
  - "Remove Access" button → sets maid_unit_approvals.is_active = false
  - "View Attendance" button → attendance log for that maid in their flat
- "Register New Domestic Help" button → form:
  - Name (required)
  - Phone (optional)
  - Upload Photo (required — stored in Supabase Storage)
  - Aadhaar Number (last 4 digits visible; full stored encrypted)
  - Upload Aadhaar Copy (PDF/image)
  - Voter ID Number (optional)
  - Upload Voter ID Copy (optional)
  - Background Check Document (optional)
  - Typical Working Days (checkboxes: Mon–Sun)
  - Typical Hours: From (time) To (time)
  - Consent checkbox: "I confirm the information provided is accurate and I am authorising this person to enter my premises"

**Guard view (read-only):**
- Search by name or phone
- Shows: Photo, Name, Phone, Approved Flats list, Active/Suspended badge
- Entry button → records `maid_attendance.entry_at = now()`
- Exit button → updates `maid_attendance.exit_at = now()`

**Exec/Admin view:**
- Full list of all maids in society
- Filter: Active | Suspended
- Suspend button (on each maid) → modal: Reason for suspension + confirm
- Suspended maids shown with red badge; guard view shows "ACCESS SUSPENDED" banner
- Suspension is society-wide (affects all flats)

**`src/pages/portal/maids/[id].astro`** — Maid detail
- All profile details (view/edit based on role)
- Approved Flats tab: list of units with approval date
- Attendance Log tab: date-range calendar with entry/exit times
- Documents tab: Aadhaar, Voter ID, Background Check (signed URL links)

---

## MODULE 13 — Media Gallery

### 13A. Migration: `047_gallery.sql`

```sql
CREATE TABLE gallery_albums (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  title         text NOT NULL,
  description   text,
  cover_key     text,                  -- Supabase Storage key for album cover
  event_date    date,                  -- when the event/occasion was
  is_published  bool NOT NULL DEFAULT false,
  created_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE gallery_photos (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  album_id      uuid NOT NULL REFERENCES gallery_albums(id) ON DELETE CASCADE,
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  storage_key   text NOT NULL,
  caption       text,
  display_order int  NOT NULL DEFAULT 0,
  uploaded_by   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  uploaded_at   timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE gallery_albums ENABLE ROW LEVEL SECURITY;
ALTER TABLE gallery_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "society_view_published_albums" ON gallery_albums FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id=auth.uid())
         AND is_published = true
    OR EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
      AND (portal_role IN ('executive','secretary','president') OR is_admin)));

CREATE POLICY "exec_manage_albums" ON gallery_albums FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));

CREATE POLICY "society_view_album_photos" ON gallery_photos FOR SELECT
  USING (album_id IN (
    SELECT id FROM gallery_albums WHERE is_published=true
      AND society_id IN (SELECT society_id FROM profiles WHERE id=auth.uid())
  ) OR EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));

CREATE POLICY "exec_manage_photos" ON gallery_photos FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));
```

### 13B. New Pages

**`src/pages/portal/gallery/index.astro`** — Gallery home
- Masonry grid of album cards (3 cols desktop, 2 tablet, 1 mobile)
- Each album card: Cover photo (h-48, object-cover), Title, Event Date, Photo count badge
- Exec: "Create Album" button (top-right) + "Draft/Published" toggle badge on each card
- CSS class: `columns-1 sm:columns-2 lg:columns-3 gap-4`

**`src/pages/portal/gallery/[id].astro`** — Album detail (photo viewer)
- Album header: Title, Description, Event Date, Photo count
- Photo grid: `grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-2`
- Each photo: `aspect-square overflow-hidden rounded-lg cursor-pointer hover:opacity-90 transition-opacity`
- Click → lightbox overlay (vanilla JS):
  ```javascript
  // Full-screen overlay: bg-black/90 z-50
  // Navigation: prev/next arrows (white, absolute left/right)
  // Close: X button top-right
  // Caption shown at bottom
  // Keyboard: Arrow keys to navigate, Escape to close
  ```
- Exec: "Add Photos" button → file input (multiple), drag-drop zone
- Exec: "Publish Album" / "Unpublish" toggle button
- Exec: Edit caption inline (click caption text → contenteditable)

**`src/pages/portal/gallery/manage.astro`** — Exec album management
- List view with draft/published albums
- Bulk photo upload for existing album
- Reorder photos via drag-and-drop (using display_order)
- Set cover photo button on each photo

**Register in PortalLayout** — add 'gallery' to module list in `PortalLayout.astro`:
```typescript
{ key: 'gallery', displayName: 'Gallery', icon: 'fas fa-images', path: '/portal/gallery' }
```

---

## MODULE 14 — Community & Marketplace Enhancements

### 14A. Migration: `048_community_enhancements.sql`

```sql
-- Post image attachment
ALTER TABLE community_posts
  ADD COLUMN IF NOT EXISTS image_key    text,     -- Supabase Storage key
  ADD COLUMN IF NOT EXISTS is_pinned    bool NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS is_reported  bool NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS report_count int  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_hidden    bool NOT NULL DEFAULT false;  -- moderated off

-- Post reports
CREATE TABLE post_reports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     uuid NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  reported_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason      text NOT NULL
    CHECK (reason IN ('inappropriate','spam','misinformation','offensive','other')),
  details     text,
  reviewed    bool NOT NULL DEFAULT false,
  reviewed_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(post_id, reported_by)
);

-- Marketplace enhancements
ALTER TABLE marketplace_listings
  ADD COLUMN IF NOT EXISTS image_keys   text[],   -- array of Supabase Storage keys (up to 5)
  ADD COLUMN IF NOT EXISTS expires_at   timestamptz DEFAULT now() + interval '60 days',
  ADD COLUMN IF NOT EXISTS is_reported  bool NOT NULL DEFAULT false;

CREATE TABLE marketplace_reports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id  uuid NOT NULL REFERENCES marketplace_listings(id) ON DELETE CASCADE,
  reported_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason      text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(listing_id, reported_by)
);

ALTER TABLE post_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE marketplace_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_report_post" ON post_reports FOR INSERT
  WITH CHECK (reported_by = auth.uid());
CREATE POLICY "exec_view_reports" ON post_reports FOR SELECT
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));

CREATE POLICY "member_report_listing" ON marketplace_reports FOR INSERT
  WITH CHECK (reported_by = auth.uid());
CREATE POLICY "exec_view_listing_reports" ON marketplace_reports FOR SELECT
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));
```

### 14B. Page Changes

**Community post creation form** — add image upload:
```html
<div class="mt-4">
  <label class="form-label">Add Photo (optional)</label>
  <div class="border-2 border-dashed border-border-light rounded-xl p-4 text-center cursor-pointer hover:border-primary-300 transition-colors" id="post-image-zone">
    <i class="fas fa-image text-2xl text-primary-300 mb-1 block"></i>
    <p class="text-xs text-text-secondary">Click or drag to add a photo</p>
    <input type="file" accept="image/jpeg,image/png,image/webp" class="hidden" id="post-image" />
  </div>
  <div id="post-image-preview" class="hidden mt-2">
    <img id="post-image-thumb" class="w-full max-h-40 object-cover rounded-lg" />
    <button type="button" id="remove-post-image" class="text-xs text-red-500 mt-1">Remove photo</button>
  </div>
</div>
```

**Post card in feed** — add:
- Image display: full-width image below post text (if image_key set)
- "Pin" button (exec only): `<button class="text-xs text-amber-600"><i class="fas fa-thumbtack"></i></button>`
- "Report" button (member): three-dot menu → "Report Post" → modal with reason select
- Pinned posts: amber left border + "📌 Pinned" badge, always shown at top of feed

**Exec moderation queue** — `src/pages/portal/admin/moderation.astro` (new):
- Tabs: Posts | Marketplace
- Each row: Content preview | Reporter | Reason | Date | Actions (Hide Post / Dismiss Report)
- Hidden posts shown with grey overlay and "Hidden by moderator" label in feed

**Marketplace listing creation** — extend with image upload:
```html
<div class="mt-4">
  <label class="form-label">Photos (up to 5)</label>
  <div class="grid grid-cols-5 gap-2" id="listing-photos">
    <!-- Up to 5 upload slots, each: dashed border box, click to select file -->
  </div>
  <p class="text-xs text-text-secondary mt-1">Add photos to attract more buyers</p>
</div>
```

**Marketplace listing card** — photo carousel (if multiple images):
- CSS: `overflow-x-auto flex gap-1 snap-x snap-mandatory`
- Each image: `snap-start shrink-0 w-full h-48 object-cover rounded-t-xl`

**Listing expiry** — auto-archive cron (Supabase pg_cron):
```sql
-- Run daily: archive expired listings
UPDATE marketplace_listings
SET status = 'archived'
WHERE expires_at < now() AND status = 'active';
```

---

## MODULE 15 — Documents Enhancements

### 15A. Migration: `049_document_enhancements.sql`

```sql
-- Document version history
CREATE TABLE document_versions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  document_id     uuid NOT NULL,             -- references documents(id)
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  version_number  int  NOT NULL,
  storage_key     text NOT NULL,
  file_name       text NOT NULL,
  file_size_bytes bigint,
  change_notes    text,
  uploaded_by     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  uploaded_at     timestamptz NOT NULL DEFAULT now()
);

-- Extend documents table
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS version          int  NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS current_key      text,         -- same as storage_key, for clarity
  ADD COLUMN IF NOT EXISTS file_size_bytes  bigint,
  ADD COLUMN IF NOT EXISTS download_count   int  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS expires_at       timestamptz,
  ADD COLUMN IF NOT EXISTS search_text      text GENERATED ALWAYS AS (
    lower(title || ' ' || coalesce(description,'') || ' ' || coalesce(category,''))
  ) STORED;

CREATE INDEX IF NOT EXISTS idx_documents_search ON documents USING GIN (to_tsvector('english', search_text));

ALTER TABLE document_versions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_versions" ON document_versions FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id=auth.uid()));

CREATE POLICY "exec_manage_versions" ON document_versions FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));
```

### 15B. Page Changes

**`src/pages/portal/documents/index.astro`** — extend:

**Search bar** (add above document list):
```html
<div class="relative mb-6">
  <input type="text" id="doc-search" class="form-input pl-10" placeholder="Search documents..." />
  <i class="fas fa-search absolute left-3 top-3.5 text-text-secondary"></i>
</div>
```
JS: debounce 300ms → filter cards client-side using search_text field.

**Document card** — extend:
- Version badge: `v{version}` in gray pill
- File size: shown in metadata line
- Download count (exec view only): `{n} downloads`
- Expiry: amber badge if expiring in 30 days; red if expired

**Version History drawer** (exec):
- "History" button on each document card
- Right-side drawer lists all versions: Version # | Date | Uploaded By | Size | Download | Change Notes
- "Upload New Version" button → file input + change notes textarea → POST `/api/v1/documents/{id}/versions`

---

## MODULE 16 — Polls Enhancements

### 16A. Migration: `050_polls_enhancements.sql`

```sql
ALTER TABLE polls
  ADD COLUMN IF NOT EXISTS quorum_percentage      numeric(5,2) DEFAULT 0,
    -- min % of eligible voters needed for result to be valid; 0 = no quorum
  ADD COLUMN IF NOT EXISTS target_wings           text[],
    -- NULL = all; array = specific wings only
  ADD COLUMN IF NOT EXISTS results_visible_before_close bool NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS eligible_voter_count   int,
    -- computed at poll creation time from active members
  ADD COLUMN IF NOT EXISTS attached_document_key  text;  -- PDF linked to poll (e.g. budget proposal)

-- Poll result PDF export log
CREATE TABLE poll_exports (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id     uuid NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  exported_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  exported_at timestamptz NOT NULL DEFAULT now()
);
```

### 16B. Page Changes

**Poll creation form** — extend:
```html
<div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
  <div>
    <label class="form-label">Quorum Required (%)</label>
    <div class="relative">
      <input type="number" name="quorum_percentage" class="form-input pr-8" value="0" min="0" max="100" step="5" />
      <span class="absolute right-3 top-3 text-text-secondary text-sm">%</span>
    </div>
    <p class="text-xs text-text-secondary mt-1">0 = no quorum required</p>
  </div>
  <div>
    <label class="form-label">Target Audience</label>
    <select name="target_wings" multiple class="form-input h-20">
      <option value="">All Residents</option>
      <!-- Wing options populated from units -->
    </select>
  </div>
</div>

<div class="flex items-center gap-3 mt-4">
  <input type="checkbox" name="results_visible_before_close" id="live-results"
         class="w-4 h-4 rounded accent-primary-600" />
  <label for="live-results" class="text-sm font-medium text-text-primary">
    Show live results to voters before poll closes
  </label>
</div>

<div class="mt-4">
  <label class="form-label">Attach Document (optional)</label>
  <label class="btn-outline cursor-pointer text-sm py-2">
    <i class="fas fa-paperclip mr-1"></i> Attach PDF
    <input type="file" accept="application/pdf" class="hidden" id="poll-doc" />
  </label>
  <p class="text-xs text-text-secondary mt-1">e.g. Budget proposal, maintenance plan</p>
</div>
```

**Poll result view** — add:
- Quorum status bar: "Participation: {actual}% of {quorum}% required"
  - Bar fills proportionally; green if met, amber if not
- If results_visible_before_close = false AND poll is open → show only "Vote to see results"
- "Export Results PDF" button (exec only) → `/api/v1/polls/{id}/export`
- Attached document link

**Export API:** `GET /api/v1/polls/[id]/export`
- Auth: exec only
- PDF via pdfmake:
  - Title: "{Poll Title} — Results"
  - Society name, poll open/close dates
  - Total eligible voters, actual votes (%), quorum met/not
  - Bar chart (text-based in PDF) per option: Option | Votes | %
  - Timestamp: "Exported on {date} by {exec name}"

---

## MODULE 17 — Events Enhancements

### 17A. Migration: `051_events_enhancements.sql`

```sql
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS banner_key         text,         -- Supabase Storage key for event banner
  ADD COLUMN IF NOT EXISTS guests_allowed     bool NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS max_guests_per_rsvp int DEFAULT 0,
  ADD COLUMN IF NOT EXISTS is_paid_event      bool NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS ticket_fee         numeric(12,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS gallery_album_id   uuid REFERENCES gallery_albums(id) ON DELETE SET NULL;

-- Event attendance marking (day-of check-in by exec/staff)
CREATE TABLE event_attendance (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id    uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  rsvp_id     uuid REFERENCES event_rsvps(id) ON DELETE SET NULL,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  checked_in_at timestamptz NOT NULL DEFAULT now(),
  checked_in_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  guest_count int NOT NULL DEFAULT 0,
  UNIQUE(event_id, user_id)
);

ALTER TABLE event_attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "exec_manage_attendance" ON event_attendance FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));

CREATE POLICY "member_view_own_attendance" ON event_attendance FOR SELECT
  USING (user_id = auth.uid());
```

### 17B. Page Changes

**Event creation form** — extend with:
```html
<!-- Banner image upload -->
<div class="mt-4">
  <label class="form-label">Event Banner</label>
  <div class="border-2 border-dashed border-border-light rounded-xl p-4 text-center cursor-pointer hover:border-primary-300 transition-colors">
    <i class="fas fa-image text-3xl text-primary-300 mb-2 block"></i>
    <p class="text-sm text-text-secondary">Upload event banner (16:9 recommended)</p>
    <input type="file" accept="image/jpeg,image/png,image/webp" class="hidden" id="banner-upload" />
  </div>
  <div id="banner-preview" class="hidden mt-2 rounded-xl overflow-hidden aspect-video">
    <img id="banner-thumb" class="w-full h-full object-cover" />
  </div>
</div>

<!-- Guest allowance -->
<div class="flex items-center gap-3 mt-4">
  <input type="checkbox" name="guests_allowed" id="guests-allowed"
         class="w-4 h-4 rounded accent-primary-600" />
  <label for="guests-allowed" class="text-sm font-medium">
    Residents may bring guests
  </label>
</div>
<div id="guest-limit-field" class="mt-2 hidden">
  <label class="form-label">Max guests per RSVP</label>
  <input type="number" name="max_guests_per_rsvp" class="form-input w-32" value="2" min="1" max="10" />
</div>

<!-- Paid event -->
<div class="flex items-center gap-3 mt-4">
  <input type="checkbox" name="is_paid_event" id="is-paid"
         class="w-4 h-4 rounded accent-primary-600" />
  <label for="is-paid" class="text-sm font-medium">Paid event (ticket fee applies)</label>
</div>
<div id="ticket-fee-field" class="mt-2 hidden">
  <label class="form-label">Ticket Fee (₹ per person)</label>
  <input type="number" name="ticket_fee" class="form-input w-48" value="0" min="0" step="50" />
</div>
```

**Event card in list** — add banner image at top if set (h-36 object-cover rounded-t-xl).

**Event detail page** — exec actions section add:
- "Mark Attendance" button → opens attendance sheet:
  - List of all RSVPed members; checkbox per member to mark present
  - Guest count input per member (if guests_allowed)
  - Shows total present count live
- "Link Photo Album" → select from gallery_albums
- Link shown to members: "📸 View event photos" → opens gallery album

---

## MODULE 18 — Feedback Module

### 18A. Migration: `052_feedbacks.sql`

```sql
CREATE TABLE feedbacks (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  submitted_by  uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category      text NOT NULL
    CHECK (category IN ('maintenance','staff','cleanliness','security','amenities','management','other')),
  rating        int  NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comments      text,
  is_anonymous  bool NOT NULL DEFAULT false,
  status        text NOT NULL DEFAULT 'unread'
    CHECK (status IN ('unread','read','responded')),
  response_text text,
  responded_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  responded_at  timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE feedbacks ENABLE ROW LEVEL SECURITY;

-- Members see their own feedback; anonymous ones hidden by default
CREATE POLICY "member_view_own_feedback" ON feedbacks FOR SELECT
  USING (submitted_by = auth.uid() OR EXISTS (
    SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE POLICY "member_submit_feedback" ON feedbacks FOR INSERT
  WITH CHECK (submitted_by = auth.uid());

CREATE POLICY "exec_respond_feedback" ON feedbacks FOR UPDATE
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));
```

### 18B. New Module Pages

**`src/pages/portal/feedback/index.astro`** — member view
- "Share Your Feedback" heading with sub: "Help us improve Urban Trilla Apartments"
- Submission form (top of page):
  - Category (large icon-button grid, 2 cols × 3):
    - 🔧 Maintenance | 👮 Staff | 🧹 Cleanliness | 🔒 Security | 🏊 Amenities | 📋 Management
    - Active: `border-primary-600 bg-primary-50 text-primary-700`, default: `border-border-light`
  - Star Rating (large stars, 48px): click to select 1–5
    - Label below stars: 1=Poor, 2=Fair, 3=Good, 4=Very Good, 5=Excellent
  - Comments (textarea, 4 rows): "Tell us more... (optional)"
  - Anonymous checkbox: "Submit anonymously (your name won't be shown to the committee)"
  - Submit button: `btn-primary`
- "My Previous Feedback" table below form:
  - Category | Rating (stars) | Date | Status badge | Response (if any)

**`src/pages/portal/admin/feedbacks.astro`** — exec view
- Summary cards at top: Average Rating (this month) | Total Submissions | Unread count | Category breakdown
  - Category mini-bars showing distribution
- Filter: Category | Rating (1–5) | Date Range | Status | Anonymous
- Table: Date | Category | Rating | Comments excerpt | Anonymous? | Status | Actions (Mark Read / Respond)
- Respond drawer: shows full comment, textarea for response text, Submit Response button
- Export CSV button → `/api/v1/admin/feedbacks/export`

**Add to PortalLayout module list:**
```typescript
{ key: 'feedback', displayName: 'Feedback', icon: 'fas fa-star', path: '/portal/feedback' }
```

**Add to Executive Dashboard quick actions:**
```tsx
{ label: 'View Feedback', icon: 'fa-star', href: '/portal/admin/feedbacks', color: 'bg-amber-50 text-amber-700' }
```
