-- Migration 021: Fix committee member names to match UTA MACS letterhead PDF exactly
-- Corrects names and designations seeded incorrectly in migration 020

DO $$
DECLARE
  v_template_id uuid;
BEGIN
  SELECT lt.id INTO v_template_id
  FROM letterhead_templates lt
  WHERE lt.society_id = '00000000-0000-0000-0000-000000000001'
    AND lt.is_default = true
  LIMIT 1;

  IF v_template_id IS NULL THEN
    RAISE NOTICE 'Default template not found; skipping committee name fix.';
    RETURN;
  END IF;

  UPDATE letterhead_committee_members
  SET name = 'Mr. K Bal Reddy', designation = 'President'
  WHERE template_id = v_template_id AND display_order = 1;

  UPDATE letterhead_committee_members
  SET name = 'Mr. Prashant Panikar', designation = 'Secretary'
  WHERE template_id = v_template_id AND display_order = 2;

  UPDATE letterhead_committee_members
  SET name = 'Mr. V Suresh Kumar', designation = 'Treasurer'
  WHERE template_id = v_template_id AND display_order = 3;
END $$;
