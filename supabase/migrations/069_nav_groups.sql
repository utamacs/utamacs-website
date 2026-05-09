-- Migration 069: DB-driven nav groups and minimum nav role per module
--
-- Adds two columns to module_configurations:
--   nav_group    — which sidebar section this module belongs to
--   min_nav_role — minimum resolved nav role required to see this item
--                  ('member' | 'executive' | 'admin')
--                  guard and vendor have their own special nav branches; these
--                  columns apply only to the member→executive→admin hierarchy.
--
-- PortalLayout reads these values to build the sidebar without hardcoded
-- per-module if/else chains.  Society admins can reorganise the nav by
-- updating nav_group without a code deploy.

ALTER TABLE module_configurations
  ADD COLUMN IF NOT EXISTS nav_group    text NOT NULL DEFAULT 'Community',
  ADD COLUMN IF NOT EXISTS min_nav_role text NOT NULL DEFAULT 'member';

-- ── Community group (all authenticated members) ───────────────────────────────

UPDATE module_configurations SET nav_group = 'Community', min_nav_role = 'member'
WHERE module_key IN (
  'members', 'complaints', 'notices', 'events', 'polls',
  'community', 'gallery', 'feedback', 'documents', 'notifications'
);

-- ── Services group (all authenticated members) ────────────────────────────────

UPDATE module_configurations SET nav_group = 'Services', min_nav_role = 'member'
WHERE module_key IN (
  'finance', 'facility_booking', 'visitor_mgmt', 'parking', 'maids', 'water_tankers'
);

-- ── HOTO Platform group (all authenticated members) ──────────────────────────
-- Exec-only sub-links (Vendor Procurement, HOTO Progress, etc.) are injected
-- by PortalLayout at render time and are not stored here.

UPDATE module_configurations SET nav_group = 'HOTO Platform', min_nav_role = 'member'
WHERE module_key IN ('hoto', 'snags', 'vendors');

-- ── Governance group ──────────────────────────────────────────────────────────

UPDATE module_configurations SET nav_group = 'Governance', min_nav_role = 'member'
WHERE module_key IN ('agm', 'policies', 'register');

UPDATE module_configurations SET nav_group = 'Governance', min_nav_role = 'executive'
WHERE module_key IN ('analytics', 'letters', 'tenant_kyc', 'security_patrol');

-- ── Administration group (admin-only) ─────────────────────────────────────────

UPDATE module_configurations SET nav_group = 'Administration', min_nav_role = 'admin'
WHERE module_key IN ('memberships', 'staff_kyc');

-- ── Legacy orphan keys from migration 011 (no portal pages, never shown) ──────
-- Keep nav_group = 'Community' default; min_nav_role = 'member' is already set.
-- They never appear because PortalLayout's FALLBACK_MODULES does not include them.
-- asset_mgmt, compliance — no change needed.
