-- 073_staff_activity_templates.sql
-- Activity / task templates in three languages, frequency-driven scheduling.

BEGIN;

CREATE TABLE staff_activity_templates (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id   uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  department   text NOT NULL
    CHECK (department IN ('security','housekeeping','gardening','maintenance','admin','multi')),
  title        text NOT NULL CHECK (length(title) <= 200),
  title_hi     text           CHECK (length(title_hi) <= 200),  -- Hindi
  title_te     text           CHECK (length(title_te) <= 200),  -- Telugu
  description  text,
  frequency    text NOT NULL
    CHECK (frequency IN ('daily','weekly','monthly','quarterly','half_yearly','yearly','on_demand')),
  -- For weekly: 1-7 (Mon-Sun), for monthly: day-of-month 1-31
  schedule_day int,
  -- How many minutes the task is expected to take
  estimated_mins int,
  -- Whether completion requires a photo proof upload
  requires_photo boolean NOT NULL DEFAULT false,
  -- Is this template from the approved library (true) or proposed (handled separately)
  is_approved  boolean NOT NULL DEFAULT true,
  is_active    boolean NOT NULL DEFAULT true,
  created_at   timestamptz NOT NULL DEFAULT now(),
  created_by   uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE INDEX idx_activity_templates_society ON staff_activity_templates(society_id, department, is_active);
CREATE INDEX idx_activity_templates_freq    ON staff_activity_templates(frequency, is_active);

-- ── RLS ──────────────────────────────────────────────────────────────────────

ALTER TABLE staff_activity_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "templates_read" ON staff_activity_templates FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "templates_manage" ON staff_activity_templates FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── Seed default activity templates ──────────────────────────────────────────

INSERT INTO staff_activity_templates
  (society_id, department, title, title_hi, title_te, frequency, requires_photo)
SELECT
  s.id,
  t.department,
  t.title,
  t.title_hi,
  t.title_te,
  t.frequency,
  t.requires_photo
FROM societies s
CROSS JOIN (VALUES
  -- Security
  ('security', 'Perimeter Walk',     'परिमिति गश्त',      'పరిమితి గస్తీ',    'daily',     false),
  ('security', 'Gate Log Entry',     'गेट लॉग प्रविष्टि', 'గేట్ లాగ్ ఎంట్రీ', 'daily',    false),
  ('security', 'Visitor Verification','आगंतुक सत्यापन',   'సందర్శకుల ధృవీకరణ','daily',   false),
  ('security', 'Shift Handover',     'पाली हस्तांतरण',    'షిఫ్ట్ హ్యాండోవర్', 'daily',  false),
  ('security', 'CCTV Check',         'CCTV जाँच',         'CCTV తనిఖీ',        'daily',   true ),
  ('security', 'Fire Exit Inspection','अग्नि निकास निरीक्षण','అగ్ని నిష్క్రమణ తనిఖీ','weekly', true),
  ('security', 'Emergency Drill',    'आपातकालीन अभ्यास',  'అత్యవసర విన్యాసం', 'monthly',  true ),
  -- Housekeeping
  ('housekeeping', 'Common Area Sweep',  'सामान्य क्षेत्र सफाई',  'సాధారణ ప్రాంతం తుడుపు', 'daily',     true ),
  ('housekeeping', 'Lobby Mopping',      'लॉबी पोंछा',             'లాబీ మోపింగ్',           'daily',     true ),
  ('housekeeping', 'Lift Sanitisation',  'लिफ्ट स्वच्छता',         'లిఫ్ట్ శానిటైజేషన్',     'daily',     true ),
  ('housekeeping', 'Bin Collection',     'कचरा संग्रह',            'చెత్త సేకరణ',             'daily',     false),
  ('housekeeping', 'Staircase Cleaning', 'सीढ़ी सफाई',             'మెట్ల శుభ్రత',           'weekly',    true ),
  ('housekeeping', 'Terrace Cleaning',   'छत की सफाई',             'టెరేస్ శుభ్రత',          'weekly',    true ),
  ('housekeeping', 'Deep Cleaning',      'गहरी सफाई',              'లోతైన శుభ్రత',           'monthly',   true ),
  -- Gardening
  ('gardening', 'Lawn Mowing',        'घास काटना',        'గడ్డి కోత',          'weekly',    true ),
  ('gardening', 'Plant Watering',     'पौधों को पानी देना','మొక్కలకు నీరు',     'daily',     false),
  ('gardening', 'Pruning',            'छँटाई',            'కత్తిరింపు',          'monthly',   true ),
  ('gardening', 'Fertiliser Apply',   'उर्वरक लगाना',    'ఎరువు వేయడం',        'quarterly', false),
  -- Maintenance
  ('maintenance', 'Pump Room Check',  'पंप रूम जाँच',    'పంప్ రూమ్ తనిఖీ',   'daily',     false),
  ('maintenance', 'Generator Check',  'जनरेटर जाँच',     'జనరేటర్ తనిఖీ',      'daily',     true ),
  ('maintenance', 'Lift Log',         'लिफ्ट लॉग',       'లిఫ్ట్ లాగ్',        'daily',     false),
  ('maintenance', 'STP Check',        'STP जाँच',        'STP తనిఖీ',           'daily',     false),
  ('maintenance', 'Fire Extinguisher Check','अग्निशामक जाँच','అగ్నిమాపక తనిఖీ','monthly',  true )
) AS t(department, title, title_hi, title_te, frequency, requires_photo)
ON CONFLICT DO NOTHING;

COMMIT;
