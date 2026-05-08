-- Migration 068: Upload size limits as configurable rules
-- All per-module file upload limits are now DB rules editable via /portal/admin/rules.
-- Values in MB (integers). API routes read via ruleInt(rules, 'UPLOAD_LIMIT_X_MB', default).

INSERT INTO rules (society_id, rule_category, rule_code, label, description, byelaw_reference,
                   value_type, current_value, default_value, is_locked)
SELECT s.id,
       r.rule_category, r.rule_code, r.label, r.description, r.byelaw_reference,
       r.value_type, r.current_value::jsonb, r.default_value::jsonb, r.is_locked
FROM societies s,
(VALUES

  -- ── Notice attachments ────────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_NOTICES_MB',
   'Notice attachment size limit (MB)',
   'Maximum file size for images or PDFs attached to notices and circulars.',
   null, 'INTEGER', '10', '10', false),

  -- ── Policy documents ──────────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_POLICIES_MB',
   'Policy document size limit (MB)',
   'Maximum file size for policy PDFs uploaded via the Policies & Compliance module.',
   null, 'INTEGER', '20', '20', false),

  -- ── Complaint attachments ─────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_COMPLAINTS_MB',
   'Complaint attachment size limit (MB)',
   'Maximum file size per complaint attachment. Set higher (e.g. 50) to allow video evidence.',
   null, 'INTEGER', '50', '50', false),

  -- ── Gallery ───────────────────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_GALLERY_MB',
   'Gallery photo size limit (MB)',
   'Maximum file size per photo uploaded to the Photo Gallery.',
   null, 'INTEGER', '10', '10', false),

  -- ── Community board ───────────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_COMMUNITY_MB',
   'Community post image size limit (MB)',
   'Maximum file size per image attached to a Community Board post.',
   null, 'INTEGER', '5', '5', false),

  ('UPLOAD', 'COMMUNITY_POST_MAX_IMAGES',
   'Community post maximum images',
   'Maximum number of images allowed per Community Board post.',
   null, 'INTEGER', '5', '5', false),

  -- ── Maid registry ─────────────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_MAIDS_MB',
   'Maid KYC file size limit (MB)',
   'Maximum file size for maid photos and ID documents in the Domestic Help Registry.',
   null, 'INTEGER', '5', '5', false),

  -- ── Profile avatars ───────────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_AVATARS_MB',
   'Profile avatar size limit (MB)',
   'Maximum file size for member profile photos and staff avatars.',
   null, 'INTEGER', '2', '2', false),

  -- ── Membership documents ──────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_MEMBERSHIPS_MB',
   'Membership document size limit (MB)',
   'Maximum file size for membership documents such as sale deeds and share certificates.',
   null, 'INTEGER', '10', '10', false),

  -- ── Events ────────────────────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_EVENTS_MB',
   'Event banner size limit (MB)',
   'Maximum file size for event banner images.',
   null, 'INTEGER', '5', '5', false),

  -- ── Vendors ───────────────────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_VENDORS_MB',
   'Vendor invoice size limit (MB)',
   'Maximum file size for vendor invoice PDFs uploaded to work orders.',
   null, 'INTEGER', '10', '10', false),

  -- ── Parking ───────────────────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_PARKING_MB',
   'Parking document size limit (MB)',
   'Maximum file size for RC books and insurance documents in Parking Management.',
   null, 'INTEGER', '5', '5', false),

  -- ── Snag attachments ──────────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_SNAGS_MB',
   'Snag attachment size limit (MB)',
   'Maximum file size per snag/defect attachment. Set high to allow video captures of defects.',
   null, 'INTEGER', '50', '50', false),

  -- ── HOTO governance documents ─────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_HOTO_MB',
   'HOTO document size limit (MB)',
   'Maximum file size for governance documents uploaded via the HOTO module.',
   null, 'INTEGER', '5', '5', false),

  -- ── Document library ──────────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_DOCUMENTS_MB',
   'Document library file size limit (MB)',
   'Maximum file size for files uploaded to the general Document Library (bylaws, minutes, etc.).',
   null, 'INTEGER', '20', '20', false),

  -- ── Staff KYC ─────────────────────────────────────────────────────────────
  ('UPLOAD', 'UPLOAD_LIMIT_STAFF_KYC_MB',
   'Staff KYC file size limit (MB)',
   'Maximum file size for staff photos and ID documents in the Staff & Maid KYC module.',
   null, 'INTEGER', '5', '5', false)

) AS r(rule_category, rule_code, label, description, byelaw_reference,
       value_type, current_value, default_value, is_locked)
ON CONFLICT (society_id, rule_code) DO NOTHING;
