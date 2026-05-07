-- ═══════════════════════════════════════════════════════════════
-- 042_gallery.sql
-- Photo Gallery: albums and photos
-- ═══════════════════════════════════════════════════════════════

-- ── Albums ───────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS gallery_albums (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  title         text NOT NULL CHECK (length(title) BETWEEN 2 AND 150),
  description   text CHECK (length(description) <= 500),
  cover_key     text,                 -- Supabase Storage key in gallery-photos bucket
  event_date    date,
  is_public     boolean NOT NULL DEFAULT true,
  created_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE gallery_albums ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_albums" ON gallery_albums FOR SELECT
  USING (society_id IN (
    SELECT society_id FROM profiles WHERE id = auth.uid()
  ));

CREATE POLICY "exec_manage_albums" ON gallery_albums FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = gallery_albums.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- ── Photos ───────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS gallery_photos (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  album_id      uuid NOT NULL REFERENCES gallery_albums(id) ON DELETE CASCADE,
  storage_key   text NOT NULL,             -- Supabase Storage key in gallery-photos bucket
  caption       text CHECK (length(caption) <= 300),
  taken_at      timestamptz,
  uploaded_by   uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE gallery_photos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_view_photos" ON gallery_photos FOR SELECT
  USING (
    album_id IN (
      SELECT id FROM gallery_albums
      WHERE society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
    )
  );

CREATE POLICY "exec_manage_photos" ON gallery_photos FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = gallery_photos.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- ── Album photo count (auto-maintained) ──────────────────────────────────────

ALTER TABLE gallery_albums ADD COLUMN IF NOT EXISTS photo_count int NOT NULL DEFAULT 0;

CREATE OR REPLACE FUNCTION sync_album_photo_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE gallery_albums SET photo_count = photo_count + 1 WHERE id = NEW.album_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE gallery_albums SET photo_count = GREATEST(0, photo_count - 1) WHERE id = OLD.album_id;
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_album_photo_count
AFTER INSERT OR DELETE ON gallery_photos
FOR EACH ROW EXECUTE FUNCTION sync_album_photo_count();

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_gallery_albums_society ON gallery_albums(society_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_gallery_photos_album   ON gallery_photos(album_id, created_at);

-- ── Feature flag ─────────────────────────────────────────────────────────────

INSERT INTO module_configurations (society_id, module_key, display_name, display_order, icon, is_active)
SELECT id, 'gallery', 'Photo Gallery', 18, 'fa-images', true
FROM societies
ON CONFLICT (society_id, module_key) DO NOTHING;
