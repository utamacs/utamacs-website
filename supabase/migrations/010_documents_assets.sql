-- ═══════════════════════════════════════════════════════════════
-- 010_documents_assets.sql
-- Documents (versioned), infrastructure assets, maintenance logs
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE documents (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id),
  title           text NOT NULL,
  description     text,
  category        text NOT NULL DEFAULT 'General'
                  CHECK (category IN ('Bylaws','Minutes','Financial','Legal',
                                      'Circulars','Forms','Other')),
  storage_key     text NOT NULL,
  file_name       text,
  mime_type       text,
  file_size_bytes int,
  version         int NOT NULL DEFAULT 1,
  parent_id       uuid REFERENCES documents(id),
  is_public       boolean NOT NULL DEFAULT false,
  requires_role   text NOT NULL DEFAULT 'member'
                  CHECK (requires_role IN ('member','executive','admin')),
  created_by      uuid NOT NULL REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE infrastructure_assets (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id),
  name                text NOT NULL,
  category            text NOT NULL
                      CHECK (category IN ('Lift','Generator','Pump','CCTV',
                                          'Fire_Safety','Gate','Electrical','Other')),
  make                text,
  model               text,
  serial_number       text,
  installation_date   date,
  warranty_expiry     date,
  next_service_date   date,
  last_service_date   date,
  amc_vendor_id       uuid REFERENCES vendors(id),
  amc_start           date,
  amc_end             date,
  amc_amount          numeric(10,2),
  is_active           boolean NOT NULL DEFAULT true,
  notes               text,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE asset_maintenance_logs (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  asset_id              uuid NOT NULL REFERENCES infrastructure_assets(id) ON DELETE CASCADE,
  service_date          date NOT NULL,
  service_type          text NOT NULL,
  description           text,
  cost                  numeric(10,2),
  vendor_id             uuid REFERENCES vendors(id),
  invoice_storage_key   text,
  next_service_date     date,
  performed_by          text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by            uuid REFERENCES auth.users(id)
);

-- Seed key infrastructure assets for UTA MACS
INSERT INTO infrastructure_assets (society_id, name, category)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'Block A Lift',     'Lift'),
  ('00000000-0000-0000-0000-000000000001', 'Block B Lift',     'Lift'),
  ('00000000-0000-0000-0000-000000000001', 'DG Set 1',         'Generator'),
  ('00000000-0000-0000-0000-000000000001', 'WTP System',       'Pump'),
  ('00000000-0000-0000-0000-000000000001', 'STP System',       'Pump'),
  ('00000000-0000-0000-0000-000000000001', 'CCTV Network',     'CCTV'),
  ('00000000-0000-0000-0000-000000000001', 'Main Gate',        'Gate'),
  ('00000000-0000-0000-0000-000000000001', 'Fire Suppression', 'Fire_Safety');

CREATE TRIGGER trg_documents_updated_at
  BEFORE UPDATE ON documents
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Indexes
CREATE INDEX idx_documents_society ON documents(society_id, category);
CREATE INDEX idx_documents_public ON documents(is_public) WHERE is_public = true;
CREATE INDEX idx_assets_society ON infrastructure_assets(society_id, category);
CREATE INDEX idx_asset_logs_asset ON asset_maintenance_logs(asset_id, service_date DESC);
