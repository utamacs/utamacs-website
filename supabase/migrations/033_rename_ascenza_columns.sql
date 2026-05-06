-- Migration 033: Remove builder-specific naming from HOTO schema.
-- Rename ascenza_category → hoto_category (hoto_items)
-- Rename ascenza_reference → builder_ref (snag_items)
-- These columns were named after the initial builder assessment vendor;
-- the names should be generic and contextual to the HOTO process itself.

ALTER TABLE hoto_items  RENAME COLUMN ascenza_category  TO hoto_category;
ALTER TABLE snag_items  RENAME COLUMN ascenza_reference TO builder_ref;
