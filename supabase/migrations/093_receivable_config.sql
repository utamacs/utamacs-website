-- Migration 093: Receivable categories, sub-categories, and late fee rules
--
-- Provides the configuration layer for the Finance module:
--   receivable_categories    — top-level charge buckets (Maintenance, Sinking Fund, etc.)
--   receivable_subcategories — line-item definitions with calculation type and GST rate
--   late_fee_rules           — one rule per sub-category (grace period, rate, cap)
--
-- These tables are read by the billing period creation flow to auto-populate
-- invoice line items and by the late-fee cron to calculate penalty charges.

BEGIN;

-- ── Receivable Categories ─────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS receivable_categories (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  name          text        NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
  description   text        CHECK (length(description) <= 500),
  hsn_sac_code  text        CHECK (length(hsn_sac_code) <= 20),
  is_active     bool        NOT NULL DEFAULT true,
  display_order int         NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(society_id, name)
);

-- ── Receivable Sub-Categories ─────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS receivable_subcategories (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id       uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  category_id      uuid        NOT NULL REFERENCES receivable_categories(id) ON DELETE CASCADE,
  name             text        NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
  calculation_type text        NOT NULL DEFAULT 'fixed'
                               CHECK (calculation_type IN ('fixed','per_sqft','per_unit','variable')),
  amount           numeric(12,2) CHECK (amount >= 0),
  frequency        text        NOT NULL DEFAULT 'monthly'
                               CHECK (frequency IN ('monthly','quarterly','half_yearly','annually','one_time')),
  apply_to_wings   text[],
  gst_rate         numeric(5,2) NOT NULL DEFAULT 0
                               CHECK (gst_rate IN (0, 5, 12, 18)),
  is_active        bool        NOT NULL DEFAULT true,
  display_order    int         NOT NULL DEFAULT 0,
  created_at       timestamptz NOT NULL DEFAULT now()
);

-- ── Late Fee Rules ────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS late_fee_rules (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id        uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  subcategory_id    uuid        NOT NULL REFERENCES receivable_subcategories(id) ON DELETE CASCADE,
  grace_period_days int         NOT NULL DEFAULT 0 CHECK (grace_period_days >= 0),
  fee_type          text        NOT NULL DEFAULT 'fixed'
                                CHECK (fee_type IN ('fixed','percentage')),
  fee_amount        numeric(12,2) NOT NULL CHECK (fee_amount >= 0),
  fee_frequency     text        NOT NULL DEFAULT 'one_time'
                                CHECK (fee_frequency IN ('one_time','monthly')),
  max_fee_cap       numeric(12,2) CHECK (max_fee_cap >= 0),
  waiver_type       text        NOT NULL DEFAULT 'none'
                                CHECK (waiver_type IN ('none','full','partial')),
  created_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE(subcategory_id)
);

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_receivable_categories_society
  ON receivable_categories(society_id, is_active, display_order);

CREATE INDEX IF NOT EXISTS idx_receivable_subcategories_category
  ON receivable_subcategories(category_id, is_active, display_order);

CREATE INDEX IF NOT EXISTS idx_late_fee_rules_society
  ON late_fee_rules(society_id);

-- ── Row Level Security ────────────────────────────────────────────────────────

ALTER TABLE receivable_categories    ENABLE ROW LEVEL SECURITY;
ALTER TABLE receivable_subcategories ENABLE ROW LEVEL SECURITY;
ALTER TABLE late_fee_rules           ENABLE ROW LEVEL SECURITY;

-- All authenticated society members may read
CREATE POLICY "society_read_receivable_categories" ON receivable_categories FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "society_read_receivable_subcategories" ON receivable_subcategories FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "society_read_late_fee_rules" ON late_fee_rules FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

-- Exec / admin may write
CREATE POLICY "exec_manage_receivable_categories" ON receivable_categories FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE POLICY "exec_manage_receivable_subcategories" ON receivable_subcategories FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE POLICY "exec_manage_late_fee_rules" ON late_fee_rules FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── Seed default categories for UTAMACS ──────────────────────────────────────

INSERT INTO receivable_categories (society_id, name, description, hsn_sac_code, display_order)
SELECT
  id,
  unnest(ARRAY['Maintenance Fund','Sinking Fund','Utility Charges','Special Levy','One-Time Charges']),
  unnest(ARRAY[
    'Monthly maintenance charges for common area upkeep',
    'Long-term capital reserve fund',
    'Electricity, water, and other utility charges',
    'Special purpose levy approved by general body',
    'One-time charges like move-in fee, NOC, etc.'
  ]),
  unnest(ARRAY['999741','999741','998319',NULL,NULL]),
  unnest(ARRAY[1,2,3,4,5])
FROM societies
ON CONFLICT (society_id, name) DO NOTHING;

-- Seed default sub-categories under Maintenance Fund
INSERT INTO receivable_subcategories (society_id, category_id, name, calculation_type, amount, frequency, gst_rate, display_order)
SELECT
  rc.society_id,
  rc.id,
  unnest(ARRAY['Monthly Maintenance','Housekeeping Charges','Security Charges','Lift Maintenance']),
  unnest(ARRAY['fixed','fixed','fixed','fixed']),
  unnest(ARRAY[2500, 500, 800, 300]::numeric[]),
  unnest(ARRAY['monthly','monthly','monthly','monthly']),
  unnest(ARRAY[18, 18, 18, 18]::numeric[]),
  unnest(ARRAY[1,2,3,4])
FROM receivable_categories rc
JOIN societies s ON s.id = rc.society_id
WHERE rc.name = 'Maintenance Fund'
ON CONFLICT DO NOTHING;

COMMIT;
