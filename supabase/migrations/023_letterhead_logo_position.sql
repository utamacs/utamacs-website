-- Migration 023: Add logo vertical alignment to letterhead_templates
ALTER TABLE letterhead_templates
  ADD COLUMN IF NOT EXISTS logo_valign text NOT NULL DEFAULT 'top'
    CHECK (logo_valign IN ('top', 'center', 'bottom'));
