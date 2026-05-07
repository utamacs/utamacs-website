-- ═══════════════════════════════════════════════════════════════
-- 044_events_enhancements.sql
-- Events: banner image, guest allowance, attendance tracking
-- ═══════════════════════════════════════════════════════════════

-- ── Events table enhancements ─────────────────────────────────────────────────

ALTER TABLE events
  ADD COLUMN IF NOT EXISTS banner_key     text,           -- Supabase Storage key in event-banners bucket
  ADD COLUMN IF NOT EXISTS guests_allowed boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS max_guests     int CHECK (max_guests >= 0),
  ADD COLUMN IF NOT EXISTS venue          text CHECK (length(venue) <= 200),
  ADD COLUMN IF NOT EXISTS is_cancelled   boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN events.banner_key IS 'Supabase Storage key in event-banners bucket';

-- ── Event attendance (check-in tracking) ─────────────────────────────────────

CREATE TABLE IF NOT EXISTS event_attendance (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  event_id        uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  unit_id         uuid REFERENCES units(id) ON DELETE SET NULL,
  guest_count     int NOT NULL DEFAULT 0 CHECK (guest_count >= 0 AND guest_count <= 10),
  checked_in_at   timestamptz,
  marked_by       uuid REFERENCES auth.users(id) ON DELETE SET NULL,  -- exec/guard who marked
  notes           text CHECK (length(notes) <= 200),
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (event_id, user_id)
);

ALTER TABLE event_attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_own_attendance" ON event_attendance FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = event_attendance.society_id
        AND r.role IN ('executive', 'admin', 'security_guard')
    )
  );

-- Members RSVP (insert their own record)
CREATE POLICY "member_rsvp" ON event_attendance FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND society_id = event_attendance.society_id)
  );

-- Members can update their own RSVP (e.g. change guest count)
CREATE POLICY "member_update_rsvp" ON event_attendance FOR UPDATE
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = event_attendance.society_id
        AND r.role IN ('executive', 'admin', 'security_guard')
    )
  );

-- ── RSVP count on events (auto-maintained) ────────────────────────────────────

ALTER TABLE events ADD COLUMN IF NOT EXISTS rsvp_count int NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION sync_event_rsvp_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE events SET rsvp_count = rsvp_count + 1 WHERE id = NEW.event_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE events SET rsvp_count = GREATEST(0, rsvp_count - 1) WHERE id = OLD.event_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_event_rsvp_count
AFTER INSERT OR DELETE ON event_attendance
FOR EACH ROW EXECUTE FUNCTION sync_event_rsvp_count();

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_event_attendance_event ON event_attendance(event_id);
CREATE INDEX IF NOT EXISTS idx_event_attendance_user  ON event_attendance(user_id);
