-- Migration 022: Add style configuration columns to letterhead_templates
-- Allows per-template control of logo size, font sizes, and address column width

ALTER TABLE letterhead_templates
  ADD COLUMN IF NOT EXISTS logo_height_px     integer      NOT NULL DEFAULT 160,
  ADD COLUMN IF NOT EXISTS body_font_size_pt  numeric(4,1) NOT NULL DEFAULT 11.0,
  ADD COLUMN IF NOT EXISTS header_font_size_pt numeric(4,1) NOT NULL DEFAULT 8.5,
  ADD COLUMN IF NOT EXISTS addr_col_width_px  integer      NOT NULL DEFAULT 210;
