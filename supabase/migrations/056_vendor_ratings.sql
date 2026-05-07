-- Migration 056: Vendor ratings per work order
-- Allows exec to rate vendor performance (1–5) after work order is closed/completed.
-- Average rating is tracked on the vendors table for quick display.

CREATE TABLE vendor_ratings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  work_order_id   uuid NOT NULL REFERENCES work_orders(id) ON DELETE CASCADE,
  vendor_id       uuid NOT NULL REFERENCES vendors(id) ON DELETE CASCADE,
  rating          int NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment         text CHECK (length(comment) <= 500),
  rated_by        uuid NOT NULL REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (work_order_id)  -- one rating per work order
);

-- Denormalised average rating on vendors table for fast display
ALTER TABLE vendors
  ADD COLUMN IF NOT EXISTS avg_rating  numeric(3,2),
  ADD COLUMN IF NOT EXISTS rating_count int NOT NULL DEFAULT 0;

-- Function + trigger to keep avg_rating + rating_count in sync
CREATE OR REPLACE FUNCTION update_vendor_avg_rating()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE vendors
  SET
    avg_rating   = (SELECT AVG(rating)::numeric(3,2) FROM vendor_ratings WHERE vendor_id = COALESCE(NEW.vendor_id, OLD.vendor_id)),
    rating_count = (SELECT COUNT(*)                  FROM vendor_ratings WHERE vendor_id = COALESCE(NEW.vendor_id, OLD.vendor_id))
  WHERE id = COALESCE(NEW.vendor_id, OLD.vendor_id);
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_vendor_rating_sync
  AFTER INSERT OR UPDATE OR DELETE ON vendor_ratings
  FOR EACH ROW EXECUTE FUNCTION update_vendor_avg_rating();

-- RLS
ALTER TABLE vendor_ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "exec_manage_vendor_ratings" ON vendor_ratings FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- Indexes
CREATE INDEX idx_vendor_ratings_vendor ON vendor_ratings(vendor_id);
CREATE INDEX idx_vendor_ratings_work_order ON vendor_ratings(work_order_id);

COMMENT ON TABLE vendor_ratings IS 'Per-work-order vendor performance ratings (exec only). One rating per closed work order.';
