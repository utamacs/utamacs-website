-- ═══════════════════════════════════════════════════════════════
-- 097_sprint4_polls_events_community.sql
-- Sprint 4: multi-choice poll voting, rating polls, event banner
--           UI wire-up prerequisite columns, community image count
-- ═══════════════════════════════════════════════════════════════

-- ─── POLLS: multi-choice support ────────────────────────────────

-- polls.max_choices — max options a member may select; enforced by API
-- Default 1 covers single_choice / yes_no; exec sets higher for multiple_choice
ALTER TABLE polls
  ADD COLUMN IF NOT EXISTS max_choices int NOT NULL DEFAULT 1
  CHECK (max_choices >= 1 AND max_choices <= 20);

-- poll_votes: replace UNIQUE(poll_id, user_id) with UNIQUE(poll_id, user_id, option_id)
-- This lets a member cast up to max_choices votes in a multiple_choice poll.
-- Deduplication of single-vote types is enforced at the API layer.
ALTER TABLE poll_votes
  DROP CONSTRAINT IF EXISTS poll_votes_poll_id_user_id_key;

ALTER TABLE poll_votes
  ADD CONSTRAINT poll_votes_poll_id_user_id_option_id_key
    UNIQUE (poll_id, user_id, option_id);

-- ─── POLLS RLS: update INSERT policy ────────────────────────────
-- Remove the "NOT EXISTS same (poll, user)" check — the API now enforces
-- single-vote rules for single_choice/yes_no and max_choices for multiple_choice.
DROP POLICY IF EXISTS poll_votes_insert ON poll_votes;

CREATE POLICY poll_votes_insert ON poll_votes FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND EXISTS (
      SELECT 1 FROM polls p
      WHERE p.id = poll_votes.poll_id
        AND p.society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid())
        AND p.is_published = true
    )
  );

-- ─── POLLS: result_visibility default clarification ─────────────
-- No structural change needed; column already exists from migration 006.
-- Keep DEFAULT 'after_close' (already set).

-- ─── EVENTS: ensure banner_key column exists ────────────────────
-- Already added by migration 044. Guard with IF NOT EXISTS just in case.
ALTER TABLE events
  ADD COLUMN IF NOT EXISTS banner_key text;

-- ─── COMMUNITY POSTS: ensure image_count is populated ───────────
-- Trigger already created in migration 038. Backfill any stragglers.
UPDATE community_posts
SET image_count = COALESCE(array_length(images, 1), 0)
WHERE image_count IS DISTINCT FROM COALESCE(array_length(images, 1), 0);

-- ─── INDEX: speed up multi-choice vote lookups ──────────────────
CREATE INDEX IF NOT EXISTS idx_poll_votes_poll_user
  ON poll_votes (poll_id, user_id);
