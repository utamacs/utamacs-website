-- ═══════════════════════════════════════════════════════════════
-- 019_enable_all_modules.sql
-- Enable visitor_mgmt (was seeded false) and add missing parking
-- module so every built feature appears in the portal sidebar.
-- ═══════════════════════════════════════════════════════════════

-- Enable visitor management
UPDATE module_configurations
   SET is_active = true
 WHERE module_key = 'visitor_mgmt'
   AND society_id = '00000000-0000-0000-0000-000000000001';

-- Add parking (missing from initial seed)
INSERT INTO module_configurations (society_id, module_key, display_name, display_order, icon, is_active)
VALUES ('00000000-0000-0000-0000-000000000001', 'parking', 'Parking Management', 16, 'fa-car', true)
ON CONFLICT (society_id, module_key) DO UPDATE SET is_active = true;
