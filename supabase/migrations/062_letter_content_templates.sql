-- Migration 062: Letter content templates library
-- Pre-built body text for common society letters; supports {{variable}} substitution

CREATE TABLE IF NOT EXISTS letter_content_templates (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid REFERENCES societies(id) ON DELETE CASCADE,  -- NULL = built-in (shared)
  name        text NOT NULL CHECK (length(name) <= 150),
  category    text NOT NULL CHECK (category IN ('noc','membership','financial','notice','general','legal')),
  subject     text NOT NULL CHECK (length(subject) <= 300),
  body_md     text NOT NULL,   -- Markdown body; {{variable}} placeholders auto-filled
  variables   text[] NOT NULL DEFAULT '{}',  -- list of placeholder names used in body_md
  is_built_in boolean NOT NULL DEFAULT false,
  is_active   boolean NOT NULL DEFAULT true,
  created_by  uuid REFERENCES auth.users(id),
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_letter_templates_category
  ON letter_content_templates(category, is_active) WHERE is_active;

ALTER TABLE letter_content_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "read_letter_content_templates" ON letter_content_templates FOR SELECT
  USING (
    is_built_in = true
    OR society_id IN (SELECT p.society_id FROM profiles p WHERE p.id = auth.uid())
  );

CREATE POLICY "exec_manage_letter_content_templates" ON letter_content_templates FOR ALL
  USING (
    NOT is_built_in
    AND EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid()
        AND (p.portal_role IN ('executive','secretary','president') OR p.is_admin)
    )
  );

-- ── Built-in letter content templates ────────────────────────────────────────

INSERT INTO letter_content_templates (name, category, subject, body_md, variables, is_built_in) VALUES

('No Objection Certificate (Sale)',
 'noc',
 'No Objection Certificate for Sale of Flat {{unit_number}}',
 E'This is to certify that **{{member_name}}**, the registered owner of Flat **{{unit_number}}**, {{block}}, {{society_name}}, Kondakal, Shankarpalle — 501203, Ranga Reddy District, Telangana, has **no outstanding dues** towards maintenance, corpus fund, or any other charges as on the date of this letter.\n\nAccordingly, the Society has no objection to the sale / transfer of the above-mentioned flat to the prospective buyer, subject to the buyer executing the necessary Society membership formalities and transfer fee of ₹{{transfer_fee}} as per the byelaws.\n\nThis certificate is issued at the request of the owner and is valid for **30 days** from the date of issue.',
 ARRAY['member_name','unit_number','block','society_name','transfer_fee'],
 true),

('No Objection Certificate (Rental)',
 'noc',
 'No Objection Certificate for Renting Flat {{unit_number}}',
 E'This is to certify that **{{member_name}}**, the registered owner of Flat **{{unit_number}}**, {{block}}, {{society_name}}, is permitted to rent out the above flat to **{{tenant_name}}** for a period of **{{tenancy_period}}** commencing from {{tenancy_start}}.\n\nThe Society has no objection to the said tenancy, provided the tenant complies with all Society rules and byelaws. The owner remains responsible for all Society dues and the conduct of the tenant.\n\nThe tenant shall be required to complete KYC verification with the Society within 30 days of occupation.',
 ARRAY['member_name','unit_number','block','society_name','tenant_name','tenancy_period','tenancy_start'],
 true),

('Membership Certificate',
 'membership',
 'Membership Certificate — {{member_name}}, Flat {{unit_number}}',
 E'This is to certify that **{{member_name}}** is a registered member of **{{society_name}}** having its registered office at Kondakal, Shankarpalle, Ranga Reddy District, Telangana — 501203.\n\nThe member owns Flat **{{unit_number}}**, {{block}}, measuring approximately **{{sq_ft}} sq ft**, and has been a member since **{{member_since}}**.\n\nThe Society is registered under the Telangana Cooperative Societies Act (CSACT) with Registration No. **{{reg_number}}**.\n\nThis certificate is issued for the purpose of **{{purpose}}** at the request of the member.',
 ARRAY['member_name','unit_number','block','society_name','sq_ft','member_since','reg_number','purpose'],
 true),

('Payment Confirmation Letter',
 'financial',
 'Confirmation of Maintenance Payment — {{unit_number}} for {{period}}',
 E'This is to confirm receipt of maintenance dues from **{{member_name}}**, owner of Flat **{{unit_number}}**, {{block}}.\n\n**Payment Details:**\n\n| Description | Amount |\n|---|---|\n| Maintenance charges for {{period}} | ₹{{base_amount}} |\n| GST @ 18% | ₹{{gst_amount}} |\n| **Total Received** | **₹{{total_amount}}** |\n\nPayment was received via **{{payment_mode}}** on **{{payment_date}}**. Receipt No: **{{receipt_number}}**.\n\nAll dues for the above period are cleared as of this date.',
 ARRAY['member_name','unit_number','block','period','base_amount','gst_amount','total_amount','payment_mode','payment_date','receipt_number'],
 true),

('Dues Demand Notice',
 'notice',
 'Notice — Outstanding Maintenance Dues — Flat {{unit_number}}',
 E'**NOTICE**\n\nThis is to inform **{{member_name}}**, owner / occupant of Flat **{{unit_number}}**, {{block}}, that the following maintenance dues are outstanding and overdue:\n\n| Period | Amount | Due Date |\n|---|---|---|\n{{dues_table}}\n\n**Total Outstanding: ₹{{total_outstanding}}**\n\nYou are hereby requested to clear the above dues **within 7 days** of receipt of this notice to avoid penal interest of 18% per annum as per the Society byelaws.\n\nFailure to pay may result in suspension of Society amenities including parking, facility booking, and visitor access.',
 ARRAY['member_name','unit_number','block','dues_table','total_outstanding'],
 true),

('Renovation / Repair NOC',
 'noc',
 'Permission for Renovation Works — Flat {{unit_number}}',
 E'This is to inform **{{member_name}}**, owner of Flat **{{unit_number}}**, {{block}}, that the Society Management Committee has considered the renovation proposal submitted on **{{application_date}}** and hereby grants permission for the following works:\n\n**Approved Works:** {{approved_works}}\n\n**Conditions:**\n1. Works shall be carried out only between 9:00 AM and 6:00 PM on weekdays.\n2. No structural changes to columns, beams, or slabs without a structural engineer certificate.\n3. All debris to be cleared by the owner; no dumping in common areas.\n4. A refundable deposit of ₹{{deposit}} has been collected.\n5. Works to be completed by **{{completion_date}}**.\n\nThis permission is valid for 60 days from the date of issue.',
 ARRAY['member_name','unit_number','block','application_date','approved_works','deposit','completion_date'],
 true),

('Caretaker / Agent Authorisation',
 'general',
 'Authorisation Letter — Caretaker for Flat {{unit_number}}',
 E'I, **{{member_name}}**, the registered owner of Flat **{{unit_number}}**, {{block}}, {{society_name}}, hereby authorise **{{caretaker_name}}** (Aadhaar: XXXX {{caretaker_aadhaar_last4}}) to act as my authorised representative for the following purposes:\n\n{{authorisation_scope}}\n\nThis authorisation is valid from **{{valid_from}}** to **{{valid_until}}** or until revoked in writing, whichever is earlier.\n\nThe Society is requested to extend cooperation to the above-named representative accordingly.',
 ARRAY['member_name','unit_number','block','society_name','caretaker_name','caretaker_aadhaar_last4','authorisation_scope','valid_from','valid_until'],
 true);

COMMENT ON TABLE letter_content_templates IS 'Reusable letter body templates with {{variable}} substitution for common society letters';
