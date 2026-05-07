-- ═══════════════════════════════════════════════════════════════
-- 038_community_post_images.sql
-- Document community_posts.images as storage keys + add image_count column
-- ═══════════════════════════════════════════════════════════════

-- images text[] already exists from migration 009.
-- Clarify its purpose via comment (storage keys, not public URLs).
COMMENT ON COLUMN community_posts.images IS 'Supabase storage keys in the community bucket — not public URLs. Max 5 images.';

-- Convenience column so list queries don't need to load the full array
ALTER TABLE community_posts
  ADD COLUMN IF NOT EXISTS image_count int NOT NULL DEFAULT 0;

-- Backfill from existing rows (most will be 0)
UPDATE community_posts
SET image_count = COALESCE(array_length(images, 1), 0)
WHERE image_count = 0 AND images IS NOT NULL;

-- Keep image_count in sync automatically
CREATE OR REPLACE FUNCTION sync_post_image_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.image_count := COALESCE(array_length(NEW.images, 1), 0);
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_post_image_count
  BEFORE INSERT OR UPDATE ON community_posts
  FOR EACH ROW EXECUTE FUNCTION sync_post_image_count();
