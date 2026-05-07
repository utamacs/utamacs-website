-- ═══════════════════════════════════════════════════════════════
-- 039_policies.sql
-- Policies module: policy documents + member acknowledgements
-- DPDPA: acknowledgement records are immutable consent history
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS policies (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id              uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  title                   text NOT NULL CHECK (length(title) <= 200),
  description             text CHECK (length(description) <= 1000),
  policy_type             text NOT NULL DEFAULT 'text'
                          CHECK (policy_type IN ('text', 'pdf', 'video_url')),
  body                    text,                     -- for type='text'
  document_key            text,                     -- Supabase Storage key for PDF
  video_url               text CHECK (length(video_url) <= 500),
  version                 int NOT NULL DEFAULT 1,
  effective_date          date NOT NULL DEFAULT CURRENT_DATE,
  acknowledgement_required boolean NOT NULL DEFAULT false,
  gate_portal_access      boolean NOT NULL DEFAULT false,  -- blocks portal until acked
  status                  text NOT NULL DEFAULT 'draft'
                          CHECK (status IN ('draft', 'active', 'superseded')),
  superseded_by           uuid REFERENCES policies(id) ON DELETE SET NULL,
  created_by              uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at              timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT chk_policy_content CHECK (
    (policy_type = 'text' AND body IS NOT NULL) OR
    (policy_type = 'pdf'  AND document_key IS NOT NULL) OR
    (policy_type = 'video_url' AND video_url IS NOT NULL)
  )
);

COMMENT ON COLUMN policies.document_key        IS 'Supabase Storage key in policy-documents bucket';
COMMENT ON COLUMN policies.gate_portal_access  IS 'When true, members without acknowledgement are blocked from the portal';

-- ── policy_acknowledgements — immutable consent log ───────────────────────────
-- DPDPA: no UPDATE or DELETE policy on this table

CREATE TABLE IF NOT EXISTS policy_acknowledgements (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  policy_id   uuid NOT NULL REFERENCES policies(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  -- DPDPA personal data: identity of consent giver
  acked_at    timestamptz NOT NULL DEFAULT now(),
  ip_hash     text,                         -- hashed for audit, not reversible
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (policy_id, user_id)               -- one acknowledgement per member per policy
);

COMMENT ON COLUMN policy_acknowledgements.user_id  IS 'DPDPA personal data: identity of consent giver';
COMMENT ON COLUMN policy_acknowledgements.ip_hash  IS 'DPDPA: hashed IP for audit trail — not reversible';
COMMENT ON TABLE  policy_acknowledgements           IS 'Immutable consent log — no UPDATE/DELETE policies';

-- ── RLS ───────────────────────────────────────────────────────────────────────

ALTER TABLE policies                ENABLE ROW LEVEL SECURITY;
ALTER TABLE policy_acknowledgements ENABLE ROW LEVEL SECURITY;

-- Members see active policies for their society
CREATE POLICY "member_view_active_policies" ON policies FOR SELECT
  USING (
    status = 'active'
    AND society_id = (SELECT society_id FROM profiles WHERE id = auth.uid() LIMIT 1)
  );

-- Execs see all policies (including drafts/superseded)
CREATE POLICY "exec_view_all_policies" ON policies FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = policies.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

CREATE POLICY "exec_manage_policies" ON policies FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = policies.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

-- Members can insert their own acknowledgement (append-only)
CREATE POLICY "member_ack_policy" ON policy_acknowledgements FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Members see their own acks; execs see all
CREATE POLICY "member_view_own_ack" ON policy_acknowledgements FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND r.role IN ('executive', 'admin')
    )
  );

-- NO UPDATE or DELETE policies — acknowledgements are immutable

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_policies_society_status  ON policies(society_id, status);
CREATE INDEX IF NOT EXISTS idx_policies_gate            ON policies(society_id, gate_portal_access) WHERE gate_portal_access = true;
CREATE INDEX IF NOT EXISTS idx_policy_acks_user         ON policy_acknowledgements(user_id);
CREATE INDEX IF NOT EXISTS idx_policy_acks_policy       ON policy_acknowledgements(policy_id);
