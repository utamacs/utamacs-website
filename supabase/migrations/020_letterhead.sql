-- Migration 020: Letterhead templates, dynamic fields, and generated letters archive
-- Enables enterprise-grade letter generation with configurable templates stored in GitHub

-- ─── Letterhead Templates ─────────────────────────────────────────────────────
CREATE TABLE letterhead_templates (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id              uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  name                    text NOT NULL,
  -- Header configuration
  logo_path               text NOT NULL DEFAULT 'UTA-MACS-Logo.png',
  society_name            text NOT NULL DEFAULT 'Urban Trilla MACS',
  society_tagline         text NOT NULL DEFAULT 'COMMUNITY • CARE • MAINTENANCE',
  society_reg_no          text NOT NULL DEFAULT 'TG/RRD/MACS/2026-15/FOW & M',
  society_address_line1   text NOT NULL DEFAULT 'SY NO4 25/2/1, KONDAKAL(V),',
  society_address_line2   text NOT NULL DEFAULT 'SHANKARPALLE(M), RANGAREDDY(D),',
  society_address_line3   text NOT NULL DEFAULT '501203, TELANGANA',
  -- Footer configuration
  footer_website          text NOT NULL DEFAULT 'www.utamacs.org',
  footer_phone            text NOT NULL DEFAULT '+91 7032820247',
  footer_email            text NOT NULL DEFAULT 'urbantrillaresidents@gmail.com',
  -- Multi-page configuration
  subsequent_page_header  text NOT NULL DEFAULT 'Urban Trilla MACS — Continued',
  -- Closing block (configurable)
  closing_line1           text NOT NULL DEFAULT 'Thanking you!',
  closing_line2           text NOT NULL DEFAULT 'Yours sincerely',
  -- State
  is_default              boolean NOT NULL DEFAULT false,
  is_active               boolean NOT NULL DEFAULT true,
  created_by              uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_letterhead_templates_society ON letterhead_templates(society_id);
ALTER TABLE letterhead_templates ENABLE ROW LEVEL SECURITY;

-- Only one default template per society
CREATE UNIQUE INDEX idx_letterhead_templates_default
  ON letterhead_templates(society_id)
  WHERE is_default = true;

-- ─── Committee Members (per template) ─────────────────────────────────────────
-- These appear in the header right-column AND are selectable as signatories
CREATE TABLE letterhead_committee_members (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id     uuid NOT NULL REFERENCES letterhead_templates(id) ON DELETE CASCADE,
  name            text NOT NULL,
  designation     text NOT NULL,   -- e.g. 'President', 'General Secretary', 'Treasurer'
  show_in_header  boolean NOT NULL DEFAULT true,   -- appears in header right-column
  show_in_signature boolean NOT NULL DEFAULT true, -- selectable in signature block
  display_order   int NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_letterhead_committee_template ON letterhead_committee_members(template_id);
ALTER TABLE letterhead_committee_members ENABLE ROW LEVEL SECURITY;

-- ─── Dynamic Fields (per template) ────────────────────────────────────────────
-- Configurable input fields shown on the letter generation form
CREATE TABLE letterhead_dynamic_fields (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id     uuid NOT NULL REFERENCES letterhead_templates(id) ON DELETE CASCADE,
  field_key       text NOT NULL,     -- machine key, e.g. 'date', 'to', 'subject'
  display_label   text NOT NULL,     -- human label shown on form, e.g. 'Date', 'To'
  field_type      text NOT NULL DEFAULT 'text'
                  CHECK (field_type IN ('text', 'textarea', 'date', 'richtext')),
  placeholder     text,
  is_required     boolean NOT NULL DEFAULT true,
  display_order   int NOT NULL DEFAULT 0,
  created_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (template_id, field_key)
);

CREATE INDEX idx_letterhead_fields_template ON letterhead_dynamic_fields(template_id);
ALTER TABLE letterhead_dynamic_fields ENABLE ROW LEVEL SECURITY;

-- ─── Generated Letters (metadata; actual files live in GitHub) ────────────────
CREATE TABLE generated_letters (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id       uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  template_id      uuid REFERENCES letterhead_templates(id) ON DELETE SET NULL,
  -- Human identifiers
  title            text NOT NULL,
  subject          text,
  recipient        text,
  -- GitHub storage references
  git_repo         text NOT NULL,    -- e.g. 'utamacs/utamacs-letters'
  git_path_pdf     text,             -- e.g. 'letters/2026/05-May/20260504-slug.pdf'
  git_path_docx    text,             -- e.g. 'letters/2026/05-May/20260504-slug.docx'
  git_sha_pdf      text,             -- GitHub blob SHA (for future updates)
  git_sha_docx     text,
  -- Snapshot of all values used (for audit / regeneration)
  field_values     jsonb NOT NULL DEFAULT '{}',
  signatures_used  text[] NOT NULL DEFAULT '{}',
  created_by       uuid REFERENCES profiles(id) ON DELETE SET NULL,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_generated_letters_society ON generated_letters(society_id, created_at DESC);
CREATE INDEX idx_generated_letters_created_by ON generated_letters(created_by);
ALTER TABLE generated_letters ENABLE ROW LEVEL SECURITY;

-- ─── RLS Policies ─────────────────────────────────────────────────────────────
-- Templates: admin/executive can manage; all authenticated users can read
CREATE POLICY "letterhead_templates_read" ON letterhead_templates
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "letterhead_templates_write" ON letterhead_templates
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid()
        AND society_id = letterhead_templates.society_id
        AND role IN ('admin', 'executive')
    )
  );

CREATE POLICY "letterhead_committee_read" ON letterhead_committee_members
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "letterhead_committee_write" ON letterhead_committee_members
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM letterhead_templates lt
      JOIN user_roles ur ON ur.society_id = lt.society_id
      WHERE lt.id = letterhead_committee_members.template_id
        AND ur.user_id = auth.uid()
        AND ur.role IN ('admin', 'executive')
    )
  );

CREATE POLICY "letterhead_fields_read" ON letterhead_dynamic_fields
  FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "letterhead_fields_write" ON letterhead_dynamic_fields
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM letterhead_templates lt
      JOIN user_roles ur ON ur.society_id = lt.society_id
      WHERE lt.id = letterhead_dynamic_fields.template_id
        AND ur.user_id = auth.uid()
        AND ur.role IN ('admin', 'executive')
    )
  );

-- Generated letters: only admin/executive can see; creators see their own
CREATE POLICY "generated_letters_read" ON generated_letters
  FOR SELECT USING (
    created_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid()
        AND society_id = generated_letters.society_id
        AND role IN ('admin', 'executive')
    )
  );

CREATE POLICY "generated_letters_write" ON generated_letters
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid()
        AND society_id = generated_letters.society_id
        AND role IN ('admin', 'executive')
    )
  );

-- ─── Updated-at trigger ────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_letterhead_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_letterhead_templates_updated_at
  BEFORE UPDATE ON letterhead_templates
  FOR EACH ROW EXECUTE FUNCTION update_letterhead_updated_at();

-- ─── Seed default template ────────────────────────────────────────────────────
DO $$
DECLARE
  v_society_id uuid := '00000000-0000-0000-0000-000000000001';
  v_template_id uuid;
BEGIN
  INSERT INTO letterhead_templates (
    society_id, name, is_default,
    society_name, society_tagline, society_reg_no,
    society_address_line1, society_address_line2, society_address_line3,
    footer_website, footer_phone, footer_email,
    subsequent_page_header, closing_line1, closing_line2
  ) VALUES (
    v_society_id, 'Standard Letterhead', true,
    'Urban Trilla MACS', 'COMMUNITY • CARE • MAINTENANCE', 'TG/RRD/MACS/2026-15/FOW & M',
    'SY NO4 25/2/1, KONDAKAL(V),', 'SHANKARPALLE(M), RANGAREDDY(D),', '501203, TELANGANA',
    'www.utamacs.org', '+91 7032820247', 'urbantrillaresidents@gmail.com',
    'Urban Trilla MACS — Continued', 'Thanking you!', 'Yours sincerely'
  )
  ON CONFLICT DO NOTHING
  RETURNING id INTO v_template_id;

  IF v_template_id IS NOT NULL THEN
    -- Default committee members (matches actual committee data from letterhead PDF)
    INSERT INTO letterhead_committee_members (template_id, name, designation, display_order) VALUES
      (v_template_id, 'Mr. K Bal Reddy',      'President',  1),
      (v_template_id, 'Mr. Prashant Panikar', 'Secretary',  2),
      (v_template_id, 'Mr. V Suresh Kumar',   'Treasurer',  3);

    -- Default dynamic fields matching the letterhead template
    INSERT INTO letterhead_dynamic_fields (template_id, field_key, display_label, field_type, placeholder, is_required, display_order) VALUES
      (v_template_id, 'date',         'Date',              'date',     NULL,                          true,  1),
      (v_template_id, 'to',           'To (Recipient)',    'textarea', 'Name and address of recipient', true,  2),
      (v_template_id, 'subject',      'Subject',           'text',     'Subject of the letter',        true,  3),
      (v_template_id, 'tosalutation', 'Salutation',        'text',     'e.g. Sir / Madam / Sir/Madam', true,  4),
      (v_template_id, 'message',      'Message Body',      'textarea', 'Body of the letter',           true,  5);
  END IF;
END $$;
