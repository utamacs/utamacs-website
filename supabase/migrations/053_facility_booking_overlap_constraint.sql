-- Migration 053: DB-level double-booking prevention for facility_bookings
-- The application layer already checks for conflicts, but parallel POST requests
-- can race past the application check. A PostgreSQL EXCLUDE constraint is the
-- only reliable way to enforce exclusivity under concurrent load.

-- btree_gist is a contrib extension that allows btree-indexed columns (like uuid)
-- to participate in GiST exclusion constraints alongside range types.
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Exclude overlapping time ranges for the same facility when booking is active.
-- tstzrange(start_time, end_time, '[)') = half-open interval [start, end)
-- The WHERE clause limits enforcement to active-status bookings only;
-- cancelled/completed/no_show bookings do not block new ones.
ALTER TABLE facility_bookings
  ADD CONSTRAINT no_overlapping_bookings
  EXCLUDE USING gist (
    facility_id WITH =,
    tstzrange(start_time, end_time, '[)') WITH &&
  )
  WHERE (status IN ('pending', 'confirmed', 'in_use'));

COMMENT ON CONSTRAINT no_overlapping_bookings ON facility_bookings
  IS 'Prevents double-booking: no two active bookings for the same facility may overlap in time.';
