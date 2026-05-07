-- Migration 055: AMC / Planned Maintenance Contract tracker
-- Tracks annual maintenance contracts for lifts, generators, pumps, CCTV etc.
-- Cron sends 30-day renewal reminders before end_date.

CREATE TABLE amc_contracts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  vendor_id       uuid REFERENCES vendors(id) ON DELETE SET NULL,
  equipment_name  text NOT NULL CHECK (length(equipment_name) BETWEEN 2 AND 200),
  equipment_type  text NOT NULL DEFAULT 'other'
                  CHECK (equipment_type IN ('lift','generator','pump','cctv','fire_system','hvac','intercom','solar','other')),
  scope           text,
  start_date      date NOT NULL,
  end_date        date NOT NULL,
  amount          numeric(10,2),
  payment_frequency text NOT NULL DEFAULT 'annual'
                  CHECK (payment_frequency IN ('monthly','quarterly','half_yearly','annual','one_time')),
  is_active       boolean NOT NULL DEFAULT true,
  notes           text,
  created_by      uuid NOT NULL REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT amc_date_order CHECK (end_date > start_date)
);

CREATE TRIGGER trg_amc_contracts_updated_at
  BEFORE UPDATE ON amc_contracts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Service completion log: tracks each preventive maintenance visit
CREATE TABLE amc_service_logs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  amc_id          uuid NOT NULL REFERENCES amc_contracts(id) ON DELETE CASCADE,
  service_date    date NOT NULL,
  engineer_name   text CHECK (length(engineer_name) <= 200),
  remarks         text CHECK (length(remarks) <= 2000),
  expense_id      uuid REFERENCES expenses(id) ON DELETE SET NULL,
  created_by      uuid NOT NULL REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_amc_contracts_society ON amc_contracts(society_id, is_active);
CREATE INDEX idx_amc_contracts_end_date ON amc_contracts(end_date) WHERE is_active = true;
CREATE INDEX idx_amc_service_logs_amc ON amc_service_logs(amc_id, service_date DESC);

-- RLS
ALTER TABLE amc_contracts  ENABLE ROW LEVEL SECURITY;
ALTER TABLE amc_service_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "exec_manage_amc_contracts" ON amc_contracts FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE POLICY "exec_manage_amc_service_logs" ON amc_service_logs FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

COMMENT ON TABLE amc_contracts    IS 'Annual / periodic maintenance contracts for society equipment';
COMMENT ON TABLE amc_service_logs IS 'Individual service visits against each AMC contract';
