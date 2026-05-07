-- ═══════════════════════════════════════════════════════════════
-- 050_document_library_enhancements.sql
-- Document library: folders, expanded categories, tags, archive
-- ═══════════════════════════════════════════════════════════════

-- ── Folders ───────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS document_folders (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  society_id  uuid NOT NULL REFERENCES societies(id) ON DELETE CASCADE,
  name        text NOT NULL CHECK (length(name) BETWEEN 1 AND 100),
  parent_id   uuid REFERENCES document_folders(id) ON DELETE SET NULL,
  description text CHECK (length(description) <= 300),
  display_order int NOT NULL DEFAULT 0,
  created_by  uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE document_folders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "member_read_folders" ON document_folders FOR SELECT
  USING (society_id IN (SELECT society_id FROM profiles WHERE id = auth.uid()));

CREATE POLICY "exec_manage_folders" ON document_folders FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      JOIN user_roles r ON r.user_id = p.id AND r.society_id = p.society_id
      WHERE p.id = auth.uid()
        AND p.society_id = document_folders.society_id
        AND r.role IN ('executive', 'admin')
    )
  );

CREATE INDEX IF NOT EXISTS idx_doc_folders_society ON document_folders(society_id, parent_id);

-- ── Documents enhancements ────────────────────────────────────────────────────

-- Link documents to optional folder
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS folder_id     uuid REFERENCES document_folders(id) ON DELETE SET NULL;

-- Flexible tagging (e.g. 'agm-2024', 'approved', 'draft')
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS tags          text[] NOT NULL DEFAULT '{}';

-- Soft-archive without deletion
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS is_archived   boolean NOT NULL DEFAULT false;

-- Track unique downloads (incremented by API on each signed-URL generation)
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS download_count int NOT NULL DEFAULT 0;

-- Expand category set: drop old anonymous constraint, add named one
ALTER TABLE documents DROP CONSTRAINT IF EXISTS documents_category_check;

ALTER TABLE documents
  ADD CONSTRAINT documents_category_check
    CHECK (category IN (
      'Bylaws', 'Minutes', 'Financial', 'Legal',
      'Circulars', 'Forms', 'HOTO', 'Governance', 'Maintenance', 'Other'
    ));

-- ── Indexes ───────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_documents_folder ON documents(folder_id) WHERE folder_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_documents_archived ON documents(society_id, is_archived, category);
CREATE INDEX IF NOT EXISTS idx_documents_tags ON documents USING gin(tags);
