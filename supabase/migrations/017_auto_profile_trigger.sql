-- ═══════════════════════════════════════════════════════════════
-- 017_auto_profile_trigger.sql
-- Automatically create a skeleton profile + member role whenever
-- a new user is created in auth.users (via invite or direct signup).
--
-- The trigger reads optional metadata fields set at invite time:
--   full_name   → raw_user_meta_data->>'full_name'
--   society_id  → raw_user_meta_data->>'society_id'  (defaults to fixed society)
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_society_id uuid;
  v_full_name  text;
BEGIN
  -- Resolve society_id: prefer metadata, fall back to the single seeded society
  v_society_id := COALESCE(
    (NEW.raw_user_meta_data->>'society_id')::uuid,
    '00000000-0000-0000-0000-000000000001'::uuid
  );

  -- Resolve full_name: prefer metadata, fall back to email local-part
  v_full_name := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
    SPLIT_PART(NEW.email, '@', 1)
  );

  -- Create skeleton profile (unit_id left NULL — admin fills later)
  INSERT INTO public.profiles (
    id, society_id, full_name, residency_type,
    is_active, consent_version, consent_at, created_at, updated_at
  )
  VALUES (
    NEW.id, v_society_id, v_full_name, 'owner',
    true, 0, NULL, now(), now()
  )
  ON CONFLICT (id) DO NOTHING;

  -- Grant default 'member' role (admin can elevate later)
  INSERT INTO public.user_roles (user_id, role, society_id, granted_at)
  VALUES (NEW.id, 'member', v_society_id, now())
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Fire after every new auth user (invite accepted, direct signup, admin-create)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();
