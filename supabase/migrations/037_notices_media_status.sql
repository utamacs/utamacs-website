-- ═══════════════════════════════════════════════════════════════
-- 037_notices_media_status.sql
-- Notices: add attachment_type, video_url, scheduled_at, status columns
-- ═══════════════════════════════════════════════════════════════

-- ── New columns ───────────────────────────────────────────────────────────────

ALTER TABLE notices
  ADD COLUMN IF NOT EXISTS attachment_type text
    CHECK (attachment_type IN ('image', 'pdf', 'video_link')),
  ADD COLUMN IF NOT EXISTS video_url       text
    CHECK (length(video_url) <= 500),
  ADD COLUMN IF NOT EXISTS scheduled_at   timestamptz,
  ADD COLUMN IF NOT EXISTS status         text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'scheduled', 'published', 'archived'));

COMMENT ON COLUMN notices.video_url IS 'YouTube or other external video URL — not personal data, public content link';

-- ── Backfill status from existing is_published ────────────────────────────────

UPDATE notices
SET status = CASE
  WHEN is_published = true  THEN 'published'
  ELSE 'draft'
END
WHERE status = 'draft';

-- ── Trigger: keep is_published in sync with status (backwards compat) ─────────

CREATE OR REPLACE FUNCTION sync_notice_published()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.is_published := (NEW.status = 'published');
  IF NEW.status = 'published' AND NEW.published_at IS NULL THEN
    NEW.published_at := now();
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notice_published_sync
  BEFORE INSERT OR UPDATE ON notices
  FOR EACH ROW EXECUTE FUNCTION sync_notice_published();

-- ── Index ─────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_notices_status        ON notices(society_id, status);
CREATE INDEX IF NOT EXISTS idx_notices_scheduled_at  ON notices(scheduled_at) WHERE scheduled_at IS NOT NULL;
