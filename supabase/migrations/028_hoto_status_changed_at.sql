-- 028: Add status_changed_at to hoto_items
-- Tracks when the status last changed so "waiting time" on pending approvals
-- reflects time in the current status, not the last edit timestamp.

ALTER TABLE hoto_items
  ADD COLUMN IF NOT EXISTS status_changed_at TIMESTAMPTZ;

-- Back-fill: use created_at as a safe lower bound for existing rows
UPDATE hoto_items
  SET status_changed_at = last_updated_at
  WHERE status_changed_at IS NULL;

-- Replace the existing last_updated_at trigger to also capture status changes
CREATE OR REPLACE FUNCTION update_hoto_last_updated()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.last_updated_at = NOW();
  IF NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.status_changed_at = NOW();
  END IF;
  RETURN NEW;
END;
$$;
