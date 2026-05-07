-- Migration 057: Link work orders to snag items (one-click WO creation from a snag)
-- snag_items.id is TEXT (not UUID), so the FK column must also be TEXT.

ALTER TABLE work_orders
  ADD COLUMN IF NOT EXISTS snag_id text REFERENCES snag_items(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_work_orders_snag ON work_orders(snag_id) WHERE snag_id IS NOT NULL;

COMMENT ON COLUMN work_orders.snag_id IS 'Optional link to a snag_items record when the WO was created from a snag';
