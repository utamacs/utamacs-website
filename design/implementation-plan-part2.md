# UTAMACS Portal — Full Implementation Plan (Part 2 of 4)
# Modules: Notices · Finance & Billing · Refunds · Complaints

---

## MODULE 5 — Notices Enhancements

### 5A. Migration: `039_notices_enhancements.sql`

```sql
-- Extend existing notices table (assumed columns: id, society_id, title, body, category,
-- requires_acknowledgement, created_by, created_at, published_at)

ALTER TABLE notices
  ADD COLUMN IF NOT EXISTS attachment_key    text,          -- Supabase Storage key (PDF/image)
  ADD COLUMN IF NOT EXISTS attachment_type   text
    CHECK (attachment_type IN ('image','pdf','video_url')),
  ADD COLUMN IF NOT EXISTS attachment_name   text,          -- original filename
  ADD COLUMN IF NOT EXISTS video_url         text,          -- YouTube embed URL
  ADD COLUMN IF NOT EXISTS scheduled_at      timestamptz,   -- NULL = publish immediately
  ADD COLUMN IF NOT EXISTS expires_at        timestamptz,   -- NULL = never expires
  ADD COLUMN IF NOT EXISTS is_pinned         bool NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS target_wings      text[],        -- NULL = all wings; array of block names
  ADD COLUMN IF NOT EXISTS status            text NOT NULL DEFAULT 'published'
    CHECK (status IN ('draft','scheduled','published','expired','archived'));

-- Index for efficient feed queries
CREATE INDEX IF NOT EXISTS idx_notices_status_pinned ON notices(society_id, status, is_pinned DESC, published_at DESC);

-- Scheduled notice auto-publish function (called by pg_cron or Supabase Edge Function)
-- Transition: scheduled → published when NOW() >= scheduled_at
CREATE OR REPLACE FUNCTION publish_scheduled_notices() RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  UPDATE notices
  SET status = 'published', published_at = now()
  WHERE status = 'scheduled'
    AND scheduled_at <= now();

  UPDATE notices
  SET status = 'expired'
  WHERE status = 'published'
    AND expires_at IS NOT NULL
    AND expires_at <= now();
END;
$$;
```

### 5B. Page Changes: `src/pages/portal/notices/index.astro`

**For members — reading view:**
- Pinned notices show at top with a `📌 Pinned` amber badge and `border-l-4 border-amber-400` left accent on the card
- Each notice card gains:
  - Attachment preview strip: if image → thumbnail (w-full h-32 object-cover rounded-lg mt-2); if PDF → `<i class="fas fa-file-pdf text-red-500"></i> View Document` link to signed URL; if video_url → embedded iframe (YouTube)
  - Category badge (existing) + Expiry date if set: `<span class="text-xs text-gray-400">Expires {date}</span>`
  - Wing target badge if not all: `<span class="bg-primary-50 text-primary-700 text-xs px-2 py-0.5 rounded">Block A only</span>`

**For exec — creation view:**

**`src/pages/portal/notices/new.astro`** — extend existing new-notice form with:

```html
<!-- Additional fields after existing body textarea -->

<!-- Attachment section -->
<div class="card-premium p-4 mt-4">
  <h3 class="text-sm font-semibold text-text-primary mb-3">Attachment (optional)</h3>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
    <label class="border-2 border-dashed border-border-light rounded-xl p-4 text-center cursor-pointer hover:border-primary-300 transition-colors">
      <i class="fas fa-image text-2xl text-primary-400 mb-2 block"></i>
      <span class="text-sm text-text-secondary">Upload Image</span>
      <input type="file" name="attachment" accept="image/jpeg,image/png,image/webp" class="hidden" id="attach-image" />
    </label>
    <label class="border-2 border-dashed border-border-light rounded-xl p-4 text-center cursor-pointer hover:border-primary-300 transition-colors">
      <i class="fas fa-file-pdf text-2xl text-red-400 mb-2 block"></i>
      <span class="text-sm text-text-secondary">Upload PDF</span>
      <input type="file" name="attachment" accept="application/pdf" class="hidden" id="attach-pdf" />
    </label>
    <div class="border-2 border-dashed border-border-light rounded-xl p-4">
      <i class="fab fa-youtube text-2xl text-red-500 mb-2 block text-center"></i>
      <label class="form-label">YouTube URL</label>
      <input type="url" name="video_url" class="form-input text-sm"
             placeholder="https://youtube.com/watch?v=..." />
    </div>
  </div>
</div>

<!-- Publish options -->
<div class="card-premium p-4 mt-4">
  <h3 class="text-sm font-semibold text-text-primary mb-3">Publish Settings</h3>
  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <!-- Publish timing -->
    <div>
      <label class="form-label">Publish</label>
      <div class="flex gap-3">
        <label class="flex items-center gap-2 cursor-pointer">
          <input type="radio" name="publish_timing" value="now" checked class="accent-primary-600" />
          <span class="text-sm">Immediately</span>
        </label>
        <label class="flex items-center gap-2 cursor-pointer">
          <input type="radio" name="publish_timing" value="scheduled" class="accent-primary-600" />
          <span class="text-sm">Schedule</span>
        </label>
      </div>
      <input type="datetime-local" name="scheduled_at" class="form-input mt-2 hidden" id="scheduled-at-input" />
    </div>
    <!-- Expiry -->
    <div>
      <label class="form-label">Expires On (optional)</label>
      <input type="datetime-local" name="expires_at" class="form-input" />
    </div>
  </div>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
    <!-- Wing targeting -->
    <div>
      <label class="form-label">Target Audience</label>
      <select name="target_wings" multiple class="form-input h-24">
        <option value="">All Residents</option>
        <!-- Populated from units.block distinct values -->
      </select>
      <p class="text-xs text-text-secondary mt-1">Hold Ctrl/Cmd to select multiple wings. Leave blank for all.</p>
    </div>
    <!-- Pin -->
    <div class="flex items-center gap-3 mt-6">
      <input type="checkbox" name="is_pinned" id="is_pinned"
             class="w-4 h-4 rounded accent-primary-600" />
      <label for="is_pinned" class="text-sm font-medium text-text-primary">
        Pin this notice (appears at top of feed)
      </label>
    </div>
  </div>
</div>
```

**Notice list view (exec)** — add status filter tabs:
`All | Published | Scheduled | Expired | Archived`
Each tab shows count badge. Scheduled notices show countdown: "Publishes in 2h 30m".

### 5C. Policies Module (new, separate from Documents)

#### Migration addition in `039_notices_enhancements.sql`:

```sql
CREATE TABLE policies (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id        uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  title             text NOT NULL,
  description       text,
  policy_type       text NOT NULL DEFAULT 'text'
    CHECK (policy_type IN ('text','pdf','video_url')),
  body              text,                   -- for type='text'
  document_key      text,                   -- Supabase Storage key for PDF
  video_url         text,                   -- YouTube for type='video_url'
  version           int  NOT NULL DEFAULT 1,
  effective_date    date NOT NULL DEFAULT CURRENT_DATE,
  acknowledgement_required bool NOT NULL DEFAULT false,
  gate_portal_access bool NOT NULL DEFAULT false,  -- if true, member must ack before portal access
  status            text NOT NULL DEFAULT 'active'
    CHECK (status IN ('draft','active','superseded')),
  superseded_by     uuid REFERENCES policies(id) ON DELETE SET NULL,
  created_by        uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE policy_acknowledgements (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id   uuid NOT NULL REFERENCES policies(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  acked_at    timestamptz NOT NULL DEFAULT now(),
  ip_hash     text,
  UNIQUE(policy_id, user_id)
);

ALTER TABLE policies ENABLE ROW LEVEL SECURITY;
ALTER TABLE policy_acknowledgements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "society_read_active_policies" ON policies FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
         AND status = 'active');

CREATE POLICY "exec_manage_policies" ON policies FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));

CREATE POLICY "member_ack_policy" ON policy_acknowledgements FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "member_view_own_ack" ON policy_acknowledgements FOR SELECT
  USING (user_id = auth.uid() OR EXISTS (
    SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));
```

**`src/pages/portal/policies/index.astro`** (new page)
- Member view: Card per policy — Title, Version, Effective Date, Type badge, content/link, Acknowledge button
  - Acknowledged policies show green checkmark badge, date of ack
  - Required-but-unacknowledged: amber banner at top "Please review and acknowledge the following policies"
- Exec view: same + Add Policy button, version history drawer, acknowledgement stats (N/M residents acknowledged)

**`src/pages/portal/policies/[id].astro`** (new page)
- Full policy view: inline text OR PDF viewer OR YouTube embed
- Acknowledge button (POST `/api/v1/policies/{id}/acknowledge`)
- Version history timeline (previous versions with superseded dates)

**Portal middleware gate** — in `src/middleware.ts` (or the existing Astro middleware):
```typescript
// After auth check, before serving any portal page:
const ungatedPolicies = await getPoliciesRequiringAck(user.id, user.societyId)
if (ungatedPolicies.length > 0 && !request.url.includes('/portal/policies')) {
  return redirect('/portal/policies?required=true')
}
```

---

## MODULE 6 — Finance & Billing

### 6A. Migration: `040_finance_enhancements.sql`

```sql
-- Extend billing_periods with line-item support
ALTER TABLE billing_periods
  ADD COLUMN IF NOT EXISTS description    text,
  ADD COLUMN IF NOT EXISTS target_wings   text[],       -- NULL = all
  ADD COLUMN IF NOT EXISTS invoice_prefix text NOT NULL DEFAULT 'INV',
  ADD COLUMN IF NOT EXISTS invoice_seq    int  NOT NULL DEFAULT 0;

-- Invoice line items (replaces single base_amount on maintenance_dues)
CREATE TABLE invoice_line_items (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id        uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  dues_id           uuid NOT NULL REFERENCES maintenance_dues(id) ON DELETE CASCADE,
  subcategory_id    uuid REFERENCES receivable_subcategories(id) ON DELETE SET NULL,
  description       text NOT NULL,
  quantity          numeric(10,3) NOT NULL DEFAULT 1,   -- sqft for per_sqft; units for per_unit; 1 otherwise
  unit_rate         numeric(12,2) NOT NULL,
  amount            numeric(12,2) GENERATED ALWAYS AS (quantity * unit_rate) STORED,
  gst_rate          numeric(5,2) NOT NULL DEFAULT 0,
  gst_amount        numeric(12,2) GENERATED ALWAYS AS (quantity * unit_rate * gst_rate / 100) STORED,
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- Extend maintenance_dues with invoice number
ALTER TABLE maintenance_dues
  ADD COLUMN IF NOT EXISTS invoice_number  text UNIQUE,  -- e.g. INV-2025-0042
  ADD COLUMN IF NOT EXISTS invoice_pdf_key text,         -- Supabase Storage key for generated PDF
  ADD COLUMN IF NOT EXISTS billing_notes   text;

-- Extend payments with receipt PDF
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS receipt_pdf_key text;         -- Supabase Storage key

-- Late fee charges (separate from base dues — appended when grace period exceeded)
CREATE TABLE late_fee_charges (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  dues_id         uuid NOT NULL REFERENCES maintenance_dues(id) ON DELETE CASCADE,
  rule_id         uuid REFERENCES late_fee_rules(id) ON DELETE SET NULL,
  charge_date     date NOT NULL DEFAULT CURRENT_DATE,
  amount          numeric(12,2) NOT NULL,
  waived          bool NOT NULL DEFAULT false,
  waived_by       uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  waiver_reason   text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Partial payment allocation
CREATE TABLE payment_allocations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id      uuid NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  dues_id         uuid NOT NULL REFERENCES maintenance_dues(id) ON DELETE CASCADE,
  amount_allocated numeric(12,2) NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Advance credits (member paid more than owed)
CREATE TABLE member_credits (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount          numeric(12,2) NOT NULL,         -- positive = credit available
  source_payment  uuid REFERENCES payments(id) ON DELETE SET NULL,
  applied_to_dues uuid REFERENCES maintenance_dues(id) ON DELETE SET NULL,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Invoice number auto-generation function
CREATE OR REPLACE FUNCTION generate_invoice_number(p_society_id uuid, p_prefix text)
RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_year  text := to_char(now(), 'YYYY');
  v_seq   int;
BEGIN
  UPDATE billing_periods
  SET invoice_seq = invoice_seq + 1
  WHERE society_id = p_society_id
    AND id = (SELECT id FROM billing_periods WHERE society_id = p_society_id AND is_active ORDER BY created_at DESC LIMIT 1)
  RETURNING invoice_seq INTO v_seq;

  RETURN p_prefix || '-' || v_year || '-' || lpad(v_seq::text, 4, '0');
END;
$$;

-- Enable RLS
ALTER TABLE invoice_line_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE late_fee_charges ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_credits ENABLE ROW LEVEL SECURITY;

-- Member reads their own dues/line items
CREATE POLICY "member_read_own_line_items" ON invoice_line_items FOR SELECT
  USING (dues_id IN (SELECT id FROM maintenance_dues WHERE user_id = auth.uid()));
CREATE POLICY "exec_manage_line_items" ON invoice_line_items FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));

CREATE POLICY "member_read_own_late_fees" ON late_fee_charges FOR SELECT
  USING (dues_id IN (SELECT id FROM maintenance_dues WHERE user_id = auth.uid()));
CREATE POLICY "exec_manage_late_fees_charges" ON late_fee_charges FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));

CREATE POLICY "member_read_own_credits" ON member_credits FOR SELECT
  USING (user_id = auth.uid());
CREATE POLICY "exec_manage_credits" ON member_credits FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));
```

### 6B. Finance Page Enhancements

**`src/pages/portal/finance/index.astro`** — extend existing

**Billing Period Creation Modal** — extend with new fields:
```html
<!-- In #period-modal form, after existing fields -->
<div class="mt-4">
  <label class="form-label">Description (optional)</label>
  <input type="text" name="description" class="form-input"
         placeholder="e.g. Q1 2025 Maintenance" />
</div>

<div class="mt-4">
  <label class="form-label">Target Wings (leave blank for all)</label>
  <select name="target_wings" multiple class="form-input h-20">
    <!-- Populated from units.block distinct values -->
  </select>
</div>

<div class="mt-4">
  <label class="form-label">Line Items</label>
  <div id="line-items-container">
    <!-- Dynamic rows added by JS -->
    <div class="line-item-row grid grid-cols-12 gap-2 items-end mb-2">
      <div class="col-span-4">
        <select name="subcategory_id[]" class="form-input text-sm">
          <option value="">-- Select Sub-Category --</option>
          <!-- Populated from receivable_subcategories -->
        </select>
      </div>
      <div class="col-span-3">
        <input type="text" name="description[]" class="form-input text-sm" placeholder="Description" />
      </div>
      <div class="col-span-2">
        <input type="number" name="unit_rate[]" class="form-input text-sm" placeholder="₹ Amount" step="0.01" />
      </div>
      <div class="col-span-2">
        <select name="gst_rate[]" class="form-input text-sm">
          <option value="0">0% GST</option>
          <option value="5">5%</option>
          <option value="12">12%</option>
          <option value="18">18%</option>
        </select>
      </div>
      <div class="col-span-1">
        <button type="button" class="text-red-500 hover:text-red-700 remove-line-item">
          <i class="fas fa-times"></i>
        </button>
      </div>
    </div>
  </div>
  <button type="button" id="add-line-item"
          class="text-sm text-primary-600 hover:text-primary-800 font-medium mt-1">
    <i class="fas fa-plus mr-1"></i> Add Line Item
  </button>
</div>
```

**Dues table per member** — extend columns:
- Invoice # column (INV-2025-0042, monospace font)
- Due Date column
- Line Items expand arrow (click row → expand showing sub-category breakdown)
- Late Fee column (shows accumulated late fee if any, amber text)
- Actions: Download Invoice PDF button | Record Payment | Waive Late Fee (exec only)

**Member Finance view** — add:
- Invoice PDF download button per dues row
- Credit balance banner: `"You have ₹X advance credit available — applied to next bill"`
- Payment history table: Date | Mode | Reference | Amount | Receipt PDF link

### 6C. Invoice PDF Generation

**`src/pages/api/v1/finance/invoice/[dues_id].ts`** — GET endpoint
- Auth: member (own dues only) OR exec
- Uses `pdfmake` (already in package.json)
- PDF layout:
  - Header: UTAMACS logo (from public/), society name, registration number, GST number
  - Box: Invoice # | Billing Period | Due Date
  - Bill To: Member name, Flat number, Block
  - Line items table: Description | Qty | Rate | Amount | GST
  - Totals: Sub-total | GST Total | Late Fee (if any) | **Total Due**
  - Footer: "Pay online at portal.utamacs.org | Queries: utamacs@gmail.com"
  - Watermark "PAID" in green diagonal text if status = paid
- Returns `Content-Type: application/pdf`, `Content-Disposition: attachment; filename="INV-2025-0042.pdf"`

**`src/pages/api/v1/finance/receipt/[payment_id].ts`** — GET endpoint
- Auth: member (own payment) OR exec
- PDF layout:
  - Header: UTAMACS logo + "Payment Receipt"
  - Receipt #: UTA-RCP-YYYY-##### (existing field on payments table)
  - Payment Date, Mode, Transaction Reference
  - Paid By, Flat Number
  - Line: "Payment received for: {billing_period.name}"
  - Amount in large bold text
  - Digital signature note: "This is a computer-generated receipt. No physical signature required."
  - Footer: UTAMACS contact details

### 6D. Late Fee Auto-Calculation

**Supabase Edge Function: `calculate-late-fees`** (run daily via pg_cron or Supabase cron)

```typescript
// Called once daily at 00:01 IST
// For each overdue dues record (status='overdue'):
// 1. Find applicable late_fee_rule for each line item's subcategory
// 2. Check if grace period has passed: due_date + grace_period_days < today
// 3. Check if late fee already charged today (if monthly frequency)
// 4. If not waived, insert into late_fee_charges
// 5. Update maintenance_dues.penalty_amount = SUM(late_fee_charges.amount) where not waived
```

### 6E. Partial Payments

**Record Payment modal** — extend with partial payment UI:
```html
<!-- In the payment recording modal -->
<div class="mt-4">
  <label class="form-label">Amount Being Paid</label>
  <div class="flex gap-3 items-center">
    <input type="number" name="amount" class="form-input" id="payment-amount"
           placeholder="Enter amount" step="0.01" />
    <button type="button" id="pay-full"
            class="btn-outline text-sm py-2 whitespace-nowrap">Pay Full ₹{total}</button>
  </div>
  <div id="partial-notice" class="hidden mt-2 text-sm text-amber-600 bg-amber-50 p-2 rounded-lg">
    <i class="fas fa-info-circle mr-1"></i>
    Partial payment: ₹<span id="remaining-amount">0</span> will remain outstanding.
    Status will be set to <strong>Partially Paid</strong>.
  </div>
</div>
```

Backend: `PATCH /api/v1/finance/dues/[id]/payment`
- If amount < total_amount → status = 'partially_paid'
- If amount >= total_amount → status = 'paid', paid_at = now()
- If amount > total_amount → create `member_credits` record for excess

---

## MODULE 7 — Refunds

### 7A. Migration: `041_refunds.sql`

```sql
CREATE TABLE refund_rules (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  service_type        text NOT NULL
    CHECK (service_type IN ('facility_booking','event','other')),
  service_id          uuid,                  -- NULL = applies to all facilities of this type
  cancellation_window_hours int NOT NULL DEFAULT 24,
  refund_percentage   numeric(5,2) NOT NULL  -- 0 to 100
    CHECK (refund_percentage BETWEEN 0 AND 100),
  description         text,                  -- e.g. "Cancel 24h before for full refund"
  is_active           bool NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE refund_requests (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  requested_by        uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_payment_id   uuid NOT NULL REFERENCES payments(id) ON DELETE RESTRICT,
  rule_id             uuid REFERENCES refund_rules(id) ON DELETE SET NULL,
  original_amount     numeric(12,2) NOT NULL,
  refund_amount       numeric(12,2) NOT NULL,  -- calculated from rule at time of request
  reason              text NOT NULL,
  status              text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending','approved','rejected','processing','completed')),
  reviewed_by         uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at         timestamptz,
  rejection_reason    text,
  refund_method       text
    CHECK (refund_method IN ('bank_transfer','credit_to_account','cheque')),
  bank_account_name   text,
  bank_account_number text,
  bank_ifsc           text,
  utr_reference       text,                  -- bank transfer reference
  completed_at        timestamptz,
  created_at          timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE refund_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE refund_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "society_read_refund_rules" ON refund_rules FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id=auth.uid()));

CREATE POLICY "exec_manage_refund_rules" ON refund_rules FOR ALL
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));

CREATE POLICY "member_view_own_requests" ON refund_requests FOR SELECT
  USING (requested_by = auth.uid() OR EXISTS (
    SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE POLICY "member_create_refund_request" ON refund_requests FOR INSERT
  WITH CHECK (requested_by = auth.uid());

CREATE POLICY "exec_update_refund_request" ON refund_requests FOR UPDATE
  USING (EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)));
```

### 7B. Pages

**`src/pages/portal/admin/refund-rules.astro`** (exec/admin only)
- Table: Service Type | Facility/Event | Cancellation Window | Refund % | Description | Status | Actions
- Add/edit modal fields:
  - Service Type (select: Facility Booking / Event / Other)
  - Specific Facility (select, optional — populated when Facility Booking selected)
  - Cancellation Window (hours, number, e.g. 24)
  - Refund % (slider 0-100 with numeric input)
  - Description (auto-generated preview: "Cancel at least 24 hours before for 100% refund")
  - Active toggle

**`src/pages/portal/finance/refunds.astro`** (member + exec views)

Member view:
- "My Refund Requests" table: Booking/Payment ref | Amount Paid | Refund Amount | Reason | Status badge | Date
- "Request a Refund" button → form:
  - Select Payment (dropdown of their paid facility/event bookings)
  - Reason (textarea)
  - Auto-shows applicable rule: "Based on our refund policy, you are eligible for ₹{amount} ({pct}% of ₹{paid})"
  - Bank Account Details section (account name, number, IFSC) — pre-filled if previously entered

Exec view:
- Tabbed: Pending | Approved | Processing | Completed | Rejected
- Pending tab: each request shows member details, payment ref, amount requested, rule applied
  - Action buttons: Approve (opens payment method modal) | Reject (requires reason)
  - Approve modal: Refund Method (Bank Transfer / Credit to Account / Cheque), bank details, UTR field
  - On Approve → status = 'approved'; when payment dispatched → update to 'processing'; on confirm receipt → 'completed'

---

## MODULE 8 — Complaints Enhancements

### 8A. Migration: `042_complaints_enhancements.sql`

```sql
-- Sub-categories
CREATE TABLE complaint_subcategories (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  category        text NOT NULL,             -- matches complaints.category
  name            text NOT NULL,             -- e.g. "Power Fluctuation" under "Electrical"
  is_active       bool NOT NULL DEFAULT true,
  display_order   int  NOT NULL DEFAULT 0,
  UNIQUE(society_id, category, name)
);

-- Complaint attachments (multiple photos/videos per complaint)
CREATE TABLE complaint_attachments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id    uuid NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
  storage_key     text NOT NULL,             -- Supabase Storage key
  file_type       text NOT NULL CHECK (file_type IN ('image','video','document')),
  file_name       text NOT NULL,
  uploaded_by     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  uploaded_at     timestamptz NOT NULL DEFAULT now()
);

-- Post-resolution satisfaction rating
CREATE TABLE complaint_ratings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id    uuid NOT NULL REFERENCES complaints(id) ON DELETE CASCADE UNIQUE,
  rated_by        uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating          int NOT NULL CHECK (rating BETWEEN 1 AND 5),
  feedback        text,
  rated_at        timestamptz NOT NULL DEFAULT now()
);

-- Extend complaints table
ALTER TABLE complaints
  ADD COLUMN IF NOT EXISTS subcategory  text,
  ADD COLUMN IF NOT EXISTS expected_resolution_date date,
  ADD COLUMN IF NOT EXISTS rating_requested_at timestamptz;  -- when rating email was sent

-- Extend complaint_sla_config if not already done
ALTER TABLE complaint_sla_config
  ADD COLUMN IF NOT EXISTS escalation_hours int;  -- hours after SLA breach to auto-escalate

-- Default sub-categories seed
INSERT INTO complaint_subcategories (society_id, category, name, display_order)
SELECT s.id, cat.category, cat.name, cat.display_order
FROM societies s
CROSS JOIN (VALUES
  ('Electrical','Power Fluctuation',1),('Electrical','Short Circuit',2),('Electrical','Light Not Working',3),
  ('Plumbing','Water Leakage',1),('Plumbing','Drain Blockage',2),('Plumbing','No Water Supply',3),
  ('Lift','Stuck Lift',1),('Lift','Door Not Closing',2),('Lift','Unusual Noise',3),
  ('Intercom','No Dial Tone',1),('Intercom','Damaged Unit',2),
  ('Common Area','Cleanliness',1),('Common Area','Lighting',2),('Common Area','Damaged Infrastructure',3),
  ('Security','Gate Issue',1),('Security','CCTV Fault',2),('Security','Access Card',3)
) AS cat(category, name, display_order);

ALTER TABLE complaint_attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaint_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE complaint_subcategories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "society_read_subcategories" ON complaint_subcategories FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id=auth.uid()));

CREATE POLICY "member_view_complaint_attachments" ON complaint_attachments FOR SELECT
  USING (complaint_id IN (SELECT id FROM complaints WHERE raised_by=auth.uid())
    OR EXISTS (SELECT 1 FROM profiles WHERE id=auth.uid()
      AND (portal_role IN ('executive','secretary','president') OR is_admin)));

CREATE POLICY "member_upload_attachment" ON complaint_attachments FOR INSERT
  WITH CHECK (uploaded_by = auth.uid());

CREATE POLICY "member_rate_own_complaint" ON complaint_ratings FOR INSERT
  WITH CHECK (rated_by = auth.uid()
    AND complaint_id IN (SELECT id FROM complaints WHERE raised_by=auth.uid()));

CREATE POLICY "member_view_own_rating" ON complaint_ratings FOR SELECT
  USING (rated_by = auth.uid() OR EXISTS (
    SELECT 1 FROM profiles WHERE id=auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));
```

### 8B. Page Changes

**`src/pages/portal/complaints/new.astro`** — extend form:
```html
<!-- After category select, add sub-category -->
<div class="mt-4">
  <label class="form-label">Sub-Category</label>
  <select name="subcategory" class="form-input" id="subcategory-select">
    <option value="">Select sub-category (optional)</option>
    <!-- Populated via JS based on selected category -->
  </select>
</div>

<!-- Expected resolution date (exec/admin filling on behalf) — skip for member -->

<!-- Attachment section -->
<div class="mt-4">
  <label class="form-label">Add Photos / Videos (optional)</label>
  <div class="border-2 border-dashed border-border-light rounded-xl p-6 text-center" id="attachment-drop-zone">
    <i class="fas fa-camera text-3xl text-primary-300 mb-2"></i>
    <p class="text-sm text-text-secondary">Drag & drop or click to upload</p>
    <p class="text-xs text-text-secondary mt-1">JPG, PNG up to 5MB per file; MP4 up to 50MB</p>
    <input type="file" id="attachment-files" multiple accept="image/*,video/mp4" class="hidden" />
  </div>
  <div id="attachment-previews" class="flex flex-wrap gap-2 mt-3"></div>
</div>
```

JS behaviour: on file select → show thumbnail grid; on submit → upload each file to Supabase Storage, then POST complaint with returned storage keys.

**Complaint detail page `[id].astro`** — extend:
- Photo/video gallery strip below complaint description (thumbnail grid, click to lightbox)
- **Expected Resolution Date** shown as: `"Expected by: {date}"` with colour: green if future, red if past
- **SLA Overdue Badge**: `<span class="bg-red-100 text-red-700 px-2 py-0.5 rounded-full text-xs font-medium"><i class="fas fa-exclamation-triangle mr-1"></i>SLA Breached</span>` shown when `sla_deadline < now()` and status NOT IN ('Resolved','Closed')
- **Satisfaction Rating** section (shown to complainant after status = 'Resolved'):
  ```html
  <div class="card-premium p-4 border-l-4 border-secondary-400 mt-6">
    <h3 class="font-semibold text-text-primary mb-2">How was the resolution?</h3>
    <div class="flex gap-2" id="star-rating">
      <!-- 5 star buttons, JS highlights on hover/click -->
      <button class="text-2xl text-gray-300 hover:text-accent-500 transition-colors" data-rating="1">★</button>
      <button class="text-2xl text-gray-300 hover:text-accent-500 transition-colors" data-rating="2">★</button>
      <button class="text-2xl text-gray-300 hover:text-accent-500 transition-colors" data-rating="3">★</button>
      <button class="text-2xl text-gray-300 hover:text-accent-500 transition-colors" data-rating="4">★</button>
      <button class="text-2xl text-gray-300 hover:text-accent-500 transition-colors" data-rating="5">★</button>
    </div>
    <textarea name="rating_feedback" class="form-input mt-3" rows="2"
              placeholder="Any additional feedback? (optional)"></textarea>
    <button type="submit" class="btn-primary mt-3 text-sm py-2">Submit Rating</button>
  </div>
  ```

**Complaints list view** — add:
- Sub-category column (shown on expanded row or tooltip)
- SLA Breach filter: `<button class="btn-outline text-sm text-red-600 border-red-300">SLA Breached ({count})</button>`
- Complaint card in exec list view: show SLA deadline with colour coding

### 8C. Admin: Complaint Sub-Categories Management

Add sub-section to `src/pages/portal/admin/index.astro` (or existing complaint settings page):
- Table: Category | Sub-Category | Order | Active | Actions
- Add row inline: Category (select from existing categories), Sub-Category Name, Order
- Drag to reorder (or use Up/Down arrows)
- Can be accessed at `/portal/admin/complaints-config`
