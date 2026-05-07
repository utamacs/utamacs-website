-- ═══════════════════════════════════════════════════════════════
-- 036_visitor_type_gate.sql
-- Gates master table; enrich visitor_logs with visitor_type + gate_id
-- ═══════════════════════════════════════════════════════════════

-- ── Gates master ──────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS gates (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  -- DPDPA: no personal data in this table
  name        text NOT NULL,
  gate_code   text,                     -- short label like "G1", "Main", "North"
  description text,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (society_id, name)
);

ALTER TABLE gates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_gates" ON gates FOR SELECT
  USING (society_id = (
    SELECT society_id FROM profiles WHERE id = auth.uid() LIMIT 1
  ));

CREATE POLICY "exec_manage_gates" ON gates FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = gates.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- Seed default gates
INSERT INTO gates (society_id, name, gate_code, description) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Main Gate',      'MAIN',  'Primary entry/exit gate'),
  ('00000000-0000-0000-0000-000000000001', 'North Gate',     'NORTH', 'North wing entry gate'),
  ('00000000-0000-0000-0000-000000000001', 'South Gate',     'SOUTH', 'South wing entry gate'),
  ('00000000-0000-0000-0000-000000000001', 'Service Gate',   'SVC',   'Service and delivery entry gate')
ON CONFLICT (society_id, name) DO NOTHING;

-- ── Add visitor_type + gate_id to visitor_logs ────────────────────────────────

-- Richer visitor purpose classification (complements the existing entry_type)
ALTER TABLE visitor_logs
  ADD COLUMN IF NOT EXISTS visitor_type text
    CHECK (visitor_type IN (
      'guest', 'relative', 'friend',
      'domestic_help', 'cook', 'driver', 'nurse', 'tutor',
      'plumber', 'electrician', 'carpenter', 'painter', 'pest_control_tech',
      'courier', 'food_delivery', 'grocery_delivery', 'ecommerce_delivery',
      'cab_driver', 'auto_driver',
      'medical', 'emergency',
      'real_estate_agent', 'prospective_buyer', 'prospective_tenant',
      'maintenance_staff', 'security_audit', 'govt_official',
      'other'
    )),
  ADD COLUMN IF NOT EXISTS gate_id uuid REFERENCES gates(id);

-- Backfill visitor_type from existing entry_type where possible
UPDATE visitor_logs SET visitor_type =
  CASE entry_type
    WHEN 'delivery' THEN 'courier'
    WHEN 'service'  THEN 'other'
    WHEN 'vendor'   THEN 'other'
    ELSE 'guest'
  END
WHERE visitor_type IS NULL;

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_visitor_logs_gate     ON visitor_logs(gate_id);
CREATE INDEX IF NOT EXISTS idx_visitor_logs_vtype    ON visitor_logs(visitor_type);
CREATE INDEX IF NOT EXISTS idx_gates_society         ON gates(society_id);
