-- Migration 092: Register all admin-tool pages as module_configurations rows
--
-- Before this migration, the Administration sidebar links for Audit Logs, Rules
-- Engine, RBAC, Society Profile, Holiday Calendar, etc. were hardcoded directly
-- in PortalLayout.astro (bypassing the DB-driven nav system).
--
-- This migration registers each admin tool as a proper module_configurations row
-- with nav_group = 'Administration' and min_nav_role set to match each page's
-- actual access guard.  PortalLayout step 4b (the hardcoded unshift block) is
-- removed in the same commit; the DB-driven loop now renders these links.
--
-- display_order values 84–94 slot these tools before memberships (95),
-- staff_kyc (96), and staff_management (97).

BEGIN;

-- Society Profile — admin only (page: if (!user.isAdmin) → 403)
INSERT INTO module_configurations (society_id, module_key, display_name, icon, is_active, display_order, nav_group, min_nav_role)
SELECT id, 'admin_society', 'Society Profile', 'fa-building', true, 84, 'Administration', 'admin'
FROM societies
ON CONFLICT (society_id, module_key) DO UPDATE SET
  display_name  = EXCLUDED.display_name,
  icon          = EXCLUDED.icon,
  nav_group     = EXCLUDED.nav_group,
  min_nav_role  = EXCLUDED.min_nav_role,
  display_order = EXCLUDED.display_order;

-- Holiday Calendar — exec+ (page: exec/secretary/president/isAdmin)
INSERT INTO module_configurations (society_id, module_key, display_name, icon, is_active, display_order, nav_group, min_nav_role)
SELECT id, 'admin_holidays', 'Holiday Calendar', 'fa-calendar-day', true, 85, 'Administration', 'executive'
FROM societies
ON CONFLICT (society_id, module_key) DO UPDATE SET
  display_name  = EXCLUDED.display_name,
  icon          = EXCLUDED.icon,
  nav_group     = EXCLUDED.nav_group,
  min_nav_role  = EXCLUDED.min_nav_role,
  display_order = EXCLUDED.display_order;

-- Audit Logs — admin only (page: role='admin')
INSERT INTO module_configurations (society_id, module_key, display_name, icon, is_active, display_order, nav_group, min_nav_role)
SELECT id, 'admin_audit', 'Audit Logs', 'fa-shield-alt', true, 86, 'Administration', 'admin'
FROM societies
ON CONFLICT (society_id, module_key) DO UPDATE SET
  display_name  = EXCLUDED.display_name,
  icon          = EXCLUDED.icon,
  nav_group     = EXCLUDED.nav_group,
  min_nav_role  = EXCLUDED.min_nav_role,
  display_order = EXCLUDED.display_order;

-- Asset Register — exec+ (page: executive/secretary/president/isAdmin)
INSERT INTO module_configurations (society_id, module_key, display_name, icon, is_active, display_order, nav_group, min_nav_role)
SELECT id, 'admin_assets', 'Asset Register', 'fa-cogs', true, 87, 'Administration', 'executive'
FROM societies
ON CONFLICT (society_id, module_key) DO UPDATE SET
  display_name  = EXCLUDED.display_name,
  icon          = EXCLUDED.icon,
  nav_group     = EXCLUDED.nav_group,
  min_nav_role  = EXCLUDED.min_nav_role,
  display_order = EXCLUDED.display_order;

-- Rules Engine — admin only (page: if (!user.isAdmin))
INSERT INTO module_configurations (society_id, module_key, display_name, icon, is_active, display_order, nav_group, min_nav_role)
SELECT id, 'admin_rules', 'Rules Engine', 'fa-sliders-h', true, 88, 'Administration', 'admin'
FROM societies
ON CONFLICT (society_id, module_key) DO UPDATE SET
  display_name  = EXCLUDED.display_name,
  icon          = EXCLUDED.icon,
  nav_group     = EXCLUDED.nav_group,
  min_nav_role  = EXCLUDED.min_nav_role,
  display_order = EXCLUDED.display_order;

-- RBAC & Permissions — admin only (page: if (!user.isAdmin))
INSERT INTO module_configurations (society_id, module_key, display_name, icon, is_active, display_order, nav_group, min_nav_role)
SELECT id, 'admin_rbac', 'RBAC & Permissions', 'fa-lock', true, 89, 'Administration', 'admin'
FROM societies
ON CONFLICT (society_id, module_key) DO UPDATE SET
  display_name  = EXCLUDED.display_name,
  icon          = EXCLUDED.icon,
  nav_group     = EXCLUDED.nav_group,
  min_nav_role  = EXCLUDED.min_nav_role,
  display_order = EXCLUDED.display_order;

-- Email Drafts — exec+ (page: secretary/president/isAdmin; all map to executive nav role)
INSERT INTO module_configurations (society_id, module_key, display_name, icon, is_active, display_order, nav_group, min_nav_role)
SELECT id, 'admin_email', 'Email Drafts', 'fa-envelope-open-text', true, 90, 'Administration', 'executive'
FROM societies
ON CONFLICT (society_id, module_key) DO UPDATE SET
  display_name  = EXCLUDED.display_name,
  icon          = EXCLUDED.icon,
  nav_group     = EXCLUDED.nav_group,
  min_nav_role  = EXCLUDED.min_nav_role,
  display_order = EXCLUDED.display_order;

-- Feature Config — admin only (page: role='admin')
INSERT INTO module_configurations (society_id, module_key, display_name, icon, is_active, display_order, nav_group, min_nav_role)
SELECT id, 'admin_features', 'Feature Config', 'fa-toggle-on', true, 91, 'Administration', 'admin'
FROM societies
ON CONFLICT (society_id, module_key) DO UPDATE SET
  display_name  = EXCLUDED.display_name,
  icon          = EXCLUDED.icon,
  nav_group     = EXCLUDED.nav_group,
  min_nav_role  = EXCLUDED.min_nav_role,
  display_order = EXCLUDED.display_order;

-- Staff Attendance — exec+ (page: role in executive/admin)
INSERT INTO module_configurations (society_id, module_key, display_name, icon, is_active, display_order, nav_group, min_nav_role)
SELECT id, 'admin_staff', 'Staff Attendance', 'fa-user-clock', true, 92, 'Administration', 'executive'
FROM societies
ON CONFLICT (society_id, module_key) DO UPDATE SET
  display_name  = EXCLUDED.display_name,
  icon          = EXCLUDED.icon,
  nav_group     = EXCLUDED.nav_group,
  min_nav_role  = EXCLUDED.min_nav_role,
  display_order = EXCLUDED.display_order;

-- TDS Tracking — exec+ (page: executive/secretary/president/isAdmin)
INSERT INTO module_configurations (society_id, module_key, display_name, icon, is_active, display_order, nav_group, min_nav_role)
SELECT id, 'admin_tds', 'TDS Tracking', 'fa-file-invoice', true, 93, 'Administration', 'executive'
FROM societies
ON CONFLICT (society_id, module_key) DO UPDATE SET
  display_name  = EXCLUDED.display_name,
  icon          = EXCLUDED.icon,
  nav_group     = EXCLUDED.nav_group,
  min_nav_role  = EXCLUDED.min_nav_role,
  display_order = EXCLUDED.display_order;

-- Consent Management — admin only (page: role='admin')
INSERT INTO module_configurations (society_id, module_key, display_name, icon, is_active, display_order, nav_group, min_nav_role)
SELECT id, 'admin_consent', 'Consent Mgmt', 'fa-user-shield', true, 94, 'Administration', 'admin'
FROM societies
ON CONFLICT (society_id, module_key) DO UPDATE SET
  display_name  = EXCLUDED.display_name,
  icon          = EXCLUDED.icon,
  nav_group     = EXCLUDED.nav_group,
  min_nav_role  = EXCLUDED.min_nav_role,
  display_order = EXCLUDED.display_order;

COMMIT;
