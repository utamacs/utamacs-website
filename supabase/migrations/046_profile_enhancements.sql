-- ═══════════════════════════════════════════════════════════════
-- 046_profile_enhancements.sql
-- Profiles: avatar, emergency contact, preferred language, vehicle
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS avatar_key           text,           -- Supabase Storage key in avatars bucket
  ADD COLUMN IF NOT EXISTS emergency_name       text CHECK (length(emergency_name) <= 100),  -- personal data
  ADD COLUMN IF NOT EXISTS emergency_phone      text CHECK (length(emergency_phone) <= 15),  -- personal data
  ADD COLUMN IF NOT EXISTS emergency_relation   text CHECK (length(emergency_relation) <= 50),
  ADD COLUMN IF NOT EXISTS preferred_language   text NOT NULL DEFAULT 'en'
                                                CHECK (preferred_language IN ('en','te','hi')),
  ADD COLUMN IF NOT EXISTS vehicle_reg_no       text CHECK (length(vehicle_reg_no) <= 20),   -- personal data
  ADD COLUMN IF NOT EXISTS vehicle_make         text CHECK (length(vehicle_make) <= 50),
  ADD COLUMN IF NOT EXISTS vehicle_model        text CHECK (length(vehicle_model) <= 50),
  ADD COLUMN IF NOT EXISTS bio                  text CHECK (length(bio) <= 500),
  ADD COLUMN IF NOT EXISTS whatsapp_number      text CHECK (length(whatsapp_number) <= 15),  -- personal data
  ADD COLUMN IF NOT EXISTS updated_at           timestamptz NOT NULL DEFAULT now();

COMMENT ON COLUMN profiles.avatar_key         IS 'Supabase Storage key in avatars bucket';
COMMENT ON COLUMN profiles.emergency_name     IS 'DPDPA personal data: emergency contact name';
COMMENT ON COLUMN profiles.emergency_phone    IS 'DPDPA personal data: emergency contact phone';
COMMENT ON COLUMN profiles.vehicle_reg_no     IS 'DPDPA personal data: personal vehicle registration';
COMMENT ON COLUMN profiles.whatsapp_number    IS 'DPDPA personal data: WhatsApp contact number';

-- Trigger to keep updated_at fresh
CREATE OR REPLACE FUNCTION touch_profile_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_profile_updated_at
BEFORE UPDATE ON profiles
FOR EACH ROW EXECUTE FUNCTION touch_profile_updated_at();

-- Members can read their own full profile; see limited info on others in same society
CREATE POLICY "member_read_own_profile" ON profiles FOR SELECT
  USING (
    id = auth.uid()
    OR society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
  );

-- Members can update only their own profile
CREATE POLICY "member_update_own_profile" ON profiles FOR UPDATE
  USING (id = auth.uid());
