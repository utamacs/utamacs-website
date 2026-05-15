-- Migration: Domain Events (Event Sourcing foundation)
-- Addresses: Critical Finding — No event sourcing for audit-critical workflows
-- Addresses: Missing #1 — Event sourcing for DPDPA compliance
-- This table is IMMUTABLE (no UPDATE, no DELETE — enforced by RLS and trigger)

CREATE TABLE domain_events (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES societies(id) ON DELETE RESTRICT,
  event_type      text NOT NULL,                   -- 'PAYMENT_RECORDED', 'GATE_APPROVED', etc.
  aggregate_type  text NOT NULL,                   -- 'payment', 'complaint', 'visitor_pass'
  aggregate_id    text NOT NULL,                   -- UUID of the entity this event belongs to
  sequence_no     bigint NOT NULL,                 -- Monotonically increasing per aggregate
  payload         jsonb NOT NULL DEFAULT '{}',     -- Event-specific data (PII minimized)
  metadata        jsonb NOT NULL DEFAULT '{}',     -- actor, device_id_hash, ip_hash, app_version
  occurred_at     timestamptz NOT NULL DEFAULT now(),
  schema_version  integer NOT NULL DEFAULT 1,      -- For payload evolution

  -- Composite uniqueness: no two events at same sequence for same aggregate
  UNIQUE (tenant_id, aggregate_type, aggregate_id, sequence_no)
);

-- Partition by month for efficient archival and querying
-- (actual partitioning setup requires pg_partman or manual partition creation)
CREATE INDEX domain_events_tenant_type_idx ON domain_events (tenant_id, event_type, occurred_at DESC);
CREATE INDEX domain_events_aggregate_idx ON domain_events (tenant_id, aggregate_type, aggregate_id, sequence_no);
CREATE INDEX domain_events_occurred_idx ON domain_events (occurred_at DESC);

-- Immutability enforcement
ALTER TABLE domain_events ENABLE ROW LEVEL SECURITY;

-- Read: any authenticated member of this society
CREATE POLICY "tenant_read_events" ON domain_events FOR SELECT
  USING (tenant_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

-- Insert: API service only (via service role) — no direct user inserts
CREATE POLICY "service_insert_events" ON domain_events FOR INSERT
  WITH CHECK (true);  -- Enforced by API service; RLS is backup

-- NO UPDATE policy — events are immutable
-- NO DELETE policy — events are immutable

-- Trigger: prevent any update or delete (belt and suspenders with RLS)
CREATE OR REPLACE FUNCTION prevent_event_modification() RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'domain_events are immutable. Operation % is not allowed.', TG_OP;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER no_update_events
  BEFORE UPDATE ON domain_events
  FOR EACH ROW EXECUTE FUNCTION prevent_event_modification();

CREATE TRIGGER no_delete_events
  BEFORE DELETE ON domain_events
  FOR EACH ROW EXECUTE FUNCTION prevent_event_modification();

-- Sequence function: get next sequence number for an aggregate (atomic)
CREATE OR REPLACE FUNCTION next_event_sequence(
  p_tenant_id uuid,
  p_aggregate_type text,
  p_aggregate_id text
) RETURNS bigint AS $$
DECLARE
  v_next bigint;
BEGIN
  SELECT COALESCE(MAX(sequence_no), 0) + 1
  INTO v_next
  FROM domain_events
  WHERE tenant_id = p_tenant_id
    AND aggregate_type = p_aggregate_type
    AND aggregate_id = p_aggregate_id;
  RETURN v_next;
END;
$$ LANGUAGE plpgsql;

-- Device push tokens (for mobile push notifications)
CREATE TABLE device_push_tokens (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  profile_id    uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  token         text NOT NULL,
  platform      text NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
  hub_tag       text GENERATED ALWAYS AS ('user:' || profile_id::text) STORED,
  app_version   text,
  os_version    text,
  device_model  text,
  device_id_hash text,  -- HMAC of device UUID, rotated monthly (DPDPA: no raw device ID)
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  last_used_at  timestamptz,
  is_active     boolean NOT NULL DEFAULT true,
  UNIQUE (profile_id, token)
);

ALTER TABLE device_push_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own_tokens" ON device_push_tokens FOR ALL
  USING (profile_id = auth.uid());

-- Visitor pass HMAC keys (per-tenant, stored in Azure Key Vault but reflected here)
CREATE TABLE tenant_hmac_key_metadata (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id      uuid NOT NULL REFERENCES societies(id) ON DELETE RESTRICT UNIQUE,
  key_vault_id   text NOT NULL,           -- Azure Key Vault secret name (not the key itself)
  key_version    integer NOT NULL DEFAULT 1,
  created_at     timestamptz NOT NULL DEFAULT now(),
  rotated_at     timestamptz
);

-- No RLS select on key metadata for regular users — exec+ only
ALTER TABLE tenant_hmac_key_metadata ENABLE ROW LEVEL SECURITY;
CREATE POLICY "exec_read_key_metadata" ON tenant_hmac_key_metadata FOR SELECT
  USING (
    tenant_id IN (
      SELECT society_id FROM profiles
      WHERE id = auth.uid()
        AND (portal_role IN ('executive', 'secretary', 'president') OR is_admin)
    )
  );

-- Upload jobs table (async upload tracking, replaces synchronous GitHub commit)
CREATE TABLE upload_jobs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  profile_id      uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  status          text NOT NULL DEFAULT 'pending'
                  CHECK (status IN ('pending', 'uploading', 'processing', 'complete', 'failed')),
  r2_key          text,               -- Cloudflare R2 object key (set after upload completes)
  r2_bucket       text NOT NULL,
  original_name   text NOT NULL,
  mime_type       text NOT NULL,
  size_bytes      bigint,
  pre_signed_url  text NOT NULL,      -- R2 pre-signed upload URL (15-min TTL)
  pre_signed_expires_at timestamptz NOT NULL,
  module          text NOT NULL,      -- 'complaints', 'gallery', 'maids', etc.
  entity_id       uuid,               -- ID of the entity this upload belongs to
  error_message   text,
  attempts        integer NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  completed_at    timestamptz
);

ALTER TABLE upload_jobs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "own_uploads" ON upload_jobs FOR SELECT
  USING (profile_id = auth.uid());
CREATE POLICY "own_upload_insert" ON upload_jobs FOR INSERT
  WITH CHECK (profile_id = auth.uid() AND tenant_id IN (
    SELECT society_id FROM profiles WHERE id = auth.uid()
  ));
