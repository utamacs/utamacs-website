-- Migration 091: Society profile extended fields + Holiday Calendar
-- Used by: society-profile admin page, holiday calendar page, SLA exclusion logic

-- ── Extend societies table ────────────────────────────────────────────────────
ALTER TABLE societies
  ADD COLUMN IF NOT EXISTS logo_key           text,
  ADD COLUMN IF NOT EXISTS tagline            text,
  ADD COLUMN IF NOT EXISTS contact_email      text,
  ADD COLUMN IF NOT EXISTS contact_phone      text,
  ADD COLUMN IF NOT EXISTS website_url        text,
  ADD COLUMN IF NOT EXISTS whatsapp_group_url text,
  ADD COLUMN IF NOT EXISTS fiscal_year_start  text NOT NULL DEFAULT 'april'
    CHECK (fiscal_year_start IN ('january','april')),
  ADD COLUMN IF NOT EXISTS timezone           text NOT NULL DEFAULT 'Asia/Kolkata',
  ADD COLUMN IF NOT EXISTS currency_symbol    text NOT NULL DEFAULT '₹',
  ADD COLUMN IF NOT EXISTS invoice_prefix     text NOT NULL DEFAULT 'INV',
  ADD COLUMN IF NOT EXISTS receipt_prefix     text NOT NULL DEFAULT 'RCP';

-- ── Holiday Calendar ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS holiday_calendar (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  date        date        NOT NULL,
  name        text        NOT NULL CHECK (length(name) <= 100),
  is_national bool        NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (society_id, date)
);

ALTER TABLE holiday_calendar ENABLE ROW LEVEL SECURITY;

CREATE POLICY "society_read_holiday_calendar" ON holiday_calendar
  FOR SELECT USING (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
  );

CREATE POLICY "exec_manage_holiday_calendar" ON holiday_calendar
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid()
        AND (portal_role IN ('executive','secretary','president') OR is_admin)
    )
  );

-- ── Seed standard Indian national holidays for 2025 ──────────────────────────
INSERT INTO holiday_calendar (society_id, date, name, is_national)
SELECT
  '00000000-0000-0000-0000-000000000001',
  h.date::date,
  h.name,
  true
FROM (VALUES
  ('2025-01-26', 'Republic Day'),
  ('2025-03-14', 'Holi'),
  ('2025-04-10', 'Ugadi'),
  ('2025-04-14', 'Dr. Ambedkar Jayanti'),
  ('2025-04-18', 'Good Friday'),
  ('2025-05-12', 'Buddha Purnima'),
  ('2025-06-07', 'Eid ul-Adha'),
  ('2025-07-06', 'Muharram'),
  ('2025-08-15', 'Independence Day'),
  ('2025-08-16', 'Janmashtami'),
  ('2025-09-05', 'Milad-un-Nabi'),
  ('2025-10-02', 'Gandhi Jayanti'),
  ('2025-10-02', 'Gandhi Jayanti / Dussehra'),
  ('2025-10-20', 'Diwali'),
  ('2025-11-05', 'Guru Nanak Jayanti'),
  ('2025-11-15', 'Telangana Formation Day'),
  ('2025-12-25', 'Christmas Day')
) AS h(date, name)
ON CONFLICT (society_id, date) DO NOTHING;
