-- ═══════════════════════════════════════════════════════════════
-- 005_facilities.sql
-- Facility booking: facilities, slots, bookings
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE facilities (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id              uuid NOT NULL REFERENCES societies(id),
  name                    text NOT NULL,
  description             text,
  capacity                int,
  amenities               text[],
  images                  text[],
  booking_fee             numeric(10,2) NOT NULL DEFAULT 0,
  deposit_amount          numeric(10,2) NOT NULL DEFAULT 0,
  is_active               boolean NOT NULL DEFAULT true,
  advance_booking_days    int NOT NULL DEFAULT 30,
  cancellation_hours_free int NOT NULL DEFAULT 24,
  created_at              timestamptz NOT NULL DEFAULT now()
);

-- Seed community facilities for UTA MACS
INSERT INTO facilities (society_id, name, description, capacity, advance_booking_days, cancellation_hours_free)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'Community Hall',   'Large multipurpose hall for events and gatherings', 200, 30, 48),
  ('00000000-0000-0000-0000-000000000001', 'Club House',       'Indoor club facilities with games and recreation area', 50,  14, 24),
  ('00000000-0000-0000-0000-000000000001', 'Tennis Court',     'Full-size tennis court with floodlights', 8, 7, 24),
  ('00000000-0000-0000-0000-000000000001', 'Badminton Court',  'Indoor badminton court', 8, 7, 12),
  ('00000000-0000-0000-0000-000000000001', 'Swimming Pool',    'Common swimming pool with changing rooms', 30, 3, 6),
  ('00000000-0000-0000-0000-000000000001', 'Open Amphitheatre','Open-air seating area for performances', 150, 14, 48);

CREATE TABLE facility_slots (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id   uuid NOT NULL REFERENCES facilities(id) ON DELETE CASCADE,
  day_of_week   int[],
  start_time    time NOT NULL,
  end_time      time NOT NULL,
  max_bookings  int NOT NULL DEFAULT 1,
  is_active     boolean NOT NULL DEFAULT true
);

CREATE TABLE facility_bookings (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id),
  facility_id         uuid NOT NULL REFERENCES facilities(id),
  user_id             uuid NOT NULL REFERENCES auth.users(id),
  unit_id             uuid NOT NULL REFERENCES units(id),
  booking_date        date NOT NULL,
  start_time          timestamptz NOT NULL,
  end_time            timestamptz NOT NULL,
  attendees_count     int NOT NULL DEFAULT 1,
  purpose             text,
  status              text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending','confirmed','in_use','completed','cancelled','no_show')),
  fee_charged         numeric(10,2) NOT NULL DEFAULT 0,
  deposit_paid        numeric(10,2) NOT NULL DEFAULT 0,
  deposit_refunded    boolean NOT NULL DEFAULT false,
  payment_id          uuid,
  cancelled_at        timestamptz,
  cancellation_reason text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_bookings_updated_at
  BEFORE UPDATE ON facility_bookings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Indexes
CREATE INDEX idx_bookings_facility ON facility_bookings(facility_id, booking_date);
CREATE INDEX idx_bookings_user ON facility_bookings(user_id);
CREATE INDEX idx_bookings_status ON facility_bookings(status);
