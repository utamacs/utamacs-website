-- ═══════════════════════════════════════════════════════════════
-- 004_visitors.sql
-- Visitor management: pre-approvals, entry/exit logs, delivery, staff
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE visitor_pre_approvals (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id            uuid NOT NULL REFERENCES societies(id),
  host_unit_id          uuid NOT NULL REFERENCES units(id),
  host_user_id          uuid NOT NULL REFERENCES auth.users(id),
  visitor_name          text NOT NULL,
  visitor_phone_hash    text,
  purpose               text,
  expected_date         date NOT NULL,
  expected_time_from    timestamptz,
  expected_time_to      timestamptz,
  qr_token              text UNIQUE,
  otp_code_hash         text,
  status                text NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','approved','used','expired','cancelled')),
  created_at            timestamptz NOT NULL DEFAULT now(),
  expires_at            timestamptz NOT NULL
);

CREATE TABLE visitor_logs (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id),
  pre_approval_id     uuid REFERENCES visitor_pre_approvals(id),
  visitor_name        text NOT NULL,
  visitor_phone_hash  text,
  host_unit_id        uuid REFERENCES units(id),
  entry_type          text NOT NULL DEFAULT 'walk_in'
                      CHECK (entry_type IN ('pre_approved','walk_in','delivery','service','vendor')),
  entry_time          timestamptz NOT NULL DEFAULT now(),
  exit_time           timestamptz,
  vehicle_number      text,
  logged_by           uuid NOT NULL REFERENCES auth.users(id),
  photo_storage_key   text,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE delivery_logs (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id),
  unit_id             uuid NOT NULL REFERENCES units(id),
  courier_company     text,
  tracking_number     text,
  received_at         timestamptz NOT NULL DEFAULT now(),
  collected_at        timestamptz,
  collected_by        uuid REFERENCES auth.users(id),
  logged_by           uuid NOT NULL REFERENCES auth.users(id),
  photo_storage_key   text,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE staff_members (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id),
  name                text NOT NULL,
  role                text NOT NULL
                      CHECK (role IN ('security_guard','housekeeper','gardener',
                                      'lift_operator','admin_staff','maintenance')),
  phone               text,
  id_proof_type       text,
  id_proof_encrypted  text,
  joining_date        date,
  is_active           boolean NOT NULL DEFAULT true,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE staff_attendance (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid NOT NULL REFERENCES societies(id),
  staff_id    uuid NOT NULL REFERENCES staff_members(id),
  date        date NOT NULL,
  check_in    timestamptz,
  check_out   timestamptz,
  logged_by   uuid NOT NULL REFERENCES auth.users(id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE(staff_id, date)
);

-- Auto-expire pre-approvals
CREATE OR REPLACE FUNCTION expire_visitor_pre_approvals()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE visitor_pre_approvals
  SET status = 'expired'
  WHERE status IN ('pending','approved')
    AND expires_at < now();
END;
$$;

-- Indexes
CREATE INDEX idx_pre_approvals_host ON visitor_pre_approvals(host_user_id);
CREATE INDEX idx_pre_approvals_status ON visitor_pre_approvals(status);
CREATE INDEX idx_visitor_logs_society ON visitor_logs(society_id);
CREATE INDEX idx_visitor_logs_host_unit ON visitor_logs(host_unit_id);
CREATE INDEX idx_visitor_logs_entry ON visitor_logs(entry_time DESC);
CREATE INDEX idx_delivery_logs_unit ON delivery_logs(unit_id);
CREATE INDEX idx_staff_attendance_staff ON staff_attendance(staff_id, date);
