-- ── Rules table INSERT compatibility trigger ────────────────────────────────
-- Makes rule_category, label, and default_value optional in INSERT statements
-- by filling defaults from the row itself. getRules() only reads rule_code +
-- current_value, so these columns are admin-display only.
CREATE OR REPLACE FUNCTION rules_insert_defaults()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.rule_category IS NULL OR NEW.rule_category = '' THEN
    NEW.rule_category := 'PARAMETER';
  END IF;
  IF NEW.label IS NULL OR NEW.label = '' THEN
    NEW.label := NEW.rule_code;
  END IF;
  IF NEW.default_value IS NULL THEN
    NEW.default_value := NEW.current_value;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS rules_insert_defaults_trig ON rules;
CREATE TRIGGER rules_insert_defaults_trig
  BEFORE INSERT ON rules
  FOR EACH ROW EXECUTE FUNCTION rules_insert_defaults();

-- Migration 094: Finance enhancements — invoice line items, late fee charges,
--                partial payments, member credits, billing period extensions
--
-- Extends the finance module with:
--   billing_periods       — description, target_wings, invoice_prefix, invoice_seq
--   maintenance_dues      — invoice_number, invoice_pdf_key, billing_notes, amount_paid
--   invoice_line_items    — per-dues line items (subcategory, qty, rate, gst)
--   late_fee_charges      — penalty charges appended to dues
--   payment_allocations   — maps each payment to dues it covers (partial payment support)
--   member_credits        — advance/excess payment credits

BEGIN;

-- ── Extend billing_periods ────────────────────────────────────────────────────

ALTER TABLE billing_periods
  ADD COLUMN IF NOT EXISTS description    text CHECK (length(description) <= 500),
  ADD COLUMN IF NOT EXISTS target_wings   text[],
  ADD COLUMN IF NOT EXISTS invoice_prefix text NOT NULL DEFAULT 'INV',
  ADD COLUMN IF NOT EXISTS invoice_seq    int  NOT NULL DEFAULT 0;

-- ── Extend maintenance_dues ───────────────────────────────────────────────────

ALTER TABLE maintenance_dues
  ADD COLUMN IF NOT EXISTS invoice_number   text UNIQUE CHECK (length(invoice_number) <= 50),
  ADD COLUMN IF NOT EXISTS invoice_pdf_key  text,
  ADD COLUMN IF NOT EXISTS billing_notes    text CHECK (length(billing_notes) <= 1000),
  ADD COLUMN IF NOT EXISTS amount_paid      numeric(10,2) NOT NULL DEFAULT 0;

-- ── Extend payments ───────────────────────────────────────────────────────────

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS receipt_pdf_key text;

-- ── Invoice number generator ──────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION generate_invoice_number(
  p_society_id uuid,
  p_dues_id    uuid
) RETURNS text LANGUAGE plpgsql AS $$
DECLARE
  v_prefix text;
  v_year   text := to_char(now(), 'YYYY');
  v_seq    int;
  v_period_id uuid;
BEGIN
  -- Find the active billing period for this dues record
  SELECT billing_period_id INTO v_period_id
  FROM maintenance_dues WHERE id = p_dues_id;

  -- Increment and read the sequence on the billing period
  UPDATE billing_periods
  SET invoice_seq = invoice_seq + 1
  WHERE id = v_period_id AND society_id = p_society_id
  RETURNING invoice_seq, invoice_prefix INTO v_seq, v_prefix;

  IF v_seq IS NULL THEN
    -- Fallback: global sequence across all periods
    v_seq := (SELECT COUNT(*) + 1 FROM maintenance_dues
              WHERE society_id = p_society_id AND invoice_number IS NOT NULL);
    v_prefix := 'INV';
  END IF;

  RETURN v_prefix || '/' || v_year || '/' || lpad(v_seq::text, 4, '0');
END;
$$;

-- ── Invoice Line Items ────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS invoice_line_items (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id     uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  dues_id        uuid        NOT NULL REFERENCES maintenance_dues(id) ON DELETE CASCADE,
  subcategory_id uuid        REFERENCES receivable_subcategories(id) ON DELETE SET NULL,
  description    text        NOT NULL CHECK (length(description) BETWEEN 1 AND 200),
  quantity       numeric(10,3) NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_rate      numeric(12,2) NOT NULL CHECK (unit_rate >= 0),
  gst_rate       numeric(5,2) NOT NULL DEFAULT 0 CHECK (gst_rate IN (0,5,12,18)),
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_invoice_line_items_dues
  ON invoice_line_items(dues_id);

-- ── Late Fee Charges ──────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS late_fee_charges (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id     uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  dues_id        uuid        NOT NULL REFERENCES maintenance_dues(id) ON DELETE CASCADE,
  rule_id        uuid        REFERENCES late_fee_rules(id) ON DELETE SET NULL,
  charge_date    date        NOT NULL DEFAULT CURRENT_DATE,
  amount         numeric(12,2) NOT NULL CHECK (amount > 0),
  waived         bool        NOT NULL DEFAULT false,
  waived_by      uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  waiver_reason  text        CHECK (length(waiver_reason) <= 500),
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_late_fee_charges_dues
  ON late_fee_charges(dues_id);

CREATE INDEX IF NOT EXISTS idx_late_fee_charges_date
  ON late_fee_charges(society_id, charge_date);

-- ── Payment Allocations ───────────────────────────────────────────────────────
-- Maps each payment to the dues record(s) it covers. Enables partial payment.

CREATE TABLE IF NOT EXISTS payment_allocations (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id       uuid        NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  dues_id          uuid        NOT NULL REFERENCES maintenance_dues(id) ON DELETE CASCADE,
  amount_allocated numeric(12,2) NOT NULL CHECK (amount_allocated > 0),
  created_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE(payment_id, dues_id)
);

CREATE INDEX IF NOT EXISTS idx_payment_allocations_dues
  ON payment_allocations(dues_id);

-- ── Member Credits ────────────────────────────────────────────────────────────
-- Records advance payments or excess amounts applied as credits.

CREATE TABLE IF NOT EXISTS member_credits (
  id             uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id     uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  user_id        uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount         numeric(12,2) NOT NULL CHECK (amount > 0),
  source_payment uuid        REFERENCES payments(id) ON DELETE SET NULL,
  applied_to_dues uuid       REFERENCES maintenance_dues(id) ON DELETE SET NULL,
  notes          text        CHECK (length(notes) <= 500),
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_member_credits_user
  ON member_credits(society_id, user_id);

-- ── Row Level Security ────────────────────────────────────────────────────────

ALTER TABLE invoice_line_items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE late_fee_charges    ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_credits      ENABLE ROW LEVEL SECURITY;

-- Invoice line items: member reads own; exec manages all
CREATE POLICY "member_read_own_line_items" ON invoice_line_items FOR SELECT
  USING (dues_id IN (SELECT id FROM maintenance_dues WHERE user_id = auth.uid()));

CREATE POLICY "exec_manage_line_items" ON invoice_line_items FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- Late fee charges: member reads own; exec manages all
CREATE POLICY "member_read_own_late_fee_charges" ON late_fee_charges FOR SELECT
  USING (dues_id IN (SELECT id FROM maintenance_dues WHERE user_id = auth.uid()));

CREATE POLICY "exec_manage_late_fee_charges" ON late_fee_charges FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- Payment allocations: member reads own; exec manages all
CREATE POLICY "member_read_own_allocations" ON payment_allocations FOR SELECT
  USING (dues_id IN (SELECT id FROM maintenance_dues WHERE user_id = auth.uid()));

CREATE POLICY "exec_manage_allocations" ON payment_allocations FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- Member credits: member reads own; exec manages all
CREATE POLICY "member_read_own_credits" ON member_credits FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "exec_manage_credits" ON member_credits FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── Rules engine seeds for late fee defaults ──────────────────────────────────

INSERT INTO rules (society_id, rule_code, rule_category, label, description, value_type, current_value, default_value, is_locked)
SELECT
  id,
  unnest(ARRAY[
    'LATE_FEE_GRACE_PERIOD_DAYS',
    'LATE_FEE_DEFAULT_RATE_PCT',
    'LATE_FEE_MAX_CAP_AMOUNT',
    'LATE_FEE_CRON_ENABLED'
  ]),
  'PARAMETER',
  unnest(ARRAY[
    'Late Fee Grace Period (days)',
    'Late Fee Default Rate (%)',
    'Late Fee Maximum Cap (₹)',
    'Late Fee Cron Enabled'
  ]),
  unnest(ARRAY[
    'Days after due date before late fee is applied',
    'Annual interest rate % for late fee calculation (monthly = rate/12)',
    'Maximum late fee cap per dues record (0 = uncapped)',
    'Whether the daily late fee cron job is active'
  ]),
  unnest(ARRAY['int','decimal','decimal','boolean']),
  unnest(ARRAY['5'::jsonb,'18.00'::jsonb,'5000.00'::jsonb,'true'::jsonb]),
  unnest(ARRAY['5'::jsonb,'18.00'::jsonb,'5000.00'::jsonb,'true'::jsonb]),
  unnest(ARRAY[false,false,false,false])
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;

COMMIT;
