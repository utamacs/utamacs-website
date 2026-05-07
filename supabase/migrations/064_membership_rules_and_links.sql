-- Migration 064: Membership rules in engine + portal-membership link + quorum fix
--
-- 1. Corrects QUORUM_GENERAL_BODY (20→68 per Byelaw §7.5f: 68 members or 50% of total)
-- 2. Adds membership fee rules (Byelaw §4.1, §4.5, §4.13)
-- 3. Adds staff/maid pass validity rules (Byelaw §13.3)
-- 4. Links memberships ↔ registration_requests bidirectionally
-- 5. Adds MEMBERSHIP_PORTAL_LINK_MODE rule to control auto-approval flow

-- ── Fix existing quorum rule (was incorrectly seeded as 20) ──────────────────
-- Byelaw §7.5f: "quorum shall be 68 members and/or 50% of total registered members"
-- For 136 flats: 50% = 68 = the absolute minimum stated in the byelaw
UPDATE rules
SET current_value = '68'::jsonb,
    default_value  = '68'::jsonb,
    change_reason  = 'Corrected per Byelaw §7.5f: 68 members = 50% of 136 registered flats'
WHERE rule_code = 'QUORUM_GENERAL_BODY';

-- ── New rules: membership fees + quorum percentage + pass validity ────────────
INSERT INTO rules (society_id, rule_category, rule_code, label, description, byelaw_reference,
                   value_type, current_value, default_value, is_locked)
SELECT s.id,
       r.rule_category, r.rule_code, r.label, r.description, r.byelaw_reference,
       r.value_type, r.current_value::jsonb, r.default_value::jsonb, r.is_locked
FROM societies s,
(VALUES
  -- Membership fees (byelaw-locked)
  ('PARAMETER','MEMBERSHIP_ADMISSION_FEE',
   'Admission/Entrance Fee (₹)',
   'Non-refundable admission fee paid by every new member',
   '§4.1','INTEGER','1000','1000', true),

  ('PARAMETER','MEMBERSHIP_SHARE_CAPITAL',
   'Share Capital per member (₹)',
   'Face value of one share; every owner must hold at least one share',
   '§4.1 §4.5','INTEGER','1000','1000', true),

  ('PARAMETER','MEMBERSHIP_BYELAW_COPY_FEE',
   'Byelaw copy fee (₹)',
   'Optional fee for printed byelaw copy',
   '§4.1','INTEGER','250','250', true),

  ('PARAMETER','MEMBERSHIP_DUPLICATE_CERT_FEE',
   'Duplicate share certificate fee (₹)',
   'Fee charged when share certificate is lost/damaged',
   '§4.13','INTEGER','200','200', true),

  -- AGM quorum (byelaw-locked)
  ('PARAMETER','AGM_QUORUM_PERCENTAGE',
   'AGM quorum as % of registered members',
   'Per Byelaw §7.5f: 50% of total registered members (equivalent to 68 for 136 flats)',
   '§7.5f','INTEGER','50','50', true),

  ('PARAMETER','AGM_QUORUM_ABSOLUTE_MIN',
   'AGM quorum absolute minimum (members)',
   'Per Byelaw §7.5f: minimum 68 members must attend; used when registered < 136',
   '§7.5f','INTEGER','68','68', true),

  -- Board quorum
  ('PARAMETER','BOARD_QUORUM_FORMULA',
   'Board of Directors quorum formula',
   'More than half of elected directors; Board has 12 directors so quorum = 7',
   '§7.16a','STRING','"SIMPLE_MAJORITY"','"SIMPLE_MAJORITY"', true),

  -- Staff / Maid security pass (operational, unlocked)
  ('PARAMETER','STAFF_PASS_VALIDITY_DAYS',
   'Society staff security pass validity (days)',
   'Days before a society staff security pass expires and must be renewed',
   null,'INTEGER','365','365', false),

  ('PARAMETER','MAID_PASS_VALIDITY_DAYS',
   'Domestic help security pass validity (days)',
   'Days before a maid/domestic help security pass expires and must be renewed',
   null,'INTEGER','365','365', false),

  ('PARAMETER','STAFF_PASS_EXPIRY_WARNING_DAYS',
   'Days before pass expiry to show warning',
   'How many days before expiry the system flags passes as "expiring soon"',
   null,'INTEGER','30','30', false),

  -- Portal-membership linkage mode (operational, unlocked)
  ('PARAMETER','MEMBERSHIP_PORTAL_LINK_MODE',
   'Portal access on membership approval',
   'Controls how portal registration is handled when byelaw membership is approved. "auto_approve" = automatically approve the linked portal registration; "notify" = send notification; "manual" = exec must approve separately',
   null,'STRING','"auto_approve"','"auto_approve"', false),

  -- Membership vote suspension (already exists as VOTE_SUSPENSION_DAYS = 90, adding alias)
  ('PARAMETER','MEMBERSHIP_VOTING_DISQUALIFY_DAYS',
   'Days of dues arrears before voting rights suspended',
   'Per Byelaw §4.6, §5.8: member cannot vote if dues outstanding > this many days',
   '§4.6 §5.8','INTEGER','90','90', true)

) AS r(rule_category, rule_code, label, description, byelaw_reference,
       value_type, current_value, default_value, is_locked)
ON CONFLICT (society_id, rule_code) DO NOTHING;

-- ── Link memberships ↔ registration_requests ─────────────────────────────────
-- A portal registration can be linked to a byelaw membership application
-- When byelaw membership is approved → portal registration can be auto-approved

ALTER TABLE memberships
  ADD COLUMN IF NOT EXISTS linked_registration_id uuid
    REFERENCES registration_requests(id) ON DELETE SET NULL;

ALTER TABLE registration_requests
  ADD COLUMN IF NOT EXISTS membership_id uuid
    REFERENCES memberships(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_memberships_linked_registration
  ON memberships(linked_registration_id) WHERE linked_registration_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_registration_requests_membership
  ON registration_requests(membership_id) WHERE membership_id IS NOT NULL;

COMMENT ON COLUMN memberships.linked_registration_id IS
  'FK to registration_requests — when membership is approved, linked portal registration can be auto-approved';

COMMENT ON COLUMN registration_requests.membership_id IS
  'FK to memberships — links the portal access request to the formal byelaw membership';
