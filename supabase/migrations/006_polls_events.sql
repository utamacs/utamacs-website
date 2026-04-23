-- ═══════════════════════════════════════════════════════════════
-- 006_polls_events.sql
-- Polls & Governance + Events & Engagement
-- ═══════════════════════════════════════════════════════════════

-- ─── POLLS ───────────────────────────────────────────────────
CREATE TABLE polls (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id            uuid NOT NULL REFERENCES societies(id),
  title                 text NOT NULL,
  description           text,
  poll_type             text NOT NULL DEFAULT 'single_choice'
                        CHECK (poll_type IN ('single_choice','multiple_choice','yes_no','rating')),
  scope                 text NOT NULL DEFAULT 'all_members'
                        CHECK (scope IN ('all_members','owners_only','block_specific')),
  target_blocks         text[],
  is_anonymous          boolean NOT NULL DEFAULT false,
  one_vote_per_unit     boolean NOT NULL DEFAULT false,
  starts_at             timestamptz,
  ends_at               timestamptz,
  is_published          boolean NOT NULL DEFAULT false,
  result_visibility     text NOT NULL DEFAULT 'after_close'
                        CHECK (result_visibility IN ('after_vote','after_close','executive_only')),
  created_by            uuid NOT NULL REFERENCES auth.users(id),
  created_at            timestamptz NOT NULL DEFAULT now()
);

-- NOTE: No vote_count column — always computed via COUNT(poll_votes)
-- This prevents drift from concurrent writes
CREATE TABLE poll_options (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id       uuid NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  option_text   text NOT NULL,
  order_index   int NOT NULL DEFAULT 0
);

CREATE TABLE poll_votes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id     uuid NOT NULL REFERENCES polls(id) ON DELETE CASCADE,
  option_id   uuid NOT NULL REFERENCES poll_options(id),
  user_id     uuid NOT NULL REFERENCES auth.users(id),
  unit_id     uuid REFERENCES units(id),
  voted_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE(poll_id, user_id)
);

-- ─── EVENTS ──────────────────────────────────────────────────
CREATE TABLE events (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id              uuid NOT NULL REFERENCES societies(id),
  title                   text NOT NULL,
  description             text,
  category                text,
  starts_at               timestamptz NOT NULL,
  ends_at                 timestamptz,
  location                text,
  capacity                int,
  waitlist_capacity       int NOT NULL DEFAULT 0,
  registration_deadline   timestamptz,
  is_paid                 boolean NOT NULL DEFAULT false,
  ticket_price            numeric(10,2) NOT NULL DEFAULT 0,
  gst_on_ticket           boolean NOT NULL DEFAULT false,
  is_published            boolean NOT NULL DEFAULT false,
  banner_storage_key      text,
  created_by              uuid NOT NULL REFERENCES auth.users(id),
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE event_registrations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id        uuid NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES auth.users(id),
  unit_id         uuid REFERENCES units(id),
  attendees_count int NOT NULL DEFAULT 1,
  status          text NOT NULL DEFAULT 'registered'
                  CHECK (status IN ('registered','waitlisted','attended','cancelled','no_show')),
  payment_id      uuid,
  qr_token        text UNIQUE,
  checked_in_at   timestamptz,
  registered_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(event_id, user_id)
);

CREATE TRIGGER trg_events_updated_at
  BEFORE UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Indexes
CREATE INDEX idx_polls_society ON polls(society_id);
CREATE INDEX idx_polls_published ON polls(is_published, ends_at);
CREATE INDEX idx_poll_votes_poll ON poll_votes(poll_id);
CREATE INDEX idx_events_society ON events(society_id);
CREATE INDEX idx_events_starts ON events(starts_at);
CREATE INDEX idx_registrations_event ON event_registrations(event_id);
CREATE INDEX idx_registrations_user ON event_registrations(user_id);
