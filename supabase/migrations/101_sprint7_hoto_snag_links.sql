-- ═══════════════════════════════════════════════════════════════
-- 101_sprint7_hoto_snag_links.sql
-- Sprint 7: HOTO–Snag linking table
-- ═══════════════════════════════════════════════════════════════

-- Links a snag_item to a hoto_item so that the HOTO review workflow
-- can track which defects are covered by which handover item.
CREATE TABLE IF NOT EXISTS hoto_item_snag_links (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id   uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  hoto_item_id uuid        NOT NULL REFERENCES hoto_items(id) ON DELETE CASCADE,
  snag_item_id uuid        NOT NULL REFERENCES snag_items(id) ON DELETE CASCADE,
  linked_by    uuid        REFERENCES profiles(id) ON DELETE SET NULL, -- personal data: staff identity
  notes        text        CHECK (length(notes) <= 500),
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (hoto_item_id, snag_item_id)
);

COMMENT ON TABLE hoto_item_snag_links IS 'Many-to-many: snag_items linked to hoto_items for HOTO review coverage tracking';
COMMENT ON COLUMN hoto_item_snag_links.linked_by IS 'personal data: identity of exec who created the link';

ALTER TABLE hoto_item_snag_links ENABLE ROW LEVEL SECURITY;

-- Members of the same society can see links
CREATE POLICY "society_read_hoto_item_snag_links" ON hoto_item_snag_links
  FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

-- Exec/admin can create, update, delete links
CREATE POLICY "exec_manage_hoto_item_snag_links" ON hoto_item_snag_links
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- Index for fast lookups in both directions
CREATE INDEX IF NOT EXISTS idx_hoto_snag_links_hoto  ON hoto_item_snag_links (hoto_item_id);
CREATE INDEX IF NOT EXISTS idx_hoto_snag_links_snag  ON hoto_item_snag_links (snag_item_id);
CREATE INDEX IF NOT EXISTS idx_hoto_snag_links_soc   ON hoto_item_snag_links (society_id);
