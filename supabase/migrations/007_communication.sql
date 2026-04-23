-- ═══════════════════════════════════════════════════════════════
-- 007_communication.sql
-- Notices, acknowledgements, notifications, preferences
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE notices (
  id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id                  uuid NOT NULL REFERENCES societies(id),
  title                       text NOT NULL,
  body                        text,
  category                    text NOT NULL DEFAULT 'General'
                              CHECK (category IN ('Urgent','General','Maintenance',
                                                   'Financial','Events','Governance')),
  target_audience             text NOT NULL DEFAULT 'all'
                              CHECK (target_audience IN ('all','owners','tenants','block_specific')),
  target_blocks               text[],
  is_pinned                   boolean NOT NULL DEFAULT false,
  is_published                boolean NOT NULL DEFAULT false,
  requires_acknowledgement    boolean NOT NULL DEFAULT false,
  published_at                timestamptz,
  expires_at                  timestamptz,
  attachment_storage_key      text,
  created_by                  uuid NOT NULL REFERENCES auth.users(id),
  created_at                  timestamptz NOT NULL DEFAULT now(),
  updated_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE notice_acknowledgements (
  notice_id       uuid NOT NULL REFERENCES notices(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES auth.users(id),
  acknowledged_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (notice_id, user_id)
);

CREATE TABLE notifications (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid REFERENCES societies(id),
  user_id         uuid NOT NULL REFERENCES auth.users(id),
  title           text NOT NULL,
  body            text,
  type            text NOT NULL
                  CHECK (type IN ('complaint','event','notice','poll','payment',
                                   'visitor','facility','system','security_alert')),
  reference_table text,
  reference_id    uuid,
  channel         text NOT NULL DEFAULT 'in_app'
                  CHECK (channel IN ('in_app','email','sms','whatsapp','push')),
  status          text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending','sent','delivered','failed','read')),
  is_read         boolean NOT NULL DEFAULT false,
  read_at         timestamptz,
  sent_at         timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  expires_at      timestamptz
);

CREATE TABLE notification_preferences (
  user_id             uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  complaints          boolean NOT NULL DEFAULT true,
  notices             boolean NOT NULL DEFAULT true,
  events              boolean NOT NULL DEFAULT true,
  polls               boolean NOT NULL DEFAULT true,
  payments            boolean NOT NULL DEFAULT true,
  visitor_alerts      boolean NOT NULL DEFAULT true,
  email_enabled       boolean NOT NULL DEFAULT true,
  sms_enabled         boolean NOT NULL DEFAULT false,
  push_enabled        boolean NOT NULL DEFAULT false,
  quiet_hours_start   time,
  quiet_hours_end     time,
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_notices_updated_at
  BEFORE UPDATE ON notices
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Auto-create default notification preferences for new users
CREATE OR REPLACE FUNCTION create_default_notification_preferences()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_default_notification_prefs
  AFTER INSERT ON profiles
  FOR EACH ROW EXECUTE FUNCTION create_default_notification_preferences();

-- Indexes
CREATE INDEX idx_notices_society ON notices(society_id);
CREATE INDEX idx_notices_published ON notices(is_published, published_at DESC);
CREATE INDEX idx_notices_pinned ON notices(is_pinned, published_at DESC);
CREATE INDEX idx_notifications_user ON notifications(user_id, is_read, created_at DESC);
CREATE INDEX idx_notifications_type ON notifications(type, created_at DESC);
