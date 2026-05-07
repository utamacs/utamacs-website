-- ═══════════════════════════════════════════════════════════════
-- 043_community_enhancements.sql
-- Community Board: post reports + moderation; marketplace reports
-- ═══════════════════════════════════════════════════════════════

-- ── Post reports ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS community_post_reports (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  post_id       uuid NOT NULL REFERENCES community_posts(id) ON DELETE CASCADE,
  reported_by   uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason        text NOT NULL CHECK (reason IN ('spam','offensive','misinformation','harassment','other')),
  details       text CHECK (length(details) <= 300),
  status        text NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending', 'reviewed', 'dismissed', 'actioned')),
  reviewed_by   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at   timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (post_id, reported_by)
);

ALTER TABLE community_post_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_report_post" ON community_post_reports FOR INSERT
  WITH CHECK (
    reported_by = auth.uid()
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND society_id = community_post_reports.society_id)
  );

CREATE POLICY "exec_view_reports" ON community_post_reports FOR SELECT
  USING (
    reported_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = community_post_reports.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

CREATE POLICY "exec_update_reports" ON community_post_reports FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = community_post_reports.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- ── Marketplace reports ───────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS marketplace_reports (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  listing_id      uuid NOT NULL REFERENCES marketplace_listings(id) ON DELETE CASCADE,
  reported_by     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason          text NOT NULL CHECK (reason IN ('spam','misleading','prohibited','other')),
  details         text CHECK (length(details) <= 300),
  status          text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'reviewed', 'dismissed', 'actioned')),
  reviewed_by     uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at     timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (listing_id, reported_by)
);

ALTER TABLE marketplace_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_report_listing" ON marketplace_reports FOR INSERT
  WITH CHECK (
    reported_by = auth.uid()
    AND EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND society_id = marketplace_reports.society_id)
  );

CREATE POLICY "exec_view_marketplace_reports" ON marketplace_reports FOR SELECT
  USING (
    reported_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = marketplace_reports.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

CREATE POLICY "exec_update_marketplace_reports" ON marketplace_reports FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = marketplace_reports.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- ── Hidden posts tracking ─────────────────────────────────────────────────────
-- Exec can soft-delete a post by flagging it; original record preserved for audit

ALTER TABLE community_posts ADD COLUMN IF NOT EXISTS is_hidden boolean NOT NULL DEFAULT false;
ALTER TABLE community_posts ADD COLUMN IF NOT EXISTS hidden_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE community_posts ADD COLUMN IF NOT EXISTS hidden_at  timestamptz;

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_community_reports_post    ON community_post_reports(post_id, status);
CREATE INDEX IF NOT EXISTS idx_community_reports_society ON community_post_reports(society_id, status);
CREATE INDEX IF NOT EXISTS idx_marketplace_reports       ON marketplace_reports(listing_id, status);
