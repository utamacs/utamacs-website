-- test_cleanup.sql — Remove data created by unit/e2e/Playwright test suites.
-- Matches on the "API Test" naming pattern used across all test files.
-- Safe to run multiple times. Does NOT touch demo_data.sql data.
-- Run: npx supabase db query --linked -f supabase/test_cleanup.sql

BEGIN;

-- ── Polls (votes → options → polls) ─────────────────────────────────────────
DELETE FROM poll_votes
WHERE poll_id IN (SELECT id FROM polls WHERE title LIKE 'API Test%');

DELETE FROM poll_options
WHERE poll_id IN (SELECT id FROM polls WHERE title LIKE 'API Test%');

DELETE FROM polls
WHERE title LIKE 'API Test%';

-- ── Events (registrations → events) ─────────────────────────────────────────
DELETE FROM event_registrations
WHERE event_id IN (SELECT id FROM events WHERE title LIKE 'API Test%');

DELETE FROM events
WHERE title LIKE 'API Test%';

-- ── Complaints (comments + history → complaints) ─────────────────────────────
DELETE FROM complaint_comments
WHERE complaint_id IN (SELECT id FROM complaints WHERE title LIKE 'API Test%');

DELETE FROM complaint_status_history
WHERE complaint_id IN (SELECT id FROM complaints WHERE title LIKE 'API Test%');

DELETE FROM complaints
WHERE title LIKE 'API Test%';

-- ── Notices ──────────────────────────────────────────────────────────────────
DELETE FROM notices
WHERE title LIKE 'API Test%';

-- ── Gallery (photos → albums) ─────────────────────────────────────────────
DELETE FROM gallery_photos
WHERE album_id IN (
  SELECT id FROM gallery_albums
  WHERE title LIKE 'API Test%' OR description LIKE 'Test album%'
);

DELETE FROM gallery_albums
WHERE title LIKE 'API Test%' OR description LIKE 'Test album%';

-- ── Community posts (comments → posts) ───────────────────────────────────────
DELETE FROM post_comments
WHERE post_id IN (
  SELECT id FROM community_posts
  WHERE title LIKE 'API Test%' OR body LIKE '%API Test%'
);

DELETE FROM community_posts
WHERE title LIKE 'API Test%' OR body LIKE '%API Test%';

-- ── Feedback ─────────────────────────────────────────────────────────────────
DELETE FROM feedbacks
WHERE subject LIKE 'API Test%';

-- ── Finance — expenses ────────────────────────────────────────────────────────
DELETE FROM expenses
WHERE description LIKE 'API Test%';

-- ── Maids ─────────────────────────────────────────────────────────────────────
DELETE FROM maid_attendance
WHERE maid_id IN (SELECT id FROM maids WHERE full_name LIKE 'API Test%');

DELETE FROM maid_unit_approvals
WHERE maid_id IN (SELECT id FROM maids WHERE full_name LIKE 'API Test%');

DELETE FROM maids
WHERE full_name LIKE 'API Test%';

-- ── Policies (acknowledgements → policies) ───────────────────────────────────
DELETE FROM policy_acknowledgements
WHERE policy_id IN (SELECT id FROM policies WHERE title LIKE 'API Test%');

DELETE FROM policies
WHERE title LIKE 'API Test%';

COMMIT;
