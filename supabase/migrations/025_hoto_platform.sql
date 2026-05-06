-- ═══════════════════════════════════════════════════════════════════════════════
-- 025_hoto_platform.sql
-- HOTO & Vendor Management Platform — Phase 1 Schema
-- Design: design/HOTO-VENDOR-PLATFORM-DESIGN.md v4.1
--
-- TABLE NAMING NOTES (conflicts with existing migrations avoided):
--   governance_files    ← was "documents" in design (existing `documents` = community doc library)
--   vendor_candidates   ← was "vendors"   in design (existing `vendors` = maintenance contractors)
--   governance_expenses ← was "expenses"  in design (existing `expenses` = GST/TDS expenses)
--   formal_notices      ← was "notices"   in design (existing `notices`  = community notices)
--   hoto_audit_log      ← was "audit_log" in design (existing `audit_logs` = general audit trail)
-- ═══════════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────────────────────
-- 1. Extend profiles (additive only — no existing columns touched)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS portal_role TEXT NOT NULL DEFAULT 'member',
  -- Four values only: 'member' | 'executive' | 'secretary' | 'president'
  -- Controls ALL permission and approval logic for the HOTO platform.
  ADD COLUMN IF NOT EXISTS committee_title TEXT,
  -- Display label only — no effect on permissions or approval authority.
  -- Examples: 'President', 'Vice President', 'Treasurer', 'General Secretary', etc.
  ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false,
  -- Orthogonal to portal_role. Grants user-management authority (role changes,
  -- invites, feature permission edits). Does NOT grant governance powers.
  ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'current',
  ADD COLUMN IF NOT EXISTS last_maintenance_paid_date DATE,
  ADD COLUMN IF NOT EXISTS maintenance_arrears_days INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS privacy_consent_given BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS privacy_consent_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS email_digest_enabled BOOLEAN NOT NULL DEFAULT true;

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Fix user_roles unique constraint (existing bug — role changes could produce
--    duplicate rows, silently failing the update)
-- ─────────────────────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'user_roles_user_society_unique'
      AND conrelid = 'user_roles'::regclass
  ) THEN
    ALTER TABLE user_roles
      ADD CONSTRAINT user_roles_user_society_unique UNIQUE (user_id, society_id);
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. Helper: portal role from profiles (used by RLS policies below)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_portal_role(uid uuid)
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT portal_role FROM profiles WHERE id = uid
$$;

CREATE OR REPLACE FUNCTION is_admin_user(uid uuid)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(is_admin, false) FROM profiles WHERE id = uid
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Privacy Consents (DPDP Act)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS privacy_consents (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES profiles(id),
  policy_version  TEXT NOT NULL,
  consent_given   BOOLEAN NOT NULL,
  consent_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ip_hash         TEXT,
  user_agent_hash TEXT
);
CREATE INDEX IF NOT EXISTS idx_privacy_consents_user ON privacy_consents(user_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Member Invites (invite-only registration)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS member_invites (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id       UUID NOT NULL REFERENCES societies(id),
  email            TEXT NOT NULL,
  flat_number      TEXT,
  intended_role    TEXT NOT NULL DEFAULT 'member',
  invited_by       UUID NOT NULL REFERENCES profiles(id),
  token            TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(32), 'hex'),
  token_expires_at TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '7 days',
  accepted         BOOLEAN NOT NULL DEFAULT false,
  accepted_at      TIMESTAMPTZ,
  accepted_user_id UUID REFERENCES profiles(id),
  cancelled        BOOLEAN NOT NULL DEFAULT false,
  cancelled_by     UUID REFERENCES profiles(id),
  cancelled_at     TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Partial index: fast token lookup for only active (un-accepted, un-cancelled) invites
CREATE UNIQUE INDEX IF NOT EXISTS idx_member_invites_active_token
  ON member_invites(token) WHERE NOT accepted AND NOT cancelled;

-- ─────────────────────────────────────────────────────────────────────────────
-- 6. Role Change Log (fast role history; complements hoto_audit_log)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS role_change_log (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id       UUID NOT NULL REFERENCES societies(id),
  user_id          UUID NOT NULL REFERENCES profiles(id),
  old_role         TEXT NOT NULL,
  new_role         TEXT NOT NULL,
  old_title        TEXT,
  new_title        TEXT,
  changed_by       UUID NOT NULL REFERENCES profiles(id),
  reason           TEXT NOT NULL,
  change_type      TEXT NOT NULL DEFAULT 'ROLE_AND_TITLE',
  -- 'ROLE_AND_TITLE' | 'ROLE_ONLY' | 'TITLE_ONLY' | 'ELECTION'
  election_event_id UUID,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_role_change_user
  ON role_change_log(user_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 7. Election Events (groups bulk role changes from AGM)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS election_events (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id           UUID NOT NULL REFERENCES societies(id),
  election_date        DATE NOT NULL,
  description          TEXT NOT NULL,
  total_role_changes   INTEGER NOT NULL DEFAULT 0,
  outcome_document_url TEXT,
  created_by           UUID REFERENCES profiles(id),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add FK from role_change_log.election_event_id → election_events
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'fk_role_change_election_event'
      AND conrelid = 'role_change_log'::regclass
  ) THEN
    ALTER TABLE role_change_log
      ADD CONSTRAINT fk_role_change_election_event
      FOREIGN KEY (election_event_id) REFERENCES election_events(id);
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 8. Feature Permissions (per-role feature toggles)
-- Only admin (is_admin=true) can change these via UI
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS feature_permissions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      UUID NOT NULL REFERENCES societies(id),
  role            TEXT NOT NULL,
  feature         TEXT NOT NULL,
  enabled         BOOLEAN NOT NULL DEFAULT true,
  is_locked       BOOLEAN NOT NULL DEFAULT false,
  last_changed_by UUID REFERENCES profiles(id),
  last_changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (society_id, role, feature)
);
CREATE INDEX IF NOT EXISTS idx_feature_permissions_role
  ON feature_permissions(society_id, role);

-- ─────────────────────────────────────────────────────────────────────────────
-- 9. User Feature Overrides (per-user exceptions to role defaults)
-- Grants finance access to Treasurer title-holders, delegation access to VP/Joint Sec
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_feature_overrides (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  UUID NOT NULL REFERENCES societies(id),
  user_id     UUID NOT NULL REFERENCES profiles(id),
  feature     TEXT NOT NULL,
  enabled     BOOLEAN NOT NULL,
  reason      TEXT NOT NULL,
  granted_by  UUID NOT NULL REFERENCES profiles(id),
  granted_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at  TIMESTAMPTZ,
  revoked_at  TIMESTAMPTZ,
  revoked_by  UUID REFERENCES profiles(id),
  UNIQUE (society_id, user_id, feature)
);
CREATE INDEX IF NOT EXISTS idx_user_feature_overrides_active
  ON user_feature_overrides(user_id) WHERE revoked_at IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- 10. Upload Queue (async GitHub uploads with exponential backoff)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS upload_queue (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id        UUID NOT NULL REFERENCES societies(id),
  uploaded_by       UUID REFERENCES profiles(id),
  item_type         TEXT NOT NULL,
  item_id           TEXT NOT NULL,
  file_name         TEXT NOT NULL,
  file_size_bytes   INTEGER,
  file_type         TEXT,
  file_hash_sha256  TEXT,
  source_description TEXT,
  target_github_path TEXT NOT NULL,
  -- Validated server-side: must match ^(hoto|snags|vendors|notices|finances|audit)/[a-zA-Z0-9/_.-]+$
  -- Must not contain '..', '//', or null bytes.
  status            TEXT NOT NULL DEFAULT 'PENDING',
  -- 'PENDING' | 'PROCESSING' | 'DONE' | 'FAILED' | 'PERMANENTLY_FAILED'
  attempts          INTEGER NOT NULL DEFAULT 0,
  last_attempt_at   TIMESTAMPTZ,
  backoff_until     TIMESTAMPTZ,
  error_message     TEXT,
  idempotency_key   TEXT UNIQUE,
  github_sha        TEXT,
  document_id       TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_upload_queue_status ON upload_queue(status);
CREATE INDEX IF NOT EXISTS idx_upload_queue_pending
  ON upload_queue(backoff_until) WHERE status IN ('PENDING','FAILED');

-- ─────────────────────────────────────────────────────────────────────────────
-- 11. GitHub API Log (operational health tracking)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS github_api_log (
  id            BIGSERIAL PRIMARY KEY,
  operation     TEXT NOT NULL,
  success       BOOLEAN NOT NULL,
  latency_ms    INTEGER,
  error_message TEXT,
  github_path   TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_github_api_log_recent
  ON github_api_log(created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 12. Governance Files (GitHub-backed file records for HOTO/Snag/Vendor docs)
-- Named governance_files to avoid conflict with existing community `documents` table
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS governance_files (
  id                TEXT PRIMARY KEY,
  item_type         TEXT NOT NULL,
  item_id           TEXT NOT NULL,
  name              TEXT NOT NULL,
  file_type         TEXT,
  file_size_bytes   INTEGER,
  file_hash_sha256  TEXT NOT NULL,
  source_description TEXT,
  github_path       TEXT NOT NULL,
  github_sha        TEXT,
  upload_queue_id   UUID REFERENCES upload_queue(id),
  uploaded_by       UUID REFERENCES profiles(id),
  uploaded_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  description       TEXT,
  is_confidential   BOOLEAN NOT NULL DEFAULT false,
  superseded_by     TEXT REFERENCES governance_files(id),
  superseded_at     TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_governance_files_item
  ON governance_files(item_type, item_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 13. PDF Generation Jobs
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pdf_generation_jobs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    UUID NOT NULL REFERENCES societies(id),
  requested_by  UUID REFERENCES profiles(id),
  job_type      TEXT NOT NULL,
  letter_id     TEXT,
  template      TEXT,
  input_data    JSONB,
  status        TEXT NOT NULL DEFAULT 'QUEUED',
  attempts      INTEGER NOT NULL DEFAULT 0,
  github_path   TEXT,
  error_message TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at  TIMESTAMPTZ,
  purged_at     TIMESTAMPTZ
  -- 30 days after DONE/FAILED, input_data is nulled and purged_at set (PII scrub)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 14. HOTO Items
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS hoto_items (
  id                       TEXT PRIMARY KEY,
  society_id               UUID NOT NULL REFERENCES societies(id),
  ascenza_category         TEXT NOT NULL,
  title                    TEXT NOT NULL,
  description              TEXT,
  builder_commitment       TEXT,
  builder_contact          TEXT,
  priority                 TEXT NOT NULL DEFAULT 'MEDIUM',
  -- 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
  status                   TEXT NOT NULL DEFAULT 'NOT_STARTED',
  -- 'NOT_STARTED' | 'IN_PROGRESS' | 'UNDER_REVIEW' | 'PENDING_PRESIDENT'
  -- | 'PENDING_SECRETARY' | 'APPROVED' | 'REJECTED' | 'CLOSED'
  deadline                 DATE,
  builder_sla_date         DATE,
  days_overdue             INTEGER NOT NULL DEFAULT 0,
  responsible_role         TEXT,
  responsible_user_id      UUID REFERENCES profiles(id),
  rera_escalation_eligible BOOLEAN NOT NULL DEFAULT false,
  notice_sent              BOOLEAN NOT NULL DEFAULT false,
  notice_sent_date         TIMESTAMPTZ,
  notice_draft_path        TEXT,
  dependencies             TEXT[],
  president_approved_at    TIMESTAMPTZ,
  president_approved_by    UUID REFERENCES profiles(id),
  secretary_approved_at    TIMESTAMPTZ,
  secretary_approved_by    UUID REFERENCES profiles(id),
  governance_notes         TEXT,
  created_by               UUID REFERENCES profiles(id),
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  github_path              TEXT
);
CREATE INDEX IF NOT EXISTS idx_hoto_items_society_status
  ON hoto_items(society_id, status);
CREATE INDEX IF NOT EXISTS idx_hoto_items_society_priority
  ON hoto_items(society_id, priority, days_overdue DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 15. HOTO Required Documents (checklist per item)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS hoto_required_docs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hoto_item_id TEXT NOT NULL REFERENCES hoto_items(id) ON DELETE CASCADE,
  doc_name     TEXT NOT NULL,
  required     BOOLEAN NOT NULL DEFAULT true,
  uploaded     BOOLEAN NOT NULL DEFAULT false,
  document_id  TEXT REFERENCES governance_files(id),
  bypass_by    UUID REFERENCES profiles(id),
  bypass_reason TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_hoto_required_docs_item
  ON hoto_required_docs(hoto_item_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 16. Snag Items
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS snag_items (
  id                        TEXT PRIMARY KEY,
  society_id                UUID NOT NULL REFERENCES societies(id),
  snag_scope                TEXT NOT NULL DEFAULT 'COMMON_AREA',
  -- 'COMMON_AREA' | 'APARTMENT'
  category                  TEXT NOT NULL,
  subcategory               TEXT,
  location                  TEXT NOT NULL,
  flat_number               TEXT,
  description               TEXT NOT NULL,
  severity                  TEXT NOT NULL DEFAULT 'MEDIUM',
  -- 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
  status                    TEXT NOT NULL DEFAULT 'OPEN',
  -- 'OPEN' | 'IN_PROGRESS' | 'RESOLVED' | 'VERIFIED_CLOSED' | 'REOPENED'
  ascenza_reference         TEXT,
  builder_committed_date    DATE,
  builder_sla_days_overdue  INTEGER NOT NULL DEFAULT 0,
  notice_sent               BOOLEAN NOT NULL DEFAULT false,
  formal_notice_id          TEXT,
  video_url                 TEXT,
  reported_by               UUID REFERENCES profiles(id),
  reported_date             DATE NOT NULL DEFAULT CURRENT_DATE,
  verified_by               UUID REFERENCES profiles(id),
  verified_at               TIMESTAMPTZ,
  responsible_role          TEXT,
  responsible_user_id       UUID REFERENCES profiles(id),
  reopen_reason             TEXT,
  deleted                   BOOLEAN NOT NULL DEFAULT false,
  deleted_by                UUID REFERENCES profiles(id),
  deleted_at                TIMESTAMPTZ,
  deletion_reason           TEXT,
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  github_path               TEXT
);
CREATE INDEX IF NOT EXISTS idx_snag_items_society_status
  ON snag_items(society_id, status) WHERE NOT deleted;
CREATE INDEX IF NOT EXISTS idx_snag_items_scope
  ON snag_items(society_id, snag_scope, severity);

-- ─────────────────────────────────────────────────────────────────────────────
-- 17. Vendor Requirements (RFQ / evaluation process)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vendor_requirements (
  id                        TEXT PRIMARY KEY,
  society_id                UUID NOT NULL REFERENCES societies(id),
  category                  TEXT NOT NULL,
  title                     TEXT NOT NULL,
  description               TEXT,
  status                    TEXT NOT NULL DEFAULT 'DRAFT',
  -- 'DRAFT' | 'OPEN_FOR_QUOTES' | 'VOTING_OPEN' | 'VOTING_CLOSED'
  -- | 'FINALIST_SELECTED' | 'CONTRACT_SIGNED' | 'CANCELLED'
  -- Also used for board financial votes: 'FINANCIAL_APPROVAL'
  voting_opens_at           TIMESTAMPTZ,
  voting_closes_at          TIMESTAMPTZ,
  quorum_required           INTEGER NOT NULL DEFAULT 8,
  selected_vendor_id        TEXT,
  voting_policy_committed   BOOLEAN NOT NULL DEFAULT false,
  created_by                UUID REFERENCES profiles(id),
  created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 18. Vendor Candidates (quote submissions per requirement)
-- Named vendor_candidates to avoid conflict with existing maintenance `vendors` table
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vendor_candidates (
  id                     TEXT PRIMARY KEY,
  requirement_id         TEXT NOT NULL REFERENCES vendor_requirements(id),
  vendor_name            TEXT NOT NULL,
  contact_person         TEXT,
  contact_email          TEXT,
  contact_phone          TEXT,
  site_visited           BOOLEAN NOT NULL DEFAULT false,
  quote_monthly          NUMERIC(12,2),
  quote_setup            NUMERIC(12,2),
  submitted_at           TIMESTAMPTZ,
  contract_start_date    DATE,
  contract_end_date      DATE,
  renewal_reminder_sent  BOOLEAN NOT NULL DEFAULT false,
  github_path            TEXT
);
CREATE INDEX IF NOT EXISTS idx_vendor_candidates_requirement
  ON vendor_candidates(requirement_id);

-- Forward reference: vendor_requirements.selected_vendor_id → vendor_candidates
ALTER TABLE vendor_requirements
  ADD CONSTRAINT fk_selected_vendor
  FOREIGN KEY (selected_vendor_id) REFERENCES vendor_candidates(id)
  DEFERRABLE INITIALLY DEFERRED;

-- ─────────────────────────────────────────────────────────────────────────────
-- 19. Proxy Authorizations (for vendor voting, when proxy voting is enabled)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS proxy_authorizations (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  principal_user_id UUID NOT NULL REFERENCES profiles(id),
  proxy_user_id     UUID NOT NULL REFERENCES profiles(id),
  requirement_id    TEXT REFERENCES vendor_requirements(id),
  proxy_document_id TEXT REFERENCES governance_files(id),
  valid_from        DATE NOT NULL,
  valid_until       DATE,
  activated_by      UUID REFERENCES profiles(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 20. Votes (vendor selection + financial approval board votes)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS votes (
  id                      TEXT PRIMARY KEY,
  requirement_id          TEXT NOT NULL REFERENCES vendor_requirements(id),
  voter_id                UUID NOT NULL REFERENCES profiles(id),
  proxy_authorization_id  UUID REFERENCES proxy_authorizations(id),
  vendor_id               TEXT REFERENCES vendor_candidates(id),
  -- null when this is a financial approval vote (not a vendor selection vote)
  reason                  TEXT NOT NULL,
  conflict_declared       BOOLEAN NOT NULL DEFAULT false,
  recused                 BOOLEAN NOT NULL DEFAULT false,
  cast_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (requirement_id, voter_id)
);
CREATE INDEX IF NOT EXISTS idx_votes_requirement
  ON votes(requirement_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- 21. Maintenance Records (monthly maintenance payment tracking)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS maintenance_records (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id       UUID NOT NULL REFERENCES societies(id),
  flat_number      TEXT NOT NULL,
  member_id        UUID REFERENCES profiles(id),
  amount           NUMERIC(10,2) NOT NULL,
  period_month     INTEGER NOT NULL CHECK (period_month BETWEEN 1 AND 12),
  period_year      INTEGER NOT NULL,
  paid_date        DATE,
  payment_mode     TEXT,
  reference_number TEXT,
  recorded_by      UUID REFERENCES profiles(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (society_id, flat_number, period_year, period_month)
);
CREATE INDEX IF NOT EXISTS idx_maintenance_records_flat
  ON maintenance_records(society_id, flat_number, period_year DESC, period_month DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 22. Corpus Fund Records
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS corpus_fund_records (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id           UUID NOT NULL REFERENCES societies(id),
  transaction_type     TEXT NOT NULL,
  -- 'RECEIVED_FROM_BUILDER' | 'INTEREST_EARNED' | 'APPROVED_USE'
  amount               NUMERIC(12,2) NOT NULL,
  description          TEXT,
  date                 DATE NOT NULL,
  approved_by          UUID REFERENCES profiles(id),
  board_resolution_ref TEXT,
  payment_mode         TEXT,
  reference_number     TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_corpus_fund_society
  ON corpus_fund_records(society_id, date DESC);

CREATE OR REPLACE FUNCTION get_corpus_balance(p_society_id UUID)
RETURNS NUMERIC LANGUAGE SQL STABLE SECURITY DEFINER AS $$
  SELECT COALESCE(
    SUM(CASE
      WHEN transaction_type IN ('RECEIVED_FROM_BUILDER','INTEREST_EARNED') THEN amount
      WHEN transaction_type = 'APPROVED_USE' THEN -amount
    END), 0)
  FROM corpus_fund_records WHERE society_id = p_society_id;
$$;

-- ─────────────────────────────────────────────────────────────────────────────
-- 23. Governance Expenses (approval-chained expense tracking)
-- Named governance_expenses to avoid conflict with existing GST/TDS `expenses` table
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS governance_expenses (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id           UUID NOT NULL REFERENCES societies(id),
  amount               NUMERIC(12,2) NOT NULL,
  payee                TEXT NOT NULL,
  purpose              TEXT NOT NULL,
  expense_date         DATE NOT NULL,
  payment_mode         TEXT NOT NULL,
  reference_number     TEXT,
  is_recurring         BOOLEAN NOT NULL DEFAULT false,
  sanctioned_by_role   TEXT,
  sanctioned_by        UUID REFERENCES profiles(id),
  byelaw_authority     TEXT,
  board_resolution_ref TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_governance_expenses_society
  ON governance_expenses(society_id, expense_date DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 24. Comments (generic comment thread for HOTO items, snags, vendor requirements)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS hoto_comments (
  id                TEXT PRIMARY KEY,
  item_type         TEXT NOT NULL,
  -- 'hoto_item' | 'snag_item' | 'vendor_requirement'
  item_id           TEXT NOT NULL,
  parent_comment_id TEXT REFERENCES hoto_comments(id),
  author_id         UUID NOT NULL REFERENCES profiles(id),
  content           TEXT NOT NULL,
  is_pinned         BOOLEAN NOT NULL DEFAULT false,
  edited_at         TIMESTAMPTZ,
  edited_content    TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  github_commit     TEXT
  -- No deleted column: comments are permanent governance audit records
);
CREATE INDEX IF NOT EXISTS idx_hoto_comments_item
  ON hoto_comments(item_type, item_id, created_at ASC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 25. Formal Notices (legal notices to builder / Ankura Homes)
-- Named formal_notices to avoid conflict with existing community `notices` table
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS formal_notices (
  id                TEXT PRIMARY KEY,
  notice_type       TEXT NOT NULL,
  recipient         TEXT NOT NULL,
  recipient_type    TEXT NOT NULL,
  related_item_type TEXT,
  related_item_id   TEXT,
  auto_generated    BOOLEAN NOT NULL DEFAULT false,
  status            TEXT NOT NULL DEFAULT 'DRAFT',
  -- 'DRAFT' | 'SENT' | 'RESPONDED' | 'ESCALATED_TO_RERA'
  sent_date         DATE,
  sent_by           UUID REFERENCES profiles(id),
  document_path     TEXT,
  response_received BOOLEAN NOT NULL DEFAULT false,
  response_date     DATE,
  rera_filed        BOOLEAN NOT NULL DEFAULT false,
  rera_date         DATE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 26. Approval Delegations (VP delegates for President; Joint Sec for Secretary)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS approval_delegations (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id       UUID NOT NULL REFERENCES societies(id),
  from_role        TEXT NOT NULL,
  -- 'president' | 'secretary'
  to_user_id       UUID NOT NULL REFERENCES profiles(id),
  -- Must be an executive with the appropriate committee_title (VP or Joint Secretary)
  reason           TEXT NOT NULL,
  delegation_type  TEXT NOT NULL,
  -- 'PRESIDENT_TO_VP' | 'SECRETARY_TO_JOINT_SEC'
  active           BOOLEAN NOT NULL DEFAULT true,
  activated_by     UUID NOT NULL REFERENCES profiles(id),
  activated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deactivated_at   TIMESTAMPTZ,
  notes            TEXT
);
CREATE INDEX IF NOT EXISTS idx_approval_delegations_active
  ON approval_delegations(society_id, active) WHERE active = true;

-- ─────────────────────────────────────────────────────────────────────────────
-- 27. System Config (key-value store for runtime state: circuit breaker, etc.)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS system_config (
  key        TEXT PRIMARY KEY,
  value      JSONB NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_by UUID REFERENCES profiles(id)
);

INSERT INTO system_config (key, value) VALUES
  ('github_circuit_breaker',        '"CLOSED"'),
  ('github_consecutive_failures',   '0'),
  ('upload_queue_paused',           'false'),
  ('maintenance_amount_monthly',    '1500')
ON CONFLICT (key) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- 28. Rules Engine (all configurable business + byelaw rules)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rules (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id       UUID NOT NULL REFERENCES societies(id),
  rule_category    TEXT NOT NULL,
  -- 'PARAMETER' | 'APPROVAL' | 'ESCALATION' | 'NOTIFICATION' | 'VALIDATION'
  rule_code        TEXT NOT NULL,
  label            TEXT NOT NULL,
  description      TEXT,
  byelaw_reference TEXT,
  value_type       TEXT NOT NULL,
  -- 'INTEGER' | 'DECIMAL' | 'BOOLEAN' | 'DATE_STRING' | 'JSON_ARRAY' | 'STRING'
  current_value    JSONB NOT NULL,
  default_value    JSONB NOT NULL,
  is_locked        BOOLEAN NOT NULL DEFAULT true,
  effective_from   DATE NOT NULL DEFAULT CURRENT_DATE,
  changed_by       UUID REFERENCES profiles(id),
  changed_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  change_reason    TEXT,
  UNIQUE (society_id, rule_code)
);
CREATE INDEX IF NOT EXISTS idx_rules_category
  ON rules(society_id, rule_category, rule_code);

-- Seed all rules for UTA MACS
-- PARAMETER category (byelaw-mandated values + operational parameters)
INSERT INTO rules (society_id, rule_category, rule_code, label, description, byelaw_reference, value_type, current_value, default_value, is_locked)
SELECT
  '00000000-0000-0000-0000-000000000001',
  r.rule_category, r.rule_code, r.label, r.description, r.byelaw_reference,
  r.value_type, r.current_value::jsonb, r.default_value::jsonb, r.is_locked
FROM (VALUES
  -- PARAMETER: byelaw-locked values
  ('PARAMETER','QUORUM_GENERAL_BODY',     'Quorum for General Body meeting (members)',           '§7.10',  'INTEGER', '20',    '20',    true),
  ('PARAMETER','QUORUM_BOARD',            'Quorum for Board of Directors meeting (directors)',   '§7.11',  'INTEGER', '5',     '5',     true),
  ('PARAMETER','TOTAL_DIRECTORS',         'Total number of directors',                           '§7.16a', 'INTEGER', '14',    '14',    true),
  ('PARAMETER','VOTE_SUSPENSION_DAYS',    'Maintenance arrears days before vote suspended',      '§4.6',   'INTEGER', '90',    '90',    true),
  ('PARAMETER','DEFAULTER_FLAG_DAYS',     'Days before "Defaulting Member" flag',                '§6.36',  'INTEGER', '60',    '60',    true),
  ('PARAMETER','DEFAULTER_NOTICE_DAYS',   'Days before services denial warning',                 '§6.37',  'INTEGER', '90',    '90',    true),
  ('PARAMETER','MAINTENANCE_INTEREST_RATE','Annual interest on arrears (% p.a.)',                '§19e',   'DECIMAL', '18',    '18',    true),
  ('PARAMETER','SECRETARY_APPROVAL_LIMIT','Max expense Secretary can approve unilaterally (₹)',  '§9.11a', 'INTEGER', '10000', '10000', true),
  ('PARAMETER','PRESIDENT_APPROVAL_LIMIT','Max expense President can approve unilaterally (₹)', '§9.11a', 'INTEGER', '20000', '20000', true),
  ('PARAMETER','BOARD_APPROVAL_LIMIT',    'Max expense requiring Board vote (₹)',                '§9.11b', 'INTEGER', '50000', '50000', true),
  ('PARAMETER','MINUTES_SUBMISSION_DAYS', 'Days to submit meeting minutes after meeting',        '§7.16e', 'INTEGER', '7',     '7',     true),
  ('PARAMETER','ANNUAL_STATEMENT_DEADLINE','Annual financial statement deadline (MM-DD)',        '§9.3',   'STRING',  '"09-30"','"09-30"',true),
  -- PARAMETER: operational (not byelaw-locked)
  ('PARAMETER','INVITE_EXPIRY_DAYS',      'Invite link validity (days)',                         null,     'INTEGER', '7',     '7',     false),
  ('PARAMETER','PROXY_VOTING_ENABLED',    'Allow proxy authorization for vendor votes',           null,     'BOOLEAN', 'false', 'false', false),
  ('PARAMETER','UPLOAD_MAX_SIZE_MB',      'Maximum file upload size (MB)',                       null,     'INTEGER', '5',     '5',     false),
  ('PARAMETER','PDF_PURGE_DAYS',          'Days after which PDF job input_data is PII-scrubbed', null,     'INTEGER', '30',    '30',    false),
  ('PARAMETER','PROXY_EXPIRY_ALERT_DAYS', 'Days before proxy expiry to alert admin',             null,     'INTEGER', '2',     '2',     false),
  ('PARAMETER','EMAIL_DRAFT_RETENTION_DAYS','Days to retain SENT/DISCARDED email drafts',       null,     'INTEGER', '365',   '365',   false),
  -- APPROVAL category
  ('APPROVAL', 'HOTO_APPROVAL_CHAIN',        'Roles required to approve HOTO items (in order)',                      null, 'JSON_ARRAY', '["secretary","president"]', '["secretary","president"]', true),
  ('APPROVAL', 'HOTO_APPROVAL_ALTERNATE_VP', 'Executive with VP title substitutes for President when delegation active', null, 'BOOLEAN', 'true', 'true', true),
  ('APPROVAL', 'HOTO_APPROVAL_ALTERNATE_JOINT_SEC','Executive with Joint Secretary title substitutes for Secretary when delegation active', null, 'BOOLEAN', 'true', 'true', true),
  ('APPROVAL', 'VENDOR_DECISION_REQUIRES_BOTH','Vendor final selection requires President + Secretary',             null, 'BOOLEAN', 'true', 'true', true),
  ('APPROVAL', 'EXPENSE_APPROVAL_CHAIN_10K', 'Role(s) who can approve expenses ≤ limit',                            null, 'JSON_ARRAY', '["secretary"]', '["secretary"]', true),
  ('APPROVAL', 'EXPENSE_APPROVAL_CHAIN_20K', 'Role(s) who can approve expenses ≤ limit',                            null, 'JSON_ARRAY', '["president"]', '["president"]', true),
  ('APPROVAL', 'EXPENSE_APPROVAL_CHAIN_50K', 'Board vote required for expenses above President limit',              null, 'STRING', '"BOARD_VOTE"', '"BOARD_VOTE"', true),
  -- ESCALATION category
  ('ESCALATION','HOTO_SLA_ESCALATION_DAYS',       'Days overdue before escalation actions',                 null, 'JSON_ARRAY', '[7,14,30]', '[7,14,30]', false),
  ('ESCALATION','HOTO_SLA_DAY7_ACTION',            'Action at 7 days overdue',                               null, 'STRING', '"EMAIL_COMMITTEE"',  '"EMAIL_COMMITTEE"',  false),
  ('ESCALATION','HOTO_SLA_DAY14_ACTION',           'Action at 14 days overdue',                              null, 'STRING', '"EMAIL_URGENT_FLAG"', '"EMAIL_URGENT_FLAG"',false),
  ('ESCALATION','HOTO_SLA_DAY30_ACTION',           'Action at 30 days overdue',                              null, 'STRING', '"AUTO_DRAFT_NOTICE"', '"AUTO_DRAFT_NOTICE"',false),
  ('ESCALATION','SNAG_SLA_WARNING_DAYS',           'Days before snag builder-committed date to warn',        null, 'INTEGER', '7',  '7',  false),
  ('ESCALATION','DEFAULTER_REMINDER_DAYS',         'Days arrears before reminder email to member',           null, 'INTEGER', '30', '30', false),
  ('ESCALATION','PENDING_APPROVAL_REMINDER_HOURS', 'Hours before re-notifying approver of pending item',     null, 'INTEGER', '48', '48', false),
  -- NOTIFICATION category
  ('NOTIFICATION','NOTIFY_HOTO_APPROVAL_NEEDED',   'Recipients when HOTO needs approval',                    null, 'JSON_ARRAY', '["approver"]',                                   '["approver"]',                                   false),
  ('NOTIFICATION','NOTIFY_VOTE_OPENED',             'Recipients when vendor vote opens',                      null, 'JSON_ARRAY', '["all_committee"]',                              '["all_committee"]',                              false),
  ('NOTIFICATION','NOTIFY_BUILDER_SLA_OVERDUE',    'Recipients when builder SLA overdue',                    null, 'JSON_ARRAY', '["committee"]',                                  '["committee"]',                                  false),
  ('NOTIFICATION','NOTIFY_GITHUB_HEALTH_FAIL',     'Recipients for storage outage alert',                    null, 'JSON_ARRAY', '["admin","secretary"]',                          '["admin","secretary"]',                          false),
  ('NOTIFICATION','NOTIFY_ELECTION_COMPLETE',      'Recipients after election bulk update',                   null, 'JSON_ARRAY', '["all_affected","president","secretary"]',       '["all_affected","president","secretary"]',       false),
  ('NOTIFICATION','WEEKLY_DIGEST_ENABLED',         'Send weekly HOTO digest to committee',                   null, 'BOOLEAN', 'true', 'true', false),
  ('NOTIFICATION','WEEKLY_DIGEST_DAY',             'Day of week for weekly digest (0=Sun)',                   null, 'INTEGER', '1', '1', false),
  ('NOTIFICATION','WEEKLY_DIGEST_HOUR',            'Hour (24h) to send weekly digest',                       null, 'INTEGER', '7', '7', false),
  -- VALIDATION category
  ('VALIDATION','HOTO_REQUIRE_DOCS_BEFORE_REVIEW',    'Block UNDER_REVIEW if required docs missing',         null, 'BOOLEAN', 'true',  'true',  false),
  ('VALIDATION','VOTE_REQUIRE_CONFLICT_DECLARATION',   'Force conflict-of-interest declaration before vote',  null, 'BOOLEAN', 'true',  'true',  true),
  ('VALIDATION','PAYMENT_REQUIRE_ELECTRONIC_ABOVE',    'Min amount (₹) requiring electronic payment mode',   null, 'INTEGER', '10000', '10000', true),
  ('VALIDATION','HOTO_EVIDENCE_REQUIRED_BEFORE_UPLOAD','Must select an HOTO item before uploading doc',      null, 'BOOLEAN', 'true',  'true',  false),
  ('VALIDATION','SNAG_SCOPE_REQUIRED_ON_CREATE',       'snag_scope mandatory on snag creation',              null, 'BOOLEAN', 'true',  'true',  false),
  ('VALIDATION','INVITE_EMAIL_DOMAIN_ALLOWLIST',       'Restrict invites to specific email domains (empty = any)', null, 'JSON_ARRAY', '[]', '[]', false)
) AS r(rule_category, rule_code, label, description, byelaw_reference, value_type, current_value, default_value, is_locked)
ON CONFLICT (society_id, rule_code) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- 29. Cron Heartbeats (silence detection for Vercel Cron jobs)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cron_heartbeats (
  id              BIGSERIAL PRIMARY KEY,
  cron_name       TEXT NOT NULL,
  run_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status          TEXT NOT NULL,
  -- 'OK' | 'PARTIAL' | 'FAILED' | 'CIRCUIT_OPEN'
  items_processed INTEGER NOT NULL DEFAULT 0,
  items_failed    INTEGER NOT NULL DEFAULT 0,
  duration_ms     INTEGER,
  error_message   TEXT
);
CREATE INDEX IF NOT EXISTS idx_cron_heartbeats_name
  ON cron_heartbeats(cron_name, run_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 30. Cron Locks (idempotency guard against Vercel Cron duplicate fires)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cron_locks (
  item_type   TEXT NOT NULL,
  item_id     TEXT NOT NULL,
  run_id      UUID NOT NULL,
  acquired_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at  TIMESTAMPTZ NOT NULL DEFAULT NOW() + INTERVAL '10 minutes',
  PRIMARY KEY (item_type, item_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- 31. Email Drafts (pre-generated formal communications, Tier 3 always draft)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS email_drafts (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id             UUID NOT NULL REFERENCES societies(id),
  tier                   INTEGER NOT NULL CHECK (tier IN (1, 2, 3)),
  -- Tier 1: auto-send operational; Tier 2: auto-send with action button;
  -- Tier 3: always DRAFT — Secretary/President must review and send
  triggered_by           TEXT NOT NULL,
  trigger_resource_type  TEXT,
  trigger_resource_id    TEXT,
  recipient_type         TEXT NOT NULL,
  recipient_email        TEXT,
  recipient_name         TEXT,
  subject                TEXT NOT NULL,
  body_html              TEXT NOT NULL,
  body_text              TEXT NOT NULL,
  suggested_sender_name  TEXT NOT NULL,
  suggested_sender_email TEXT NOT NULL,
  status                 TEXT NOT NULL DEFAULT 'DRAFT',
  CHECK (status IN ('DRAFT','REVIEWED','SENT','DISCARDED')),
  reviewed_by            UUID REFERENCES profiles(id),
  reviewed_at            TIMESTAMPTZ,
  sent_by                UUID REFERENCES profiles(id),
  sent_at                TIMESTAMPTZ,
  resend_message_id      TEXT,
  discarded_by           UUID REFERENCES profiles(id),
  discarded_reason       TEXT,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_email_drafts_status
  ON email_drafts(society_id, status, created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 32. HOTO Audit Log (governance-specific audit trail)
-- Separate from existing `audit_logs` (general platform events)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS hoto_audit_log (
  id                BIGSERIAL PRIMARY KEY,
  society_id        UUID NOT NULL REFERENCES societies(id),
  actor_id          UUID REFERENCES profiles(id),
  action            TEXT NOT NULL,
  resource_type     TEXT NOT NULL,
  resource_id       TEXT NOT NULL,
  old_values        JSONB,
  new_values        JSONB,
  byelaw_reference  TEXT,
  ip_hash           TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_hoto_audit_log_resource
  ON hoto_audit_log(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_hoto_audit_log_actor
  ON hoto_audit_log(actor_id, created_at DESC);

-- ─────────────────────────────────────────────────────────────────────────────
-- 33. Seed default feature permissions for 4 roles
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO feature_permissions (society_id, role, feature, enabled, is_locked)
SELECT
  '00000000-0000-0000-0000-000000000001',
  r.role, r.feature, r.enabled, r.is_locked
FROM (VALUES
  -- member
  ('member','hoto.view',             true,  true),
  ('member','snag.view',             true,  true),
  ('member','vendor.view',           true,  true),
  ('member','notice.view',           true,  false),
  -- executive
  ('executive','hoto.view',                 true,  true),
  ('executive','hoto.create',               true,  false),
  ('executive','hoto.upload',               true,  false),
  ('executive','hoto.comment',              true,  false),
  ('executive','hoto.advance_status',       true,  false),
  ('executive','hoto.approve_president',    false, true),
  ('executive','hoto.approve_secretary',    false, true),
  ('executive','hoto.bypass_required_docs', false, true),
  ('executive','snag.view',                 true,  true),
  ('executive','snag.create',               true,  false),
  ('executive','snag.verify_close',         false, true),
  ('executive','snag.delete',               false, true),
  ('executive','vendor.view',               true,  true),
  ('executive','vendor.view_quotes',        true,  false),
  ('executive','vendor.vote',               true,  false),
  ('executive','vendor.open_voting',        false, false),
  ('executive','vendor.final_select',       false, true),
  ('executive','finance.view',              false, false),
  ('executive','finance.enter',             false, false),
  ('executive','finance.approve_10k',       false, true),
  ('executive','finance.approve_20k',       false, true),
  ('executive','finance.open_board_vote',   false, true),
  ('executive','finance.view_member_phones',false, true),
  ('executive','notice.view',               true,  false),
  ('executive','notice.send',               false, false),
  ('executive','audit.view',                true,  false),
  ('executive','users.view_directory',      false, false),
  ('executive','users.invite_member',       false, false),
  ('executive','users.invite_committee',    false, true),
  ('executive','users.change_role',         false, true),
  ('executive','users.deactivate',          false, false),
  ('executive','admin.delegation',          false, true),
  ('executive','admin.elections',           false, true),
  ('executive','admin.permissions',         false, true),
  ('executive','admin.import',              false, false),
  -- secretary
  ('secretary','hoto.view',                 true,  true),
  ('secretary','hoto.create',               true,  false),
  ('secretary','hoto.upload',               true,  false),
  ('secretary','hoto.comment',              true,  false),
  ('secretary','hoto.advance_status',       true,  false),
  ('secretary','hoto.approve_secretary',    true,  true),
  ('secretary','hoto.approve_president',    false, true),
  ('secretary','hoto.bypass_required_docs', true,  true),
  ('secretary','snag.view',                 true,  true),
  ('secretary','snag.create',               true,  false),
  ('secretary','snag.verify_close',         true,  true),
  ('secretary','snag.delete',               false, true),
  ('secretary','vendor.view',               true,  true),
  ('secretary','vendor.view_quotes',        true,  false),
  ('secretary','vendor.vote',               true,  false),
  ('secretary','vendor.open_voting',        true,  false),
  ('secretary','vendor.final_select',       true,  true),
  ('secretary','finance.view',              true,  false),
  ('secretary','finance.enter',             true,  false),
  ('secretary','finance.approve_10k',       true,  true),
  ('secretary','finance.approve_20k',       false, true),
  ('secretary','finance.open_board_vote',   true,  true),
  ('secretary','finance.view_member_phones',true,  true),
  ('secretary','notice.view',               true,  false),
  ('secretary','notice.send',               true,  false),
  ('secretary','audit.view',                true,  false),
  ('secretary','users.view_directory',      true,  false),
  ('secretary','users.invite_member',       true,  false),
  ('secretary','users.invite_committee',    false, true),
  ('secretary','users.change_role',         false, true),
  ('secretary','users.deactivate',          true,  false),
  ('secretary','admin.delegation',          false, true),
  ('secretary','admin.elections',           false, true),
  ('secretary','admin.permissions',         false, true),
  ('secretary','admin.import',              false, false),
  -- president
  ('president','hoto.view',                 true,  true),
  ('president','hoto.create',               true,  false),
  ('president','hoto.upload',               true,  false),
  ('president','hoto.comment',              true,  false),
  ('president','hoto.advance_status',       true,  false),
  ('president','hoto.approve_president',    true,  true),
  ('president','hoto.approve_secretary',    true,  true),
  ('president','hoto.bypass_required_docs', true,  true),
  ('president','snag.view',                 true,  true),
  ('president','snag.create',               true,  false),
  ('president','snag.verify_close',         true,  true),
  ('president','snag.delete',               true,  true),
  ('president','vendor.view',               true,  true),
  ('president','vendor.view_quotes',        true,  false),
  ('president','vendor.vote',               true,  false),
  ('president','vendor.open_voting',        true,  false),
  ('president','vendor.final_select',       true,  true),
  ('president','finance.view',              true,  false),
  ('president','finance.enter',             true,  false),
  ('president','finance.approve_10k',       true,  true),
  ('president','finance.approve_20k',       true,  true),
  ('president','finance.open_board_vote',   false, true),
  ('president','finance.view_member_phones',true,  true),
  ('president','notice.view',               true,  false),
  ('president','notice.send',               true,  false),
  ('president','audit.view',                true,  false),
  ('president','users.view_directory',      true,  false),
  ('president','users.invite_member',       true,  false),
  ('president','users.invite_committee',    true,  true),
  ('president','users.change_role',         true,  true),
  ('president','users.deactivate',          true,  false),
  ('president','admin.delegation',          true,  true),
  ('president','admin.elections',           true,  true),
  ('president','admin.permissions',         true,  true),
  ('president','admin.import',              true,  false)
) AS r(role, feature, enabled, is_locked)
ON CONFLICT (society_id, role, feature) DO NOTHING;

-- ─────────────────────────────────────────────────────────────────────────────
-- 34. RLS policies for new tables
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE privacy_consents        ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_invites          ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_change_log         ENABLE ROW LEVEL SECURITY;
ALTER TABLE election_events         ENABLE ROW LEVEL SECURITY;
ALTER TABLE feature_permissions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_feature_overrides  ENABLE ROW LEVEL SECURITY;
ALTER TABLE upload_queue            ENABLE ROW LEVEL SECURITY;
ALTER TABLE github_api_log          ENABLE ROW LEVEL SECURITY;
ALTER TABLE governance_files        ENABLE ROW LEVEL SECURITY;
ALTER TABLE pdf_generation_jobs     ENABLE ROW LEVEL SECURITY;
ALTER TABLE hoto_items              ENABLE ROW LEVEL SECURITY;
ALTER TABLE hoto_required_docs      ENABLE ROW LEVEL SECURITY;
ALTER TABLE snag_items              ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_requirements     ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendor_candidates       ENABLE ROW LEVEL SECURITY;
ALTER TABLE proxy_authorizations    ENABLE ROW LEVEL SECURITY;
ALTER TABLE votes                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE maintenance_records     ENABLE ROW LEVEL SECURITY;
ALTER TABLE corpus_fund_records     ENABLE ROW LEVEL SECURITY;
ALTER TABLE governance_expenses     ENABLE ROW LEVEL SECURITY;
ALTER TABLE hoto_comments           ENABLE ROW LEVEL SECURITY;
ALTER TABLE formal_notices          ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_delegations    ENABLE ROW LEVEL SECURITY;
ALTER TABLE rules                   ENABLE ROW LEVEL SECURITY;
ALTER TABLE cron_heartbeats         ENABLE ROW LEVEL SECURITY;
ALTER TABLE cron_locks              ENABLE ROW LEVEL SECURITY;
ALTER TABLE email_drafts            ENABLE ROW LEVEL SECURITY;
ALTER TABLE hoto_audit_log          ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_config           ENABLE ROW LEVEL SECURITY;

-- HOTO items: all committee can read; executive+ can insert; anon blocked
DROP POLICY IF EXISTS "hoto_items_read" ON hoto_items;
CREATE POLICY "hoto_items_read" ON hoto_items
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

DROP POLICY IF EXISTS "hoto_items_insert" ON hoto_items;
CREATE POLICY "hoto_items_insert" ON hoto_items
  FOR INSERT WITH CHECK (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

DROP POLICY IF EXISTS "hoto_items_update" ON hoto_items;
CREATE POLICY "hoto_items_update" ON hoto_items
  FOR UPDATE USING (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

-- Snag items: all committee can read; executive+ can insert
DROP POLICY IF EXISTS "snag_items_read" ON snag_items;
CREATE POLICY "snag_items_read" ON snag_items
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

DROP POLICY IF EXISTS "snag_items_insert" ON snag_items;
CREATE POLICY "snag_items_insert" ON snag_items
  FOR INSERT WITH CHECK (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

DROP POLICY IF EXISTS "snag_items_update" ON snag_items;
CREATE POLICY "snag_items_update" ON snag_items
  FOR UPDATE USING (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

-- Vendor requirements + candidates: all committee can read
DROP POLICY IF EXISTS "vendor_req_read" ON vendor_requirements;
CREATE POLICY "vendor_req_read" ON vendor_requirements
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

DROP POLICY IF EXISTS "vendor_candidates_read" ON vendor_candidates;
CREATE POLICY "vendor_candidates_read" ON vendor_candidates
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

-- Votes: each user sees only their own vote record (no peeking at others)
DROP POLICY IF EXISTS "votes_read_own" ON votes;
CREATE POLICY "votes_read_own" ON votes
  FOR SELECT USING (voter_id = auth.uid());

DROP POLICY IF EXISTS "votes_insert" ON votes;
CREATE POLICY "votes_insert" ON votes
  FOR INSERT WITH CHECK (
    voter_id = auth.uid()
    AND get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

-- Feature permissions: committee can read; only admin can write
DROP POLICY IF EXISTS "feature_perms_read" ON feature_permissions;
CREATE POLICY "feature_perms_read" ON feature_permissions
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

DROP POLICY IF EXISTS "feature_perms_write" ON feature_permissions;
CREATE POLICY "feature_perms_write" ON feature_permissions
  FOR ALL USING (is_admin_user(auth.uid()));

-- User feature overrides: user sees their own; admin sees all
DROP POLICY IF EXISTS "user_overrides_read" ON user_feature_overrides;
CREATE POLICY "user_overrides_read" ON user_feature_overrides
  FOR SELECT USING (
    user_id = auth.uid() OR is_admin_user(auth.uid())
  );

DROP POLICY IF EXISTS "user_overrides_write" ON user_feature_overrides;
CREATE POLICY "user_overrides_write" ON user_feature_overrides
  FOR ALL USING (is_admin_user(auth.uid()));

-- Maintenance records: finance-enabled users + admin
DROP POLICY IF EXISTS "maintenance_records_read" ON maintenance_records;
CREATE POLICY "maintenance_records_read" ON maintenance_records
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('secretary','president')
    OR is_admin_user(auth.uid())
    OR EXISTS (
      SELECT 1 FROM user_feature_overrides
      WHERE user_id = auth.uid() AND feature = 'finance.view'
        AND enabled = true AND revoked_at IS NULL
        AND (expires_at IS NULL OR expires_at > NOW())
    )
  );

-- Corpus fund records: same as maintenance
DROP POLICY IF EXISTS "corpus_fund_read" ON corpus_fund_records;
CREATE POLICY "corpus_fund_read" ON corpus_fund_records
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('secretary','president')
    OR is_admin_user(auth.uid())
    OR EXISTS (
      SELECT 1 FROM user_feature_overrides
      WHERE user_id = auth.uid() AND feature = 'finance.view'
        AND enabled = true AND revoked_at IS NULL
        AND (expires_at IS NULL OR expires_at > NOW())
    )
  );

-- Rules: all committee can read (for display); only admin can write
DROP POLICY IF EXISTS "rules_read" ON rules;
CREATE POLICY "rules_read" ON rules
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

DROP POLICY IF EXISTS "rules_write" ON rules;
CREATE POLICY "rules_write" ON rules
  FOR ALL USING (is_admin_user(auth.uid()));

-- Comments: all committee can read and create
DROP POLICY IF EXISTS "hoto_comments_read" ON hoto_comments;
CREATE POLICY "hoto_comments_read" ON hoto_comments
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

DROP POLICY IF EXISTS "hoto_comments_insert" ON hoto_comments;
CREATE POLICY "hoto_comments_insert" ON hoto_comments
  FOR INSERT WITH CHECK (
    author_id = auth.uid()
    AND get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

-- Governance files: all committee can read; executive+ can insert
DROP POLICY IF EXISTS "governance_files_read" ON governance_files;
CREATE POLICY "governance_files_read" ON governance_files
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

DROP POLICY IF EXISTS "governance_files_insert" ON governance_files;
CREATE POLICY "governance_files_insert" ON governance_files
  FOR INSERT WITH CHECK (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

-- Role change log: admin + secretary + president can read
DROP POLICY IF EXISTS "role_change_log_read" ON role_change_log;
CREATE POLICY "role_change_log_read" ON role_change_log
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('secretary','president')
    OR is_admin_user(auth.uid())
  );

-- Email drafts: secretary + president can read/update; system can insert
DROP POLICY IF EXISTS "email_drafts_read" ON email_drafts;
CREATE POLICY "email_drafts_read" ON email_drafts
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('secretary','president')
    OR is_admin_user(auth.uid())
  );

-- HOTO audit log: secretary + president + admin can read
DROP POLICY IF EXISTS "hoto_audit_read" ON hoto_audit_log;
CREATE POLICY "hoto_audit_read" ON hoto_audit_log
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
    OR is_admin_user(auth.uid())
  );

-- Upload queue: committee can see their own uploads; admin sees all
DROP POLICY IF EXISTS "upload_queue_read" ON upload_queue;
CREATE POLICY "upload_queue_read" ON upload_queue
  FOR SELECT USING (
    uploaded_by = auth.uid() OR is_admin_user(auth.uid())
  );

-- Approval delegations: all committee can read (affects their approval routing)
DROP POLICY IF EXISTS "approval_delegations_read" ON approval_delegations;
CREATE POLICY "approval_delegations_read" ON approval_delegations
  FOR SELECT USING (
    get_portal_role(auth.uid()) IN ('executive','secretary','president')
  );

-- System config: admin only
DROP POLICY IF EXISTS "system_config_admin" ON system_config;
CREATE POLICY "system_config_admin" ON system_config
  FOR ALL USING (is_admin_user(auth.uid()));

-- Member invites: admin can manage; invited user can read their own
DROP POLICY IF EXISTS "member_invites_admin" ON member_invites;
CREATE POLICY "member_invites_admin" ON member_invites
  FOR ALL USING (is_admin_user(auth.uid()));

-- Cron tables: service role only (no RLS bypass needed — these use service client)
DROP POLICY IF EXISTS "cron_heartbeats_admin" ON cron_heartbeats;
CREATE POLICY "cron_heartbeats_admin" ON cron_heartbeats
  FOR ALL USING (is_admin_user(auth.uid()));

DROP POLICY IF EXISTS "cron_locks_admin" ON cron_locks;
CREATE POLICY "cron_locks_admin" ON cron_locks
  FOR ALL USING (is_admin_user(auth.uid()));

-- Github API log: admin only
DROP POLICY IF EXISTS "github_api_log_admin" ON github_api_log;
CREATE POLICY "github_api_log_admin" ON github_api_log
  FOR ALL USING (is_admin_user(auth.uid()));

-- ─────────────────────────────────────────────────────────────────────────────
-- 35. Trigger: auto-update hoto_items.last_updated_at
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_hoto_last_updated()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.last_updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS hoto_items_updated ON hoto_items;
CREATE TRIGGER hoto_items_updated
  BEFORE UPDATE ON hoto_items
  FOR EACH ROW EXECUTE FUNCTION update_hoto_last_updated();
