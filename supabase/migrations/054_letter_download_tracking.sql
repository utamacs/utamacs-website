-- Migration 054: Download receipt tracking for generated_letters
-- Tracks how many times a letter has been downloaded and when it was last accessed.
-- Useful for legal purposes: "Downloaded by exec on [date]".

ALTER TABLE generated_letters
  ADD COLUMN IF NOT EXISTS download_count  int          NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_downloaded_at timestamptz;

COMMENT ON COLUMN generated_letters.download_count      IS 'Number of times this letter has been downloaded as PDF or DOCX';
COMMENT ON COLUMN generated_letters.last_downloaded_at  IS 'Timestamp of the most recent download';
