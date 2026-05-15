-- ═══════════════════════════════════════════════════════════════
-- 104_sprint10_notifications.sql
-- Sprint 10: email queue, digest scheduling, notification cleanup
-- ═══════════════════════════════════════════════════════════════

-- ── Email queue: reliable outbound email delivery ─────────────────────────────

CREATE TABLE IF NOT EXISTS email_queue (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid        NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  user_id         uuid        REFERENCES profiles(id) ON DELETE SET NULL,
  to_email        text        NOT NULL CHECK (length(to_email) <= 254),
  subject         text        NOT NULL CHECK (length(subject) <= 500),
  html_body       text        NOT NULL,
  notification_id uuid        REFERENCES notifications(id) ON DELETE SET NULL,
  status          text        NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending','sent','failed','cancelled')),
  retry_count     int         NOT NULL DEFAULT 0,
  max_retries     int         NOT NULL DEFAULT 3,
  scheduled_for   timestamptz NOT NULL DEFAULT now(),
  sent_at         timestamptz,
  last_error      text        CHECK (length(last_error) <= 500),
  created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE  email_queue                IS 'Outbound email delivery queue with retry tracking';
COMMENT ON COLUMN email_queue.to_email       IS 'personal data: recipient email address';
COMMENT ON COLUMN email_queue.user_id        IS 'personal data: portal user who will receive the email';
COMMENT ON COLUMN email_queue.html_body      IS 'Pre-rendered HTML — do not store unencoded PII';
COMMENT ON COLUMN email_queue.notification_id IS 'Linked in-app notification (for deduplication)';

ALTER TABLE email_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "exec_manage_email_queue" ON email_queue
  FOR ALL
  USING (EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

CREATE INDEX IF NOT EXISTS idx_email_queue_pending
  ON email_queue (society_id, scheduled_for)
  WHERE status = 'pending';

CREATE INDEX IF NOT EXISTS idx_email_queue_user
  ON email_queue (user_id, created_at DESC);

-- ── Digest tracking: prevent duplicate daily digests ─────────────────────────

ALTER TABLE notification_preferences
  ADD COLUMN IF NOT EXISTS last_digest_sent_at timestamptz;

COMMENT ON COLUMN notification_preferences.last_digest_sent_at IS 'Timestamp of last daily digest email sent to this user';

-- ── Rules engine seeds ────────────────────────────────────────────────────────

INSERT INTO rules (society_id, rule_code, value_type, current_value, description, is_locked)
SELECT
  s.id,
  r.code,
  r.vtype,
  r.val::jsonb,
  r.descr,
  false
FROM societies s
CROSS JOIN (VALUES
  ('NOTIFICATION_EMAIL_ENABLED',    'boolean', 'false', 'Master switch: enable outbound email notifications (requires RESEND_API_KEY env var)'),
  ('NOTIFICATION_EMAIL_MAX_RETRIES','integer', '3',     'Maximum retry attempts for a failed email before marking it permanently failed'),
  ('NOTIFICATION_DIGEST_HOUR',      'integer', '9',     'Hour of day (0–23 IST) at which daily digest emails are sent'),
  ('NOTIFICATION_DIGEST_WINDOW_HRS','integer', '24',    'Window (hours) of unread notifications to include in each digest email'),
  ('NOTIFICATION_BATCH_SIZE',       'integer', '50',    'Maximum emails processed per call to the email queue processor')
) AS r(code, vtype, val, descr)
ON CONFLICT (society_id, rule_code) DO NOTHING;
