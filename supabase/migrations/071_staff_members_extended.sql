-- 071_staff_members_extended.sql
-- Extend staff_members with department, agency link, QR token, language preference,
-- portal role, designation, and shift assignment.

BEGIN;

-- Department enum for all staff types
ALTER TABLE staff_members
  ADD COLUMN IF NOT EXISTS department   text
    CHECK (department IN ('security','housekeeping','gardening','maintenance','admin','multi')),
  ADD COLUMN IF NOT EXISTS designation  text CHECK (length(designation) <= 100),
  ADD COLUMN IF NOT EXISTS agency_id    uuid REFERENCES staff_agencies(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS employment_type text NOT NULL DEFAULT 'agency'
    CHECK (employment_type IN ('direct','agency')),
  ADD COLUMN IF NOT EXISTS qr_token     uuid NOT NULL DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS language_preference text NOT NULL DEFAULT 'en'
    CHECK (language_preference IN ('en','hi','te')),
  ADD COLUMN IF NOT EXISTS whatsapp_number text,   -- personal data: for WhatsApp notifications
  ADD COLUMN IF NOT EXISTS emergency_contact text, -- personal data: next-of-kin name + phone
  ADD COLUMN IF NOT EXISTS date_of_birth date,     -- personal data: for CLRA Form XIII
  ADD COLUMN IF NOT EXISTS portal_role  text
    CHECK (portal_role IN ('staff','supervisor','afm'));

COMMENT ON COLUMN staff_members.whatsapp_number    IS 'personal data: staff WhatsApp for task/attendance notifications';
COMMENT ON COLUMN staff_members.emergency_contact  IS 'personal data: next-of-kin contact (CLRA requirement)';
COMMENT ON COLUMN staff_members.date_of_birth      IS 'personal data: date of birth required for CLRA Form XIII muster roll';

-- QR token must be globally unique (used in /staff/[token] URL)
CREATE UNIQUE INDEX IF NOT EXISTS idx_staff_members_qr_token ON staff_members(qr_token);
CREATE INDEX IF NOT EXISTS idx_staff_members_agency    ON staff_members(agency_id) WHERE agency_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_staff_members_dept      ON staff_members(society_id, department);
CREATE INDEX IF NOT EXISTS idx_staff_members_portal_role ON staff_members(portal_role) WHERE portal_role IS NOT NULL;

-- Back-fill department from existing role values
UPDATE staff_members SET department =
  CASE role
    WHEN 'security_guard'  THEN 'security'
    WHEN 'housekeeper'     THEN 'housekeeping'
    WHEN 'gardener'        THEN 'gardening'
    WHEN 'maintenance'     THEN 'maintenance'
    WHEN 'admin_staff'     THEN 'admin'
    ELSE 'multi'
  END
WHERE department IS NULL;

-- ── RLS: staff portal roles can read their own record ────────────────────────

DROP POLICY IF EXISTS "staff_self_read" ON staff_members;
CREATE POLICY "staff_self_read" ON staff_members FOR SELECT
  USING (user_id = auth.uid());

-- ── Rules: portal staff count threshold alert ─────────────────────────────────
INSERT INTO rules (society_id, rule_code, description, value_type, current_value, is_locked)
SELECT
  id,
  'STAFF_LATE_CHECKIN_ALERT_MINS',
  'Minutes after shift start before a late check-in alert is triggered',
  'integer',
  '30',
  false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;

COMMIT;
