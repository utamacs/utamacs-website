-- ============================================================
-- 016_agm.sql
-- AGM Document Workflow
-- Full state machine: draft → submitted → approved / rejected
-- Covers AGM minutes, financial statements, resolutions
-- Compliant with TS MACS Act 1995 (immutable once approved)
-- ============================================================

-- AGM sessions (one per AGM meeting)
CREATE TABLE IF NOT EXISTS agm_sessions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  agm_year        int NOT NULL,                          -- e.g. 2025
  agm_type        text NOT NULL DEFAULT 'annual'
                  CHECK (agm_type IN ('annual', 'extraordinary')),
  meeting_date    date NOT NULL,
  meeting_time    timestamptz,
  venue           text,
  quorum_met      boolean DEFAULT false,
  attendees_count int DEFAULT 0,
  chair_user_id   uuid REFERENCES auth.users(id),
  status          text NOT NULL DEFAULT 'scheduled'
                  CHECK (status IN ('scheduled', 'held', 'adjourned', 'cancelled')),
  notes           text,
  created_by      uuid REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (society_id, agm_year, agm_type)
);

-- AGM documents (minutes, financial statements, resolutions, etc.)
-- State machine: draft → submitted → approved / rejected
-- Once APPROVED, the record is effectively immutable (no UPDATE RLS policy for non-admins)
CREATE TABLE IF NOT EXISTS agm_documents (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  agm_session_id  uuid REFERENCES agm_sessions(id) ON DELETE CASCADE,
  document_type   text NOT NULL
                  CHECK (document_type IN (
                    'minutes',              -- meeting minutes
                    'financial_statement',  -- P&L, balance sheet
                    'audit_report',         -- external auditor report
                    'resolution',           -- formal resolution (maintenance hike, committee, etc.)
                    'notice',               -- AGM notice / agenda
                    'proxy_form',           -- proxy voting form
                    'other'
                  )),
  title           text NOT NULL,
  description     text,
  storage_key     text,                                  -- Supabase Storage key (NOT public URL)
  file_name       text,
  mime_type       text,
  file_size_bytes int,
  version         int NOT NULL DEFAULT 1,
  parent_id       uuid REFERENCES agm_documents(id),    -- for revised versions
  -- Workflow state machine
  status          text NOT NULL DEFAULT 'draft'
                  CHECK (status IN ('draft', 'submitted', 'approved', 'rejected')),
  -- Submission
  submitted_by    uuid REFERENCES auth.users(id),
  submitted_at    timestamptz,
  -- Approval / Rejection
  reviewed_by     uuid REFERENCES auth.users(id),
  reviewed_at     timestamptz,
  review_comment  text,
  -- Approval requires dual sign-off for financial documents
  secondary_approver_id   uuid REFERENCES auth.users(id),
  secondary_approved_at   timestamptz,
  secondary_comment       text,
  -- Effective date (when the resolution/decision takes effect)
  effective_date  date,
  -- Visibility
  is_public       boolean NOT NULL DEFAULT false,        -- visible to all members once approved
  -- Timestamps
  created_by      uuid REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Append-only audit trail for AGM document workflow transitions
CREATE TABLE IF NOT EXISTS agm_workflow_history (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  agm_document_id uuid NOT NULL REFERENCES agm_documents(id) ON DELETE CASCADE,
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  old_status      text,
  new_status      text NOT NULL,
  action          text NOT NULL
                  CHECK (action IN ('DRAFT_CREATED', 'SUBMITTED', 'APPROVED', 'REJECTED',
                                    'REVISION_REQUESTED', 'SECONDARY_APPROVED', 'PUBLISHED')),
  actor_id        uuid REFERENCES auth.users(id),
  comment         text,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- AGM resolutions (structured data for resolutions, separate from document)
CREATE TABLE IF NOT EXISTS agm_resolutions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  agm_session_id  uuid NOT NULL REFERENCES agm_sessions(id) ON DELETE CASCADE,
  agm_document_id uuid REFERENCES agm_documents(id),
  resolution_no   text NOT NULL,                         -- "AGM-2025-R01"
  title           text NOT NULL,
  description     text,
  resolution_type text NOT NULL DEFAULT 'ordinary'
                  CHECK (resolution_type IN ('ordinary', 'special', 'extraordinary')),
  status          text NOT NULL DEFAULT 'proposed'
                  CHECK (status IN ('proposed', 'passed', 'defeated', 'withdrawn', 'deferred')),
  votes_for       int DEFAULT 0,
  votes_against   int DEFAULT 0,
  votes_abstain   int DEFAULT 0,
  passed_at       timestamptz,
  effective_date  date,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- Indexes
-- ============================================================

CREATE INDEX IF NOT EXISTS agm_documents_session_idx ON agm_documents (agm_session_id);
CREATE INDEX IF NOT EXISTS agm_documents_status_idx ON agm_documents (status, society_id);
CREATE INDEX IF NOT EXISTS agm_workflow_doc_idx ON agm_workflow_history (agm_document_id);

-- ============================================================
-- Triggers
-- ============================================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_agm_documents_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER agm_documents_updated_at
  BEFORE UPDATE ON agm_documents
  FOR EACH ROW EXECUTE FUNCTION update_agm_documents_updated_at();

CREATE OR REPLACE FUNCTION update_agm_sessions_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER agm_sessions_updated_at
  BEFORE UPDATE ON agm_sessions
  FOR EACH ROW EXECUTE FUNCTION update_agm_sessions_updated_at();

-- ============================================================
-- RLS Policies
-- ============================================================

ALTER TABLE agm_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE agm_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE agm_workflow_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE agm_resolutions ENABLE ROW LEVEL SECURITY;

-- AGM sessions: all members can read; exec/admin can insert/update
CREATE POLICY agm_sessions_read ON agm_sessions FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY agm_sessions_write ON agm_sessions FOR INSERT
  WITH CHECK (get_user_role(auth.uid()) IN ('executive', 'admin'));

CREATE POLICY agm_sessions_update ON agm_sessions FOR UPDATE
  USING (get_user_role(auth.uid()) IN ('executive', 'admin'));

-- AGM documents:
--   DRAFT: visible only to creator and exec/admin
--   SUBMITTED: visible to exec/admin
--   APPROVED with is_public=true: visible to all members
--   APPROVED with is_public=false: visible to exec/admin only
CREATE POLICY agm_docs_read ON agm_documents FOR SELECT
  USING (
    (status = 'approved' AND is_public = true AND auth.uid() IS NOT NULL)
    OR (status IN ('draft', 'submitted', 'approved', 'rejected')
        AND get_user_role(auth.uid()) IN ('executive', 'admin'))
    OR (status = 'draft' AND created_by = auth.uid())
  );

CREATE POLICY agm_docs_insert ON agm_documents FOR INSERT
  WITH CHECK (get_user_role(auth.uid()) IN ('executive', 'admin'));

-- Only exec/admin can update; approved docs cannot be modified (enforced at API layer)
CREATE POLICY agm_docs_update ON agm_documents FOR UPDATE
  USING (get_user_role(auth.uid()) IN ('executive', 'admin'));

-- Workflow history: append-only; exec/admin can read all
CREATE POLICY agm_workflow_read ON agm_workflow_history FOR SELECT
  USING (get_user_role(auth.uid()) IN ('executive', 'admin'));

CREATE POLICY agm_workflow_insert ON agm_workflow_history FOR INSERT
  WITH CHECK (actor_id = auth.uid());

-- Resolutions: members can read all; exec/admin can write
CREATE POLICY agm_resolutions_read ON agm_resolutions FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY agm_resolutions_write ON agm_resolutions FOR INSERT
  WITH CHECK (get_user_role(auth.uid()) IN ('executive', 'admin'));

CREATE POLICY agm_resolutions_update ON agm_resolutions FOR UPDATE
  USING (get_user_role(auth.uid()) IN ('executive', 'admin'));

-- ============================================================
-- Feature flag seed for AGM module
-- ============================================================

INSERT INTO module_configurations (id, society_id, module_key, display_name, is_active, display_order, icon)
  VALUES (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000001',
    'agm',
    'AGM & Governance',
    true,
    95,
    'fa-landmark'
  )
  ON CONFLICT (society_id, module_key) DO NOTHING;
