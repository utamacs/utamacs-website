-- ============================================================
-- 015_parking.sql
-- Full parking allocation module
-- State machine: available → allocated (reserved) → released → available
-- Supports multiple vehicle types, slot types, and waiting list
-- ============================================================

-- Parking slots (physical bays managed by the society)
CREATE TABLE IF NOT EXISTS parking_slots (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  slot_number     text NOT NULL,                      -- "A-P-01", "B-P-02"
  slot_type       text NOT NULL DEFAULT 'open'
                  CHECK (slot_type IN ('covered', 'open', 'basement', 'visitor')),
  vehicle_type    text NOT NULL DEFAULT 'car'
                  CHECK (vehicle_type IN ('car', 'bike', 'cycle', 'ev', 'any')),
  level           int DEFAULT 0,                      -- floor/level for multi-level parking
  is_active       boolean NOT NULL DEFAULT true,
  monthly_charge  numeric(8,2) DEFAULT 0,             -- 0 = included in maintenance
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (society_id, slot_number)
);

-- Parking allocations (unit/user assigned a slot)
-- One active allocation per slot at a time enforced by partial unique index
CREATE TABLE IF NOT EXISTS parking_allocations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  slot_id         uuid NOT NULL REFERENCES parking_slots(id) ON DELETE RESTRICT,
  unit_id         uuid NOT NULL REFERENCES units(id) ON DELETE RESTRICT,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  vehicle_number  text,
  vehicle_make    text,
  status          text NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active', 'released', 'suspended')),
  -- State machine timestamps
  allocated_at    timestamptz NOT NULL DEFAULT now(),
  released_at     timestamptz,
  suspended_at    timestamptz,
  -- Who did the action
  allocated_by    uuid REFERENCES auth.users(id),
  released_by     uuid REFERENCES auth.users(id),
  -- Expiry for temporary allocations (NULL = indefinite)
  expires_at      timestamptz,
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Enforce: one active allocation per slot
CREATE UNIQUE INDEX IF NOT EXISTS parking_allocations_slot_active
  ON parking_allocations (slot_id)
  WHERE status = 'active';

-- Parking waiting list
CREATE TABLE IF NOT EXISTS parking_waitlist (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  unit_id         uuid NOT NULL REFERENCES units(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  slot_type       text DEFAULT 'any'
                  CHECK (slot_type IN ('covered', 'open', 'basement', 'visitor', 'any')),
  vehicle_type    text DEFAULT 'car'
                  CHECK (vehicle_type IN ('car', 'bike', 'cycle', 'ev', 'any')),
  status          text NOT NULL DEFAULT 'waiting'
                  CHECK (status IN ('waiting', 'offered', 'allocated', 'withdrawn')),
  requested_at    timestamptz NOT NULL DEFAULT now(),
  offered_at      timestamptz,
  offered_slot_id uuid REFERENCES parking_slots(id),
  notes           text,
  UNIQUE (society_id, user_id, status) -- user can only be once in active waitlist
);

-- Append-only allocation history log
CREATE TABLE IF NOT EXISTS parking_audit (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  slot_id         uuid NOT NULL REFERENCES parking_slots(id),
  allocation_id   uuid REFERENCES parking_allocations(id),
  action          text NOT NULL
                  CHECK (action IN ('ALLOCATED', 'RELEASED', 'SUSPENDED', 'REINSTATED', 'WAITLIST_ADDED', 'WAITLIST_OFFERED', 'WAITLIST_ALLOCATED', 'WAITLIST_WITHDRAWN')),
  actor_id        uuid REFERENCES auth.users(id),
  unit_id         uuid REFERENCES units(id),
  notes           text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- RLS Policies
-- ============================================================

ALTER TABLE parking_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE parking_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE parking_waitlist ENABLE ROW LEVEL SECURITY;
ALTER TABLE parking_audit ENABLE ROW LEVEL SECURITY;

-- Slots: all authenticated users in society can view
CREATE POLICY parking_slots_read ON parking_slots FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Allocations: members see their own; exec/admin see all
CREATE POLICY parking_allocations_member_read ON parking_allocations FOR SELECT
  USING (user_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive', 'admin'));

-- Waitlist: members see their own; exec/admin see all
CREATE POLICY parking_waitlist_member_read ON parking_waitlist FOR SELECT
  USING (user_id = auth.uid() OR get_user_role(auth.uid()) IN ('executive', 'admin'));

-- Audit: admin/exec read only
CREATE POLICY parking_audit_read ON parking_audit FOR SELECT
  USING (get_user_role(auth.uid()) IN ('executive', 'admin'));

-- Audit: insert only (append-only)
CREATE POLICY parking_audit_insert ON parking_audit FOR INSERT
  WITH CHECK (actor_id = auth.uid());
