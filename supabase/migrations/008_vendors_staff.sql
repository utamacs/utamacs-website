-- ═══════════════════════════════════════════════════════════════
-- 008_vendors_staff.sql
-- Vendors and work orders
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE vendors (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id            uuid NOT NULL REFERENCES societies(id),
  name                  text NOT NULL,
  category              text NOT NULL
                        CHECK (category IN ('Plumbing','Electrical','Security','Housekeeping',
                                            'Lift','Pest_Control','Landscaping','IT',
                                            'Civil','Painting','CCTV','Other')),
  contact_person        text,
  phone                 text,
  email                 text,
  gstin                 text,
  pan                   text,
  bank_account_encrypted text,
  bank_ifsc             text,
  contract_start        date,
  contract_end          date,
  is_active             boolean NOT NULL DEFAULT true,
  notes                 text,
  created_at            timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE work_orders (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id      uuid NOT NULL REFERENCES societies(id),
  vendor_id       uuid NOT NULL REFERENCES vendors(id),
  complaint_id    uuid REFERENCES complaints(id),
  title           text NOT NULL,
  description     text,
  status          text NOT NULL DEFAULT 'draft'
                  CHECK (status IN ('draft','issued','in_progress','completed','disputed','closed')),
  issued_at       timestamptz,
  deadline        timestamptz,
  completed_at    timestamptz,
  quoted_amount   numeric(10,2),
  final_amount    numeric(10,2),
  invoice_storage_key text,
  notes           text,
  created_by      uuid NOT NULL REFERENCES auth.users(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER trg_workorders_updated_at
  BEFORE UPDATE ON work_orders
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Backfill vendor_id on expenses (FK defined now that vendors table exists)
ALTER TABLE expenses ADD CONSTRAINT fk_expense_vendor
  FOREIGN KEY (vendor_id) REFERENCES vendors(id);

-- Indexes
CREATE INDEX idx_vendors_society ON vendors(society_id, is_active);
CREATE INDEX idx_work_orders_vendor ON work_orders(vendor_id);
CREATE INDEX idx_work_orders_complaint ON work_orders(complaint_id);
CREATE INDEX idx_work_orders_status ON work_orders(status);
