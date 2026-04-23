-- ═══════════════════════════════════════════════════════════════
-- 001_foundation.sql
-- Societies, units, profiles, user_roles, audit_logs
-- ═══════════════════════════════════════════════════════════════

-- Multi-tenant root — one row per residential society
CREATE TABLE societies (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,
  registration_no text UNIQUE,
  address         text,
  city            text,
  state           text DEFAULT 'Telangana',
  pincode         text,
  total_units     int,
  total_area_acres numeric(5,2),
  gstin           text,
  pan             text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Seed UTA MACS society
INSERT INTO societies (id, name, registration_no, address, city, state, pincode, total_units, total_area_acres)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'Urban Trilla Apartment Owners MACS Ltd',
  'TSMACS-2015-001',
  'Survey No 425/2/1, Kondakal Village, Rajendranagar Mandal',
  'Hyderabad',
  'Telangana',
  '500086',
  136,
  2.9
);

-- Residential units
CREATE TABLE units (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  unit_number     text NOT NULL,
  block           text,
  floor           int,
  area_sqft       numeric(8,2),
  unit_type       text,
  is_vacant       boolean NOT NULL DEFAULT false,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE(society_id, unit_number)
);

-- Extended member profile (auth.users is managed by Supabase Auth)
CREATE TABLE profiles (
  id                uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  society_id        uuid NOT NULL REFERENCES societies(id),
  full_name         text NOT NULL,
  unit_id           uuid REFERENCES units(id),
  phone_encrypted   text,
  residency_type    text NOT NULL DEFAULT 'owner' CHECK (residency_type IN ('owner','tenant')),
  family_members    jsonb DEFAULT '[]'::jsonb,
  move_in_date      date,
  move_out_date     date,
  avatar_storage_key text,
  is_active         boolean NOT NULL DEFAULT true,
  consent_version   int NOT NULL DEFAULT 1,
  consent_at        timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);

-- Role assignments (one role per user per society)
CREATE TABLE user_roles (
  user_id     uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  role        text NOT NULL DEFAULT 'member'
              CHECK (role IN ('member','executive','admin','security_guard','vendor')),
  society_id  uuid NOT NULL REFERENCES societies(id),
  granted_by  uuid REFERENCES auth.users(id),
  granted_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz
);

-- Append-only audit trail (NO UPDATE / DELETE policies)
CREATE TABLE audit_logs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid REFERENCES societies(id),
  user_id         uuid,
  action          text NOT NULL,
  resource_type   text,
  resource_id     text,
  old_values      jsonb,
  new_values      jsonb,
  ip_hash         text,
  user_agent_hash text,
  session_id      text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Trigger: auto-update profiles.updated_at
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Indexes
CREATE INDEX idx_profiles_society ON profiles(society_id);
CREATE INDEX idx_profiles_unit ON profiles(unit_id);
CREATE INDEX idx_user_roles_society ON user_roles(society_id);
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at DESC);
CREATE INDEX idx_units_society ON units(society_id);
