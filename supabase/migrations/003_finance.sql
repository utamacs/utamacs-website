-- ═══════════════════════════════════════════════════════════════
-- 003_finance.sql
-- Finance module: billing periods, dues, payments (immutable), expenses
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE billing_periods (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id    uuid NOT NULL REFERENCES societies(id),
  name          text NOT NULL,
  start_date    date NOT NULL,
  end_date      date NOT NULL,
  due_date      date NOT NULL,
  base_amount   numeric(10,2) NOT NULL,
  is_active     boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE maintenance_dues (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id),
  unit_id             uuid NOT NULL REFERENCES units(id),
  user_id             uuid NOT NULL REFERENCES auth.users(id),
  billing_period_id   uuid REFERENCES billing_periods(id),
  base_amount         numeric(10,2) NOT NULL,
  penalty_amount      numeric(10,2) NOT NULL DEFAULT 0,
  gst_amount          numeric(10,2) NOT NULL DEFAULT 0,
  total_amount        numeric(10,2) GENERATED ALWAYS AS
                      (base_amount + penalty_amount + gst_amount) STORED,
  status              text NOT NULL DEFAULT 'pending'
                      CHECK (status IN ('pending','partially_paid','paid','overdue','waived')),
  due_date            date NOT NULL,
  paid_at             timestamptz,
  waived_by           uuid REFERENCES auth.users(id),
  waiver_reason       text,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

-- IMMUTABLE: no UPDATE or DELETE RLS policies will be created
CREATE TABLE payments (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id),
  dues_id             uuid REFERENCES maintenance_dues(id),
  user_id             uuid NOT NULL REFERENCES auth.users(id),
  amount              numeric(10,2) NOT NULL CHECK (amount > 0),
  payment_mode        text NOT NULL DEFAULT 'cash'
                      CHECK (payment_mode IN ('cash','cheque','upi','neft','rtgs','online')),
  transaction_ref     text,
  receipt_number      text UNIQUE NOT NULL,
  receipt_storage_key text,
  gst_invoice_no      text,
  tds_deducted        numeric(10,2) NOT NULL DEFAULT 0,
  recorded_by         uuid REFERENCES auth.users(id),
  paid_at             timestamptz NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE expense_categories (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id       uuid NOT NULL REFERENCES societies(id),
  name             text NOT NULL,
  gst_applicable   boolean NOT NULL DEFAULT false,
  tds_applicable   boolean NOT NULL DEFAULT false,
  UNIQUE(society_id, name)
);

CREATE TABLE expenses (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id            uuid NOT NULL REFERENCES societies(id),
  category_id           uuid REFERENCES expense_categories(id),
  vendor_id             uuid,
  description           text NOT NULL,
  amount                numeric(10,2) NOT NULL,
  gst_amount            numeric(10,2) NOT NULL DEFAULT 0,
  tds_deducted          numeric(10,2) NOT NULL DEFAULT 0,
  net_payable           numeric(10,2) GENERATED ALWAYS AS
                        (amount + gst_amount - tds_deducted) STORED,
  bill_number           text,
  bill_date             date,
  payment_date          date,
  approved_by           uuid REFERENCES auth.users(id),
  receipt_storage_key   text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  created_by            uuid REFERENCES auth.users(id)
);

-- Auto-generate receipt number: UTA-RCP-2025-00001
CREATE SEQUENCE receipt_seq START 1;
CREATE OR REPLACE FUNCTION generate_receipt_number()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.receipt_number := 'UTA-RCP-' || to_char(now(), 'YYYY') || '-' ||
    lpad(nextval('receipt_seq')::text, 5, '0');
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_payment_receipt
  BEFORE INSERT ON payments
  FOR EACH ROW WHEN (NEW.receipt_number IS NULL OR NEW.receipt_number = '')
  EXECUTE FUNCTION generate_receipt_number();

CREATE TRIGGER trg_dues_updated_at
  BEFORE UPDATE ON maintenance_dues
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Indexes
CREATE INDEX idx_dues_society ON maintenance_dues(society_id);
CREATE INDEX idx_dues_user ON maintenance_dues(user_id);
CREATE INDEX idx_dues_status ON maintenance_dues(status);
CREATE INDEX idx_payments_dues ON payments(dues_id);
CREATE INDEX idx_payments_user ON payments(user_id);
CREATE INDEX idx_expenses_society ON expenses(society_id);
