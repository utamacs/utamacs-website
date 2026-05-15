-- Migration 095: Sprint 2 Finance — online payments, expense approvals, GST enforcement
-- Adds: online_payment_orders, expense approval columns + audit table, GST threshold rule,
-- Razorpay toggle rule, and EXPENSE_APPROVAL_CHAIN rules (if not already seeded).

-- ── 1. Online Payment Orders (Razorpay) ────────────────────────────────────

CREATE TABLE IF NOT EXISTS online_payment_orders (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id          uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  dues_id             uuid NOT NULL REFERENCES maintenance_dues(id),
  user_id             uuid NOT NULL REFERENCES profiles(id),
  razorpay_order_id   text NOT NULL UNIQUE,
  amount              numeric(12,2) NOT NULL,
  currency            text NOT NULL DEFAULT 'INR',
  status              text NOT NULL DEFAULT 'created'
                        CHECK (status IN ('created','paid','failed','expired')),
  razorpay_payment_id text,
  razorpay_signature  text,
  payment_id          uuid REFERENCES payments(id),
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_oporders_dues      ON online_payment_orders(dues_id);
CREATE INDEX IF NOT EXISTS idx_oporders_user      ON online_payment_orders(user_id);
CREATE INDEX IF NOT EXISTS idx_oporders_rp_order  ON online_payment_orders(razorpay_order_id);
CREATE INDEX IF NOT EXISTS idx_oporders_society   ON online_payment_orders(society_id);

ALTER TABLE online_payment_orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_own_orders" ON online_payment_orders FOR SELECT
  USING (user_id = auth.uid() OR EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- Orders are immutable — no RLS update/delete policy

-- ── 2. Expense Approval Columns & Audit Table ──────────────────────────────

ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS approval_status text NOT NULL DEFAULT 'pending'
    CHECK (approval_status IN ('pending','approved','rejected')),
  ADD COLUMN IF NOT EXISTS approval_tier   int  NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rejection_notes text;

CREATE TABLE IF NOT EXISTS expense_approvals (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  expense_id  uuid NOT NULL REFERENCES expenses(id),
  approver_id uuid NOT NULL REFERENCES profiles(id),
  decision    text NOT NULL CHECK (decision IN ('approved','rejected')),
  tier        int  NOT NULL DEFAULT 1,
  notes       text,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_exp_approvals_expense  ON expense_approvals(expense_id);
CREATE INDEX IF NOT EXISTS idx_exp_approvals_approver ON expense_approvals(approver_id);

ALTER TABLE expense_approvals ENABLE ROW LEVEL SECURITY;

-- Exec can read all approvals; members see nothing (approval records are exec-internal)
CREATE POLICY "exec_read_approvals" ON expense_approvals FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
    AND society_id = expense_approvals.society_id
  ));

-- No DELETE on expense_approvals — immutable audit trail
CREATE POLICY "exec_insert_approvals" ON expense_approvals FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid()
    AND (portal_role IN ('executive','secretary','president') OR is_admin)
  ));

-- ── 3. Rules: GST Threshold + Razorpay Toggle ─────────────────────────────

-- GST_THRESHOLD_MONTHLY — maintenance below this (₹7,500/month) is GST-exempt per CBIC circular
INSERT INTO rules (society_id, rule_code, rule_category, label, description, default_value, current_value, value_type, is_locked)
SELECT
  id,
  'GST_THRESHOLD_MONTHLY',
  'Finance',
  'GST-exempt threshold — monthly maintenance (₹)',
  'Monthly maintenance amount below which GST is not levied (CBIC circular: ₹7,500/month).',
  '7500'::jsonb,
  '7500'::jsonb,
  'DECIMAL',
  false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;

-- RAZORPAY_ENABLED — disabled by default; society enables when merchant account is live
INSERT INTO rules (society_id, rule_code, rule_category, label, description, default_value, current_value, value_type, is_locked)
SELECT
  id,
  'RAZORPAY_ENABLED',
  'Finance',
  'Enable Razorpay online payments',
  'When true, members see a "Pay Online" button on dues using the configured Razorpay credentials.',
  'false'::jsonb,
  'false'::jsonb,
  'BOOLEAN',
  false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;

-- Ensure EXPENSE_APPROVAL_CHAIN rules exist (seeded in migration 025 but using old schema)
INSERT INTO rules (society_id, rule_code, rule_category, label, description, default_value, current_value, value_type, is_locked)
SELECT
  id,
  'EXPENSE_APPROVAL_CHAIN_10K',
  'Finance',
  'Expense approver role — 10K–20K',
  'Portal role required to approve expenses between ₹10,000 and ₹20,000.',
  '"secretary"'::jsonb,
  '"secretary"'::jsonb,
  'STRING',
  false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;

INSERT INTO rules (society_id, rule_code, rule_category, label, description, default_value, current_value, value_type, is_locked)
SELECT
  id,
  'EXPENSE_APPROVAL_CHAIN_20K',
  'Finance',
  'Expense approver role — 20K–50K',
  'Portal role required to approve expenses between ₹20,000 and ₹50,000.',
  '"president"'::jsonb,
  '"president"'::jsonb,
  'STRING',
  false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;

INSERT INTO rules (society_id, rule_code, rule_category, label, description, default_value, current_value, value_type, is_locked)
SELECT
  id,
  'EXPENSE_APPROVAL_CHAIN_50K',
  'Finance',
  'Expense approver role — above 50K',
  'Portal role required to approve expenses above ₹50,000 (normally president or board vote).',
  '"president"'::jsonb,
  '"president"'::jsonb,
  'STRING',
  false
FROM societies
ON CONFLICT (society_id, rule_code) DO NOTHING;
