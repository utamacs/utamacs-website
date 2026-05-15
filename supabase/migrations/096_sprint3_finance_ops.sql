-- Sprint 3: Finance Operations Foundation
-- Brings in tables that were designed in Sprint 1 but not yet in a merged migration:
--   invoice_line_items, late_fee_charges, payment_allocations, member_credits
-- Extends maintenance_dues + payments with Sprint 1 columns
-- Adds payment_refunds table
-- Seeds late fee rules, notice ack reminder rule

-- ── Extensions to existing tables ────────────────────────────────────────────

ALTER TABLE maintenance_dues
  ADD COLUMN IF NOT EXISTS amount_paid       numeric(12,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS invoice_number    text UNIQUE,
  ADD COLUMN IF NOT EXISTS invoice_pdf_key   text,
  ADD COLUMN IF NOT EXISTS billing_notes     text CHECK (length(billing_notes) <= 500);

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS receipt_pdf_key   text;

-- billing_periods extensions (invoice sequencing, targeting)
ALTER TABLE billing_periods
  ADD COLUMN IF NOT EXISTS description       text CHECK (length(description) <= 500),
  ADD COLUMN IF NOT EXISTS target_wings      text[],
  ADD COLUMN IF NOT EXISTS invoice_prefix    text NOT NULL DEFAULT 'INV',
  ADD COLUMN IF NOT EXISTS invoice_seq       integer NOT NULL DEFAULT 0;

-- ── Invoice Number Generator ──────────────────────────────────────────────────
-- Returns next sequential invoice number for a society in format INV/YYYY/NNNN
-- Atomically increments the per-billing-period sequence.

CREATE OR REPLACE FUNCTION generate_invoice_number(
  p_society_id   uuid,
  p_dues_id      uuid
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_period_id  uuid;
  v_prefix     text;
  v_seq        integer;
  v_year       text;
  v_inv_no     text;
BEGIN
  SELECT billing_period_id INTO v_period_id
  FROM maintenance_dues WHERE id = p_dues_id AND society_id = p_society_id;

  IF v_period_id IS NULL THEN
    RAISE EXCEPTION 'dues not found';
  END IF;

  -- Fetch existing invoice_number if already assigned
  SELECT invoice_number INTO v_inv_no
  FROM maintenance_dues WHERE id = p_dues_id;
  IF v_inv_no IS NOT NULL THEN RETURN v_inv_no; END IF;

  -- Atomically bump sequence on the billing period
  UPDATE billing_periods
  SET invoice_seq = invoice_seq + 1
  WHERE id = v_period_id
  RETURNING invoice_prefix, invoice_seq INTO v_prefix, v_seq;

  v_year := to_char(now(), 'YYYY');
  v_inv_no := v_prefix || '/' || v_year || '/' || lpad(v_seq::text, 4, '0');

  UPDATE maintenance_dues SET invoice_number = v_inv_no WHERE id = p_dues_id;
  RETURN v_inv_no;
END;
$$;

-- ── Invoice Line Items ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS invoice_line_items (
  id               uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id       uuid          NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  dues_id          uuid          NOT NULL REFERENCES maintenance_dues(id) ON DELETE CASCADE,
  subcategory_id   uuid,
  description      text          NOT NULL CHECK (length(description) <= 255),
  quantity         numeric(8,2)  NOT NULL DEFAULT 1,
  unit_rate        numeric(12,2) NOT NULL,
  gst_rate         numeric(5,2)  NOT NULL DEFAULT 0 CHECK (gst_rate IN (0,5,12,18)),
  gst_amount       numeric(12,2) NOT NULL DEFAULT 0,
  line_total       numeric(12,2) NOT NULL,
  created_at       timestamptz   NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invoice_line_items_dues ON invoice_line_items(dues_id);

ALTER TABLE invoice_line_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "member_read_own_line_items" ON invoice_line_items;
CREATE POLICY "member_read_own_line_items" ON invoice_line_items FOR SELECT
  USING (dues_id IN (SELECT id FROM maintenance_dues WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "exec_manage_line_items" ON invoice_line_items;
CREATE POLICY "exec_manage_line_items" ON invoice_line_items FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── Late Fee Charges ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS late_fee_charges (
  id               uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id       uuid          NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  dues_id          uuid          NOT NULL REFERENCES maintenance_dues(id) ON DELETE CASCADE,
  charge_date      date          NOT NULL DEFAULT CURRENT_DATE,
  fee_amount       numeric(12,2) NOT NULL CHECK (fee_amount > 0),
  fee_type         text          NOT NULL CHECK (fee_type IN ('fixed','percentage')),
  rate_applied     numeric(8,4)  NOT NULL,
  created_at       timestamptz   NOT NULL DEFAULT now(),
  UNIQUE (dues_id, charge_date)
);

CREATE INDEX IF NOT EXISTS idx_late_fee_charges_dues ON late_fee_charges(dues_id);
CREATE INDEX IF NOT EXISTS idx_late_fee_charges_date ON late_fee_charges(society_id, charge_date);

ALTER TABLE late_fee_charges ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "member_read_own_late_fees" ON late_fee_charges;
DROP POLICY IF EXISTS "member_read_own_late_fee_charges" ON late_fee_charges;
CREATE POLICY "member_read_own_late_fees" ON late_fee_charges FOR SELECT
  USING (dues_id IN (SELECT id FROM maintenance_dues WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "exec_manage_late_fees" ON late_fee_charges;
DROP POLICY IF EXISTS "exec_manage_late_fee_charges" ON late_fee_charges;
CREATE POLICY "exec_manage_late_fees" ON late_fee_charges FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── Payment Allocations ───────────────────────────────────────────────────────
-- Maps each payment to the dues it covers (partial payment support).

CREATE TABLE IF NOT EXISTS payment_allocations (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id       uuid        NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  dues_id          uuid        NOT NULL REFERENCES maintenance_dues(id) ON DELETE CASCADE,
  amount_allocated numeric(12,2) NOT NULL CHECK (amount_allocated > 0),
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE(payment_id, dues_id)
);

CREATE INDEX IF NOT EXISTS idx_payment_allocations_dues ON payment_allocations(dues_id);
CREATE INDEX IF NOT EXISTS idx_payment_allocations_payment ON payment_allocations(payment_id);

ALTER TABLE payment_allocations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "member_read_own_allocations" ON payment_allocations;
CREATE POLICY "member_read_own_allocations" ON payment_allocations FOR SELECT
  USING (dues_id IN (SELECT id FROM maintenance_dues WHERE user_id = auth.uid()));

DROP POLICY IF EXISTS "exec_read_allocations" ON payment_allocations;
DROP POLICY IF EXISTS "exec_manage_allocations" ON payment_allocations;
CREATE POLICY "exec_read_allocations" ON payment_allocations FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- NO UPDATE/DELETE — payment allocations are immutable records matching payments

-- ── Member Credits ────────────────────────────────────────────────────────────
-- Records advance payments or excess amounts as reusable credits.

CREATE TABLE IF NOT EXISTS member_credits (
  id               uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id       uuid          NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  user_id          uuid          NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount           numeric(12,2) NOT NULL CHECK (amount > 0),
  source_payment   uuid          REFERENCES payments(id) ON DELETE SET NULL,
  applied_to_dues  uuid          REFERENCES maintenance_dues(id) ON DELETE SET NULL,
  notes            text          CHECK (length(notes) <= 500),
  status           text          NOT NULL DEFAULT 'available'
                   CHECK (status IN ('available','refunded','applied')),
  refunded_at      timestamptz,
  created_at       timestamptz   NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_member_credits_user ON member_credits(society_id, user_id);

ALTER TABLE member_credits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "member_read_own_credits" ON member_credits;
CREATE POLICY "member_read_own_credits" ON member_credits FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "exec_read_credits" ON member_credits;
DROP POLICY IF EXISTS "exec_manage_credits" ON member_credits;
CREATE POLICY "exec_read_credits" ON member_credits FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

DROP POLICY IF EXISTS "system_insert_credits" ON member_credits;
CREATE POLICY "system_insert_credits" ON member_credits FOR INSERT
  WITH CHECK (society_id = (SELECT society_id FROM profiles WHERE id = auth.uid() LIMIT 1));

-- Exec can update status (to 'refunded' or 'applied')
DROP POLICY IF EXISTS "exec_update_credits" ON member_credits;
CREATE POLICY "exec_update_credits" ON member_credits FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── Payment Refunds ───────────────────────────────────────────────────────────
-- Immutable record of exec-issued refunds from member credit balances.

CREATE TABLE IF NOT EXISTS payment_refunds (
  id               uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id       uuid          NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  credit_id        uuid          NOT NULL REFERENCES member_credits(id) ON DELETE CASCADE,
  user_id          uuid          NOT NULL REFERENCES auth.users(id),
  approved_by      uuid          NOT NULL REFERENCES auth.users(id),
  amount           numeric(12,2) NOT NULL CHECK (amount > 0),
  refund_mode      text          NOT NULL CHECK (refund_mode IN ('bank_transfer','cheque','cash','upi')),
  transaction_ref  text          CHECK (length(transaction_ref) <= 100),
  notes            text          CHECK (length(notes) <= 500),
  refunded_at      timestamptz   NOT NULL DEFAULT now(),
  created_at       timestamptz   NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payment_refunds_user ON payment_refunds(society_id, user_id);
CREATE INDEX IF NOT EXISTS idx_payment_refunds_credit ON payment_refunds(credit_id);

ALTER TABLE payment_refunds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_read_own_refunds" ON payment_refunds FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "exec_manage_refunds" ON payment_refunds FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- NO UPDATE/DELETE — refunds are immutable records

-- ── Rules Seeds ──────────────────────────────────────────────────────────────

INSERT INTO rules (society_id, rule_code, rule_category, value_type, current_value, is_locked, label)
SELECT
  id,
  unnest(ARRAY[
    'LATE_FEE_GRACE_PERIOD_DAYS',
    'LATE_FEE_DEFAULT_RATE_PCT',
    'LATE_FEE_MAX_CAP_AMOUNT',
    'LATE_FEE_CRON_ENABLED',
    'NOTICE_ACK_REMINDER_DAYS'
  ]),
  unnest(ARRAY[
    'finance',
    'finance',
    'finance',
    'finance',
    'notices'
  ]),
  unnest(ARRAY[
    'integer',
    'decimal',
    'decimal',
    'boolean',
    'integer'
  ]),
  unnest(ARRAY[
    '5'::jsonb,
    '18.00'::jsonb,
    '5000.00'::jsonb,
    'true'::jsonb,
    '3'::jsonb
  ]),
  unnest(ARRAY[false, false, false, false, false]),
  unnest(ARRAY[
    'Grace period (days) before late fee starts accruing',
    'Default late fee rate (% per month)',
    'Maximum cumulative late fee cap per due (₹)',
    'Enable automatic late fee application via cron',
    'Days after publication before reminder sent to pending ack members'
  ])
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;
