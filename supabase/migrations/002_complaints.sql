-- ═══════════════════════════════════════════════════════════════
-- 002_complaints.sql
-- Complaints module: SLA config, tickets, comments, attachments, history
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE complaint_sla_config (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid NOT NULL REFERENCES societies(id),
  category    text NOT NULL,
  priority    text NOT NULL,
  sla_hours   int NOT NULL,
  UNIQUE(society_id, category, priority)
);

-- Seed default SLA configuration
INSERT INTO complaint_sla_config (society_id, category, priority, sla_hours)
SELECT
  '00000000-0000-0000-0000-000000000001',
  cat,
  pri,
  CASE
    WHEN pri = 'Critical' THEN 4
    WHEN pri = 'High'     THEN 24
    WHEN pri = 'Medium'   THEN 48
    ELSE                       96
  END
FROM
  (VALUES ('Plumbing'),('Electrical'),('Lift'),('Security'),('Housekeeping'),
          ('Parking'),('Water_Supply'),('Maintenance'),('Common_Area'),
          ('Pest_Control'),('Internet_Cable'),('Generator'),('Garden'),('Other')) AS cats(cat),
  (VALUES ('Critical'),('High'),('Medium'),('Low')) AS pris(pri);

CREATE TABLE complaints (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id),
  ticket_number   text UNIQUE NOT NULL,
  title           text NOT NULL,
  description     text,
  category        text NOT NULL DEFAULT 'Other',
  priority        text NOT NULL DEFAULT 'Medium'
                  CHECK (priority IN ('Low','Medium','High','Critical')),
  status          text NOT NULL DEFAULT 'Open'
                  CHECK (status IN ('Open','Assigned','In_Progress','Waiting_for_User',
                                    'Resolved','Closed','Reopened')),
  raised_by       uuid NOT NULL REFERENCES auth.users(id),
  assigned_to     uuid REFERENCES auth.users(id),
  unit_id         uuid REFERENCES units(id),
  sla_hours       int,
  sla_deadline    timestamptz,
  resolved_at     timestamptz,
  closed_at       timestamptz,
  reopen_count    int NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Immutable comments (no UPDATE policy will be created)
CREATE TABLE complaint_comments (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id  uuid NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
  user_id       uuid NOT NULL REFERENCES auth.users(id),
  comment       text NOT NULL,
  is_internal   boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);

-- File attachments — storage_key references bucket path, never a public URL
CREATE TABLE complaint_attachments (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id    uuid NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
  storage_key     text NOT NULL,
  file_name       text,
  mime_type       text,
  file_size_bytes int,
  uploaded_by     uuid REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Append-only status history
CREATE TABLE complaint_status_history (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  complaint_id  uuid NOT NULL REFERENCES complaints(id) ON DELETE CASCADE,
  old_status    text,
  new_status    text NOT NULL,
  note          text,
  changed_by    uuid REFERENCES auth.users(id),
  changed_at    timestamptz NOT NULL DEFAULT now()
);

-- Auto-generate ticket_number: UTA-2025-00001
CREATE SEQUENCE complaint_seq START 1;
CREATE OR REPLACE FUNCTION generate_ticket_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.ticket_number := 'UTA-' || to_char(now(), 'YYYY') || '-' ||
    lpad(nextval('complaint_seq')::text, 5, '0');
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_complaint_ticket
  BEFORE INSERT ON complaints
  FOR EACH ROW WHEN (NEW.ticket_number IS NULL OR NEW.ticket_number = '')
  EXECUTE FUNCTION generate_ticket_number();

-- Set SLA deadline from config on insert
CREATE OR REPLACE FUNCTION set_complaint_sla()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_sla_hours int;
BEGIN
  SELECT sla_hours INTO v_sla_hours
  FROM complaint_sla_config
  WHERE society_id = NEW.society_id
    AND category = NEW.category
    AND priority = NEW.priority
  LIMIT 1;

  IF v_sla_hours IS NOT NULL THEN
    NEW.sla_hours := v_sla_hours;
    NEW.sla_deadline := now() + (v_sla_hours || ' hours')::interval;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_complaint_sla
  BEFORE INSERT ON complaints
  FOR EACH ROW EXECUTE FUNCTION set_complaint_sla();

-- Auto-close resolved complaints after 72 hours (called by pg_cron or Edge Function)
CREATE OR REPLACE FUNCTION auto_close_resolved_complaints()
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  UPDATE complaints
  SET status = 'Closed', closed_at = now(), updated_at = now()
  WHERE status = 'Resolved'
    AND resolved_at < now() - interval '72 hours';
END;
$$;

CREATE TRIGGER trg_complaints_updated_at
  BEFORE UPDATE ON complaints
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Indexes
CREATE INDEX idx_complaints_society ON complaints(society_id);
CREATE INDEX idx_complaints_raised_by ON complaints(raised_by);
CREATE INDEX idx_complaints_assigned_to ON complaints(assigned_to);
CREATE INDEX idx_complaints_status ON complaints(status);
CREATE INDEX idx_complaints_created ON complaints(created_at DESC);
CREATE INDEX idx_complaint_comments_ticket ON complaint_comments(complaint_id);
