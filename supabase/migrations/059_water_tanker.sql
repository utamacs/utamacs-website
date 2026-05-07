-- Migration 059: Water / Tanker Management module

CREATE TABLE IF NOT EXISTS water_tankers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  delivery_date   date NOT NULL,
  supplier_name   text NOT NULL CHECK (length(supplier_name) <= 200),
  tanker_capacity_kl numeric(6,2) NOT NULL CHECK (tanker_capacity_kl > 0),
  tanker_count    int NOT NULL DEFAULT 1 CHECK (tanker_count > 0),
  total_kl        numeric(8,2) GENERATED ALWAYS AS (tanker_capacity_kl * tanker_count) STORED,
  cost_per_kl     numeric(10,2),
  total_cost      numeric(10,2),
  payment_mode    text CHECK (payment_mode IN ('cash','upi','bank_transfer','credit','other')),
  invoice_number  text CHECK (length(invoice_number) <= 100),
  notes           text CHECK (length(notes) <= 1000),
  created_by      uuid REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now()
  -- personal data: supplier_name for vendor accountability only
);

CREATE INDEX IF NOT EXISTS idx_water_tankers_society_date
  ON water_tankers(society_id, delivery_date DESC);

ALTER TABLE water_tankers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "society_read_water_tankers" ON water_tankers FOR SELECT
  USING (society_id IN (
    SELECT p.society_id FROM profiles p WHERE p.id = auth.uid()
  ));

CREATE POLICY "exec_manage_water_tankers" ON water_tankers FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles p
    WHERE p.id = auth.uid()
      AND (p.portal_role IN ('executive','secretary','president') OR p.is_admin)
  ));

-- Monthly usage summary view
CREATE OR REPLACE VIEW water_monthly_summary AS
SELECT
  society_id,
  date_trunc('month', delivery_date)::date AS month,
  COUNT(*)                                  AS delivery_count,
  SUM(tanker_count)                         AS total_tankers,
  SUM(total_kl)                             AS total_kl,
  SUM(total_cost)                           AS total_cost
FROM water_tankers
GROUP BY society_id, date_trunc('month', delivery_date);

COMMENT ON TABLE water_tankers IS 'Water tanker delivery log for the society';

-- Register module
INSERT INTO module_configurations (society_id, module_key, display_name, display_order, icon, is_active)
SELECT id, 'water_tankers', 'Water Management', 20, 'fa-tint', true
FROM societies
ON CONFLICT (society_id, module_key) DO NOTHING;
