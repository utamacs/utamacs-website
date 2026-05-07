-- ═══════════════════════════════════════════════════════════════
-- 048_snag_attachments.sql
-- Snag/defect photo attachments
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS snag_attachments (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  snag_item_id  uuid NOT NULL REFERENCES snag_items(id) ON DELETE CASCADE,
  storage_key   text NOT NULL,   -- Supabase Storage key in complaint-attachments bucket (reuse bucket)
  mime_type     text NOT NULL CHECK (mime_type IN ('image/jpeg','image/png','image/webp','image/heic','video/mp4')),
  uploaded_by   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  caption       text CHECK (length(caption) <= 200),
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE snag_attachments ENABLE ROW LEVEL SECURITY;

-- Members see attachments on snags within their society
CREATE POLICY "member_view_snag_attachments" ON snag_attachments FOR SELECT
  USING (
    society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
  );

-- Any authenticated member in the society can add photos
CREATE POLICY "member_upload_snag_attachment" ON snag_attachments FOR INSERT
  WITH CHECK (
    uploaded_by = auth.uid()
    AND society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
  );

-- Exec can delete attachments
CREATE POLICY "exec_delete_attachment" ON snag_attachments FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = snag_attachments.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- ── Attachment count on snags ─────────────────────────────────────────────────

ALTER TABLE snag_items ADD COLUMN IF NOT EXISTS attachment_count int NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION sync_snag_attachment_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE snag_items SET attachment_count = attachment_count + 1 WHERE id = NEW.snag_item_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE snag_items SET attachment_count = GREATEST(0, attachment_count - 1) WHERE id = OLD.snag_item_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_snag_attachment_count
AFTER INSERT OR DELETE ON snag_attachments
FOR EACH ROW EXECUTE FUNCTION sync_snag_attachment_count();

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_snag_attachments_snag ON snag_attachments(snag_item_id, created_at);
