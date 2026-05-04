-- Migration 024: Configurable logo width and horizontal alignment for letterhead templates
ALTER TABLE letterhead_templates
  ADD COLUMN IF NOT EXISTS logo_width_px  integer NOT NULL DEFAULT 0
    CHECK (logo_width_px >= 0 AND logo_width_px <= 800),
  ADD COLUMN IF NOT EXISTS logo_halign    text    NOT NULL DEFAULT 'left'
    CHECK (logo_halign IN ('left', 'center', 'right'));
