-- ═══════════════════════════════════════════════════════════════
-- 040_parking_enhancements.sql
-- Parking: vehicle info on slots, RC document upload, slot transfers
-- ═══════════════════════════════════════════════════════════════

-- ── Vehicle metadata + RC on parking_slots ────────────────────────────────────

ALTER TABLE parking_slots
  ADD COLUMN IF NOT EXISTS block          text,           -- wing/block adjacent to slot
  ADD COLUMN IF NOT EXISTS level_label    text,           -- human label: "Basement 1", "Ground Floor"
  ADD COLUMN IF NOT EXISTS vehicle_make   text CHECK (length(vehicle_make)  <= 50),
  ADD COLUMN IF NOT EXISTS vehicle_model  text CHECK (length(vehicle_model) <= 50),
  ADD COLUMN IF NOT EXISTS vehicle_colour text CHECK (length(vehicle_colour) <= 30),
  ADD COLUMN IF NOT EXISTS vehicle_reg_no text CHECK (length(vehicle_reg_no) <= 20),
  ADD COLUMN IF NOT EXISTS rc_doc_key     text;           -- Supabase Storage key in parking-docs bucket

COMMENT ON COLUMN parking_slots.rc_doc_key     IS 'Supabase Storage key in parking-docs bucket — personal data: RC document';
COMMENT ON COLUMN parking_slots.vehicle_reg_no IS 'DPDPA personal data: vehicle registration number';

-- ── Slot transfer requests ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS parking_slot_transfers (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  slot_id       uuid NOT NULL REFERENCES parking_slots(id) ON DELETE CASCADE,
  from_unit_id  uuid REFERENCES units(id) ON DELETE SET NULL,
  to_unit_id    uuid REFERENCES units(id) ON DELETE SET NULL,
  reason        text CHECK (length(reason) <= 500),
  status        text NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'approved', 'rejected')),
  requested_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_by   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at   timestamptz,
  rejection_note text CHECK (length(rejection_note) <= 300),
  created_at    timestamptz NOT NULL DEFAULT now()
);

COMMENT ON COLUMN parking_slot_transfers.from_unit_id IS 'DPDPA personal data: current occupant unit';
COMMENT ON COLUMN parking_slot_transfers.to_unit_id   IS 'DPDPA personal data: requested occupant unit';

ALTER TABLE parking_slot_transfers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_own_transfers" ON parking_slot_transfers FOR SELECT
  USING (
    requested_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = parking_slot_transfers.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

CREATE POLICY "member_request_transfer" ON parking_slot_transfers FOR INSERT
  WITH CHECK (
    requested_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND society_id = parking_slot_transfers.society_id
    )
  );

CREATE POLICY "exec_manage_transfers" ON parking_slot_transfers FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = parking_slot_transfers.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_parking_transfers_society  ON parking_slot_transfers(society_id, status);
CREATE INDEX IF NOT EXISTS idx_parking_transfers_requester ON parking_slot_transfers(requested_by);
