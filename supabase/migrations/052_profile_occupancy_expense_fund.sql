-- Migration 052: unit_occupancy + emergency_contact on profiles; fund_type on expenses
-- Adds occupancy status tracking for units and emergency contact for DPDPA-compliant data collection.
-- Adds fund_type to expenses so each spend is attributed to the correct society fund.

-- ── profiles: unit occupancy and emergency contact ────────────────────────────

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS unit_occupancy text
    CHECK (unit_occupancy IN ('owner_occupied', 'rented', 'vacant'))
    DEFAULT 'owner_occupied'; -- personal data: occupancy status for society management

COMMENT ON COLUMN profiles.unit_occupancy IS 'personal data: occupancy status — owner_occupied | rented | vacant';

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS emergency_contact jsonb DEFAULT NULL;
-- Stores: { name: text, phone: text (encrypted at app layer), relationship: text }

COMMENT ON COLUMN profiles.emergency_contact IS 'personal data: emergency contact details — stored encrypted at application layer; display name + relationship only in UI';

-- ── expenses: fund type ───────────────────────────────────────────────────────

ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS fund_type text
    CHECK (fund_type IN ('maintenance', 'sinking', 'corpus', 'special', 'other'))
    DEFAULT 'maintenance';

COMMENT ON COLUMN expenses.fund_type IS 'Which society fund this expense is drawn from: maintenance (monthly corpus), sinking (long-term capital), corpus (initial deposit), special (one-time levy), other';

-- Index for fund-wise reporting
CREATE INDEX IF NOT EXISTS idx_expenses_fund_type ON expenses(society_id, fund_type);
