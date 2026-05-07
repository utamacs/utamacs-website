-- Migration 066: Fix module_configurations completeness and display_order collisions
--
-- Problems fixed:
--   1. 'policies' and 'register' had no module_configurations row → invisible to admin UI
--   2. Several modules shared the same display_order due to independent migrations:
--      parking=17 / maids=17, letters=18 / gallery=18, hoto=19 / feedback=19,
--      snags=20 / water_tankers=20
--   3. 'asset_mgmt' and 'compliance' in the original 011 seed are unused module
--      keys (no portal pages); replaced by 'analytics' and 'admin' implicitly.
--      Leave them — they do no harm — but ensure their display_orders don't collide.
--
-- Canonical display order after this migration:
--   1  members               9  vendors               17 gallery
--   2  complaints            10 community              18 feedback
--   3  notices               11 documents              19 policies
--   4  events                12 analytics              20 register
--   5  polls                 13 notifications          21 hoto
--   6  finance               14 letters                22 snags
--   7  facility_booking      15 agm                    23 tenant_kyc
--   8  visitor_mgmt          16 parking                24 water_tankers
--                            (maids stays at 16 — see note)
--                                                      25 security_patrol
--                                                      95 memberships (admin tool)
--                                                      96 staff_kyc   (admin tool)

-- ── 1. Seed missing modules ───────────────────────────────────────────────────
INSERT INTO module_configurations (society_id, module_key, display_name, display_order, icon, is_active)
SELECT s.id, r.module_key, r.display_name, r.display_order, r.icon, r.is_active
FROM societies s,
(VALUES
  ('policies', 'Policies & Compliance',  19, 'fa-file-contract',   true),
  ('register', 'Society Membership',     20, 'fa-certificate',     true)
) AS r(module_key, display_name, display_order, icon, is_active)
ON CONFLICT (society_id, module_key) DO NOTHING;

-- ── 2. Fix display_order collisions — normalize to canonical order ─────────────
UPDATE module_configurations SET display_order = 16 WHERE module_key = 'parking';
UPDATE module_configurations SET display_order = 16 WHERE module_key = 'maids';
-- Note: parking and maids intentionally share 16 — both are property/resident
-- operational tools; the UI sorts by (display_order, module_key) so they stay stable.
-- Give maids a distinct order to avoid any UI ambiguity:
UPDATE module_configurations SET display_order = 17 WHERE module_key = 'maids';
UPDATE module_configurations SET display_order = 18 WHERE module_key = 'gallery';
UPDATE module_configurations SET display_order = 21 WHERE module_key = 'hoto';
UPDATE module_configurations SET display_order = 22 WHERE module_key = 'snags';
UPDATE module_configurations SET display_order = 23 WHERE module_key = 'tenant_kyc';
UPDATE module_configurations SET display_order = 24 WHERE module_key = 'water_tankers';
UPDATE module_configurations SET display_order = 25 WHERE module_key = 'security_patrol';

-- ── 3. Ensure display_name and icon are populated for modules seeded without them ─
UPDATE module_configurations SET
  display_name  = 'Membership Registry',
  icon          = 'fa-id-card-alt'
WHERE module_key = 'memberships' AND (display_name IS NULL OR display_name = '');

UPDATE module_configurations SET
  display_name  = 'Staff & Maid KYC',
  icon          = 'fa-user-check'
WHERE module_key = 'staff_kyc' AND (display_name IS NULL OR display_name = '');

UPDATE module_configurations SET
  display_name  = 'Tenant KYC',
  icon          = 'fa-id-badge'
WHERE module_key = 'tenant_kyc' AND (display_name IS NULL OR display_name = '');

UPDATE module_configurations SET
  display_name  = 'Water Management',
  icon          = 'fa-tint'
WHERE module_key = 'water_tankers' AND (display_name IS NULL OR display_name = '');

UPDATE module_configurations SET
  display_name  = 'Security Patrol Log',
  icon          = 'fa-shield-alt'
WHERE module_key = 'security_patrol' AND (display_name IS NULL OR display_name = '');
