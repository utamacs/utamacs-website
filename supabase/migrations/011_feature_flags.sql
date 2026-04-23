-- ═══════════════════════════════════════════════════════════════
-- 011_feature_flags.sql
-- Feature flags and module configuration
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE module_configurations (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id),
  module_key    text NOT NULL,
  display_name  text NOT NULL,
  is_active     boolean NOT NULL DEFAULT true,
  display_order int NOT NULL DEFAULT 0,
  icon          text,
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(society_id, module_key)
);

CREATE TABLE feature_flags (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id),
  module_key    text NOT NULL,
  feature_key   text NOT NULL,
  is_enabled    boolean NOT NULL DEFAULT true,
  allowed_roles text[],
  config_json   jsonb DEFAULT '{}'::jsonb,
  updated_by    uuid REFERENCES auth.users(id),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(society_id, module_key, feature_key)
);

-- Seed module configurations for UTA MACS
INSERT INTO module_configurations (society_id, module_key, display_name, display_order, icon, is_active)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'members',          'Member Directory',         1,  'fa-users',          true),
  ('00000000-0000-0000-0000-000000000001', 'complaints',       'Complaints',               2,  'fa-tools',          true),
  ('00000000-0000-0000-0000-000000000001', 'notices',          'Notices & Circulars',      3,  'fa-bell',           true),
  ('00000000-0000-0000-0000-000000000001', 'events',           'Events',                   4,  'fa-calendar-alt',   true),
  ('00000000-0000-0000-0000-000000000001', 'polls',            'Polls & Voting',           5,  'fa-vote-yea',       true),
  ('00000000-0000-0000-0000-000000000001', 'finance',          'Finance & Dues',           6,  'fa-rupee-sign',     true),
  ('00000000-0000-0000-0000-000000000001', 'facility_booking', 'Facility Booking',         7,  'fa-building',       true),
  ('00000000-0000-0000-0000-000000000001', 'visitor_mgmt',     'Visitor Management',       8,  'fa-id-badge',       false),
  ('00000000-0000-0000-0000-000000000001', 'vendors',          'Vendors & Work Orders',    9,  'fa-hard-hat',       true),
  ('00000000-0000-0000-0000-000000000001', 'community',        'Community Board',          10, 'fa-comments',       true),
  ('00000000-0000-0000-0000-000000000001', 'documents',        'Documents',                11, 'fa-file-alt',       true),
  ('00000000-0000-0000-0000-000000000001', 'asset_mgmt',       'Asset Management',         12, 'fa-cogs',           true),
  ('00000000-0000-0000-0000-000000000001', 'notifications',    'Notifications',            13, 'fa-envelope',       true),
  ('00000000-0000-0000-0000-000000000001', 'analytics',        'Analytics & Reports',      14, 'fa-chart-bar',      true),
  ('00000000-0000-0000-0000-000000000001', 'compliance',       'Compliance & Audit',       15, 'fa-shield-alt',     true);

-- Seed default feature flags
INSERT INTO feature_flags (society_id, module_key, feature_key, is_enabled, allowed_roles, config_json)
VALUES
  -- Complaints
  ('00000000-0000-0000-0000-000000000001', 'complaints', 'attachments',       true,  NULL, '{"max_file_size_mb": 10, "max_files": 5}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'complaints', 'internal_comments', true,  ARRAY['executive','admin'], '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'complaints', 'sla_tracking',      true,  NULL, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'complaints', 'auto_assignment',   false, ARRAY['admin'], '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'complaints', 'escalation',        false, ARRAY['executive','admin'], '{}'::jsonb),
  -- Finance
  ('00000000-0000-0000-0000-000000000001', 'finance', 'billing_engine',   true,  ARRAY['executive','admin'], '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'finance', 'payment_gateway',  false, ARRAY['admin'], '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'finance', 'gst_invoicing',    true,  ARRAY['executive','admin'], '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'finance', 'tds_tracking',     false, ARRAY['executive','admin'], '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'finance', 'dues_reminders',   true,  ARRAY['executive','admin'], '{}'::jsonb),
  -- Events
  ('00000000-0000-0000-0000-000000000001', 'events', 'paid_events',       false, ARRAY['executive','admin'], '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'events', 'qr_attendance',     false, ARRAY['executive','admin'], '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'events', 'waitlist',          true,  NULL, '{}'::jsonb),
  -- Polls
  ('00000000-0000-0000-0000-000000000001', 'polls', 'anonymous_voting',   true,  NULL, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'polls', 'result_export',      true,  ARRAY['executive','admin'], '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'polls', 'one_vote_per_unit',  true,  NULL, '{}'::jsonb),
  -- Visitor Management (disabled by default — requires QR/OTP setup)
  ('00000000-0000-0000-0000-000000000001', 'visitor_mgmt', 'pre_approval_qr',    false, NULL, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'visitor_mgmt', 'pre_approval_otp',   false, NULL, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'visitor_mgmt', 'delivery_tracking',  false, NULL, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'visitor_mgmt', 'staff_attendance',   false, NULL, '{}'::jsonb),
  -- Notifications
  ('00000000-0000-0000-0000-000000000001', 'notifications', 'email',          true,  NULL, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'notifications', 'sms_trai_dlt',   false, NULL, '{"note": "Requires TRAI DLT entity and template registration before enabling"}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'notifications', 'whatsapp_trai_dlt', false, NULL, '{"note": "Requires TRAI DLT registration before enabling"}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'notifications', 'push',           false, NULL, '{}'::jsonb),
  ('00000000-0000-0000-0000-000000000001', 'notifications', 'realtime',       true,  NULL, '{}'::jsonb);

-- Indexes
CREATE INDEX idx_feature_flags_lookup ON feature_flags(society_id, module_key, feature_key);
CREATE INDEX idx_module_config_lookup ON module_configurations(society_id, display_order);
